---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps MineClearing Unit Tests
local MineClearing = require("src.modules.landingOps.mineClearing")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MineClearing", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local errorStub
  ---@type luassert.spy
  local logStub
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
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

  ---@return table
  local function makeConfig()
    return {
      tuning = {
        route = {
          deployLineNm = 12,
          launchLineNm = 3,
          assaultLineNm = 2,
          waterLaneSpacingM = 750,
          waterLaneMinSpacingM = 500,
          waterLaneMaxSpacingM = 1000,
          beachLaneOffsetsM = { -180, -60, 60, 180 },
          shoreStandoffM = 100,
          inlandMarginM = 100,
          columnSpacingM = 100,
          queueDepth = 5,
          queueSpacingM = 50,
          laneTieNm = 0.5,
          arrivalNm = 0.1,
        },
        mineClearing = { areaMarginM = 60 },
      },
      minefields = {},
      formation = { shipSpeed = 17 }
    }
  end

  ---@return table
  local function makeZone()
    return {
      name = "Taoyuan",
      heading = BEARING,
      movement = { holdingAreas = { deployLine = { "RP-LST" }, mothership = { "RP-ANC" } } },
      landing = {
        laneCenter = { "RP-CENTER" },
        obstacleArea = { "RP-O1", "RP-O2", "RP-O3" },
        sweeper = { missionName = "", settings = {} },
        acv = { area = { "RP-10", "RP-11" } },
      },
    }
  end

  ---@param guid string
  ---@param lateral number
  ---@param overrides? table
  ---@return table
  local function makeSweeper(guid, lateral, overrides)
    local pos = LaneGeometry.buildPoint(frame, -20000, lateral)
    local unit = {
      guid = guid,
      name = guid,
      dbid = constants.PLATFORMS.TYPE_082,
      latitude = pos.latitude,
      longitude = pos.longitude,
      inArea = function() return true end,
      RTB = function() end,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---@param guid string
  ---@param lateral number
  ---@return table
  local function makeLST(guid, lateral)
    local pos = LaneGeometry.buildPoint(frame, -20000, lateral)
    return {
      guid = guid,
      name = guid,
      type = "Ship",
      dbid = constants.PLATFORMS.TYPE_071,
      latitude = pos.latitude,
      longitude = pos.longitude,
      inArea = function() return true end,
    }
  end

  ---@param unitMap table<string, table>
  local function stubUnits(unitMap)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return unitMap[guid] end))
  end

  local function stubReferencePoints()
    trackStub(stub(GameUtils, "findAreaLocations").invokes(function(_, area)
      if area[1] == "RP-CENTER" then return { CENTER } end
      return {
        LaneGeometry.buildPoint(frame, 0, -2000),
        LaneGeometry.buildPoint(frame, 300, 0),
        LaneGeometry.buildPoint(frame, 0, 2000),
      }
    end))
  end

  -- ============================================================================
  -- layMinefields
  -- ============================================================================

  describe("layMinefields", function()
    -- Positive: lays a BLUE minefield of sea mines over the configured area
    it("should lay BLUE sea mines for each configured minefield", function()
      local stubAdd = trackStub(stub(GameApi, "ScenEdit_AddMinefield").returns(40))

      local config = { minefields = { { area = { "RP-M1", "RP-M2", "RP-M3" }, number = 40, delay = 0 } } }

      MineClearing.layMinefields(config)

      assert.stub(stubAdd).was.called_with({
        side = constants.SIDES.BLUE,
        dbid = constants.WEAPONS.SEA_MINE,
        number = 40,
        delay = 0,
        area = { "RP-M1", "RP-M2", "RP-M3" },
      })
    end)

    -- Negative: empty areas are skipped without calling CMO
    it("should skip minefields whose area is not set", function()
      local stubAdd = trackStub(stub(GameApi, "ScenEdit_AddMinefield"))

      local config = { minefields = { { area = {}, number = 40, delay = 0 } } }

      MineClearing.layMinefields(config)

      assert.stub(stubAdd).was_not.called()
    end)
  end)

  -- ============================================================================
  -- startMineClearing
  -- ============================================================================

  describe("startMineClearing", function()
    -- Positive: each sweeper gets its water lane's sweep course, left to right
    it("should build lanes and give each sweeper its sweep course and mission area", function()
      stubReferencePoints()
      local left = makeSweeper("529-L", -800)
      local right = makeSweeper("529-R", 800)
      stubUnits({ ["529-L"] = left, ["529-R"] = right })
      local zoneState = {}
      local ships = { { guid = "529-R" }, { guid = "529-L" } }

      local ok = MineClearing.startMineClearing(makeConfig(), makeZone(), zoneState, ships)

      assert.is_true(ok)
      assert.are.equal(2, #zoneState.lanes.waterLanes)
      assert.are.same(zoneState.lanes.waterLanes[1].sweepCourse, left.course)
      assert.are.same(zoneState.lanes.waterLanes[2].sweepCourse, right.course)
      assert.are.equal("W1", zoneState.minesweepers["529-L"].waterLaneId)
      assert.are.equal(4, #zoneState.minesweepers["529-L"].missionArea)
      assert.is_false(zoneState.minesweepers["529-L"].isDone)
      -- E_lane = obstacle depth 300 m + inland margin 100 m
      local endAlong = LaneGeometry.projectPoint(frame, zoneState.lanes.waterLanes[1].beachLanes[1].endPoint)
      assert.is_near(400, endAlong, 0.5)
    end)

    -- Positive: lanes sit in the gaps between the deploy line LSTs, not on them
    it("should place water lanes at the midpoints of the gaps between LSTs", function()
      stubReferencePoints()
      stubUnits({
        ["529-L"] = makeSweeper("529-L", -800),
        ["529-R"] = makeSweeper("529-R", 800),
        ["LST-1"] = makeLST("LST-1", -750),
        ["LST-2"] = makeLST("LST-2", 0),
        ["LST-3"] = makeLST("LST-3", 750),
      })
      local zoneState = {}
      local ships = { { guid = "529-L" }, { guid = "529-R" }, { guid = "LST-1" }, { guid = "LST-2" }, { guid = "LST-3" } }

      assert.is_true(MineClearing.startMineClearing(makeConfig(), makeZone(), zoneState, ships))

      local _, left = LaneGeometry.projectPoint(frame, zoneState.lanes.waterLanes[1].launchPoint)
      local _, right = LaneGeometry.projectPoint(frame, zoneState.lanes.waterLanes[2].launchPoint)
      assert.is_near(-375, left, 0.5)
      assert.is_near(375, right, 0.5)
    end)

    -- Negative: gaps too narrow for the lanes fall back to even spacing with a WARN
    it("should fall back to even spacing and warn when the LST gaps cannot hold the lanes", function()
      stubReferencePoints()
      stubUnits({
        ["529-L"] = makeSweeper("529-L", -800),
        ["529-R"] = makeSweeper("529-R", 800),
        ["LST-1"] = makeLST("LST-1", -100),
        ["LST-2"] = makeLST("LST-2", 100),
      })
      local zoneState = {}
      local ships = { { guid = "529-L" }, { guid = "529-R" }, { guid = "LST-1" }, { guid = "LST-2" } }

      assert.is_true(MineClearing.startMineClearing(makeConfig(), makeZone(), zoneState, ships))

      local _, left = LaneGeometry.projectPoint(frame, zoneState.lanes.waterLanes[1].launchPoint)
      assert.is_near(-375, left, 0.5)
      local logged = ""
      for _, call in ipairs(logStub.calls) do logged = logged .. tostring(call.vals[2]) end
      assert.truthy(string.find(logged, "ship_gaps_cannot_hold_lanes"))
    end)

    -- Positive: fast-forward deletes only the mines lying on a lane
    it("should delete only the mines inside lane cells in fast-forward", function()
      stubReferencePoints()
      stubUnits({ ["529-1"] = makeSweeper("529-1", 0) })
      local onLane = LaneGeometry.buildPoint(frame, -5000, 10)
      local offLane = LaneGeometry.buildPoint(frame, -5000, 300)
      trackStub(stub(GameApi, "ScenEdit_GetMinefield").returns({
        { guid = "M-ON",  latitude = onLane.latitude,  longitude = onLane.longitude },
        { guid = "M-OFF", latitude = offLane.latitude, longitude = offLane.longitude },
      }))
      local deleteStub = trackStub(stub(GameApi, "ScenEdit_DeleteMine").returns(true))
      trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local config = makeConfig()
      config.debug = { enabled = true }
      config.tuning.obstacle = { cellSizeM = 50 }
      config.minefields = { { area = { "RP-M1", "RP-M2", "RP-M3" }, number = 2, delay = 0 } }

      local zoneState = {}
      local ships = { { guid = "529-1" } }

      assert.is_true(MineClearing.startMineClearing(config, makeZone(), zoneState, ships))

      assert.stub(deleteStub).was.called(1)
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.BLUE, guid = "M-ON" })
    end)

    -- Negative: missing reference points are logged and nothing changes
    it("should fail without changes when lane reference points are not set", function()
      trackStub(stub(GameUtils, "findAreaLocations").returns({}))
      local zoneState = {}
      local ships = {}

      local ok = MineClearing.startMineClearing(makeConfig(), makeZone(), zoneState, ships)

      assert.is_false(ok)
      assert.is_nil(zoneState.lanes)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=lane_reference_points_not_set"))
    end)

    -- Negative: no Type 529 in the zone
    it("should fail when no Type 529 is in the zone", function()
      stubReferencePoints()
      stubUnits({ ["S-1"] = makeSweeper("S-1", 0, { dbid = constants.PLATFORMS.TYPE_072A }) })

      local zoneState = {}
      local ships = { { guid = "S-1" } }

      local ok = MineClearing.startMineClearing(makeConfig(), makeZone(), zoneState, ships)

      assert.is_false(ok)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=no_type082_in_zone"))
    end)
  end)

  -- ============================================================================
  -- updateMineClearing
  -- ============================================================================

  describe("updateMineClearing", function()
    local FINAL = { latitude = 24.9, longitude = 121.1 }

    -- Positive: a sweeper at its final point is sent home
    it("should RTB a sweeper that reached its final point and report done", function()
      local rtbCalled = false
      stubUnits({ ["529-1"] = makeSweeper("529-1", 0, { RTB = function() rtbCalled = true end }) })
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local zoneState = { minesweepers = { ["529-1"] = { finalPoint = FINAL, isDone = false } } }

      local done = MineClearing.updateMineClearing(makeConfig(), zoneState)

      assert.is_true(done)
      assert.is_true(rtbCalled)
      assert.is_true(zoneState.minesweepers["529-1"].isDone)
    end)

    -- Negative: a sweeper still under way keeps the phase going
    it("should not report done while a sweeper is still under way", function()
      local rtbCalled = false
      stubUnits({ ["529-1"] = makeSweeper("529-1", 0, { RTB = function() rtbCalled = true end }) })
      trackStub(stub(GameApi, "Tool_Range").returns(3))
      local zoneState = { minesweepers = { ["529-1"] = { finalPoint = FINAL, isDone = false } } }

      assert.is_false(MineClearing.updateMineClearing(makeConfig(), zoneState))
      assert.is_false(rtbCalled)
    end)

    -- Boundary: a destroyed sweeper counts as done
    it("should count a destroyed sweeper as done", function()
      stubUnits({})
      local zoneState = { minesweepers = { ["529-1"] = { finalPoint = FINAL, isDone = false } } }

      assert.is_true(MineClearing.updateMineClearing(makeConfig(), zoneState))
    end)
  end)
end)
