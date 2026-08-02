local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Cycle = require("src.modules.missileSystem.cycle")
local Triggers = require("src.modules.missileSystem.triggers")
local Deployment = require("src.modules.missileSystem.deployment")
local Context = require("src.modules.missileSystem.context")

local MissileSystem = {}

---Extract position type token from UnitEntersArea trigger description
---@param event CMO__Event|nil Scenario event object
---@return string|nil # Position type token (FP/AHA/HA/RL)
local function extractPositionType(event)
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
---@param unit CMO__Unit Unit entering area
---@param contacts CMO__Contact[]|nil Contacts list from ScenEdit_GetContacts
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

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success Whether the move was successful
function MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)
  local success, errorFields = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
  if not success and errorFields then
    Logger.error(LogFormat.line("FAIL", LogFormat.merge({
      module = constants.TAGS.MISSILE_SYSTEM,
      action = "move_to_firing_point",
      unit = firingUnitCtx and firingUnitCtx.name or firingUnit and firingUnit.name
    }, errorFields)))
  end
  return success
end

---Unload firing unit group from hide area buildings
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to unload
---@return boolean success Whether unload was performed
---@return table<string, any>? errorFields Log fields describing the failure
function MissileSystem.moveFromHideArea(unitCtx, unit)
  return Concealment.moveFromHideArea(unitCtx, unit)
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number|nil Percentage threshold
---@param weaponDBID number|number[]|nil Weapon database ID(s)
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  return Ammo.isLowAmmo(firingUnit, percentage, weaponDBID)
end

---Calculate ammunition inventory across firing/resupply/ammo for a missile system
---@param systemCtx SBJ__MissileSystemContext Missile system runtime context
---@param sideName string Side name used to resolve firing units in game state
---@return SBJ__AmmoInventoryReport # Inventory report with subtotals and percentages
function MissileSystem.getAmmoInventory(systemCtx, sideName)
  return Ammo.getInventory(systemCtx, sideName)
end

---Check status of all missile systems and trigger corresponding actions
---@param groundCtx SBJ__GroundForceContext Ground force contexts keyed by missile system type
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(groundCtx, isAuto, sideName)
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Reload cycle")

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      for _, result in ipairs(Cycle.process(systemCtx, isAuto, sideName)) do
        result.fields.system = missileSystem
        report.add(result.tag, result.fields)
      end
    end
  end

  report.emit({ mode = isAuto and "auto" or "manual" })
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)
  local success, result = Context.handleSupplyAssetDestruction(unit, systemCtx)

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
  end

  return success, result
end

---Initialize event triggers and zones for missile system operational areas
---@param operationalAreas SBJ__OperationalArea[] Array of operational area configurations
---@param operationalAreasToRemove SBJ__OperationalArea[] Array of operational areas to remove triggers for
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function MissileSystem.initEventTriggers(operationalAreas, operationalAreasToRemove, positionTypes, sideName)
  Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, positionTypes, sideName)
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function MissileSystem.addMissileSystems(groundForceCfg, sideName)
  Deployment.addMissileSystems(groundForceCfg, sideName)
end

---Initialize missile system runtime contexts from configuration
---@param groundForceCfg SBJ__GroundForceConfig Ground force configuration
---@param groundForceCtx SBJ__GroundForceContext Ground force runtime context
function MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)
  Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)
end

---Normalize behavior options with default values
---@param behavior SBJ__MoveToPositionBehavior|nil Optional behavior configuration
---@param unitSide string Unit side name used as default lookup side
---@return SBJ__MoveToPositionBehavior # Resolved behavior object
local function resolveBehavior(behavior, unitSide)
  if behavior then
    return behavior
  end

  return {
    hideOnEnterHA = false,
    hideResupplyOnRLNoMeeting = false,
    firingUnitLookupSide = unitSide
  }
end

---Iterate through enabled missile systems only
---@param groundCtx table<string, SBJ__MissileSystemContext> Missile system contexts keyed by system type
---@param callback fun(systemCtx: SBJ__MissileSystemContext, systemName: string) Callback invoked for each enabled system context
local function forEachEnabledSystem(groundCtx, callback)
  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      callback(systemCtx, missileSystem)
    end
  end
end

---Handle entering firing point logic for a single missile system context
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration, unused here
---@return SBJ__LogResult|nil result Deferred log row when state changed
local function handleFiringPoint(systemName, systemCtx, unit, isAuto, behavior)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if Movement.isRepositioning(firingUnitCtx, isAuto) then
    Movement.setWCSToFree(firingUnitCtx, unit, isAuto)
    return {
      tag = "OK",
      fields = { system = systemName, unit = unit.name, action = "firing_ready", state = "STATIC", wcs = "FREE" }
    }
  end

  return nil
end

---Handle entering hide area logic for a single missile system context
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__LogResult|nil result Deferred log row when the hide flow ran
local function handleHideArea(systemName, systemCtx, unit, isAuto, behavior)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if not firingUnitCtx then
    return nil
  end

  if behavior.hideOnEnterHA and not Ammo.isLowAmmo(unit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Movement.setStateToHide(firingUnitCtx, unit, isAuto)
    local success, errorFields = Concealment.hideUnit(firingUnitCtx, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = systemName,
          unit = unit.name,
          action = "concealment_failed",
          state = "HIDE"
        }, errorFields)
      }
    end

    return { tag = "OK", fields = { system = systemName, unit = unit.name, action = "concealed", state = "HIDE" } }
  end

  return nil
end

---Handle reload-point fallback when no meeting occurs
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__LogResult|nil result Deferred log row when the fallback performed a visible action
local function handleReloadPointNoMeeting(systemName, systemCtx, unit, isAuto, behavior)
  -- Pass false instead of isAuto so a firing unit drifting through RL during repositioning is not halted.
  Movement.setStateToStatic(systemCtx, unit, false)
  if not behavior.hideResupplyOnRLNoMeeting then
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

  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, behavior.firingUnitLookupSide)
  if firingUnit and not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    local success, errorFields = Concealment.hideUnit(resupplyUnitCtx, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = systemName,
          unit = unit.name,
          action = "resupply_concealment_failed",
          pairedFiringUnit = firingUnitCtx.name
        }, errorFields)
      }
    end

    return {
      tag = "OK",
      fields = {
        system = systemName,
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
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__LogResult|nil result Deferred log row when the reload flow changed state
local function handleReloadPoint(systemName, systemCtx, unit, isAuto, behavior)
  local hasMet, firingUnitCtx = Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)

  if hasMet and firingUnitCtx then
    local firingUnit = (unit.name == firingUnitCtx.name) and unit or
        GameApi.ScenEdit_GetUnit(firingUnitCtx.name, unit.side)
    if firingUnit then
      Movement.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
      return {
        tag = "OK",
        fields = {
          system = systemName,
          unit = firingUnitCtx.name,
          action = "reload_started",
          triggerUnit = unit.name,
          state = "RELOAD",
          startedAt = firingUnitCtx.reloadStartTime
        }
      }
    end

    return {
      tag = "WARN",
      fields = {
        system = systemName,
        unit = firingUnitCtx.name,
        action = "reload_not_started",
        triggerUnit = unit.name,
        reason = "firing_unit_not_found"
      }
    }
  end

  return handleReloadPointNoMeeting(systemName, systemCtx, unit, isAuto, behavior)
end

---Handle entering ammo holding area logic for a single missile system context
---Position handlers share one signature so they can be dispatched from a table;
---this one has no behavior switches of its own.
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration, unused here
---@return SBJ__LogResult|nil result Deferred log row when the transload flow changed state
local function handleAmmoHoldingArea(systemName, systemCtx, unit, isAuto, behavior)
  local hasMet, resupplyUnit = Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]

  if resupplyUnitCtx and hasMet and resupplyUnit then
    Movement.setReloadStartTime(resupplyUnit, unit, isAuto)
    return {
      tag = "OK",
      fields = {
        system = systemName,
        unit = resupplyUnit.name,
        action = "transload_started",
        state = "RELOAD",
        startedAt = resupplyUnit.reloadStartTime
      }
    }
  end

  Movement.setStateToStatic(systemCtx, unit, isAuto)
  return nil
end

---Position handlers keyed by the token extracted from the event trigger.
---Every entry takes the same arguments so the dispatch site never has to know
---which of them a given handler actually uses.
---@type table<string, fun(systemName: string, systemCtx: SBJ__MissileSystemContext, unit: CMO__Unit, isAuto: boolean, behavior: SBJ__MoveToPositionBehavior): SBJ__LogResult|nil>
local POSITION_HANDLERS = {
  [constants.POSITION_TYPES.FIRING_POINT]      = handleFiringPoint,
  [constants.POSITION_TYPES.HIDE_AREA]         = handleHideArea,
  [constants.POSITION_TYPES.RELOAD_POINT]      = handleReloadPoint,
  [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = handleAmmoHoldingArea,
}

---Handle missile system UnitEntersArea flow for FP/HA/RL/AHA positions
---@param opts SBJ__MoveToPositionEventOpts Unit-enter-area event handling options
function MissileSystem.handleMoveToPositionEvent(opts)
  local unit = opts.unit
  local isAuto = opts.isAuto
  local behavior = resolveBehavior(opts.behavior, unit.side)
  local positionType = extractPositionType(opts.event)
  local handler = POSITION_HANDLERS[positionType]

  if not handler then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, opts.contacts)
  end

  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. unit.side, "Position event")

  forEachEnabledSystem(opts.groundCtx, function(systemCtx, systemName)
    local row = handler(systemName, systemCtx, unit, isAuto, behavior)
    if row then
      report.add(row.tag, row.fields)
    end
  end)

  -- position is derived from the event trigger, so it describes the whole batch
  -- rather than any single row.
  report.emit({ mode = isAuto and "auto" or "manual", position = positionType })
end

return MissileSystem
