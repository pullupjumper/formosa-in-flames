local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Movement = require("src.modules.missileSystem.movement")

---The only writer of a battery's state, reload clock and stow clock.
---Other files issue CMO commands and ask this one to record what the commands mean.
local Transitions = {}

---Send a unit on a move order; it is repositioning only when the order went out
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
---@param unit CMO__Unit
---@param order SBJ__MoveOrder One of Movement.ORDER
---@return SBJ__LogResult # The order's row, for the caller to keep or log
function Transitions.depart(unitState, unit, order)
  local result = Movement.moveTo(unitState, unit, order)
  if result.tag == "OK" then
    unitState.state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING
  end

  return result
end

---Firing unit reached its firing point: ready to fire
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Transitions.arriveAtFiringPoint(firingUnitState, firingUnit, isAuto)
  firingUnitState.state = constants.MISSILE_UNIT_POSTURE.STATIC
  Movement.applyMode(firingUnit, isAuto, constants.WCS.FREE)
end

---Firing unit reached its hide area and goes into hiding
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Transitions.hide(firingUnitState, firingUnit, isAuto)
  firingUnitState.state = constants.MISSILE_UNIT_POSTURE.HIDE
  Movement.applyMode(firingUnit, isAuto, constants.WCS.HOLD)
end

---Unit met its partner (resupply unit at RL, canister stock at ATP): start the reload clock
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
---@param unit CMO__Unit
---@param isAuto boolean
function Transitions.beginReload(unitState, unit, isAuto)
  unitState.state = constants.MISSILE_UNIT_POSTURE.RELOAD
  unitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  Movement.applyMode(unit, isAuto, constants.WCS.HOLD)
end

---Start the reload clock of a reloading unit that has none yet
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
function Transitions.ensureReloadClock(unitState)
  if unitState.reloadStartTime == nil then
    unitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end
end

---Reload or transload is done: the unit stands still and its reload clock stops
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
function Transitions.finishReload(unitState)
  unitState.state = constants.MISSILE_UNIT_POSTURE.STATIC
  unitState.reloadStartTime = nil
end

---Unit arrived without a reload: it stands still and its reload clock stops
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param isAuto boolean
function Transitions.settle(systemState, unit, isAuto)
  local unitState = systemState.firingUnits[unit.name] or systemState.resupplyUnits[unit.name]

  if unitState then
    Transitions.finishReload(unitState)
    Movement.applyMode(unit, isAuto, constants.WCS.HOLD)
  end
end

---Start the stow countdown unless one is already running
---@param firingUnitState SBJ__FiringUnitState
---@return boolean # Whether a new countdown started
function Transitions.beginStow(firingUnitState)
  if firingUnitState.stowStartTime then
    return false
  end

  firingUnitState.stowStartTime = GameApi.ScenEdit_CurrentTime()
  return true
end

---Stop the stow countdown once the unit has been sent on
---@param firingUnitState SBJ__FiringUnitState
function Transitions.endStow(firingUnitState)
  firingUnitState.stowStartTime = nil
end

return Transitions
