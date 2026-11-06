local constants = require("src.core.constants")

---Decides which steps a battery unit takes next, and every condition those steps depend on.
---Never calls CMO and never writes state. Observations that read CMO arrive as functions,
---called only on the branch that needs them.
---Executors (arrival, cycle, init) gather the observations and carry the steps out in order.
---An observation is either complete or nil: a rule emits a step that reads it only after its own nil check.
local Rules = {}

local STATE = constants.MISSILE_UNIT_POSTURE

---Step names returned by the evaluate functions; executors key their handlers on these
Rules.STEP = {
  -- Arrival at a position zone
  ARRIVE_AT_FIRING_POINT = "arriveAtFiringPoint",
  HIDE_LAUNCHER = "hideLauncher",
  BEGIN_RELOAD = "beginReload",
  STOP_IN_MANUAL_MODE = "stopInManualMode",
  HIDE_UNMET_TRANSLOADER = "hideUnmetTransloader",
  BEGIN_TRANSLOAD = "beginTransload",
  STOP = "stop",
  -- Launcher reload cycle
  BEGIN_STOW = "beginStow",
  END_STOW = "endStow",
  MOVE_TO_HIDE_AREA = "moveToHideArea",
  UNHIDE_TRANSLOADER = "unhideTransloader",
  MOVE_TRANSLOADER_TO_RELOAD_POINT = "moveTransloaderToReloadPoint",
  WARN_TRANSLOADER_NOT_FOUND = "warnTransloaderNotFound",
  WARN_RESUPPLY_STATE_NOT_FOUND = "warnTransloaderStateNotFound",
  MOVE_TO_RELOAD_POINT = "moveToReloadPoint",
  ENSURE_RELOAD_CLOCK = "ensureReloadClock",
  COMPLETE_RELOAD = "completeReload",
  HIDE_TRANSLOADER_AFTER_RELOAD = "hideTransloaderAfterReload",
  MOVE_TO_FIRING_POINT = "moveToFiringPoint",
  -- Transloader transload cycle
  MOVE_TO_AMMUNITION_TRANSFER_POINT = "moveToAmmunitionTransferPoint",
  COMPLETE_TRANSLOAD = "completeTransload",
  FAIL_CANISTER_STOCK_STATE_NOT_FOUND = "failCanisterStockStateNotFound",
  RECALL_TO_RELOAD_POINT = "recallToReloadPoint",
  -- Fire support plan dispatch
  UNHIDE = "unhide",
}

local STEP = Rules.STEP

---Launcher states in which the unit is out of its hide area and has to be stowed back
local DEPLOYED_STATES = {
  [STATE.STATIC] = true,
  [STATE.REPOSITIONING] = true
}

---Whether a missile system keeps its launchers on station after firing
---SAM guards the airspace, so it leaves its position only when low on ammo and returns to its firing point after a reload.
---@param missileSystemType string Missile system name in any case (e.g., "SAM", "sam")
---@return boolean # Whether the system stays deployed
function Rules.staysDeployed(missileSystemType)
  return string.lower(missileSystemType) == constants.MISSILE_SYSTEM_TYPES.SAM
end

---Check if launcher is currently repositioning
---Manual mode has no REPOSITIONING state, so any tracked unit counts as on the move.
---@param launcherState SBJ__LauncherState|nil
---@param isAuto boolean
---@return boolean # Whether the unit is repositioning
function Rules.isRepositioning(launcherState, isAuto)
  if not launcherState then
    return false
  end

  if isAuto then
    return launcherState.state == STATE.REPOSITIONING
  end

  return true
end

---Whether a launcher stands still at its position, ready to fire once at FP
---@param launcherState SBJ__LauncherState
---@return boolean # True if the unit is STATIC
function Rules.isInPosition(launcherState)
  return launcherState.state == STATE.STATIC
end

---Whether a launcher is out of its hide area, so an aborted fire task has to stow it back
---HIDE and RELOAD units are left alone; RELOAD already ends in HA.
---@param launcherState SBJ__LauncherState
---@return boolean # True if the unit is STATIC or REPOSITIONING
function Rules.isDeployed(launcherState)
  return DEPLOYED_STATES[launcherState.state] == true
end

---Evaluate whether a tracked, present launcher can take a fire support task
---The ammo read is a callback because fire support planning asks every tick, and only hiding units need it.
---@param launcherState SBJ__LauncherState
---@param isLowAmmo fun(): boolean Called only for a hiding unit
---@return missileSystemReadiness
function Rules.evaluateReadiness(launcherState, isLowAmmo)
  local readiness = constants.MISSILE_SYSTEM_READINESS

  if launcherState.state ~= STATE.HIDE then
    return readiness.NOT_HIDDEN
  end

  if isLowAmmo() then
    return readiness.LOW_AMMO
  end

  return readiness.READY
end

---Evaluate the steps for a fire support plan sending a launcher to its firing point
---Only a hiding unit with enough ammunition leaves; units already out are left alone.
---@param launcherState SBJ__LauncherState
---@param isLowAmmo fun(): boolean Called only for a hiding unit, as in evaluateReadiness
---@return string[] steps
function Rules.evaluateSendToFiringPoint(launcherState, isLowAmmo)
  if launcherState.state == STATE.HIDE and not isLowAmmo() then
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

---Whether a launcher met its transloader at RL for a reload: the unit that triggered may meet,
---the launcher is low, the transloader has missiles, and both stand in one RL zone
---@param pair SBJ__ReloadPair
---@param isAuto boolean
---@return boolean # True if the reload may start or finish
local function hasMetTransloader(pair, isAuto)
  local triggeringState = pair.isTriggeredByLauncher and pair.launcherState or pair.transloaderState

  return canMeet(triggeringState.state, isAuto)
      and pair.isLauncherLowAmmo()
      and pair.transloaderState.weaponCountCurrent > 0
      and pair.isInSameReloadArea()
end

---Whether an empty transloader met its canister stock at ATP
---@param transloaderState SBJ__TransloaderState
---@param isAuto boolean
---@param isAtCanisterStock fun(): boolean
---@return boolean # True if the transload may start or finish
local function hasMetCanisterStock(transloaderState, isAuto, isAtCanisterStock)
  return canMeet(transloaderState.state, isAuto)
      and transloaderState.weaponCountCurrent == 0
      and isAtCanisterStock()
end

---Evaluate the steps for a unit entering its firing point
---@param runCtx SBJ__ArrivalRunContext
---@param launcherState SBJ__LauncherState|nil Nil when the unit is not a launcher of this system
---@return string[] steps
function Rules.evaluateFiringPointArrival(runCtx, launcherState)
  if Rules.isRepositioning(launcherState, runCtx.isAuto) then
    return { STEP.ARRIVE_AT_FIRING_POINT }
  end

  return {}
end

---Evaluate the steps for a unit entering its hide area
---Low-ammo units stay out so the reload cycle can send them on to RL.
---@param runCtx SBJ__ArrivalRunContext
---@param observation SBJ__HideAreaObservation|nil Nil when the unit is not a launcher of this system
---@return string[] steps
function Rules.evaluateHideAreaArrival(runCtx, observation)
  if observation and runCtx.hideOnEnterHA and not observation.isLowAmmo() then
    return { STEP.HIDE_LAUNCHER }
  end

  return {}
end

---Evaluate the steps for a unit entering its reload point
---Without a meeting the unit stops in manual mode, so a launcher drifting through RL during repositioning is not halted.
---A transloader that arrives alone may hide when its launcher does not need it.
---@param runCtx SBJ__ArrivalRunContext
---@param pair SBJ__ReloadPair|nil Nil unless both units of the pair are tracked and in the game
---@return string[] steps
function Rules.evaluateReloadPointArrival(runCtx, pair)
  if not pair then
    return { STEP.STOP_IN_MANUAL_MODE }
  end

  if hasMetTransloader(pair, runCtx.isAuto) then
    return { STEP.BEGIN_RELOAD }
  end

  local steps = { STEP.STOP_IN_MANUAL_MODE }
  if runCtx.hideTransloaderOnRLNoMeeting and not pair.isTriggeredByLauncher and not pair.isLauncherLowAmmo() then
    table.insert(steps, STEP.HIDE_UNMET_TRANSLOADER)
  end

  return steps
end

---Evaluate the steps for a unit entering its ammunition transfer point
---@param runCtx SBJ__ArrivalRunContext
---@param observation SBJ__AmmunitionTransferPointObservation|nil Nil when the unit is not a transloader of this system
---@return string[] steps
function Rules.evaluateAmmunitionTransferPointArrival(runCtx, observation)
  if observation and hasMetCanisterStock(observation.transloaderState, runCtx.isAuto, observation.isAtCanisterStock) then
    return { STEP.BEGIN_TRANSLOAD }
  end

  return { STEP.STOP }
end

---A static auto-mode launcher that fired or ran low waits out the stow time, then leaves:
---to its hide area with enough ammo, otherwise to the reload point together with its transloader
---@param tick SBJ__LauncherTick
---@param pair SBJ__ReloadPair|nil
---@return string[] steps
local function evaluateStaticLauncher(tick, pair)
  if not tick.isAuto then
    return {}
  end

  local stowElapsedSec = calculateElapsedSec(tick.launcherState.stowStartTime, tick.now)
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
    table.insert(steps, STEP.UNHIDE_TRANSLOADER)
    table.insert(steps, STEP.MOVE_TRANSLOADER_TO_RELOAD_POINT)
  elseif tick.hasTransloaderState then
    table.insert(steps, STEP.WARN_TRANSLOADER_NOT_FOUND)
  else
    table.insert(steps, STEP.WARN_RESUPPLY_STATE_NOT_FOUND)
  end

  table.insert(steps, STEP.MOVE_TO_RELOAD_POINT)
  table.insert(steps, STEP.END_STOW)
  return steps
end

---A reloading launcher finishes once the reload time passed and it still meets its transloader.
---In auto mode the transloader hides when the reload leaves it missiles, and the launcher leaves:
---SAM back to its firing point, others to their hide area.
---@param tick SBJ__LauncherTick
---@param pair SBJ__ReloadPair|nil
---@return string[] steps
local function evaluateReloadingLauncher(tick, pair)
  local steps = { STEP.ENSURE_RELOAD_CLOCK }

  -- A clock that has not started counts as 0 seconds, so a reload time of 0 finishes in the tick that starts it
  local reloadElapsedSec = calculateElapsedSec(tick.launcherState.reloadStartTime, tick.now) or 0
  if reloadElapsedSec < tick.reloadTimeSec or not pair or not hasMetTransloader(pair, tick.isAuto) then
    return steps
  end

  table.insert(steps, STEP.COMPLETE_RELOAD)
  if tick.isAuto then
    if pair.transloaderState.weaponCountCurrent > pair.buildReload().count then
      table.insert(steps, STEP.HIDE_TRANSLOADER_AFTER_RELOAD)
    end
    table.insert(steps, tick.staysDeployed and STEP.MOVE_TO_FIRING_POINT or STEP.MOVE_TO_HIDE_AREA)
  end

  return steps
end

---Evaluate the steps for one launcher in a reload cycle
---@param tick SBJ__LauncherTick
---@param pair SBJ__ReloadPair|nil Nil unless its transloader is tracked and in the game
---@return string[] steps
function Rules.evaluateLauncherTick(tick, pair)
  local state = tick.launcherState.state

  if state == STATE.STATIC then
    return evaluateStaticLauncher(tick, pair)
  end

  if state == STATE.RELOAD then
    return evaluateReloadingLauncher(tick, pair)
  end

  return {}
end

---Evaluate the steps for one transloader in a reload cycle
---An empty auto-mode transloader standing in an RL zone goes to the ammunition transfer point;
---a transloading one finishes once the reload time passed and it still meets its canister stock.
---@param tick SBJ__TransloaderTick
---@param canisterStockState SBJ__CanisterStockState|nil Nil when its canister stock is not tracked
---@return string[] steps
function Rules.evaluateTransloaderTick(tick, canisterStockState)
  local transloaderState = tick.transloaderState

  if transloaderState.state == STATE.STATIC then
    if tick.isAuto and transloaderState.weaponCountCurrent == 0 and tick.isInReloadArea() then
      return { STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT }
    end

    return {}
  end

  if transloaderState.state ~= STATE.RELOAD then
    return {}
  end

  local steps = { STEP.ENSURE_RELOAD_CLOCK }
  local reloadElapsedSec = calculateElapsedSec(transloaderState.reloadStartTime, tick.now) or 0
  if reloadElapsedSec < tick.reloadTimeSec or not hasMetCanisterStock(transloaderState, tick.isAuto, tick.isAtCanisterStock) then
    return steps
  end

  if not canisterStockState then
    table.insert(steps, STEP.FAIL_CANISTER_STOCK_STATE_NOT_FOUND)
    return steps
  end

  table.insert(steps, STEP.COMPLETE_TRANSLOAD)
  if tick.isAuto then
    table.insert(steps, STEP.RECALL_TO_RELOAD_POINT)
  end

  return steps
end

return Rules
