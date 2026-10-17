---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Hovercraft Unit Tests
local Hovercraft = require("src.modules.landingOps.hovercraft")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("Hovercraft", function()
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
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(0))
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

  ---@return SBJ__RouteConfig
  local function makeRouteConfig()
    return {
      deployLineNm = 12,
      launchLineNm = 3,
      assaultLineNm = 2,
      waterLaneSpacingM = 750,
      beachLaneOffsetsM = { -180, -60, 60, 180 },
      shoreStandoffM = 100,
      inlandMarginM = 100,
      columnSpacingM = 100,
      queueDepth = 5,
      queueSpacingM = 50,
      laneTieNm = 0.5,
      arrivalNm = 0.1,
    }
  end

  local CONFIG = { tuning = { route = makeRouteConfig(), acvWave = { capacity = { zbd05 = 1 }, hovercraftWaitSec = 3600 } }, formationSettings = { hovercraftSpeed = 40 } }
  local zone = {
    name = "Taoyuan",
    movement = { holdingAreas = { mothership = { "RP-ANC" } } },
    landing = {
      hovercraft = { speed = 40, missions = { { name = "LANDING/TAO/1/1", unitCount = 1 }, { name = "LANDING/TAO/1/2", unitCount = 3 } } },
    },
  }

  ---@param isCleared boolean
  ---@return SBJ__ZoneState
  local function makeZoneState(isCleared)
    local lanes = LaneGeometry.buildLanes({
      origin = CENTER,
      bearing = BEARING,
      count = 1,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = makeRouteConfig(),
    })
    for _, beachLane in ipairs(lanes.waterLanes[1].beachLanes) do
      beachLane.isCleared = isCleared
    end
    return { lanes = lanes, obstacle = { cells = {} } }
  end

  ---@param calls string[]
  ---@param overrides? table
  ---@return table
  local function makeCraft(calls, overrides)
    local craft = {
      guid = "LCAC-1",
      dbid = constants.PLATFORMS.TYPE_726A,
      readytime_v = 0,
      cargo = { { cargo = { { guid = "C-1", dbid = constants.PLATFORMS.PLL05 } } } },
      Launch = function() table.insert(calls, "launch") end,
    }
    if overrides then
      for k, v in pairs(overrides) do craft[k] = v end
    end
    return setmetatable(craft, {
      __newindex = function(t, k, v)
        if k == "course" then table.insert(calls, "course") end
        rawset(t, k, v)
      end
    })
  end

  ---@param craft table
  local function stubFleet(craft)
    local pos = LaneGeometry.buildPoint(frame, -25 * 1852, 0)
    local ship = {
      guid = "LHD-1",
      dbid = constants.PLATFORMS.TYPE_075,
      latitude = pos.latitude,
      longitude = pos.longitude,
      embarkedUnits = { [constants.PLATFORM_TYPES.BOATS] = { craft.guid } },
      inArea = function() return true end,
    }
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "LHD-1" then return ship end
      if guid == craft.guid then return craft end
      return nil
    end))
  end

  -- ============================================================================
  -- launchHovercraft
  -- ============================================================================

  describe("launchHovercraft", function()
    -- Positive: course through the lanes is set before Launch and the craft is recorded
    it("should set a lane course before launching and record the hovercraft", function()
      local calls = {}
      local craft = makeCraft(calls)
      stubFleet(craft)
      local zoneState = makeZoneState(true)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({ "course", "launch" }, calls)
      assert.are.same(zoneState.lanes.waterLanes[1].deployPoint, craft.course[1])
      local entry = zoneState.hovercraft["LCAC-1"]
      assert.are.equal("LANDING/TAO/1/1", entry.missionName)
      assert.are.same(craft.course[#craft.course], entry.finalPoint)
      assert.is_false(entry.arrived)
    end)

    -- Negative: no cleared lane means the craft stays aboard
    it("should not launch when no beach lane is cleared", function()
      local calls = {}
      stubFleet(makeCraft(calls))
      local zoneState = makeZoneState(false)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
      assert.is_nil(zoneState.hovercraft["LCAC-1"])
    end)

    -- Negative: empty hovercraft are not sent
    it("should not launch a hovercraft without cargo", function()
      local calls = {}
      stubFleet(makeCraft(calls, { cargo = { { cargo = {} } } }))
      local zoneState = makeZoneState(true)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
    end)

    -- Boundary: a hovercraft is routed only once
    it("should not route an already recorded hovercraft again", function()
      local calls = {}
      stubFleet(makeCraft(calls))
      local zoneState = makeZoneState(true)
      zoneState.hovercraft = { ["LCAC-1"] = { missionName = "X", finalPoint = CENTER, arrived = true } }

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
    end)
  end)

  -- ============================================================================
  -- updateHovercraft
  -- ============================================================================

  describe("updateHovercraft", function()
    -- Positive: a hovercraft at its slot is marked arrived
    it("should mark a hovercraft arrived at its parking slot", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "LCAC-1" }))
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local zoneState = { hovercraft = { ["LCAC-1"] = { missionName = "X", finalPoint = CENTER, arrived = false } } }

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.is_true(zoneState.hovercraft["LCAC-1"].arrived)
    end)

    -- Negative: still under way
    it("should not mark a hovercraft still under way", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "LCAC-1" }))
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local zoneState = { hovercraft = { ["LCAC-1"] = { missionName = "X", finalPoint = CENTER, arrived = false } } }

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.is_false(zoneState.hovercraft["LCAC-1"].arrived)
    end)
  end)
end)
