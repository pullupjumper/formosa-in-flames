local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Cycle = require("src.modules.missileSystem.cycle")
local Triggers = require("src.modules.missileSystem.triggers")
local Deployment = require("src.modules.missileSystem.deployment")
local Context = require("src.modules.missileSystem.context")
local StatusView = require("src.modules.missileSystem.statusView")
local ControlPanelLayout = require("src.modules.missileSystem.controlPanelLayout")

local MissileSystem = {}

---Firing unit states in which the unit is out of its hide area and has to be stowed back
---Manual mode for flows that must never halt a unit
local MANUAL_MODE = false

local DEPLOYED_STATES = {
  [constants.MISSILE_SYSTEM_STATE.STATIC] = true,
  [constants.MISSILE_SYSTEM_STATE.REPOSITIONING] = true
}

---Position types whose zones and triggers are rebuilt when batteries are redeployed
local REDEPLOY_POSITION_TYPES = {
  constants.POSITION_TYPES.RELOAD_POINT,
  constants.POSITION_TYPES.FIRING_POINT,
  constants.POSITION_TYPES.HIDE_AREA,
  constants.POSITION_TYPES.AMMO_HOLDING_AREA
}

---Extract position type token from UnitEntersArea trigger description
---@param event CMO__Event|nil
---@return string|nil # Position type token (FP/AHA/HA/RL)
local function resolvePositionType(event)
  if not event or not event.triggers then
    return nil
  end

  for _, trigger in ipairs(event.triggers) do
    local entersArea = trigger["UnitEntersArea"]
    if entersArea and entersArea.Description then
      local positionType = string.match(entersArea.Description, "Arrive in (FP) ") or
          string.match(entersArea.Description, "Arrive in (AHA) ") or
          string.match(entersArea.Description, "Arrive in (HA) ") or
          string.match(entersArea.Description, "Arrive in (RL) ")
      if positionType then
        return positionType
      end
    end
  end

  return nil
end

---Drop contact entries that point to the incoming unit
---@param unit CMO__Unit
---@param contacts CMO__Contact[]|nil
local function dropUnitContact(unit, contacts)
  if not contacts then
    return
  end

  for _, contact in ipairs(contacts) do
    if unit.guid == contact.actualunitid then
      contact:DropContact()
    end
  end
end

---Command firing unit to move to firing point (FP), logging any failure
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
local function startMoveToFiringPoint(firingUnitCtx, firingUnit)
  local success, errorFields = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
  if not success and errorFields then
    Logger.error(LogFormat.line("FAIL", LogFormat.merge({
      module = constants.TAGS.MISSILE_SYSTEM,
      action = "move_to_firing_point",
      unit = firingUnitCtx.name or firingUnit.name
    }, errorFields)))
  end
end

---Check if a firing unit is below its own ammunition threshold
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnitCtx, firingUnit)
  return Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
end

---Send a firing unit from its hide area to its firing point when it is ready
---A unit is ready when it is hiding with enough ammunition; units already out are left alone.
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@return boolean inPosition Whether the unit is at its firing point
function MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)
  if firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE and
      not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Concealment.moveFromHideArea(firingUnitCtx, firingUnit)
    startMoveToFiringPoint(firingUnitCtx, firingUnit)
  end

  return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.STATIC
end

---Calculate ammunition inventory across firing/resupply/ammo for a missile system
---@param groundCtx SBJ__GroundContext
---@param missileSystemType string Missile system type (constants.MISSILE_SYSTEM_TYPES)
---@param sideName string
---@return SBJ__AmmoInventoryResult|nil # Inventory report with subtotals and percentages, nil when the system is absent
function MissileSystem.getAmmoInventory(groundCtx, missileSystemType, sideName)
  local systemCtx = groundCtx.missileSystemTypes[missileSystemType]
  if not systemCtx then
    return nil
  end

  return Ammo.getInventory(systemCtx, sideName)
end

---Resolve a firing unit runtime context by missile system and unit name
---@param groundCtx SBJ__GroundContext
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return SBJ__FiringUnitContext|nil # Firing unit runtime context, or nil when missing
function MissileSystem.getFiringUnitContext(groundCtx, missileSystemType, firingUnitName)
  local systemCtx = groundCtx.missileSystemTypes[string.lower(missileSystemType)] --[[@as SBJ__MissileSystemContext?]]
  return systemCtx and systemCtx.firingUnits and systemCtx.firingUnits[firingUnitName]
end

---Start the stow countdown so the reload cycle sends the firing units back
---SAM never stows, and a countdown already running is kept.
---@param groundCtx SBJ__GroundContext
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
---@param opts {onlyDeployed: boolean}|nil onlyDeployed skips units still in their hide area or reloading
function MissileSystem.startStow(groundCtx, missileSystemType, firingUnits, opts)
  if not missileSystemType or not firingUnits or string.lower(missileSystemType) == constants.MISSILE_SYSTEM_TYPES.SAM then
    return
  end

  local onlyDeployed = opts and opts.onlyDeployed
  local currentTime = GameApi.ScenEdit_CurrentTime()

  for _, firingUnit in ipairs(firingUnits) do
    local firingUnitCtx = MissileSystem.getFiringUnitContext(groundCtx, missileSystemType, firingUnit.name)

    if firingUnitCtx and not firingUnitCtx.stowStartTime and (not onlyDeployed or DEPLOYED_STATES[firingUnitCtx.state]) then
      firingUnitCtx.stowStartTime = currentTime
    end
  end
end

---Check status of all missile systems and trigger corresponding actions
---@param groundCtx SBJ__GroundContext
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param isAuto boolean
---@param sideName string
function MissileSystem.process(groundCtx, missileSystemConfigMap, isAuto, sideName)
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Reload cycle")

  for missileSystemType, systemCtx in pairs(groundCtx.missileSystemTypes) do
    if systemCtx.enabled then
      for _, result in ipairs(Cycle.process(systemCtx, { systemConfig = missileSystemConfigMap[missileSystemType], isAuto = isAuto }, sideName)) do
        result.fields.system = missileSystemType
        report.add(result.tag, result.fields)
      end
    end
  end

  report.emit({ mode = isAuto and "auto" or "manual" })
end

---Run one reload/hide cycle for a side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.processSide(config, saveData, sideName)
  local sideConfig = config[GameUtils.getCachedSideConfig(sideName).field]

  MissileSystem.process(
    PersistentState.ground(saveData, sideName),
    sideConfig.ground.missileSystemTypes,
    sideConfig.ground.policy.isAuto,
    sideName
  )
end

---Deduct ammunition when an ammo depot or resupply vehicle of any missile system is destroyed
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@return boolean processed Whether the unit belonged to a missile system and ammo was adjusted
function MissileSystem.processSupplyAssetDestruction(saveData, unit)
  local groundCtx = PersistentState.ground(saveData, unit.side)

  for _, systemCtx in pairs(groundCtx.missileSystemTypes) do
    local success, result = Context.processSupplyAssetDestruction(unit, systemCtx)

    -- A destroyed unit belongs to at most one system, so the first match ends the search.
    if success and result then
      Logger.log(constants.TAGS.MISSILE_SYSTEM, LogFormat.line(result.tag, {
        system = result.system,
        action = "supply_asset_destroyed",
        role = result.role,
        unit = result.unitName,
        context = result.contextName,
        ammoBefore = result.ammoBefore,
        ammoAfter = result.ammoAfter,
        delta = result.delta
      }))
      return true
    end
  end

  return false
end

---Move batteries to player-chosen operational areas, then rebuild their zones, units and state
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundCtx SBJ__GroundContext
---@param sideName string
---@param layouts SBJ__MissileSystemLayout[]
function MissileSystem.redeploy(missileSystemConfigMap, groundCtx, sideName, layouts)
  local operationalAreas, operationalAreasToRemove = Deployment.updateLayouts(missileSystemConfigMap, layouts)

  Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, REDEPLOY_POSITION_TYPES, sideName)
  Deployment.addMissileSystems(missileSystemConfigMap, sideName)
  Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)
end

---Redeploy a side's batteries to the placements submitted by the control panel
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param entries SBJ__MissileSystemResult[]
function MissileSystem.redeployFromControlPanel(config, saveData, sideName, entries)
  MissileSystem.redeploy(
    config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes,
    PersistentState.ground(saveData, sideName),
    sideName,
    ControlPanelLayout.buildLayouts(entries)
  )
end

---Build a side's missile system rows for the control panel
---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig> # Config copies with zone vertices, keyed by system type
function MissileSystem.buildDeploymentSystems(config, sideName)
  return ControlPanelLayout.buildDeploymentSystems(
    config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes,
    sideName
  )
end

---Add a side's missile system units and build their runtime contexts from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.deploySide(config, saveData, sideName)
  local missileSystemConfigMap = config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes

  Deployment.addMissileSystems(missileSystemConfigMap, sideName)
  Context.initMissileSystemContexts(missileSystemConfigMap, PersistentState.ground(saveData, sideName))
end

---Build a side's battery statuses for the control panel, one per battery (firing unit plus its paired resupply unit)
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@return SBJ__BatteryStatus[] # One status per battery
function MissileSystem.buildBatteryStatuses(config, saveData, sideName)
  return StatusView.buildBatteryStatuses(
    PersistentState.ground(saveData, sideName),
    config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes,
    GameApi.ScenEdit_CurrentTime()
  )
end

---Seed a side's default per-system state (name, enabled, empty unit maps) from configuration
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.ensureGroundState(config, saveData, sideName)
  Context.ensureGroundState(
    config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes,
    PersistentState.ground(saveData, sideName)
  )
end

---Initialize a side's missile system runtime contexts from configuration when its ground forces are enabled
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.initSide(config, saveData, sideName)
  local groundCtx = PersistentState.ground(saveData, sideName)
  if not groundCtx.enabled then
    return
  end

  Context.initMissileSystemContexts(config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes,
    groundCtx)
end

---Iterate through enabled missile systems only
---@param groundCtx SBJ__GroundContext
---@param callback fun(systemCtx: SBJ__MissileSystemContext, missileSystemType: string)
local function forEachEnabledSystem(groundCtx, callback)
  for missileSystemType, systemCtx in pairs(groundCtx.missileSystemTypes) do
    if systemCtx.enabled then
      callback(systemCtx, missileSystemType)
    end
  end
end

---Handle entering firing point logic for a single missile system context
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param missileSystemType string
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext Side-specific switches, unused here
---@return SBJ__LogResult|nil result Deferred log row when state changed
local function processFiringPoint(missileSystemType, systemCtx, unit, moveCtx)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if Movement.isRepositioning(firingUnitCtx, moveCtx.isAuto) then
    Movement.setWCSToFree(firingUnitCtx, unit, moveCtx.isAuto)
    return {
      tag = "OK",
      fields = { system = missileSystemType, unit = unit.name, action = "firing_ready", state = "STATIC", wcs = "FREE" }
    }
  end

  return nil
end

---Handle entering hide area logic for a single missile system context
---@param missileSystemType string
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the hide flow ran
local function processHideArea(missileSystemType, systemCtx, unit, moveCtx)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if not firingUnitCtx then
    return nil
  end

  if moveCtx.hideOnEnterHA and not Ammo.isLowAmmo(unit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Movement.setStateToHide(firingUnitCtx, unit, moveCtx.isAuto)
    local success, errorFields = Concealment.hideUnit(firingUnitCtx, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = missileSystemType,
          unit = unit.name,
          action = "concealment_failed",
          state = "HIDE"
        }, errorFields)
      }
    end

    return { tag = "OK", fields = { system = missileSystemType, unit = unit.name, action = "concealed", state = "HIDE" } }
  end

  return nil
end

---Handle reload-point fallback when no meeting occurs
---@param missileSystemType string
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the fallback performed a visible action
local function processReloadPointNoMeeting(missileSystemType, systemCtx, unit, moveCtx)
  -- Use the manual mode instead of moveCtx so a firing unit drifting through RL during repositioning is not halted.
  Movement.setStateToStatic(systemCtx, unit, MANUAL_MODE)
  if not moveCtx.hideResupplyOnRLNoMeeting then
    return nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]
  if not resupplyUnitCtx then
    return nil
  end

  local firingUnitCtx = systemCtx.firingUnits[resupplyUnitCtx.firingUnit]
  if not firingUnitCtx then
    return nil
  end

  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, moveCtx.firingUnitLookupSide)
  if firingUnit and not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    local success, errorFields = Concealment.hideUnit(resupplyUnitCtx, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = missileSystemType,
          unit = unit.name,
          action = "resupply_concealment_failed",
          pairedFiringUnit = firingUnitCtx.name
        }, errorFields)
      }
    end

    return {
      tag = "OK",
      fields = {
        system = missileSystemType,
        unit = unit.name,
        action = "resupply_concealed",
        pairedFiringUnit = firingUnitCtx.name,
        ammoStatus = "sufficient"
      }
    }
  end

  return nil
end

---Handle entering reload point logic for a single missile system context
---@param missileSystemType string
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the reload flow changed state
local function processReloadPoint(missileSystemType, systemCtx, unit, moveCtx)
  local hasMet, firingUnitCtx = Meeting.hasMetResupplyUnit(systemCtx, unit, moveCtx.isAuto)

  if hasMet and firingUnitCtx then
    local firingUnit = (unit.name == firingUnitCtx.name) and unit or
        GameApi.ScenEdit_GetUnit(firingUnitCtx.name, unit.side)
    if firingUnit then
      Movement.setReloadStartTime(firingUnitCtx, firingUnit, moveCtx.isAuto)
      return {
        tag = "OK",
        fields = {
          system = missileSystemType,
          unit = firingUnitCtx.name,
          action = "reload_started",
          triggerUnit = unit.name,
          state = "RELOAD",
          startedAt = os.date(constants.DATE_FORMAT, firingUnitCtx.reloadStartTime)
        }
      }
    end

    return {
      tag = "WARN",
      fields = {
        system = missileSystemType,
        unit = firingUnitCtx.name,
        action = "reload_not_started",
        triggerUnit = unit.name,
        reason = "firing_unit_not_found"
      }
    }
  end

  return processReloadPointNoMeeting(missileSystemType, systemCtx, unit, moveCtx)
end

---Handle entering ammo holding area logic for a single missile system context
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param missileSystemType string
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext Side-specific switches, unused here
---@return SBJ__LogResult|nil result Deferred log row when the transload flow changed state
local function processAmmoHoldingArea(missileSystemType, systemCtx, unit, moveCtx)
  local hasMet, resupplyUnit = Meeting.hasMetAmmoDepot(systemCtx, unit, moveCtx.isAuto)
  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]

  if resupplyUnitCtx and hasMet and resupplyUnit then
    Movement.setReloadStartTime(resupplyUnit, unit, moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        system = missileSystemType,
        unit = resupplyUnit.name,
        action = "transload_started",
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, resupplyUnitCtx.reloadStartTime)
      }
    }
  end

  Movement.setStateToStatic(systemCtx, unit, moveCtx.isAuto)
  return nil
end

---Position handlers keyed by the token extracted from the event trigger.
---Every entry takes the same arguments so the dispatch site never has to know
---which of them a given handler actually uses.
---@type table<string, fun(missileSystemType: string, systemCtx: SBJ__MissileSystemContext, unit: CMO__Unit, moveCtx: SBJ__MoveToPositionContext): SBJ__LogResult|nil>
local POSITION_HANDLERS = {
  [constants.POSITION_TYPES.FIRING_POINT]      = processFiringPoint,
  [constants.POSITION_TYPES.HIDE_AREA]         = processHideArea,
  [constants.POSITION_TYPES.RELOAD_POINT]      = processReloadPoint,
  [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = processAmmoHoldingArea,
}

---Handle missile system UnitEntersArea flow for FP/HA/RL/AHA positions
---@param params SBJ__MoveToPositionEventParams
local function processMoveToPositionEvent(params)
  local unit = params.unit
  local moveCtx = params.moveCtx
  local positionType = resolvePositionType(params.event)
  local handler = POSITION_HANDLERS[positionType]

  if not handler then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, params.contacts)
  end

  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. unit.side, "Position event")

  forEachEnabledSystem(params.groundCtx, function(systemCtx, missileSystemType)
    local row = handler(missileSystemType, systemCtx, unit, moveCtx)
    if row then
      report.add(row.tag, row.fields)
    end
  end)

  -- position is derived from the event trigger, so it describes the whole batch
  -- rather than any single row.
  report.emit({ mode = moveCtx.isAuto and "auto" or "manual", position = positionType })
end

---Handle a UnitEntersArea event for the triggering unit's side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param event CMO__Event
function MissileSystem.processUnitEntersArea(config, saveData, unit, event)
  local policy = config[GameUtils.getCachedSideConfig(unit.side).field].ground.policy

  processMoveToPositionEvent({
    groundCtx = PersistentState.ground(saveData, unit.side),
    unit = unit,
    event = event,
    contacts = GameApi.ScenEdit_GetContacts(unit.side),
    moveCtx = {
      isAuto = policy.isAuto,
      hideOnEnterHA = policy.hideOnEnterHA,
      hideResupplyOnRLNoMeeting = policy.hideResupplyOnRLNoMeeting,
      firingUnitLookupSide = unit.side
    }
  })
end

return MissileSystem
