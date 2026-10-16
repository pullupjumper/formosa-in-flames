---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps ObstacleClearing Unit Tests
local ObstacleClearing = require("src.modules.landingOps.obstacleClearing")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("ObstacleClearing", function()
  ---@type luassert.spy[]
  local activeStubs
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  local CENTER = { latitude = 25.0, longitude = 121.0 }
  local BEARING = 150
  local frame = { origin = CENTER, bearing = BEARING }
  local CONFIG = { red = { amphibOps = { obstacle = { cellSizeM = 50, clearSec = 600 } } } }
  local zone = { name = "Penghu", obstacleArea = { "RP-O1", "RP-O2", "RP-O3", "RP-O4" } }

  ---@return SBJ__ZoneState
  local function makeZoneState()
    local routeConfig = {
      deployLineNm = 12, launchLineNm = 3, assaultLineNm = 2,
      waterLaneSpacingM = 750, beachLaneOffsetsM = { -180, -60, 60, 180 }, shoreStandoffM = 100,
    }
    local params = {
      origin = CENTER, bearing = BEARING, count = 1, inlandDepthM = 400, areaMarginM = 60,
      routeConfig = routeConfig,
    }
    local boats = {
      ["BOAT-ALIVE"] = { beachLaneId = "W1-B1", status = "arrived" },
      ["BOAT-DEAD"] = { beachLaneId = "W1-B2", status = "arrived" },
      ["BOAT-LOST"] = { beachLaneId = "W1-B3", status = "lost" },
    }
    local zoneState = { lanes = LaneGeometry.buildLanes(params), boats = boats }
    return zoneState
  end

  before_each(function()
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      return guid == "BOAT-ALIVE" and { guid = guid } or nil
    end))
    trackStub(stub(GameUtils, "findAreaLocations").returns({
      LaneGeometry.buildPoint(frame, 0, -500),
      LaneGeometry.buildPoint(frame, 0, 500),
      LaneGeometry.buildPoint(frame, 300, 500),
      LaneGeometry.buildPoint(frame, 300, -500),
    }))
  end)

  ---@param cells SBJ__ObstacleCellEntry[]
  ---@param state string
  ---@return integer
  local function countState(cells, state)
    local count = 0
    for _, cell in ipairs(cells) do
      if cell.state == state then count = count + 1 end
    end
    return count
  end

  -- Positive: cells tile the area; those in front of a living boat start clearing
  it("should tile the obstacle area and mark the living boat's lane as clearing", function()
    local zoneState = makeZoneState()

    ObstacleClearing.startObstacleClearing(CONFIG, zone, zoneState, 1000)

    assert.are.equal(1000, zoneState.obstacleStartedAt)
    assert.are.equal(120, #zoneState.obstacle.cells) -- 6 x 20 cells
    assert.are.equal(6, countState(zoneState.obstacle.cells, constants.OBSTACLE_CELL_STATES.CLEARING))
  end)

  -- Negative: nothing clears before clearSec
  it("should not clear before clearSec has passed", function()
    local zoneState = makeZoneState()
    ObstacleClearing.startObstacleClearing(CONFIG, zone, zoneState, 1000)

    assert.is_false(ObstacleClearing.updateObstacleClearing(CONFIG, zoneState, 1500))
    assert.is_false(zoneState.lanes.waterLanes[1].beachLanes[1].isCleared)
  end)

  -- Positive: after clearSec only lanes with a living boat open
  it("should clear cells and open only lanes whose boat is alive after clearSec", function()
    local zoneState = makeZoneState()
    ObstacleClearing.startObstacleClearing(CONFIG, zone, zoneState, 1000)

    local done = ObstacleClearing.updateObstacleClearing(CONFIG, zoneState, 1600)
    local beachLanes = zoneState.lanes.waterLanes[1].beachLanes

    assert.is_true(done)
    assert.is_true(beachLanes[1].isCleared)
    assert.is_false(beachLanes[2].isCleared)
    assert.is_false(beachLanes[3].isCleared)
    assert.are.equal(6, countState(zoneState.obstacle.cells, constants.OBSTACLE_CELL_STATES.CLEARED))
    local route = { beachLanes[1].shorePoint, beachLanes[1].endPoint }
    assert.is_true(LaneGeometry.isRouteClear(route, zoneState.obstacle.cells))
  end)
end)
