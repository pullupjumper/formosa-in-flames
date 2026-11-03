local constants = require("src.core.constants")

---Decides which steps a battery unit takes next.
---Pure: reads plain observations, never calls CMO and never writes state.
---Executors (arrival, cycle, init) gather the observations and run the steps in order.
local Rules = {}

local STATE = constants.MISSILE_SYSTEM_STATE
local POSITION = constants.POSITION_TYPES

---Step names returned by the evaluate functions; executors key their handlers on these
Rules.STEP = {
  -- Arrival at a position zone
  ARRIVE_AT_FIRING_POINT = "arriveAtFiringPoint",
  HIDE_FIRING_UNIT = "hideFiringUnit",
  BEGIN_RELOAD = "beginReload",
  WARN_FIRING_UNIT_NOT_FOUND = "warnFiringUnitNotFound",
  STOP_IN_MANUAL_MODE = "stopInManualMode",
  BEGIN_TRANSLOAD = "beginTransload",
  STOP = "stop",
  -- Firing unit reload cycle
  BEGIN_STOW = "beginStow",
  END_STOW = "endStow",
  MOVE_TO_HIDE_AREA = "moveToHideArea",
  UNHIDE_RESUPPLY_UNIT = "unhideResupplyUnit",
  MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT = "moveResupplyUnitToReloadPoint",
  WARN_RESUPPLY_UNIT_NOT_FOUND = "warnResupplyUnitNotFound",
  WARN_RESUPPLY_STATE_NOT_FOUND = "warnResupplyStateNotFound",
  MOVE_TO_RELOAD_POINT = "moveToReloadPoint",
  ENSURE_RELOAD_CLOCK = "ensureReloadClock",
  COMPLETE_RELOAD = "completeReload",
  HIDE_RESUPPLY_UNIT = "hideResupplyUnit",
  MOVE_TO_FIRING_POINT = "moveToFiringPoint",
  -- Resupply unit transload cycle
  MOVE_TO_AMMO_HOLDING_AREA = "moveToAmmoHoldingArea",
  COMPLETE_TRANSLOAD = "completeTransload",
  FAIL_AMMO_DEPOT_STATE_NOT_FOUND = "failAmmoDepotStateNotFound",
  RECALL_TO_RELOAD_POINT = "recallToReloadPoint",
  -- Fire support plan dispatch
  UNHIDE = "unhide",
}

local STEP = Rules.STEP

---Firing unit states in which the unit is out of its hide area and has to be stowed back
local DEPLOYED_STATES = {
  [STATE.STATIC] = true,
  [STATE.REPOSITIONING] = true
}

---Whether a missile system keeps its firing units deployed instead of stowing them
---SAM never stows and returns straight to its firing point after a reload.
---@param missileSystemType string Missile system name in any case (e.g., "SAM", "sam")
---@return boolean # Whether the system stays deployed
function Rules.staysDeployed(missileSystemType)
  return string.lower(missileSystemType) == constants.MISSILE_SYSTEM_TYPES.SAM
end

---Check if firing unit is currently repositioning
---Manual mode has no REPOSITIONING state, so any tracked unit counts as on the move.
---@param firingUnitState SBJ__FiringUnitState|nil
---@param isAuto boolean
---@return boolean # Whether the unit is repositioning
function Rules.isRepositioning(firingUnitState, isAuto)
  if not firingUnitState then
    return false
  end

  if isAuto then
    return firingUnitState.state == STATE.REPOSITIONING
  end

  return true
end

---Whether a stow countdown may start for a firing unit
---@param firingUnitState SBJ__FiringUnitState|nil
---@param opts {onlyDeployed: boolean}|nil onlyDeployed skips units still in their hide area or reloading
---@return boolean # True if the countdown may start
function Rules.shouldStow(firingUnitState, opts)
  if not firingUnitState then
    return false
  end

  return not (opts and opts.onlyDeployed) or DEPLOYED_STATES[firingUnitState.state] == true
end

---Evaluate whether a tracked, present firing unit can take a fire support task
---@param firingUnitState SBJ__FiringUnitState
---@param isLowAmmo boolean
---@return missileSystemReadiness
function Rules.evaluateReadiness(firingUnitState, isLowAmmo)
  local readiness = constants.MISSILE_SYSTEM_READINESS

  if firingUnitState.state ~= STATE.HIDE then
    return readiness.NOT_HIDDEN
  end

  if isLowAmmo then
    return readiness.LOW_AMMO
  end

  return readiness.READY
end

---Evaluate the steps for a fire support plan sending a firing unit to its firing point
---Only a hiding unit with enough ammunition leaves; units already out are left alone.
---@param firingUnitState SBJ__FiringUnitState
---@param isLowAmmo boolean
---@return string[] steps
function Rules.evaluateSendToFiringPoint(firingUnitState, isLowAmmo)
  if firingUnitState.state == STATE.HIDE and not isLowAmmo then
    return { STEP.UNHIDE, STEP.MOVE_TO_FIRING_POINT }
  end

  return {}
end

---@param params SBJ__ArrivalRuleParams
---@return string[] steps
local function evaluateFiringPointArrival(params)
  if Rules.isRepositioning(params.firingUnitState, params.isAuto) then
    return { STEP.ARRIVE_AT_FIRING_POINT }
  end

  return {}
end

---Low-ammo units stay out so the reload cycle can send them on to RL
---@param params SBJ__ArrivalRuleParams
---@return string[] steps
local function evaluateHideAreaArrival(params)
  if params.firingUnitState and params.hideOnEnterHA and not params.isLowAmmo then
    return { STEP.HIDE_FIRING_UNIT }
  end

  return {}
end

---Without a meeting the unit stops in manual mode, so a firing unit drifting through RL during repositioning is not halted
---@param params SBJ__ArrivalRuleParams
---@return string[] steps
local function evaluateReloadPointArrival(params)
  if params.hasMet then
    if params.hasFiringUnit then
      return { STEP.BEGIN_RELOAD }
    end

    return { STEP.WARN_FIRING_UNIT_NOT_FOUND }
  end

  local steps = { STEP.STOP_IN_MANUAL_MODE }
  if params.hideResupplyOnRLNoMeeting and params.resupplyUnitState and params.pairedFiringUnitState
      and params.hasPairedFiringUnit and not params.isPairedFiringUnitLowAmmo then
    table.insert(steps, STEP.HIDE_RESUPPLY_UNIT)
  end

  return steps
end

---@param params SBJ__ArrivalRuleParams
---@return string[] steps
local function evaluateAmmoHoldingAreaArrival(params)
  if params.hasMet then
    return { STEP.BEGIN_TRANSLOAD }
  end

  return { STEP.STOP }
end

local ARRIVAL_RULES = {
  [POSITION.FIRING_POINT] = evaluateFiringPointArrival,
  [POSITION.HIDE_AREA] = evaluateHideAreaArrival,
  [POSITION.RELOAD_POINT] = evaluateReloadPointArrival,
  [POSITION.AMMO_HOLDING_AREA] = evaluateAmmoHoldingAreaArrival,
}

---Evaluate the steps for a unit entering one of its battery's position zones
---@param positionType string Position type token (FP/HA/RL/AHA)
---@param params SBJ__ArrivalRuleParams
---@return string[] steps Empty for an unknown position type
function Rules.evaluateArrival(positionType, params)
  local rule = ARRIVAL_RULES[positionType]
  if not rule then
    return {}
  end

  return rule(params)
end

---A static auto-mode firing unit that fired or ran low waits out the stow time, then leaves:
---to its hide area with enough ammo, otherwise to the reload point together with its resupply unit
---@param params SBJ__FiringUnitTickRuleParams
---@return string[] steps
local function evaluateStaticFiringUnit(params)
  if not params.isAuto then
    return {}
  end

  if params.stowElapsedSec == nil then
    return params.isLowAmmo and { STEP.BEGIN_STOW } or {}
  end

  if params.stowElapsedSec < params.stowTimeSec then
    return {}
  end

  if not params.isLowAmmo then
    return { STEP.MOVE_TO_HIDE_AREA, STEP.END_STOW }
  end

  local steps = {}
  if not params.hasResupplyUnitState then
    table.insert(steps, STEP.WARN_RESUPPLY_STATE_NOT_FOUND)
  elseif not params.hasResupplyUnit then
    table.insert(steps, STEP.WARN_RESUPPLY_UNIT_NOT_FOUND)
  else
    table.insert(steps, STEP.UNHIDE_RESUPPLY_UNIT)
    table.insert(steps, STEP.MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT)
  end

  table.insert(steps, STEP.MOVE_TO_RELOAD_POINT)
  table.insert(steps, STEP.END_STOW)
  return steps
end

---A reloading firing unit finishes once the reload time passed, it still met its resupply unit
---and is still low; in auto mode SAM goes back to its firing point, others to their hide area
---@param params SBJ__FiringUnitTickRuleParams
---@return string[] steps
local function evaluateReloadingFiringUnit(params)
  local steps = { STEP.ENSURE_RELOAD_CLOCK }

  if params.reloadElapsedSec < params.reloadTimeSec or not params.hasMet or not params.isLowAmmo then
    return steps
  end

  table.insert(steps, STEP.COMPLETE_RELOAD)
  if params.isAuto then
    table.insert(steps, STEP.HIDE_RESUPPLY_UNIT)
    table.insert(steps, params.staysDeployed and STEP.MOVE_TO_FIRING_POINT or STEP.MOVE_TO_HIDE_AREA)
  end

  return steps
end

---Evaluate the steps for one firing unit in a reload cycle
---@param params SBJ__FiringUnitTickRuleParams
---@return string[] steps
function Rules.evaluateFiringUnitTick(params)
  if params.state == STATE.STATIC then
    return evaluateStaticFiringUnit(params)
  end

  if params.state == STATE.RELOAD then
    return evaluateReloadingFiringUnit(params)
  end

  return {}
end

---Evaluate the steps for one resupply unit in a reload cycle
---An empty auto-mode resupply unit inside its operational area goes to the ammo holding area;
---a transloading one finishes once the reload time passed and it still met its ammo depot.
---@param params SBJ__ResupplyUnitTickRuleParams
---@return string[] steps
function Rules.evaluateResupplyUnitTick(params)
  if params.state == STATE.STATIC then
    if params.isAuto and params.weaponCount == 0 and params.isInOperationalArea then
      return { STEP.MOVE_TO_AMMO_HOLDING_AREA }
    end

    return {}
  end

  if params.state ~= STATE.RELOAD then
    return {}
  end

  local steps = { STEP.ENSURE_RELOAD_CLOCK }
  if params.reloadElapsedSec < params.reloadTimeSec or params.weaponCount ~= 0 or not params.hasMet then
    return steps
  end

  if not params.hasAmmoDepotState then
    table.insert(steps, STEP.FAIL_AMMO_DEPOT_STATE_NOT_FOUND)
    return steps
  end

  table.insert(steps, STEP.COMPLETE_TRANSLOAD)
  if params.isAuto then
    table.insert(steps, STEP.RECALL_TO_RELOAD_POINT)
  end

  return steps
end

return Rules
