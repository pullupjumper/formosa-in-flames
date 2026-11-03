local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Transitions = require("src.modules.missileSystem.transitions")

---Reacts to a unit entering one of its battery's FP / HA / RL / AHA zones.
local Arrival = {}

---Manual mode for flows that must never halt a unit
local MANUAL_MODE = false

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
  if Transitions.isRepositioning(firingUnitState, moveCtx.isAuto) then
    Transitions.arriveAtFiringPoint(firingUnitState, unit, moveCtx.isAuto)
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
    Transitions.hide(firingUnitState, unit, moveCtx.isAuto)
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
  Transitions.settle(systemState, unit, MANUAL_MODE)
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
      Transitions.beginReload(firingUnitState, firingUnit, moveCtx.isAuto)
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
    Transitions.beginReload(resupplyUnit, unit, moveCtx.isAuto)
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

  Transitions.settle(systemState, unit, moveCtx.isAuto)
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
function Arrival.processMoveToPositionEvent(params)
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

return Arrival
