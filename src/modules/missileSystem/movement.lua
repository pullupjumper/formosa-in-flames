local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

local Movement = {}

---Move units to a randomly selected position
---Failure fields omit the unit name because every caller already labels the row
---with the unit it was acting on.
---@param opts SBJ__MoveToPositionOpts Movement options
---@return boolean success Whether the move was successful
---@return table<string, any>? errorFields Log fields describing the failure
function Movement.moveUnitToPosition(opts)
  local posCount = Utils.getCount(opts.positions)
  if posCount == 0 then
    return false, {
      reason = "no_positions_available",
      position = opts.positionType,
      area = opts.areaName
    }
  end

  local posIdx = math.random(posCount)
  local position = opts.positions[posIdx]

  if not position or not position.course then
    return false, {
      reason = "invalid_position_data",
      position = opts.positionType,
      index = posIdx,
      area = opts.areaName
    }
  end

  local course = position.course
  if opts.useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  Shared.applyToGroupUnits(opts.battery, function(unit)
    return {
      unit = unit,
      throttle = constants.THROTTLES.FULL,
      speed = constants.SPEEDS.NORMAL,
      course = course,
      holdPosition = false,
      wcs = opts.wcs
    }
  end)

  return true, nil
end

---Command unit to move to reload point (RL)
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context
---@param unit CMO__Unit Unit group
---@param positions? SBJ__Position[]
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToReloadPoint(unitCtx, unit, positions)
  unitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return Movement.moveUnitToPosition({
    unitName = unitCtx.name,
    battery = unit,
    positions = positions or unitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = unitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command firing unit to move to hide area (HA)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
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
  return Movement.moveUnitToPosition({
    unitName = firingUnitCtx.name,
    battery = firingUnit,
    positions = firingUnitCtx.operationalArea.HA,
    positionType = constants.POSITION_TYPES.HIDE_AREA,
    areaName = firingUnitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return Movement.moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    battery = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.AHA,
    positionType = constants.POSITION_TYPES.AMMO_HOLDING_AREA,
    areaName = resupplyUnitCtx.operationalArea.name
  })
end

---Command resupply unit to move to reload point (RL)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return Movement.moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    battery = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = resupplyUnitCtx.operationalArea.name,
    useLastCourse = true
  })
end

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success
---@return table<string, any>? errorFields
function Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return Movement.moveUnitToPosition({
    unitName = firingUnitCtx.name,
    battery = firingUnit,
    positions = firingUnitCtx.operationalArea.FP,
    positionType = constants.POSITION_TYPES.FIRING_POINT,
    areaName = firingUnitCtx.operationalArea.name
  })
end

---Set firing unit reload start time
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function Movement.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.RELOAD
  firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  Shared.applyToGroupUnits(firingUnit, function(unit)
    return Shared.buildModeProperties(unit, isAuto, constants.WCS.HOLD)
  end)
end

---Set firing unit weapon control status to free fire
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function Movement.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  Shared.applyToGroupUnits(firingUnit, function(unit)
    return Shared.buildModeProperties(unit, isAuto, constants.WCS.FREE)
  end)
end

---Set firing unit status to hide
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether the action is automatic
function Movement.setStateToHide(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.HIDE
  Shared.applyToGroupUnits(firingUnit, function(unit)
    return Shared.buildModeProperties(unit, isAuto, constants.WCS.HOLD)
  end)
end

---Reset unit state to STATIC and clear reload timer
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param firingUnit CMO__Unit Unit group to reset
---@param isAuto boolean Whether the action is automatic
function Movement.setStateToStatic(systemCtx, firingUnit, isAuto)
  local unitCtx = systemCtx.firingUnits[firingUnit.name] or systemCtx.resupplyUnits[firingUnit.name]

  if unitCtx then
    unitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
    unitCtx.reloadStartTime = nil
    Shared.applyToGroupUnits(firingUnit, function(unit)
      return Shared.buildModeProperties(unit, isAuto, constants.WCS.HOLD)
    end)
  end
end

---Check if firing unit is currently repositioning
---@param firingUnitCtx SBJ__FiringUnitContext|nil Firing unit context
---@param isAuto boolean Whether the action is automatic
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
