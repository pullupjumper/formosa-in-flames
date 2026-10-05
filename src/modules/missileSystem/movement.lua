local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

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
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext
---@param unit CMO__Unit
---@param positions? SBJ__Position[]
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToReloadPoint(unitCtx, unit, positions)
  unitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = unitCtx.name,
    firingUnit = unit,
    positions = positions or unitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = unitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command firing unit to move to hide area (HA)
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToHideArea(firingUnitCtx, firingUnit)
  if not firingUnitCtx.operationalArea.HA then
    return false, {
      reason = "no_ha_defined",
      area = firingUnitCtx.operationalArea.name
    }
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = firingUnitCtx.name,
    firingUnit = firingUnit,
    positions = firingUnitCtx.operationalArea.HA,
    positionType = constants.POSITION_TYPES.HIDE_AREA,
    areaName = firingUnitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext
---@param resupplyUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    firingUnit = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.AHA,
    positionType = constants.POSITION_TYPES.AMMO_HOLDING_AREA,
    areaName = resupplyUnitCtx.operationalArea.name
  })
end

---Command resupply unit to move to reload point (RL)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext
---@param resupplyUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    firingUnit = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = resupplyUnitCtx.operationalArea.name,
    useLastCourse = true
  })
end

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = firingUnitCtx.name,
    firingUnit = firingUnit,
    positions = firingUnitCtx.operationalArea.FP,
    positionType = constants.POSITION_TYPES.FIRING_POINT,
    areaName = firingUnitCtx.operationalArea.name
  })
end

---Set firing unit reload start time
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Movement.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.RELOAD
  firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  Shared.setGroupUnitProperties(firingUnit, function(unit)
    return Shared.buildModeProperties(isAuto, constants.WCS.HOLD)
  end)
end

---Set firing unit weapon control status to free fire
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Movement.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  Shared.setGroupUnitProperties(firingUnit, function(unit)
    return Shared.buildModeProperties(isAuto, constants.WCS.FREE)
  end)
end

---Set firing unit status to hide
---@param firingUnitCtx SBJ__FiringUnitContext
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Movement.setStateToHide(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.HIDE
  Shared.setGroupUnitProperties(firingUnit, function(unit)
    return Shared.buildModeProperties(isAuto, constants.WCS.HOLD)
  end)
end

---Reset unit state to STATIC and clear reload timer
---@param systemCtx SBJ__MissileSystemContext
---@param firingUnit CMO__Unit
---@param isAuto boolean
function Movement.setStateToStatic(systemCtx, firingUnit, isAuto)
  local unitCtx = systemCtx.firingUnits[firingUnit.name] or systemCtx.resupplyUnits[firingUnit.name]

  if unitCtx then
    unitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
    unitCtx.reloadStartTime = nil
    Shared.setGroupUnitProperties(firingUnit, function(unit)
      return Shared.buildModeProperties(isAuto, constants.WCS.HOLD)
    end)
  end
end

---Check if firing unit is currently repositioning
---@param firingUnitCtx SBJ__FiringUnitContext|nil
---@param isAuto boolean
---@return boolean # Whether the unit is repositioning
function Movement.isRepositioning(firingUnitCtx, isAuto)
  if not firingUnitCtx then
    return false
  end

  if isAuto then
    return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  end

  return true
end

return Movement
