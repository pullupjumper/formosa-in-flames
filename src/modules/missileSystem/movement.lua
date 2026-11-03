local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

---CMO movement and mode commands; Transitions records what they mean for a unit's state
local Movement = {}

---Move units to a randomly selected position
---Failure fields omit the unit name because every caller already labels the row
---with the unit it was acting on.
---@param params SBJ__MoveToPositionParams
---@return boolean success Whether the move was successful
---@return table<string, any>? errorFields Log fields describing the failure
local function moveUnitToPosition(params)
  local posCount = Utils.getCount(params.positions)
  if posCount == 0 then
    return false, {
      reason = "no_positions_available",
      position = params.positionType,
      area = params.areaName
    }
  end

  local posIdx = math.random(posCount)
  local position = params.positions[posIdx]

  if not position or not position.course then
    return false, {
      reason = "invalid_position_data",
      position = params.positionType,
      index = posIdx,
      area = params.areaName
    }
  end

  local course = position.course
  if params.useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  Shared.setGroupUnitProperties(params.firingUnit, function(unit)
    return {
      unit = unit,
      throttle = constants.THROTTLES.FULL,
      speed = constants.SPEEDS.NORMAL,
      course = course,
      holdPosition = false,
      wcs = params.wcs
    }
  end)

  return true, nil
end

---Command unit to move to reload point (RL)
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
---@param unit CMO__Unit
---@param positions? SBJ__Position[]
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToReloadPoint(unitState, unit, positions)
  return moveUnitToPosition({
    unitName = unitState.name,
    firingUnit = unit,
    positions = positions or unitState.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = unitState.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command firing unit to move to hide area (HA)
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToHideArea(firingUnitState, firingUnit)
  if not firingUnitState.operationalArea.HA then
    return false, {
      reason = "no_ha_defined",
      area = firingUnitState.operationalArea.name
    }
  end

  return moveUnitToPosition({
    unitName = firingUnitState.name,
    firingUnit = firingUnit,
    positions = firingUnitState.operationalArea.HA,
    positionType = constants.POSITION_TYPES.HIDE_AREA,
    areaName = firingUnitState.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToAmmoHoldingArea(resupplyUnitState, resupplyUnit)
  return moveUnitToPosition({
    unitName = resupplyUnitState.name,
    firingUnit = resupplyUnit,
    positions = resupplyUnitState.operationalArea.AHA,
    positionType = constants.POSITION_TYPES.AMMO_HOLDING_AREA,
    areaName = resupplyUnitState.operationalArea.name
  })
end

---Command resupply unit to move to reload point (RL)
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveResupplyUnitToReloadPoint(resupplyUnitState, resupplyUnit)
  return moveUnitToPosition({
    unitName = resupplyUnitState.name,
    firingUnit = resupplyUnit,
    positions = resupplyUnitState.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = resupplyUnitState.operationalArea.name,
    useLastCourse = true
  })
end

---Command firing unit to move to firing point (FP)
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToFiringPoint(firingUnitState, firingUnit)
  return moveUnitToPosition({
    unitName = firingUnitState.name,
    firingUnit = firingUnit,
    positions = firingUnitState.operationalArea.FP,
    positionType = constants.POSITION_TYPES.FIRING_POINT,
    areaName = firingUnitState.operationalArea.name
  })
end

---Hold or release a unit group in place under the auto/manual mode, with the given weapon control status
---@param unit CMO__Unit
---@param isAuto boolean
---@param wcs integer
function Movement.applyMode(unit, isAuto, wcs)
  Shared.setGroupUnitProperties(unit, function()
    return Shared.buildModeProperties(isAuto, wcs)
  end)
end

return Movement
