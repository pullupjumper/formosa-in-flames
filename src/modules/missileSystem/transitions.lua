local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Movement = require("src.modules.missileSystem.movement")

---The only writer of a battery's state, reload clock and stow clock.
---Other files issue CMO commands and ask this one to record what the commands mean.
local Transitions = {}

---Send a unit on a move order; it is repositioning only when the order went out
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
---@param unit CMO__Unit
---@param order SBJ__MoveOrder One of Movement.ORDER
---@return SBJ__LogResult # The order's row, for the caller to keep or log
function Transitions.startMove(unitState, unit, order)
  local result = Movement.moveTo(unitState, unit, order)
  if result.tag == "OK" then
    unitState.state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING
  end

  return result
end

---Launcher reached its firing point: ready to fire
---@param launcherState SBJ__LauncherState
---@param launcher CMO__Unit
---@param isAuto boolean
function Transitions.arriveAtFiringPoint(launcherState, launcher, isAuto)
  launcherState.state = constants.MISSILE_UNIT_POSTURE.STATIC
  Movement.setMode(launcher, isAuto, constants.WCS.FREE)
end

---Launcher reached its hide area and goes into hiding
---@param launcherState SBJ__LauncherState
---@param launcher CMO__Unit
---@param isAuto boolean
function Transitions.hide(launcherState, launcher, isAuto)
  launcherState.state = constants.MISSILE_UNIT_POSTURE.HIDE
  Movement.setMode(launcher, isAuto, constants.WCS.HOLD)
end

---Unit met its partner (transloader at RL, canister stock at ATP): start the reload clock
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
---@param unit CMO__Unit
---@param isAuto boolean
function Transitions.startReload(unitState, unit, isAuto)
  unitState.state = constants.MISSILE_UNIT_POSTURE.RELOAD
  unitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  Movement.setMode(unit, isAuto, constants.WCS.HOLD)
end

---Start the reload clock of a reloading unit that has none yet
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
function Transitions.ensureReloadClock(unitState)
  if unitState.reloadStartTime == nil then
    unitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end
end

---Reload or transload is done: the unit stands still and its reload clock stops
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
function Transitions.completeReload(unitState)
  unitState.state = constants.MISSILE_UNIT_POSTURE.STATIC
  unitState.reloadStartTime = nil
end

---Unit arrived without a reload: it stands still and its reload clock stops
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param isAuto boolean
function Transitions.completeArrival(systemState, unit, isAuto)
  local unitState = systemState.launchers[unit.name] or systemState.transloaders[unit.name]

  if unitState then
    Transitions.completeReload(unitState)
    Movement.setMode(unit, isAuto, constants.WCS.HOLD)
  end
end

---Start the stow countdown unless one is already running
---@param launcherState SBJ__LauncherState
---@return boolean # Whether a new countdown started
function Transitions.startStow(launcherState)
  if launcherState.stowStartTime then
    return false
  end

  launcherState.stowStartTime = GameApi.ScenEdit_CurrentTime()
  return true
end

---Stop the stow countdown once the unit has been sent on
---@param launcherState SBJ__LauncherState
function Transitions.completeStow(launcherState)
  launcherState.stowStartTime = nil
end

return Transitions
