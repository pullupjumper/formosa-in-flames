local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local Rules = require("src.modules.missileSystem.rules")
local Transitions = require("src.modules.missileSystem.transitions")
local Triggers = require("src.modules.missileSystem.triggers")

---Reacts to a unit entering one of its battery's FP / HA / RL / AHA zones:
---observes the unit, asks Rules for the steps and carries them out.
local Arrival = {}

local STEP = Rules.STEP

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
      local positionType = Triggers.parsePositionType(entersArea.Description)
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

---Arrival steps keyed by Rules.STEP; each one acts on CMO, records the transition and returns its log row
---@type table<string, fun(stepCtx: SBJ__ArrivalStepContext): SBJ__LogResult|nil>
local ARRIVAL_STEPS = {
  [STEP.ARRIVE_AT_FIRING_POINT] = function(stepCtx)
    local unit = stepCtx.unit
    Transitions.arriveAtFiringPoint(stepCtx.firingUnitState --[[@as SBJ__FiringUnitState]], unit, stepCtx.moveCtx.isAuto)
    return {
      tag = "OK",
      fields = { system = stepCtx.missileSystemType, unit = unit.name, action = "firing_ready", state = "STATIC", wcs = "FREE" }
    }
  end,

  [STEP.HIDE_FIRING_UNIT] = function(stepCtx)
    local unit = stepCtx.unit
    local firingUnitState = stepCtx.firingUnitState --[[@as SBJ__FiringUnitState]]
    Transitions.hide(firingUnitState, unit, stepCtx.moveCtx.isAuto)
    local success, errorFields = Concealment.hideUnit(firingUnitState, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = stepCtx.missileSystemType,
          unit = unit.name,
          action = "concealment_failed",
          state = "HIDE"
        }, errorFields)
      }
    end

    return { tag = "OK", fields = { system = stepCtx.missileSystemType, unit = unit.name, action = "concealed", state = "HIDE" } }
  end,

  [STEP.BEGIN_RELOAD] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState --[[@as SBJ__FiringUnitState]]
    Transitions.beginReload(firingUnitState, stepCtx.firingUnit --[[@as CMO__Unit]], stepCtx.moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        system = stepCtx.missileSystemType,
        unit = firingUnitState.name,
        action = "reload_started",
        triggerUnit = stepCtx.unit.name,
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, firingUnitState.reloadStartTime)
      }
    }
  end,

  [STEP.WARN_FIRING_UNIT_NOT_FOUND] = function(stepCtx)
    return {
      tag = "WARN",
      fields = {
        system = stepCtx.missileSystemType,
        unit = (stepCtx.firingUnitState --[[@as SBJ__FiringUnitState]]).name,
        action = "reload_not_started",
        triggerUnit = stepCtx.unit.name,
        reason = "firing_unit_not_found"
      }
    }
  end,

  -- The manual mode keeps a firing unit drifting through RL during repositioning from being halted.
  [STEP.STOP_IN_MANUAL_MODE] = function(stepCtx)
    Transitions.settle(stepCtx.systemState, stepCtx.unit, MANUAL_MODE)
    return nil
  end,

  [STEP.HIDE_RESUPPLY_UNIT] = function(stepCtx)
    local unit = stepCtx.unit
    local pairedFiringUnitName = (stepCtx.pairedFiringUnitState --[[@as SBJ__FiringUnitState]]).name
    local success, errorFields = Concealment.hideUnit(stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]], unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          system = stepCtx.missileSystemType,
          unit = unit.name,
          action = "resupply_concealment_failed",
          pairedFiringUnit = pairedFiringUnitName
        }, errorFields)
      }
    end

    return {
      tag = "OK",
      fields = {
        system = stepCtx.missileSystemType,
        unit = unit.name,
        action = "resupply_concealed",
        pairedFiringUnit = pairedFiringUnitName,
        ammoStatus = "sufficient"
      }
    }
  end,

  [STEP.BEGIN_TRANSLOAD] = function(stepCtx)
    local metResupplyUnitState = stepCtx.metResupplyUnitState --[[@as SBJ__ResupplyUnitState]]
    Transitions.beginReload(metResupplyUnitState, stepCtx.unit, stepCtx.moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        system = stepCtx.missileSystemType,
        unit = metResupplyUnitState.name,
        action = "transload_started",
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, (stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]).reloadStartTime)
      }
    }
  end,

  [STEP.STOP] = function(stepCtx)
    Transitions.settle(stepCtx.systemState, stepCtx.unit, stepCtx.moveCtx.isAuto)
    return nil
  end,
}

---Observe a firing unit entering its firing point
---@param stepCtx SBJ__ArrivalStepContext
---@return SBJ__ArrivalRuleParams
local function observeFiringPoint(stepCtx)
  stepCtx.firingUnitState = stepCtx.systemState.firingUnits[stepCtx.unit.name]
  return { isAuto = stepCtx.moveCtx.isAuto, firingUnitState = stepCtx.firingUnitState }
end

---Observe a firing unit entering its hide area
---@param stepCtx SBJ__ArrivalStepContext
---@return SBJ__ArrivalRuleParams
local function observeHideArea(stepCtx)
  local unit, moveCtx = stepCtx.unit, stepCtx.moveCtx
  local firingUnitState = stepCtx.systemState.firingUnits[unit.name]
  stepCtx.firingUnitState = firingUnitState
  return {
    isAuto = moveCtx.isAuto,
    firingUnitState = firingUnitState,
    hideOnEnterHA = moveCtx.hideOnEnterHA,
    isLowAmmo = firingUnitState ~= nil and Ammo.isLowAmmo(unit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID),
  }
end

---Observe a unit entering its reload point: the meeting, and the arriving resupply unit's paired firing unit
---@param stepCtx SBJ__ArrivalStepContext
---@return SBJ__ArrivalRuleParams
local function observeReloadPoint(stepCtx)
  local unit, moveCtx, systemState = stepCtx.unit, stepCtx.moveCtx, stepCtx.systemState
  local hasMet, metFiringUnitState = Meeting.hasMetResupplyUnit(systemState, unit, moveCtx.isAuto)
  hasMet = hasMet and metFiringUnitState ~= nil
  if hasMet and metFiringUnitState then
    stepCtx.firingUnitState = metFiringUnitState
    stepCtx.firingUnit = (unit.name == metFiringUnitState.name) and unit or
        GameApi.ScenEdit_GetUnit(metFiringUnitState.name, unit.side)
  end

  local resupplyUnitState = systemState.resupplyUnits[unit.name]
  local pairedFiringUnitState = resupplyUnitState and (GroundStateStore.resolvePair(systemState, unit.name))
  local pairedFiringUnit = pairedFiringUnitState and
      GameApi.ScenEdit_GetUnit(pairedFiringUnitState.name, moveCtx.firingUnitLookupSide)
  stepCtx.resupplyUnitState = resupplyUnitState
  stepCtx.pairedFiringUnitState = pairedFiringUnitState

  return {
    isAuto = moveCtx.isAuto,
    hasMet = hasMet,
    hasFiringUnit = stepCtx.firingUnit ~= nil,
    hideResupplyOnRLNoMeeting = moveCtx.hideResupplyOnRLNoMeeting,
    resupplyUnitState = resupplyUnitState,
    pairedFiringUnitState = pairedFiringUnitState,
    hasPairedFiringUnit = pairedFiringUnit ~= nil,
    isPairedFiringUnitLowAmmo = pairedFiringUnitState ~= nil and pairedFiringUnit ~= nil and
        Ammo.isLowAmmo(pairedFiringUnit, pairedFiringUnitState.ammoThreshold, pairedFiringUnitState.weaponDBID),
  }
end

---Observe a resupply unit entering its ammo holding area
---@param stepCtx SBJ__ArrivalStepContext
---@return SBJ__ArrivalRuleParams
local function observeAmmoHoldingArea(stepCtx)
  local unit, moveCtx = stepCtx.unit, stepCtx.moveCtx
  local hasMet, metResupplyUnitState = Meeting.hasMetAmmoDepot(stepCtx.systemState, unit, moveCtx.isAuto)
  local resupplyUnitState = stepCtx.systemState.resupplyUnits[unit.name]
  stepCtx.resupplyUnitState = resupplyUnitState
  stepCtx.metResupplyUnitState = metResupplyUnitState
  return {
    isAuto = moveCtx.isAuto,
    hasMet = resupplyUnitState ~= nil and hasMet and metResupplyUnitState ~= nil,
  }
end

---Position observers keyed by the token extracted from the event trigger
---@type table<string, fun(stepCtx: SBJ__ArrivalStepContext): SBJ__ArrivalRuleParams>
local POSITION_OBSERVERS = {
  [constants.POSITION_TYPES.FIRING_POINT]      = observeFiringPoint,
  [constants.POSITION_TYPES.HIDE_AREA]         = observeHideArea,
  [constants.POSITION_TYPES.RELOAD_POINT]      = observeReloadPoint,
  [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = observeAmmoHoldingArea,
}

---Observe one missile system, ask Rules for the steps and run them
---@param positionType string
---@param stepCtx SBJ__ArrivalStepContext
---@return SBJ__LogResult[] rows Log rows of the steps that produced one
local function processSystem(positionType, stepCtx)
  local rows = {}
  local steps = Rules.evaluateArrival(positionType, POSITION_OBSERVERS[positionType](stepCtx))
  for _, step in ipairs(steps) do
    local row = ARRIVAL_STEPS[step](stepCtx)
    if row then
      table.insert(rows, row)
    end
  end
  return rows
end

---Handle missile system UnitEntersArea flow for FP/HA/RL/AHA positions
---@param params SBJ__MoveToPositionEventParams
function Arrival.processMoveToPositionEvent(params)
  local unit = params.unit
  local moveCtx = params.moveCtx
  local positionType = resolvePositionType(params.event)
  if not positionType or not POSITION_OBSERVERS[positionType] then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, params.contacts)
  end

  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. unit.side, "Position event")

  forEachEnabledSystem(params.groundState, function(systemState, missileSystemType)
    local rows = processSystem(positionType, {
      missileSystemType = missileSystemType,
      systemState = systemState,
      unit = unit,
      moveCtx = moveCtx
    })
    for _, row in ipairs(rows) do
      report.add(row.tag, row.fields)
    end
  end)

  -- position is derived from the event trigger, so it describes the whole batch
  -- rather than any single row.
  report.emit({ mode = moveCtx.isAuto and "auto" or "manual", position = positionType })
end

return Arrival
