local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")

local ObstacleClearing = {}

---Set the state of every cell that the inland line of the beach lane touches
---@param cells SBJ__ObstacleCellEntry[]
---@param beachLane SBJ__BeachLaneEntry
---@param state string constants.OBSTACLE_CELL_STATES value
---@return integer # Number of cells set
local function setLaneCells(cells, beachLane, state)
  local count = 0
  for _, cell in ipairs(cells) do
    if LaneGeometry.isSegmentTouchingCell(beachLane.assaultPoint, beachLane.endPoint, cell) then
      cell.state = state
      cell.beachLaneId = beachLane.id
      count = count + 1
    end
  end
  return count
end

---Call fn for every beach lane that has a landed, living boat
---@param zoneState SBJ__ZoneState
---@param fn fun(beachLane: SBJ__BeachLaneEntry)
local function forEachLandedLane(zoneState, fn)
  local laneIdSet = AssaultBoat.findLandedLaneIdSet(zoneState)
  for _, waterLane in ipairs(zoneState.lanes.waterLanes) do
    for _, beachLane in ipairs(waterLane.beachLanes) do
      if laneIdSet[beachLane.id] then
        fn(beachLane)
      end
    end
  end
end

---Start obstacle clearing in a zone. Tile the obstacle area into cells and set the cells in front of landed boats to clearing.
---Then start the clearing timer.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param currentTime number
---@return boolean # Always true. A missing obstacle area gives no cells
function ObstacleClearing.startObstacleClearing(amphibOps, zone, zoneState, currentTime)
  local lanes = zoneState.lanes

  if not lanes then
    return false
  end

  local frame = LaneGeometry.buildFrame(lanes)
  local polygon = GameUtils.findAreaLocations(constants.SIDES.BLUE, zone.landing.obstacleArea)
  local cells = LaneGeometry.buildObstacleCells(frame, polygon, amphibOps.tuning.obstacle.cellSizeM)

  zoneState.obstacle = { cells = cells }
  zoneState.obstacleStartedAt = currentTime

  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Start obstacle clearing")
  report.add("OK", { cells = #cells })
  forEachLandedLane(zoneState, function(beachLane)
    report.add("OK", {
      beachLane = beachLane.id,
      cells = setLaneCells(cells, beachLane, constants.OBSTACLE_CELL_STATES.CLEARING),
    })
  end)
  report.emit()

  return true
end

---Update obstacle clearing in a zone. After clearSec, clear the cells of each lane whose boat is alive and open those lanes
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@param currentTime number
---@return boolean # True once clearing has finished
function ObstacleClearing.updateObstacleClearing(amphibOps, zoneState, currentTime)
  local elapsed = currentTime - (zoneState.obstacleStartedAt or currentTime)
  local isFastForward = DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING)
  if not isFastForward and elapsed < amphibOps.tuning.obstacle.clearSec then
    return false
  end

  local cells = zoneState.obstacle and zoneState.obstacle.cells or {}
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "obstacle", "Clear obstacles")

  forEachLandedLane(zoneState, function(beachLane)
    setLaneCells(cells, beachLane, constants.OBSTACLE_CELL_STATES.CLEARED)
    beachLane.isCleared = true
    report.add("OK", { beachLane = beachLane.id })
  end)
  report.emit()

  return true
end

return ObstacleClearing
