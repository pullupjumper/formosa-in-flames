local constants = require("src.core.constants")

---Decides which steps a battery unit takes next, and every condition those steps depend on.
---Never calls CMO and never writes state. Observations that read CMO arrive as functions,
---called only on the branch that needs them.
---Executors (arrival, cycle, init) gather the observations and carry the steps out in order.
---An observation is either complete or nil: a rule emits a step that reads it only after its own nil check.
local Rules = {}

local STATE = constants.MISSILE_SYSTEM_STATE

---Step names returned by the evaluate functions; executors key their handlers on these
Rules.STEP = {
  -- Arrival at a position zone
  ARRIVE_AT_FIRING_POINT = "arriveAtFiringPoint",
  HIDE_FIRING_UNIT = "hideFiringUnit",
  BEGIN_RELOAD = "beginReload",
  STOP_IN_MANUAL_MODE = "stopInManualMode",
  HIDE_UNMET_RESUPPLY_UNIT = "hideUnmetResupplyUnit",
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
  HIDE_RESUPPLY_UNIT_AFTER_RELOAD = "hideResupplyUnitAfterReload",
  MOVE_TO_FIRING_POINT = "moveToFiringPoint",
  -- Resupply unit transload cycle
  MOVE_TO_AMMUNITION_TRANSFER_POINT = "moveToAmmunitionTransferPoint",
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

---Whether a missile system keeps its firing units on station after firing
---SAM guards the airspace, so it leaves its position only when low on ammo and returns to its firing point after a reload.
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

---Whether a firing unit stands still at its position, ready to fire once at FP
---@param firingUnitState SBJ__FiringUnitState
---@return boolean # True if the unit is STATIC
function Rules.isInPosition(firingUnitState)
  return firingUnitState.state == STATE.STATIC
end

---Whether a firing unit is out of its hide area, so an aborted fire task has to stow it back
---HIDE and RELOAD units are left alone; RELOAD already ends in HA.
---@param firingUnitState SBJ__FiringUnitState
---@return boolean # True if the unit is STATIC or REPOSITIONING
function Rules.isDeployed(firingUnitState)
  return DEPLOYED_STATES[firingUnitState.state] == true
end

---Evaluate whether a tracked, present firing unit can take a fire support task
---The ammo read is a callback because fire support planning asks every tick, and only hiding units need it.
---@param firingUnitState SBJ__FiringUnitState
---@param isLowAmmo fun(): boolean Called only for a hiding unit
---@return missileSystemReadiness
function Rules.evaluateReadiness(firingUnitState, isLowAmmo)
  local readiness = constants.MISSILE_SYSTEM_READINESS

  if firingUnitState.state ~= STATE.HIDE then
    return readiness.NOT_HIDDEN
  end

  if isLowAmmo() then
    return readiness.LOW_AMMO
  end

  return readiness.READY
end

---Evaluate the steps for a fire support plan sending a firing unit to its firing point
---Only a hiding unit with enough ammunition leaves; units already out are left alone.
---@param firingUnitState SBJ__FiringUnitState
---@param isLowAmmo fun(): boolean Called only for a hiding unit, as in evaluateReadiness
---@return string[] steps
function Rules.evaluateSendToFiringPoint(firingUnitState, isLowAmmo)
  if firingUnitState.state == STATE.HIDE and not isLowAmmo() then
    return { STEP.UNHIDE, STEP.MOVE_TO_FIRING_POINT }
  end

  return {}
end

---Seconds since a clock started, or nil when it has not started
---@param startTime number|nil
---@param now number
---@return number|nil
local function calculateElapsedSec(startTime, now)
  return startTime and now - startTime
end

---Whether a unit's state lets it count as meeting its partner
---Manual mode has no REPOSITIONING state, so any state counts there.
---@param state integer
---@param isAuto boolean
---@return boolean # True in manual mode, or when REPOSITIONING or RELOAD in auto mode
local function canMeet(state, isAuto)
  if not isAuto then
    return true
  end

  return state == STATE.REPOSITIONING or state == STATE.RELOAD
end

---Whether a firing unit met its resupply unit at RL for a reload: the unit that triggered may meet,
---the firing unit is low, the resupply unit has missiles, and both stand in one RL zone
---@param pair SBJ__ReloadPair
---@param isAuto boolean
---@return boolean # True if the reload may start or finish
local function hasMetResupplyUnit(pair, isAuto)
  local triggeringState = pair.isTriggeredByFiringUnit and pair.firingUnitState or pair.resupplyUnitState

  return canMeet(triggeringState.state, isAuto)
      and pair.isFiringUnitLowAmmo()
      and pair.resupplyUnitState.weaponCountCurrent > 0
      and pair.isInSameReloadArea()
end

---Whether an empty resupply unit met its ammo depot at ATP
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param isAuto boolean
---@param isAtAmmoDepot fun(): boolean
---@return boolean # True if the transload may start or finish
local function hasMetAmmoDepot(resupplyUnitState, isAuto, isAtAmmoDepot)
  return canMeet(resupplyUnitState.state, isAuto)
      and resupplyUnitState.weaponCountCurrent == 0
      and isAtAmmoDepot()
end

---Evaluate the steps for a unit entering its firing point
---@param moveCtx SBJ__MoveToPositionContext
---@param firingUnitState SBJ__FiringUnitState|nil Nil when the unit is not a firing unit of this system
---@return string[] steps
function Rules.evaluateFiringPointArrival(moveCtx, firingUnitState)
  if Rules.isRepositioning(firingUnitState, moveCtx.isAuto) then
    return { STEP.ARRIVE_AT_FIRING_POINT }
  end

  return {}
end

---Evaluate the steps for a unit entering its hide area
---Low-ammo units stay out so the reload cycle can send them on to RL.
---@param moveCtx SBJ__MoveToPositionContext
---@param observation SBJ__HideAreaObservation|nil Nil when the unit is not a firing unit of this system
---@return string[] steps
function Rules.evaluateHideAreaArrival(moveCtx, observation)
  if observation and moveCtx.hideOnEnterHA and not observation.isLowAmmo() then
    return { STEP.HIDE_FIRING_UNIT }
  end

  return {}
end

---Evaluate the steps for a unit entering its reload point
---Without a meeting the unit stops in manual mode, so a firing unit drifting through RL during repositioning is not halted.
---A resupply unit that arrives alone may hide when its firing unit does not need it.
---@param moveCtx SBJ__MoveToPositionContext
---@param pair SBJ__ReloadPair|nil Nil unless both units of the pair are tracked and in the game
---@return string[] steps
function Rules.evaluateReloadPointArrival(moveCtx, pair)
  if not pair then
    return { STEP.STOP_IN_MANUAL_MODE }
  end

  if hasMetResupplyUnit(pair, moveCtx.isAuto) then
    return { STEP.BEGIN_RELOAD }
  end

  local steps = { STEP.STOP_IN_MANUAL_MODE }
  if moveCtx.hideResupplyOnRLNoMeeting and not pair.isTriggeredByFiringUnit and not pair.isFiringUnitLowAmmo() then
    table.insert(steps, STEP.HIDE_UNMET_RESUPPLY_UNIT)
  end

  return steps
end

---Evaluate the steps for a unit entering its ammunition transfer point
---@param moveCtx SBJ__MoveToPositionContext
---@param observation SBJ__AmmunitionTransferPointObservation|nil Nil when the unit is not a resupply unit of this system
---@return string[] steps
function Rules.evaluateAmmunitionTransferPointArrival(moveCtx, observation)
  if observation and hasMetAmmoDepot(observation.resupplyUnitState, moveCtx.isAuto, observation.isAtAmmoDepot) then
    return { STEP.BEGIN_TRANSLOAD }
  end

  return { STEP.STOP }
end

---A static auto-mode firing unit that fired or ran low waits out the stow time, then leaves:
---to its hide area with enough ammo, otherwise to the reload point together with its resupply unit
---@param tick SBJ__FiringUnitTick
---@param pair SBJ__ReloadPair|nil
---@return string[] steps
local function evaluateStaticFiringUnit(tick, pair)
  if not tick.isAuto then
    return {}
  end

  local stowElapsedSec = calculateElapsedSec(tick.firingUnitState.stowStartTime, tick.now)
  if stowElapsedSec == nil then
    return tick.isLowAmmo() and { STEP.BEGIN_STOW } or {}
  end

  if stowElapsedSec < tick.stowTimeSec then
    return {}
  end

  if not tick.isLowAmmo() then
    return { STEP.MOVE_TO_HIDE_AREA, STEP.END_STOW }
  end

  local steps = {}
  if pair then
    table.insert(steps, STEP.UNHIDE_RESUPPLY_UNIT)
    table.insert(steps, STEP.MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT)
  elseif tick.hasResupplyUnitState then
    table.insert(steps, STEP.WARN_RESUPPLY_UNIT_NOT_FOUND)
  else
    table.insert(steps, STEP.WARN_RESUPPLY_STATE_NOT_FOUND)
  end

  table.insert(steps, STEP.MOVE_TO_RELOAD_POINT)
  table.insert(steps, STEP.END_STOW)
  return steps
end

---A reloading firing unit finishes once the reload time passed and it still meets its resupply unit.
---In auto mode the resupply unit hides when the reload leaves it missiles, and the firing unit leaves:
---SAM back to its firing point, others to their hide area.
---@param tick SBJ__FiringUnitTick
---@param pair SBJ__ReloadPair|nil
---@return string[] steps
local function evaluateReloadingFiringUnit(tick, pair)
  local steps = { STEP.ENSURE_RELOAD_CLOCK }

  -- A clock that has not started counts as 0 seconds, so a reload time of 0 finishes in the tick that starts it
  local reloadElapsedSec = calculateElapsedSec(tick.firingUnitState.reloadStartTime, tick.now) or 0
  if reloadElapsedSec < tick.reloadTimeSec or not pair or not hasMetResupplyUnit(pair, tick.isAuto) then
    return steps
  end

  table.insert(steps, STEP.COMPLETE_RELOAD)
  if tick.isAuto then
    if pair.resupplyUnitState.weaponCountCurrent > pair.buildReload().count then
      table.insert(steps, STEP.HIDE_RESUPPLY_UNIT_AFTER_RELOAD)
    end
    table.insert(steps, tick.staysDeployed and STEP.MOVE_TO_FIRING_POINT or STEP.MOVE_TO_HIDE_AREA)
  end

  return steps
end

---Evaluate the steps for one firing unit in a reload cycle
---@param tick SBJ__FiringUnitTick
---@param pair SBJ__ReloadPair|nil Nil unless its resupply unit is tracked and in the game
---@return string[] steps
function Rules.evaluateFiringUnitTick(tick, pair)
  local state = tick.firingUnitState.state

  if state == STATE.STATIC then
    return evaluateStaticFiringUnit(tick, pair)
  end

  if state == STATE.RELOAD then
    return evaluateReloadingFiringUnit(tick, pair)
  end

  return {}
end

---Evaluate the steps for one resupply unit in a reload cycle
---An empty auto-mode resupply unit standing in an RL zone goes to the ammunition transfer point;
---a transloading one finishes once the reload time passed and it still meets its ammo depot.
---@param tick SBJ__ResupplyUnitTick
---@param ammoDepotState SBJ__AmmunitionState|nil Nil when its ammo depot is not tracked
---@return string[] steps
function Rules.evaluateResupplyUnitTick(tick, ammoDepotState)
  local resupplyUnitState = tick.resupplyUnitState

  if resupplyUnitState.state == STATE.STATIC then
    if tick.isAuto and resupplyUnitState.weaponCountCurrent == 0 and tick.isInReloadArea() then
      return { STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT }
    end

    return {}
  end

  if resupplyUnitState.state ~= STATE.RELOAD then
    return {}
  end

  local steps = { STEP.ENSURE_RELOAD_CLOCK }
  local reloadElapsedSec = calculateElapsedSec(resupplyUnitState.reloadStartTime, tick.now) or 0
  if reloadElapsedSec < tick.reloadTimeSec or not hasMetAmmoDepot(resupplyUnitState, tick.isAuto, tick.isAtAmmoDepot) then
    return steps
  end

  if not ammoDepotState then
    table.insert(steps, STEP.FAIL_AMMO_DEPOT_STATE_NOT_FOUND)
    return steps
  end

  table.insert(steps, STEP.COMPLETE_TRANSLOAD)
  if tick.isAuto then
    table.insert(steps, STEP.RECALL_TO_RELOAD_POINT)
  end

  return steps
end

return Rules
