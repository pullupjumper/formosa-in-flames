---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps AssaultBoat Unit Tests
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("AssaultBoat", function()
  local trackStub = StubTracker.track

  before_each(function()
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
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

  ---@return table
  local function buildConfig()
    return { route = buildRouteConfig(), formation = { assaultBoatSpeed = 30 } }
  end

  ---@param count integer
  ---@return SBJ__LanePlanState
  local function buildLanes(count)
    return LaneGeometry.buildLanes({
      origin = ORIGIN,
      bearing = BEARING,
      count = count,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = buildRouteConfig(),
    })
  end

  local zone = { name = "Sishu", movement = { holdingAreas = { deployLine = { "RP-LST" } } }, landing = { acv = { area = { "RP-ACV" } } } }

  ---Build carriers spread left to right, each with boatsPer assault boats
  ---@param carrierCount integer
  ---@param boatsPer integer
  ---@return table unitMap
  ---@return table ships
  local function buildFleet(carrierCount, boatsPer)
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

  describe("pairBoats", function()
    it("should pair one boat per beach lane using each carrier's first boat first", function()
      local unitMap, ships = buildFleet(4, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = buildLanes(1) }

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

    -- Sishu has 12 boats for 16 lanes and drops the 4 outermost lanes on one side
    it("should drop the outermost lanes on one side when boats are short", function()
      local unitMap, ships = buildFleet(6, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = buildLanes(4) }

      AssaultBoat.pairBoats(zone, zoneState, ships)

      local laneIdSet = collectLaneIds(zoneState.boats)
      local usedLeft = laneIdSet["W1-B1"] and laneIdSet["W1-B4"]
      local usedRight = laneIdSet["W4-B1"] and laneIdSet["W4-B4"]
      local count = 0
      for _ in pairs(laneIdSet) do count = count + 1 end

      assert.are.equal(12, count)
      assert.is_true((usedLeft and not laneIdSet["W4-B1"]) or (usedRight and not laneIdSet["W1-B4"]))
    end)

    it("should add second boats when first boats are not enough", function()
      local unitMap, ships = buildFleet(3, 2)
      stubUnits(unitMap)
      local zoneState = { lanes = buildLanes(1) }

      AssaultBoat.pairBoats(zone, zoneState, ships)

      local count = 0
      for _ in pairs(zoneState.boats) do count = count + 1 end
      assert.are.equal(4, count)
      assert.is_not_nil(zoneState.boats["BOAT-1-1"])
      assert.is_not_nil(zoneState.boats["BOAT-3-1"])
    end)
  end)

  describe("launchBoats", function()
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
        lanes = buildLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(buildConfig(), zone, zoneState)

      assert.are.same({ "course", "launch" }, calls)
      assert.are.equal(30, boat.manualSpeed)
      assert.are.equal(5, #boat.course)
      assert.are.equal("launched", zoneState.boats["BOAT-1"].status)
      assert.are.same(zoneState.lanes.waterLanes[1].beachLanes[2].shorePoint, zoneState.boats["BOAT-1"].finalPoint)
    end)

    it("should hold a slot on the boat's beach lane after launching", function()
      stubUnits({
        ["LST-1"] = { guid = "LST-1", inArea = function() return true end },
        ["BOAT-1"] = { guid = "BOAT-1", readytime_v = 0, Launch = function() end },
      })
      local zoneState = {
        lanes = buildLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(buildConfig(), zone, zoneState)

      local heldSlots = zoneState.laneSlots["W1-B2"]
      assert.are.equal("BOAT-1", heldSlots[#heldSlots])
    end)

    it("should not launch while the carrier is outside the ACV area", function()
      local launched = false
      stubUnits({
        ["LST-1"] = { guid = "LST-1", inArea = function() return false end },
        ["BOAT-1"] = { guid = "BOAT-1", readytime_v = 0, Launch = function() launched = true end },
      })
      local zoneState = {
        lanes = buildLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(buildConfig(), zone, zoneState)

      assert.is_false(launched)
      assert.are.equal("pending", zoneState.boats["BOAT-1"].status)
    end)

    it("should remove a pending boat that is no longer found", function()
      stubUnits({ ["LST-1"] = { guid = "LST-1", inArea = function() return true end } })
      local zoneState = {
        lanes = buildLanes(1),
        boats = { ["BOAT-1"] = { shipGuid = "LST-1", beachLaneId = "W1-B2", status = "pending" } },
      }

      AssaultBoat.launchBoats(buildConfig(), zone, zoneState)

      assert.is_nil(zoneState.boats["BOAT-1"])
    end)
  end)

  describe("updateBoats", function()
    it("should finish when every boat has arrived or is no longer found", function()
      stubUnits({ ["BOAT-1"] = { guid = "BOAT-1" } })
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local zoneState = {
        boats = {
          ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = FINAL_POINT },
          ["BOAT-2"] = { beachLaneId = "W1-B2", status = "launched", finalPoint = FINAL_POINT },
        },
      }

      assert.is_true(AssaultBoat.updateBoats(buildConfig(), zoneState))
      assert.are.equal("arrived", zoneState.boats["BOAT-1"].status)
      assert.is_nil(zoneState.boats["BOAT-2"])
      assert.are.same({ ["W1-B1"] = true }, AssaultBoat.findLandedLaneIdSet(zoneState))
    end)

    it("should remove a boat that is no longer found during fast-forward without touching it", function()
      stubUnits({})
      local setUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local config = buildConfig()
      config.debug = { enabled = true }
      local zoneState = {
        phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
        boats = { ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = FINAL_POINT } },
      }

      assert.is_true(AssaultBoat.updateBoats(config, zoneState))
      assert.is_nil(zoneState.boats["BOAT-1"])
      assert.stub(setUnit).was.called(0)
    end)

    it("should free the parking slot of a launched boat that is no longer found", function()
      stubUnits({})
      local zoneState = {
        boats = { ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = FINAL_POINT } },
        laneSlots = { ["W1-B1"] = { "BOAT-1" } },
      }

      AssaultBoat.updateBoats(buildConfig(), zoneState)

      assert.are.same({ false }, zoneState.laneSlots["W1-B1"])
    end)

    it("should teleport a live boat to its final point during fast-forward", function()
      stubUnits({ ["BOAT-1"] = { guid = "BOAT-1" } })
      local setUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local config = buildConfig()
      config.debug = { enabled = true }
      local zoneState = {
        phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
        boats = { ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = FINAL_POINT } },
      }

      AssaultBoat.updateBoats(config, zoneState)

      assert.stub(setUnit).was.called_with({ guid = "BOAT-1", latitude = 25.0, longitude = 121.0 })
    end)

    it("should not finish while a boat is still under way or pending", function()
      stubUnits({ ["BOAT-1"] = { guid = "BOAT-1" }, ["BOAT-2"] = { guid = "BOAT-2" } })
      trackStub(stub(GameApi, "Tool_Range").returns(2))
      local zoneState = {
        boats = {
          ["BOAT-1"] = { beachLaneId = "W1-B1", status = "launched", finalPoint = FINAL_POINT },
          ["BOAT-2"] = { beachLaneId = "W1-B2", status = "pending" },
        },
      }

      assert.is_false(AssaultBoat.updateBoats(buildConfig(), zoneState))
    end)
  end)

  describe("hasPendingBoats", function()
    it("should return true when a boat is still pending", function()
      local zoneState = { boats = {
        ["BOAT-1"] = { status = "launched" },
        ["BOAT-2"] = { status = "pending" },
      } }

      assert.is_true(AssaultBoat.hasPendingBoats(zoneState))
    end)

    it("should return false when no boat is pending", function()
      local zoneState = { boats = { ["BOAT-1"] = { status = "launched" } } }

      assert.is_false(AssaultBoat.hasPendingBoats(zoneState))
    end)

    it("should return false when no boats were paired", function()
      local zoneState = {}

      assert.is_false(AssaultBoat.hasPendingBoats(zoneState))
    end)
  end)

  describe("estimateShoreArrival", function()
    local NOW = 1000

    ---@return SBJ__AmphibOpsConfig
    local function buildEstimateConfig()
      local amphibOps = buildConfig()
      amphibOps.formation.shipSpeed = 14
      amphibOps.route.launchStationFarNm = 4
      return amphibOps
    end

    ---Add a carrier `offshoreNm` off the lane origin with one pending boat
    ---@param unitMap table<string, table>
    ---@param boats table<string, SBJ__AssaultBoatState>
    ---@param guid string
    ---@param offshoreNm number
    ---@param isInArea boolean Whether the carrier is in the ACV staging area
    local function addCarrier(unitMap, boats, guid, offshoreNm, isInArea)
      local pos = LaneGeometry.buildPoint(frame, -offshoreNm * constants.METERS_PER_NM, 0)
      unitMap[guid] = {
        guid = guid,
        latitude = pos.latitude,
        longitude = pos.longitude,
        inArea = function() return isInArea end,
      }
      boats["BOAT-" .. guid] = { shipGuid = guid, beachLaneId = "W1-B1", status = "pending" }
    end

    ---@param boats table<string, SBJ__AssaultBoatState>
    ---@return SBJ__ZoneState
    local function buildEstimateZoneState(boats)
      return { lanes = { origin = ORIGIN, bearing = BEARING, waterLanes = {} }, boats = boats }
    end

    it("should launch the boats now when their carrier is already in the staging area", function()
      local unitMap, boats = {}, {}
      addCarrier(unitMap, boats, "LST-1", 5, true)
      stubUnits(unitMap)

      local arrivalAt = AssaultBoat.estimateShoreArrival(buildEstimateConfig(), zone, buildEstimateZoneState(boats), NOW)

      -- By hand: the boat runs 5 nm - 100 m = 4.946 nm at 30 kt = 593.5 s
      assert.is_near(NOW + 593.5, arrivalAt, 1)
    end)

    it("should let a carrier outside the staging area sail to the outer edge of the station band first", function()
      local unitMap, boats = {}, {}
      addCarrier(unitMap, boats, "LST-1", 20, false)
      stubUnits(unitMap)

      local arrivalAt = AssaultBoat.estimateShoreArrival(buildEstimateConfig(), zone, buildEstimateZoneState(boats), NOW)

      -- By hand: the carrier sails 16 nm at 14 kt (4114.3 s), then the boat runs 3.946 nm at 30 kt (473.5 s)
      assert.is_near(NOW + 4587.8, arrivalAt, 1)
    end)

    it("should launch from where the carrier is when it is already inside the outer edge", function()
      local unitMap, boats = {}, {}
      addCarrier(unitMap, boats, "LST-1", 3, false)
      stubUnits(unitMap)

      local arrivalAt = AssaultBoat.estimateShoreArrival(buildEstimateConfig(), zone, buildEstimateZoneState(boats), NOW)

      -- By hand: the boat runs 3 nm - 100 m = 2.946 nm at 30 kt = 353.5 s
      assert.is_near(NOW + 353.5, arrivalAt, 1)
    end)

    it("should wait for the last boat to reach the shore", function()
      local unitMap, boats = {}, {}
      addCarrier(unitMap, boats, "LST-1", 5, true)
      addCarrier(unitMap, boats, "LST-2", 20, false)
      stubUnits(unitMap)

      local arrivalAt = AssaultBoat.estimateShoreArrival(buildEstimateConfig(), zone, buildEstimateZoneState(boats), NOW)

      assert.is_near(NOW + 4587.8, arrivalAt, 1)
    end)

    it("should return now when no boat is still pending", function()
      local unitMap, boats = {}, {}
      addCarrier(unitMap, boats, "LST-1", 20, false)
      boats["BOAT-LST-1"].status = "launched"
      stubUnits(unitMap)

      local arrivalAt = AssaultBoat.estimateShoreArrival(buildEstimateConfig(), zone, buildEstimateZoneState(boats), NOW)

      assert.are.equal(NOW, arrivalAt)
    end)
  end)

  describe("findLandedLaneIdSet", function()
    it("should stop looking up a landed boat that is no longer found", function()
      local getUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local zoneState = { boats = { ["BOAT-1"] = { beachLaneId = "W1-B1", status = "arrived" } } }

      assert.are.same({}, AssaultBoat.findLandedLaneIdSet(zoneState))
      assert.are.same({}, AssaultBoat.findLandedLaneIdSet(zoneState))

      assert.stub(getUnit).was.called(1)
    end)

    it("should free the parking slot of a landed boat that is no longer found", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local zoneState = {
        boats = { ["BOAT-1"] = { beachLaneId = "W1-B1", status = "arrived" } },
        laneSlots = { ["W1-B1"] = { false, "BOAT-1" } },
      }

      AssaultBoat.findLandedLaneIdSet(zoneState)

      assert.are.same({ false, false }, zoneState.laneSlots["W1-B1"])
    end)
  end)
end)
