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
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
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
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
local function startMoveToFiringPoint(firingUnitState, firingUnit)
  local success, errorFields = Movement.moveToFiringPoint(firingUnitState, firingUnit)
  if not success and errorFields then
    Logger.error(LogFormat.line("FAIL", LogFormat.merge({
      module = constants.TAGS.MISSILE_SYSTEM,
      action = "move_to_firing_point",
      unit = firingUnitState.name or firingUnit.name
    }, errorFields)))
  end
end

---Find a firing unit runtime state by missile system and unit name
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return SBJ__FiringUnitState|nil # Firing unit runtime state, or nil when missing
local function findFiringUnitState(groundState, missileSystemType, firingUnitName)
  local systemState = groundState.missileSystemTypes[string.lower(missileSystemType)] --[[@as SBJ__MissileSystemState?]]
  return systemState and systemState.firingUnits and systemState.firingUnits[firingUnitName]
end

---Send a firing unit from its hide area to its firing point when it is ready
---A unit is ready when it is hiding with enough ammunition; units already out are left alone.
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return boolean inPosition Whether the unit is at its firing point
---@return boolean isMissing Whether the unit no longer exists in game or has no runtime state
function MissileSystem.sendToFiringPoint(groundState, missileSystemType, firingUnitName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  if not firingUnit or not firingUnitState then
    return false, true
  end

  if firingUnitState.state == constants.MISSILE_SYSTEM_STATE.HIDE and
      not Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID) then
    Concealment.moveFromHideArea(firingUnitState, firingUnit)
    startMoveToFiringPoint(firingUnitState, firingUnit)
  end

  return firingUnitState.state == constants.MISSILE_SYSTEM_STATE.STATIC, false
end

---Calculate ammunition inventory across firing/resupply/ammo for a missile system
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system type (constants.MISSILE_SYSTEM_TYPES)
---@param sideName string
---@return SBJ__AmmoInventoryResult|nil # Inventory report with subtotals and percentages, nil when the system is absent
function MissileSystem.getAmmoInventory(groundState, missileSystemType, sideName)
  local systemState = groundState.missileSystemTypes[missileSystemType]
  if not systemState then
    return nil
  end

  return Ammo.getInventory(systemState, sideName)
end

---Evaluate whether a firing unit can take a fire support task, and why not
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@param getUnit fun(name: string): CMO__Unit|nil Called only when the unit has a runtime state
---@return missileSystemReadiness
function MissileSystem.evaluateReadiness(groundState, missileSystemType, firingUnitName, getUnit)
  local readiness = constants.MISSILE_SYSTEM_READINESS
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  if not firingUnitState then
    return readiness.NO_STATE
  end

  local firingUnit = getUnit(firingUnitName)
  if not firingUnit then
    return readiness.UNIT_NOT_FOUND
  end

  if firingUnitState.state ~= constants.MISSILE_SYSTEM_STATE.HIDE then
    return readiness.NOT_HIDDEN
  end

  if Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID) then
    return readiness.LOW_AMMO
  end

  return readiness.READY
end

---Start the stow countdown so the reload cycle sends the firing units back
---SAM never stows, and a countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
---@param opts {onlyDeployed: boolean}|nil onlyDeployed skips units still in their hide area or reloading
function MissileSystem.startStow(groundState, missileSystemType, firingUnits, opts)
  if not missileSystemType or not firingUnits or string.lower(missileSystemType) == constants.MISSILE_SYSTEM_TYPES.SAM then
    return
  end

  local onlyDeployed = opts and opts.onlyDeployed
  local currentTime = GameApi.ScenEdit_CurrentTime()

  for _, firingUnit in ipairs(firingUnits) do
    local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnit.name)

    if firingUnitState and not firingUnitState.stowStartTime and (not onlyDeployed or DEPLOYED_STATES[firingUnitState.state]) then
      firingUnitState.stowStartTime = currentTime
    end
  end
end

---Check status of all missile systems and trigger corresponding actions
---@param groundState SBJ__GroundState
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param isAuto boolean
---@param sideName string
local function process(groundState, missileSystemConfigMap, isAuto, sideName)
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Reload cycle")

  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    if systemState.enabled then
      for _, result in ipairs(Cycle.process(systemState, { systemConfig = missileSystemConfigMap[missileSystemType], isAuto = isAuto }, sideName)) do
        result.fields.system = missileSystemType
        report.add(result.tag, result.fields)
      end
    end
  end

  report.emit({ mode = isAuto and "auto" or "manual" })
end

---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig>
local function getMissileSystemTypes(config, sideName)
  return config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes
end

---Run one reload/hide cycle for a side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.processSide(config, saveData, sideName)
  local sideConfig = config[GameUtils.getCachedSideConfig(sideName).field]

  process(
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
  local groundState = PersistentState.ground(saveData, unit.side)

  for _, systemState in pairs(groundState.missileSystemTypes) do
    local success, result = GroundStateStore.processSupplyAssetDestruction(unit, systemState)

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
---@param groundState SBJ__GroundState
---@param sideName string
---@param layouts SBJ__MissileSystemLayout[]
local function redeploy(missileSystemConfigMap, groundState, sideName, layouts)
  local operationalAreas, operationalAreasToRemove = Deployment.updateLayouts(missileSystemConfigMap, layouts)

  Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, REDEPLOY_POSITION_TYPES, sideName)
  local rebuiltFiringUnits = {}
  for _, layout in ipairs(layouts) do
    rebuiltFiringUnits[layout.unitname] = true
  end
  Deployment.addMissileSystems(missileSystemConfigMap, sideName, rebuiltFiringUnits)
  GroundStateStore.initMissileSystemStates(missileSystemConfigMap, groundState)
end

---Redeploy a side's batteries to the placements submitted by the control panel
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param entries SBJ__MissileSystemResult[]
function MissileSystem.redeployFromControlPanel(config, saveData, sideName, entries)
  redeploy(
    getMissileSystemTypes(config, sideName),
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
    getMissileSystemTypes(config, sideName),
    sideName
  )
end

---Add a side's missile system units and build their runtime states from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.deploySide(config, saveData, sideName)
  local missileSystemConfigMap = getMissileSystemTypes(config, sideName)

  Deployment.addMissileSystems(missileSystemConfigMap, sideName)
  GroundStateStore.initMissileSystemStates(missileSystemConfigMap, PersistentState.ground(saveData, sideName))
end

---Build a side's battery statuses for the control panel, one per battery (firing unit plus its paired resupply unit)
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@return SBJ__BatteryStatus[] # One status per battery
function MissileSystem.buildBatteryStatuses(config, saveData, sideName)
  return StatusView.buildBatteryStatuses(
    PersistentState.ground(saveData, sideName),
    getMissileSystemTypes(config, sideName),
    GameApi.ScenEdit_CurrentTime()
  )
end

---Seed a side's default per-system state (name, enabled, empty unit maps) from configuration
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.ensureGroundState(config, saveData, sideName)
  GroundStateStore.ensureGroundState(
    getMissileSystemTypes(config, sideName),
    PersistentState.ground(saveData, sideName)
  )
end

---Initialize a side's missile system runtime states from configuration when its ground forces are enabled
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.initSide(config, saveData, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  if not groundState.enabled then
    return
  end

  GroundStateStore.initMissileSystemStates(getMissileSystemTypes(config, sideName), groundState)
end

---Iterate through enabled missile systems only
---@param groundState SBJ__GroundState
---@param callback fun(systemState: SBJ__MissileSystemState, missileSystemType: string)
local function forEachEnabledSystem(groundState, callback)
  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    if systemState.enabled then
      callback(systemState, missileSystemType)
    end
  end
end

---Handle entering firing point logic for a single missile system state
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param missileSystemType string
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext Side-specific switches, unused here
---@return SBJ__LogResult|nil result Deferred log row when state changed
local function processFiringPoint(missileSystemType, systemState, unit, moveCtx)
  local firingUnitState = systemState.firingUnits[unit.name]
  if Movement.isRepositioning(firingUnitState, moveCtx.isAuto) then
    Movement.setWCSToFree(firingUnitState, unit, moveCtx.isAuto)
    return {
      tag = "OK",
      fields = { system = missileSystemType, unit = unit.name, action = "firing_ready", state = "STATIC", wcs = "FREE" }
    }
  end

  return nil
end

---Handle entering hide area logic for a single missile system state
---@param missileSystemType string
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the hide flow ran
local function processHideArea(missileSystemType, systemState, unit, moveCtx)
  local firingUnitState = systemState.firingUnits[unit.name]
  if not firingUnitState then
    return nil
  end

  if moveCtx.hideOnEnterHA and not Ammo.isLowAmmo(unit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID) then
    Movement.setStateToHide(firingUnitState, unit, moveCtx.isAuto)
    local success, errorFields = Concealment.hideUnit(firingUnitState, unit)
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
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the fallback performed a visible action
local function processReloadPointNoMeeting(missileSystemType, systemState, unit, moveCtx)
  -- Use the manual mode instead of moveCtx so a firing unit drifting through RL during repositioning is not halted.
  Movement.setStateToStatic(systemState, unit, MANUAL_MODE)
  if not moveCtx.hideResupplyOnRLNoMeeting then
    return nil
  end

  local resupplyUnitState = systemState.resupplyUnits[unit.name]
  if not resupplyUnitState then
    return nil
  end

  local firingUnitState = systemState.firingUnits[resupplyUnitState.firingUnit]
  if not firingUnitState then
    return nil
  end

  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitState.name, moveCtx.firingUnitLookupSide)
  if firingUnit and not Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID) then
    local success, errorFields = Concealment.hideUnit(resupplyUnitState, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = missileSystemType,
          unit = unit.name,
          action = "resupply_concealment_failed",
          pairedFiringUnit = firingUnitState.name
        }, errorFields)
      }
    end

    return {
      tag = "OK",
      fields = {
        system = missileSystemType,
        unit = unit.name,
        action = "resupply_concealed",
        pairedFiringUnit = firingUnitState.name,
        ammoStatus = "sufficient"
      }
    }
  end

  return nil
end

---Handle entering reload point logic for a single missile system state
---@param missileSystemType string
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext
---@return SBJ__LogResult|nil result Deferred log row when the reload flow changed state
local function processReloadPoint(missileSystemType, systemState, unit, moveCtx)
  local hasMet, firingUnitState = Meeting.hasMetResupplyUnit(systemState, unit, moveCtx.isAuto)

  if hasMet and firingUnitState then
    local firingUnit = (unit.name == firingUnitState.name) and unit or
        GameApi.ScenEdit_GetUnit(firingUnitState.name, unit.side)
    if firingUnit then
      Movement.setReloadStartTime(firingUnitState, firingUnit, moveCtx.isAuto)
      return {
        tag = "OK",
        fields = {
          system = missileSystemType,
          unit = firingUnitState.name,
          action = "reload_started",
          triggerUnit = unit.name,
          state = "RELOAD",
          startedAt = os.date(constants.DATE_FORMAT, firingUnitState.reloadStartTime)
        }
      }
    end

    return {
      tag = "WARN",
      fields = {
        system = missileSystemType,
        unit = firingUnitState.name,
        action = "reload_not_started",
        triggerUnit = unit.name,
        reason = "firing_unit_not_found"
      }
    }
  end

  return processReloadPointNoMeeting(missileSystemType, systemState, unit, moveCtx)
end

---Handle entering ammo holding area logic for a single missile system state
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param missileSystemType string
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param moveCtx SBJ__MoveToPositionContext Side-specific switches, unused here
---@return SBJ__LogResult|nil result Deferred log row when the transload flow changed state
local function processAmmoHoldingArea(missileSystemType, systemState, unit, moveCtx)
  local hasMet, resupplyUnit = Meeting.hasMetAmmoDepot(systemState, unit, moveCtx.isAuto)
  local resupplyUnitState = systemState.resupplyUnits[unit.name]

  if resupplyUnitState and hasMet and resupplyUnit then
    Movement.setReloadStartTime(resupplyUnit, unit, moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        system = missileSystemType,
        unit = resupplyUnit.name,
        action = "transload_started",
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, resupplyUnitState.reloadStartTime)
      }
    }
  end

  Movement.setStateToStatic(systemState, unit, moveCtx.isAuto)
  return nil
end

---Position handlers keyed by the token extracted from the event trigger.
---Every entry takes the same arguments so the dispatch site never has to know
---which of them a given handler actually uses.
---@type table<string, fun(missileSystemType: string, systemState: SBJ__MissileSystemState, unit: CMO__Unit, moveCtx: SBJ__MoveToPositionContext): SBJ__LogResult|nil>
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

  forEachEnabledSystem(params.groundState, function(systemState, missileSystemType)
    local row = handler(missileSystemType, systemState, unit, moveCtx)
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
    groundState = PersistentState.ground(saveData, unit.side),
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
