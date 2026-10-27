---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Hovercraft Unit Tests
local Hovercraft = require("src.modules.landingOps.hovercraft")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("Hovercraft", function()
  local trackStub = StubTracker.track

  before_each(function()
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(0))
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  local ORIGIN = { latitude = 25.0, longitude = 121.0 }
  local FINAL_POINT = { latitude = 25.0, longitude = 121.0 }
  local BEARING = 150
  local frame = { origin = ORIGIN, bearing = BEARING }

  ---@return SBJ__RouteConfig
  local function buildRouteConfig()
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

  local CONFIG = { tuning = { route = buildRouteConfig(), acvWave = { capacity = { zbd05 = 1 }, hovercraftWaitSec = 3600 } }, formation = { hovercraftSpeed = 40 } }
  local zone = {
    name = "Taoyuan",
    movement = { holdingAreas = { mothership = { "RP-ANC" } } },
    landing = {
      hovercraft = { speed = 40, missionName = "LANDING/TAO/1/1" },
    },
  }

  ---@param isCleared boolean
  ---@return SBJ__ZoneState
  local function buildZoneState(isCleared)
    local lanes = LaneGeometry.buildLanes({
      origin = ORIGIN,
      bearing = BEARING,
      count = 1,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = buildRouteConfig(),
    })
    for _, beachLane in ipairs(lanes.waterLanes[1].beachLanes) do
      beachLane.isCleared = isCleared
    end
    return { lanes = lanes, obstacle = { cells = {} } }
  end

  ---@param calls string[]
  ---@param overrides? table
  ---@return table
  local function buildCraft(calls, overrides)
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
    it("should set a lane course before launching and record the hovercraft", function()
      local calls = {}
      local craft = buildCraft(calls)
      stubFleet(craft)
      local zoneState = buildZoneState(true)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({ "course", "launch" }, calls)
      assert.are.same(zoneState.lanes.waterLanes[1].deployPoint, craft.course[1])
      local entry = zoneState.hovercraft["LCAC-1"]
      assert.are.equal("LANDING/TAO/1/1", entry.missionName)
      assert.are.same(craft.course[#craft.course], entry.finalPoint)
      assert.are.equal("enroute", entry.phase)
    end)

    it("should not launch when no beach lane is cleared", function()
      local calls = {}
      stubFleet(buildCraft(calls))
      local zoneState = buildZoneState(false)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
      assert.is_nil(zoneState.hovercraft["LCAC-1"])
    end)

    it("should not launch a hovercraft without cargo", function()
      local calls = {}
      stubFleet(buildCraft(calls, { cargo = { { cargo = {} } } }))
      local zoneState = buildZoneState(true)

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
    end)

    it("should not route an already recorded hovercraft again", function()
      local calls = {}
      stubFleet(buildCraft(calls))
      local zoneState = buildZoneState(true)
      zoneState.hovercraft = { ["LCAC-1"] = { missionName = "X", finalPoint = FINAL_POINT, phase = "returning" } }

      local ships = { { guid = "LHD-1" } }

      Hovercraft.launchHovercraft(CONFIG, zone, zoneState, ships)

      assert.are.same({}, calls)
    end)
  end)

  -- ============================================================================
  -- updateHovercraft
  -- ============================================================================

  describe("updateHovercraft", function()
    local stubUnload

    before_each(function()
      stubUnload = trackStub(stub(GameApi, "ScenEdit_UnloadCargo"))
    end)

    ---@param phase string
    ---@return SBJ__ZoneState
    local function buildState(phase)
      return { hovercraft = { ["LCAC-1"] = { missionName = "X", finalPoint = FINAL_POINT, phase = phase } } }
    end

    it("should unload a hovercraft that reaches its parking slot", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "LCAC-1", RTB = spy.new(function() end) }))
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local zoneState = buildState("enroute")

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.stub(stubUnload).was.called_with("LCAC-1")
      assert.are.equal("unloading", zoneState.hovercraft["LCAC-1"].phase)
    end)

    it("should neither unload nor return a hovercraft still under way", function()
      local craft = { guid = "LCAC-1", condition = constants.UNIT_CONDITIONS.UNDERWAY, RTB = spy.new(function() end) }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(craft))
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local zoneState = buildState("enroute")

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.stub(stubUnload).was_not.called()
      assert.spy(craft.RTB).was_not.called()
      assert.are.equal("enroute", zoneState.hovercraft["LCAC-1"].phase)
    end)

    it("should keep waiting while the cargo is still transferring", function()
      local craft = { guid = "LCAC-1", condition = constants.UNIT_CONDITIONS.TRANSFERRING_CARGO, RTB = spy.new(function() end) }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(craft))
      local zoneState = buildState("unloading")

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.spy(craft.RTB).was_not.called()
      assert.are.equal("unloading", zoneState.hovercraft["LCAC-1"].phase)
    end)

    it("should send a hovercraft home once its cargo is out", function()
      local craft = { guid = "LCAC-1", condition = constants.UNIT_CONDITIONS.UNDERWAY, RTB = spy.new(function() end) }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(craft))
      local zoneState = buildState("unloading")

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.spy(craft.RTB).was.called(1)
      assert.is_true(craft.RTB.calls[1].vals[2])
      assert.are.equal("returning", zoneState.hovercraft["LCAC-1"].phase)
    end)

    it("should not touch a hovercraft already returning", function()
      local craft = { guid = "LCAC-1", condition = constants.UNIT_CONDITIONS.UNDERWAY, RTB = spy.new(function() end) }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(craft))
      local zoneState = buildState("returning")

      Hovercraft.updateHovercraft(CONFIG, zoneState)

      assert.stub(stubUnload).was_not.called()
      assert.spy(craft.RTB).was_not.called()
    end)
  end)

  describe("hasUnlaunchedHovercraft", function()
    local ships = { { guid = "LHD-1" } }

    it("should return true when a mothership holds a loaded, unrouted hovercraft", function()
      stubFleet(buildCraft({}))
      local zoneState = {}

      assert.is_true(Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, ships))
    end)

    it("should return false once the hovercraft is routed", function()
      stubFleet(buildCraft({}))
      local zoneState = { hovercraft = { ["LCAC-1"] = {} } }

      assert.is_false(Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, ships))
    end)

    it("should return false when the hovercraft carries no cargo", function()
      stubFleet(buildCraft({}, { cargo = { { cargo = {} } } }))
      local zoneState = {}

      assert.is_false(Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, ships))
    end)

    it("should return false when the mothership is outside the holding area", function()
      local craft = buildCraft({})
      local outside = {
        guid = "LHD-1",
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return false end,
        embarkedUnits = { [constants.PLATFORM_TYPES.BOATS] = { craft.guid } },
      }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "LHD-1" then return outside end
        return craft
      end))
      local zoneState = {}

      assert.is_false(Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, ships))
    end)
  end)
end)
