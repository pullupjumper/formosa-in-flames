local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

---CMO movement and mode commands; Transitions records what they mean for a unit's state
local Movement = {}

---Platforms whose weapon control status lives in the air doctrine field instead of land
---@type table<number, true>
local AIR_WCS_DBIDS = {
  [constants.PLATFORMS.PAC3] = true,
  [constants.PLATFORMS.SKY_GUARD] = true,
  [constants.PLATFORMS.TC2] = true,
  [constants.PLATFORMS.CUSTOMED_TK3] = true,
  [constants.PLATFORMS.CUSTOMED_SAM] = true,
  [constants.PLATFORMS.S300] = true,
  [constants.PLATFORMS.S400] = true,
  [constants.PLATFORMS.HQ12] = true,
  [constants.PLATFORMS.HQ22] = true,
}

---Set unit movement and weapon control status
---@param unit CMO__Unit
---@param params SBJ__SetUnitPropertiesOpts
local function setUnitProperties(unit, params)
  local unitSetParams = {
    guid = unit.guid,
    manualthrottle = params.throttle or "Stop",
    manualSpeed = params.speed or 0,
    holdposition = params.holdPosition == nil and true or params.holdPosition
  }

  if params.course then
    unitSetParams.course = params.course
  end

  GameApi.ScenEdit_SetUnit(unitSetParams)

  if params.wcs then
    local doctrine = { weapon_control_status_land = params.wcs }

    if AIR_WCS_DBIDS[unit.dbid] then
      doctrine = { weapon_control_status_air = params.wcs }
    end

    GameApi.ScenEdit_SetDoctrine({ side = unit.side, guid = unit.guid }, doctrine)
  end

  if params.formation then
    unit.formation = params.formation
  end
end

---Apply the same properties to all units in a group
---@param groupUnit CMO__Unit
---@param props SBJ__SetUnitPropertiesOpts
local function setGroupUnitProperties(groupUnit, props)
  for _, guid in ipairs(Shared.getGroupUnits(groupUnit)) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit then
      setUnitProperties(unit, props)
    end
  end
end

local POSITION_TYPES = constants.POSITION_TYPES

---Every path that sends a battery unit somewhere; Transitions.depart is the only caller of moveTo
---@type table<string, SBJ__MoveOrder>
Movement.ORDER = {
  FIRING_POINT = {
    action = "move_to_firing_point", positionType = POSITION_TYPES.FIRING_POINT, positionKeys = { "FP" }
  },
  HIDE_AREA = {
    action = "move_to_hide_area",
    positionType = POSITION_TYPES.HIDE_AREA,
    positionKeys = { "HA" },
    absentReason = "no_ha_defined",
    wcs = constants.WCS.HOLD
  },
  RELOAD_POINT = {
    action = "move_launcher_to_reload_point",
    positionType = POSITION_TYPES.RELOAD_POINT,
    positionKeys = { "RL" },
    wcs = constants.WCS.HOLD
  },
  -- Stow ended: the transloader leaves its shelter along SHRL; areas without SHRL take RL.
  RESUPPLY_VIA_SHRL = {
    action = "move_transloader_to_reload_point",
    positionType = POSITION_TYPES.RELOAD_POINT,
    positionKeys = { "SHRL", "RL" },
    wcs = constants.WCS.HOLD
  },
  -- Transload done: the transloader drives straight to the last waypoint of an RL course.
  RESUPPLY_RECALL = {
    action = "move_transloader_to_reload_point",
    positionType = POSITION_TYPES.RELOAD_POINT,
    positionKeys = { "RL" },
    useLastCourse = true
  },
  AMMUNITION_TRANSFER_POINT = {
    action = "move_to_ammunition_transfer_point", positionType = POSITION_TYPES.AMMUNITION_TRANSFER_POINT, positionKeys = { "ATP" }
  },
}

---First position list the order names that the operational area defines
---@param operationalArea SBJ__OperationalArea
---@param order SBJ__MoveOrder
---@return SBJ__Position[]|nil
local function findPositions(operationalArea, order)
  for _, key in ipairs(order.positionKeys) do
    if operationalArea[key] then
      return operationalArea[key]
    end
  end
  return nil
end

---Send the unit group along the course of a random position
---@param unit CMO__Unit
---@param positions SBJ__Position[]
---@param order SBJ__MoveOrder
---@param areaName string
---@return table<string, any>|nil errorFields Log fields describing the failure; nil when the order went out
local function issueMove(unit, positions, order, areaName)
  local posCount = Utils.getCount(positions)
  if posCount == 0 then
    return { reason = "no_positions_available", position = order.positionType, area = areaName }
  end

  local posIdx = math.random(posCount)
  local position = positions[posIdx]

  if not position or not position.course then
    return { reason = "invalid_position_data", position = order.positionType, index = posIdx, area = areaName }
  end

  local course = position.course
  if order.useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  setGroupUnitProperties(unit, {
    throttle = constants.THROTTLES.FULL,
    speed = constants.SPEEDS.NORMAL,
    course = course,
    holdPosition = false,
    wcs = order.wcs
  })

  return nil
end

---Order a unit to a position of its operational area; call through Transitions.depart, which records the move
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
---@param unit CMO__Unit
---@param order SBJ__MoveOrder
---@return SBJ__LogResult # OK with unit and action; FAIL adds the reason
function Movement.moveTo(unitState, unit, order)
  local operationalArea = unitState.operationalArea
  local positions = findPositions(operationalArea, order)
  local fields = { unit = unitState.name, action = order.action }
  local errorFields

  if not positions and order.absentReason then
    errorFields = { reason = order.absentReason, area = operationalArea.name }
  else
    errorFields = issueMove(unit, positions or {}, order, operationalArea.name)
  end

  if errorFields then
    return { tag = "FAIL", fields = LogFormat.merge(fields, errorFields) }
  end
  return { tag = "OK", fields = fields }
end

---Hold or release a unit group in place under the auto/manual mode, with the given weapon control status
---@param unit CMO__Unit
---@param isAuto boolean
---@param wcs integer
function Movement.applyMode(unit, isAuto, wcs)
  setGroupUnitProperties(unit, {
    holdPosition = isAuto,
    throttle = isAuto and "Stop" or "OFF",
    speed = isAuto and 0 or "OFF",
    wcs = wcs,
  })
end

return Movement
