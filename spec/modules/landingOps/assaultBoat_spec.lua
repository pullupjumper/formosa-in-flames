-- LandingOps AssaultBoat Unit Tests
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
describe("AssaultBoat", function()
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

  ---@return table
  local function makeConfig()
    return { red = { amphibOps = { route = makeRouteConfig(), assaultBoat = { speed = 30 } } } }
  end

  ---@param count integer
  ---@return SBJ__LanePlanState
  local function makeLanes(count)
    return LaneGeometry.buildLanes({
      origin = CENTER,
      bearing = BEARING,
      count = count,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = makeRouteConfig(),
    })
  end

  local zone = { name = "Sishu", lstAnchorageArea = { "RP-LST" }, acv = { area = { "RP-ACV" } } }

  ---Build carriers spread left to right, each with boatsPer assault boats
  ---@param carrierCount integer
  ---@param boatsPer integer
  ---@return table unitMap
  ---@return table ships
  local function makeFleet(carrierCount, boatsPer)
    local unitMap, ships = {}, {}
    for i = 1, carrierCount do
      local pos = LaneGeometry.buildPoint(frame, -20000, (i - (carrierCount + 1) / 2) * 400)
      local boats = {}
      for j = 1, boatsPer do
        local boatGuid = "BOAT-" .. i .. "-" .. j
        table.insert(boats, boatGuid)
        unitMap[boatGuid] = { guid = boatGuid, dbid = constants.PLATFORMS.ASSAULT_BOAT, readytime_v = 0 }
      end
      local guid = "LST-" .. i
      unitMap[guid] = {
        guid = guid,
        dbid = constants.PLATFORMS.TYPE_072A,
        latitude = pos.latitude,
        longitude = pos.longitude,
        embarkedUnits = { [constants.PLATFORM_TYPES.BOATS] = boats },
        inArea = function() return true end,
      }
      table.insert(ships, { guid = guid })
    end
    return unitMap, ships
  end

  ---@param unitMap table<string, table>
  local function stubUnits(unitMap)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return unitMap[guid] end))
  end

  ---@param boats table<string, SBJ__AssaultBoatState>
  ---@return table<string, true>
  local function collectLaneIds(boats)
    local laneIdSet = {}
    for _, entry in pairs(boats) do laneIdSet[entry.beachLaneId] = true end
    return laneIdSet
  end

  -- ============================================================================
  -- pairBoats
  -- ============================================================================

  describe("pairBoats", function()
    -- Positive: enough first boats cover every lane one-to-one
    it("should pair one boat per beach lane using each carrier's first boat first", function()
      local unitMap, ships = makeFleet(4, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = makeLanes(1) }

      AssaultBoat.pairBoats(zone, zoneState, ships)

      local count = 0
      for boatGuid, entry in pairs(zoneState.boats) do
        count = count + 1
        assert.truthy(boatGuid:match("%-1$"))
        assert.are.equal("pending", entry.status)
      end
      assert.are.equal(4, count)
      assert.are.equal("W1-B1", zoneState.boats["BOAT-1-1"].beachLaneId)
      assert.are.equal("W1-B4", zoneState.boats["BOAT-4-1"].beachLaneId)
    end)

    -- Boundary: Sishu has 12 boats for 16 lanes and drops the 4 outermost lanes on one side
    it("should drop the outermost lanes on one side when boats are short", function()
      local unitMap, ships = makeFleet(6, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = makeLanes(4) }

      AssaultBoat.pairBoats(zone, zoneState, ships)

      local laneIdSet = collectLaneIds(zoneState.boats)
      local usedLeft = laneIdSet["W1-B1"] and laneIdSet["W1-B4"]
      local usedRight = laneIdSet["W4-B1"] and laneIdSet["W4-B4"]
      local count = 0
      for _ in pairs(laneIdSet) do count = count + 1 end

      assert.are.equal(12, count)
      assert.is_true((usedLeft and not laneIdSet["W4-B1"]) or (usedRight and not laneIdSet["W1-B4"]))
    end)

    -- Positive: second boats fill lanes when first boats run out
    it("should add second boats when first boats are not enough", function()
      local unitMap, ships = makeFleet(3, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = makeLanes(1) }

      AssaultBoat.pairBoats(zone, zoneState, ships)

      local count = 0
      for _ in pairs(zoneState.boats) do count = count + 1 end
      assert.are.equal(4, count)
      assert.is_not_nil(zoneState.boats["BOAT-1-1"])
      assert.is_not_nil(zoneState.boats["BOAT-3-1"])
    end)
  end)

  -- ============================================================================
  -- launchBoats
  -- ============================================================================

  describe("launchBoats", function()
    -- Positive: course is set before Launch, then speed and status follow
    it("should set course and speed before launching a boat whose carrier is in the ACV area", function()
      local calls = {}
      local boat = { guid = "BOAT-1", readytime_v = 0 }
      setmetatable(boat, {
        __newindex = function(t, k, v)
          if k == "course" then table.insert(calls, "course") end
          rawset(t, k, v)
        end
      })
      boat.Launch = function() table.insert(calls, "launch") end
      stubUnits({ ["LST-1"] = { guid = "LST-1", inArea = function() return true end }, ["BOAT-1"] = boat })
      local zoneState = {
        lanes = makeLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(makeConfig(), zone, zoneState)

      assert.are.same({ "course", "launch" }, calls)
      assert.are.equal(30, boat.manualSpeed)
      assert.are.equal(5, #boat.course)
      assert.are.equal("launched", zoneState.boats["BOAT-1"].status)
      assert.are.same(zoneState.lanes.waterLanes[1].beachLanes[2].shorePoint, zoneState.boats["BOAT-1"].finalPoint)
    end)

    -- Negative: carrier not yet at the launch area keeps the boat aboard
    it("should not launch while the carrier is outside the ACV area", function()
      local launched = false
      stubUnits({
        ["LST-1"] = { guid = "LST-1", inArea = function() return false end },
        ["BOAT-1"] = { guid = "BOAT-1", readytime_v = 0, Launch = function() launched = true end },
      })
      local zoneState = {
        lanes = makeLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(makeConfig(), zone, zoneState)

      assert.is_false(launched)
      assert.are.equal("pending", zoneState.boats["BOAT-1"].status)
    end)
  end)

  -- ============================================================================
  -- updateBoats / findLandedLaneIdSet
  -- ============================================================================

  describe("updateBoats", function()
    -- Positive: all boats at S_lane or lost finishes the phase
    it("should finish when every boat has arrived or been lost", function()
      stubUnits({ ["BOAT-1"] = { guid = "BOAT-1" } })
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local zoneState = {
        boats = {
          ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = CENTER },
          ["BOAT-2"] = { beachLaneId = "W1-B2", status = "launched", finalPoint = CENTER },
        },
      }

      assert.is_true(AssaultBoat.updateBoats(makeConfig(), zoneState))
      assert.are.equal("arrived", zoneState.boats["BOAT-1"].status)
      assert.are.equal("lost", zoneState.boats["BOAT-2"].status)
      assert.are.same({ ["W1-B1"] = true }, AssaultBoat.findLandedLaneIdSet(zoneState))
    end)

    -- Negative: a boat still under way or aboard keeps the phase going
    it("should not finish while a boat is still under way or pending", function()
      stubUnits({ ["BOAT-1"] = { guid = "BOAT-1" }, ["BOAT-2"] = { guid = "BOAT-2" } })
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local zoneState = {
        boats = {
          ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = CENTER },
          ["BOAT-2"] = { beachLaneId = "W1-B2", status = "pending" },
        },
      }

      assert.is_false(AssaultBoat.updateBoats(makeConfig(), zoneState))
    end)
  end)
end)
