---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps AmphibiousAssault Unit Tests
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AcvWave = require("src.modules.landingOps.acvWave")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("AmphibiousAssault", function()
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  local trackStub = StubTracker.track

  before_each(function()
    logStub = trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  ---Create a landing mission descriptor
  ---@param overrides? table
  ---@return table
  local function buildMission(overrides)
    local mission = {
      name = "TestMission",
      startTime = 3600,
    }
    if overrides then
      for k, v in pairs(overrides) do mission[k] = v end
    end
    return mission
  end

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function buildZone(overrides)
    local zone = {
      name = "ZoneAlpha",
      sags = {},
      heading = 270,
      movement = {
        holdingAreas = {
          deployLine = { "RP-LST-1", "RP-LST-2" },
          mothership = { "RP-ANC-1", "RP-ANC-2" },
        },
      },
      air = {
      },
      landing = {
        laneCenter = { "RP-CENTER" },
        boat = { missions = { buildMission({ name = "BoatMission1" }) } },
        lstSettings = {
          speed = 10,
          distance = 5,
        },
        acv = {
          area = { "RP-ACV-1", "RP-ACV-2" },
          distance = 0.5,
          speed = 20,
          destination = { { latitude = 25.0, longitude = 121.0 } },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        if type(zone[k]) == "table" and (k == "movement" or k == "air" or k == "landing" or k == "fleet") then
          for groupKey, groupValue in pairs(v) do zone[k][groupKey] = groupValue end
        else
          zone[k] = v
        end
      end
    end
    return zone
  end

  ---Create an amphibOpsConfig
  ---@param overrides? table
  ---@return table
  local function buildAmphibOpsConfig(overrides)
    local config = {
      zones = { buildZone() },
    }
    if overrides then
      for k, v in pairs(overrides) do config[k] = v end
    end
    return config
  end

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildUnit(overrides)
    local unit = {
      guid = "SHIP-001",
      name = "TestShip",
      dbid = constants.PLATFORMS.TYPE_071,
      type = "Ship",
      latitude = 25.0,
      longitude = 121.0,
      course = {},
      manualSpeed = 0,
      IsDestroyed = false,
      inArea = function() return false end,
      cargo = {
        [1] = {
          cargo = {
            { guid = "CARGO-ZBD-1", dbid = 241 },
            { guid = "CARGO-ZBD-2", dbid = 241 },
            { guid = "CARGO-ZTD-1", dbid = 240 },
            { guid = "CARGO-ZTD-2", dbid = 240 },
          },
        },
      },
      deleteUnitCargo = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create a contact
  ---@param overrides? table
  ---@return table
  local function buildContact(overrides)
    local contact = {
      guid = "CONTACT-001",
      typed = 8,
      inArea = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do contact[k] = v end
    end
    return contact
  end

  describe("recordLandingStartTime", function()
    it("should store the current time as airlandingMissionStartTime", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(5000))
      local zoneState = { phase = "assault" }

      AmphibiousAssault.recordLandingStartTime(zoneState)

      assert.are.equal(5000, zoneState.airlandingMissionStartTime)
    end)
  end)

  describe("moveToLaunchStations", function()
    local stubGetUnit, stubGetReferencePoints
    local NM = constants.METERS_PER_NM / constants.METERS_PER_DEGREE -- degrees of latitude per nautical mile (laneGeometry flat-earth scale)

    -- Zone heading 0 (north) with the lane center at 25.0N: along = (latitude - 25.0) in meters toward the north
    local center = { latitude = 25.0, longitude = 121.0 }

    local amphibOps = {
      tuning = { route = { launchStationNearNm = 2, launchStationFarNm = 4 } },
    }

    ---Create a side unit entry as returned by the side's unit list
    ---@param guid string
    ---@return table
    local function sideUnit(guid)
      return { guid = guid, name = guid }
    end

    ---Create a zone heading north toward the shore
    ---@return table
    local function buildNorthZone()
      return buildZone({ heading = 0 })
    end

    ---Create an LST at the given distance offshore
    ---@param zone table
    ---@param offshoreNm number
    ---@param overrides? table
    ---@return table
    local function buildLST(zone, offshoreNm, overrides)
      local unit = buildUnit({
        latitude = center.latitude - offshoreNm * NM,
        longitude = center.longitude,
        inArea = function(_, area)
          return area == zone.movement.holdingAreas.deployLine
        end,
      })
      if overrides then
        for k, v in pairs(overrides) do unit[k] = v end
      end
      return unit
    end

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
      stubGetReferencePoints = trackStub(stub(GameApi, "ScenEdit_GetReferencePoints").returns({ center }))
    end)

    it("should move the formation to the middle of the 2-4 nm band keeping its shape", function()
      local zone = buildNorthZone()
      local rear = buildLST(zone, 12, sideUnit("SHIP-001"))
      local front = buildLST(zone, 11.2, sideUnit("SHIP-002"))
      stubGetUnit.invokes(function(id)
        return id == "SHIP-001" and rear or front
      end)

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001"), sideUnit("SHIP-002") })

      assert.is_true(result)
      assert.are.equal(1, #rear.course)
      assert.is_near(center.latitude - 3.4 * NM, rear.course[1].latitude, 1e-6)
      assert.is_near(center.latitude - 2.6 * NM, front.course[1].latitude, 1e-6)
      assert.is_near(center.longitude, rear.course[1].longitude, 1e-6)
      assert.are.equal(zone.landing.lstSettings.speed, rear.manualSpeed)
      assert.stub(logStub).was.called()
    end)

    it("should keep the lateral position of each LST", function()
      local zone = buildNorthZone()
      local unit = buildLST(zone, 12, { longitude = center.longitude + 0.01 })
      stubGetUnit.returns(unit)

      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001") })

      assert.is_near(center.longitude + 0.01, unit.course[1].longitude, 1e-6)
      assert.is_near(center.latitude - 3 * NM, unit.course[1].latitude, 1e-6)
    end)

    it("should return false and leave courses untouched when the formation is deeper than the band", function()
      local zone = buildNorthZone()
      local rear = buildLST(zone, 12, sideUnit("SHIP-001"))
      local front = buildLST(zone, 9.5, sideUnit("SHIP-002"))
      stubGetUnit.invokes(function(id)
        return id == "SHIP-001" and rear or front
      end)

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001"), sideUnit("SHIP-002") })

      assert.is_false(result)
      assert.are.same({}, rear.course)
      assert.are.same({}, front.course)
    end)

    -- No lane center means no reference to measure the band from
    it("should return false when the lane center is not set", function()
      stubGetReferencePoints.returns({})
      local zone = buildNorthZone()
      stubGetUnit.returns(buildLST(zone, 12))

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001") })

      assert.is_false(result)
    end)

    it("should not set course for RORO ships even when in holding area", function()
      local zone = buildNorthZone()
      local unit = buildLST(zone, 12, { name = "RORO" })
      stubGetUnit.returns(unit)

      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001") })

      assert.are.same({}, unit.course)
      assert.are.equal(0, unit.manualSpeed)
    end)

    it("should not set course for Barge ships even when in holding area", function()
      local zone = buildNorthZone()
      local unit = buildLST(zone, 12, { name = "Barge" })
      stubGetUnit.returns(unit)

      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001") })

      assert.are.same({}, unit.course)
    end)

    it("should not set course for Type 529 sweepers in the holding area", function()
      local zone = buildNorthZone()
      local sweepCourse = { { latitude = 24.0, longitude = 120.0 } }
      local unit = buildLST(zone, 12, { name = "Type 529", dbid = constants.PLATFORMS.TYPE_082, course = sweepCourse })
      stubGetUnit.returns(unit)

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, { sideUnit("SHIP-001") })

      assert.is_true(result)
      assert.are.same(sweepCourse, unit.course)
    end)

    it("should set course for SAG groups to staging area", function()
      local sagCourse = { { latitude = 24.0, longitude = 120.0 } }
      local sagUnit = buildUnit({ guid = "SAG-001" })
      stubGetUnit.invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        return nil
      end)

      local zone = buildZone()
      zone.sags = {
        {
          groupName = "SAG Alpha",
          to = { amphibiousVehicleStagingArea = sagCourse },
        },
      }

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, {})

      assert.is_true(result)
      assert.are.same(sagCourse, sagUnit.course)
      assert.stub(logStub).was.called()
    end)

    it("should teleport every SAG ship into formation in fast-forward", function()
      local ffConfig = {
        tuning = amphibOps.tuning,
        debug = { enabled = true, startStage = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT },
      }
      local sagCourse = { { latitude = 24.0, longitude = 120.0 } }
      local sagUnit = buildUnit({ guid = "SAG-001", group = { unitlist = { "D-1", "F-1" } } })
      local destroyer = buildUnit({ guid = "D-1", dbid = constants.PLATFORMS.TYPE_052D })
      local frigate = buildUnit({ guid = "F-1", dbid = constants.PLATFORMS.TYPE_054A })
      stubGetUnit.invokes(function(id)
        return ({ ["SAG Alpha"] = sagUnit, ["D-1"] = destroyer, ["F-1"] = frigate })[id]
      end)
      trackStub(stub(GameApi, "World_GetPointFromBearing").returns({ latitude = 24.01, longitude = 120.01 }))
      local setUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      local zone = buildZone()
      zone.sags = { { groupName = "SAG Alpha", to = { amphibiousVehicleStagingArea = sagCourse } } }

      assert.is_true(AmphibiousAssault.moveToLaunchStations(ffConfig, zone, {}))

      assert.stub(setUnit).was.called_with({ guid = "D-1", latitude = 24.0, longitude = 120.0 })
      assert.stub(setUnit).was.called_with({ guid = "F-1", latitude = 24.01, longitude = 120.01 })
      assert.are.same(sagCourse, sagUnit.course)
    end)

    it("should return false when SAG unit is not found", function()
      stubGetUnit.returns(nil)

      local zone = buildZone()
      zone.sags = {
        {
          groupName = "SAG Alpha",
          to = { amphibiousVehicleStagingArea = {} },
        },
      }

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, {})

      assert.is_false(result)
    end)

    it("should skip units that cannot be retrieved", function()
      stubGetUnit.returns(nil)

      local zone = buildNorthZone()
      local units = { sideUnit("MISSING-001") }

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, units)

      assert.is_true(result)
    end)

    it("should skip units that are not of type Ship", function()
      local zone = buildNorthZone()
      local unit = buildUnit({
        type = "Aircraft",
        inArea = function(_, area)
          return area == zone.movement.holdingAreas.deployLine
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { sideUnit("SHIP-001") }

      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, units)

      assert.are.same({}, unit.course)
    end)

    it("should not set course for ships not in any holding area", function()
      local unit = buildUnit({
        inArea = function() return false end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local zone = buildNorthZone()
      local units = { sideUnit("SHIP-001") }

      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, units)

      assert.are.same({}, unit.course)
    end)

    it("should return true when units list is empty and no SAG", function()
      local zone = buildZone()

      local result = AmphibiousAssault.moveToLaunchStations(amphibOps, zone, {})

      assert.is_true(result)
    end)
  end)

  describe("countUnitsInEachArea", function()
    local config = {
      red = { amphibOps = { zones = { buildZone({ name = "A", air = { attackHelicopter = { zone = "CAS-A" } } }), buildZone({ name = "B", air = { attackHelicopter = { zone = "CAS-B" } } }) } } }
    }

    ---Stub China's units; each unit is a buildUnit override table
    ---@param units table[] Units China owns
    local function stubRedUnits(units)
      local byGuid = {}
      local sideUnits = {}
      for _, overrides in ipairs(units) do
        byGuid[overrides.guid] = buildUnit(overrides)
        table.insert(sideUnits, { guid = overrides.guid })
      end
      trackStub(stub(GameApi, "VP_GetSide").returns({ units = sideUnits }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return byGuid[guid] end))
    end

    ---Build an inArea method true only for the given CAS area
    local function inCasArea(casArea)
      return function(_, area) return area == casArea end
    end

    -- Counts each type only in the zone whose CAS area holds the unit
    it("should count unit types separately for each zone", function()
      stubRedUnits({
        { guid = "U-1", dbid = constants.PLATFORMS.ZBD05, inArea = inCasArea("CAS-A") },
        { guid = "U-2", dbid = constants.PLATFORMS.ZBD05, inArea = inCasArea("CAS-A") },
        { guid = "U-3", dbid = constants.PLATFORMS.MC,    inArea = inCasArea("CAS-B") },
      })

      local result = AmphibiousAssault.countUnitsInEachArea(config.red.amphibOps.zones)

      assert.are.equal(2, result.A["ZBD-05"])
      assert.are.equal(0, result.A["AirborneCorps"])
      assert.are.equal(1, result.B["AirborneCorps"])
      assert.are.equal(0, result.B["ZBD-05"])
    end)

    it("should ignore platforms that are not landed unit types", function()
      stubRedUnits({ { guid = "U-1", dbid = constants.PLATFORMS.TYPE_071, inArea = inCasArea("CAS-A") } })

      local result = AmphibiousAssault.countUnitsInEachArea(config.red.amphibOps.zones)

      for _, count in pairs(result.A) do
        assert.are.equal(0, count)
      end
    end)

    -- A unit listed on the side but already gone must not break the count
    it("should skip side units that no longer resolve", function()
      trackStub(stub(GameApi, "VP_GetSide").returns({ units = { { guid = "GONE" } } }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local result = AmphibiousAssault.countUnitsInEachArea(config.red.amphibOps.zones)

      assert.are.equal(0, result.A["ZBD-05"])
    end)
  end)

  describe("countContactsInArea", function()
    local area = { "RP-ZONE-1", "RP-ZONE-2" }

    -- Counts ground contacts (typed == 8) in area
    it("should count ground contacts in the specified area", function()
      local contacts = {
        buildContact(),
        buildContact({ guid = "CONTACT-002" }),
        buildContact({ guid = "CONTACT-003" }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(3, count)
    end)

    it("should not count contacts with typed other than 8", function()
      local contacts = {
        buildContact({ typed = 8 }),
        buildContact({ guid = "CONTACT-002", typed = 1 }),
        buildContact({ guid = "CONTACT-003", typed = 3 }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(1, count)
    end)

    it("should not count contacts outside the area", function()
      local contacts = {
        buildContact({ inArea = function() return true end }),
        buildContact({ guid = "CONTACT-002", inArea = function() return false end }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(1, count)
    end)

    it("should return zero when no contacts are ground type in area", function()
      local contacts = {
        buildContact({ typed = 1 }),
        buildContact({ guid = "CONTACT-002", inArea = function() return false end }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(0, count)
    end)

    it("should return zero for empty contacts list", function()
      local count = AmphibiousAssault.countContactsInArea({}, area)

      assert.are.equal(0, count)
    end)
  end)

  describe("launchACV", function()
    ---@param phase string
    ---@return table zoneStates
    ---@return table zoneState
    local function buildZoneStates(phase)
      local zoneState = { phase = phase }
      return { ZoneAlpha = zoneState }, zoneState
    end

    ---Create a loaded LST inside the ACV area of ZoneAlpha
    ---@param overrides? table
    ---@return table
    local function buildLaunchShip(overrides)
      local ship = buildUnit({ inArea = function() return true end, RTB = function() end })
      for k, v in pairs(overrides or {}) do ship[k] = v end
      return ship
    end

    it("should release ACVs once the ship's zone reaches ASSAULT_LANDING", function()
      local ship = buildLaunchShip()
      local amphibOps = buildAmphibOpsConfig()
      local zoneStates, zoneState = buildZoneStates(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      local stubRelease = trackStub(stub(AcvWave, "release").returns({ count = 2, isEmpty = false, isPaused = false }))

      local result = AmphibiousAssault.launchACV(amphibOps, zoneStates, ship)

      assert.is_true(result)
      assert.stub(stubRelease).was.called_with(amphibOps, amphibOps.zones[1], zoneState, ship)
    end)

    it("should not release before the zone reaches ASSAULT_LANDING", function()
      local zoneStates = buildZoneStates(constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING)
      local stubRelease = trackStub(stub(AcvWave, "release"))

      local result = AmphibiousAssault.launchACV(buildAmphibOpsConfig(), zoneStates, buildLaunchShip())

      assert.is_false(result)
      assert.stub(stubRelease).was_not.called()
    end)

    it("should return false when the ship is in no zone's ACV area", function()
      local zoneStates = buildZoneStates(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      local stubRelease = trackStub(stub(AcvWave, "release"))

      local result = AmphibiousAssault.launchACV(buildAmphibOpsConfig(), zoneStates,
        buildLaunchShip({ inArea = function() return false end }))

      assert.is_false(result)
      assert.stub(stubRelease).was_not.called()
    end)

    local SHIP_CASES = {
      { label = "Type 071", overrides = { dbid = constants.PLATFORMS.TYPE_071 }, isReleased = true },
      { label = "Type 072III", overrides = { dbid = constants.PLATFORMS.TYPE_072III }, isReleased = true },
      { label = "Type 072A", overrides = { dbid = constants.PLATFORMS.TYPE_072A }, isReleased = true },
      { label = "Type 073A", overrides = { dbid = constants.PLATFORMS.TYPE_073A }, isReleased = true },
      { label = "a ship named Ferry", overrides = { name = "Ferry", dbid = 99999 }, isReleased = true },
      { label = "an unrecognized ship", overrides = { name = "Destroyer", dbid = 99999 }, isReleased = false },
      { label = "a Type 529 minesweeper", overrides = { name = "Type 529", dbid = constants.PLATFORMS.TYPE_082 }, isReleased = false },
      { label = "a Type 075 LHD", overrides = { name = "Type075", dbid = constants.PLATFORMS.TYPE_075 }, isReleased = false },
    }

    for _, case in ipairs(SHIP_CASES) do
      it("should " .. (case.isReleased and "" or "not ") .. "release ACVs from " .. case.label, function()
        local zoneStates = buildZoneStates(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
        local stubRelease = trackStub(stub(AcvWave, "release").returns({ count = 1, isEmpty = false, isPaused = false }))

        local result = AmphibiousAssault.launchACV(buildAmphibOpsConfig(), zoneStates, buildLaunchShip(case.overrides))

        assert.are.equal(case.isReleased, result)
        assert.stub(stubRelease).was.called(case.isReleased and 1 or 0)
      end)
    end

    it("should release into the zone whose ACV area holds the ship", function()
      local zone1 = buildZone({ name = "ZoneAlpha" })
      local zone2 = buildZone({ name = "ZoneBravo" })
      local amphibOps = buildAmphibOpsConfig({ zones = { zone1, zone2 } })
      local zoneStates = {
        ZoneAlpha = { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING },
        ZoneBravo = { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING },
      }
      local ship = buildLaunchShip({ inArea = function(_, area) return area == zone2.landing.acv.area end })
      local stubRelease = trackStub(stub(AcvWave, "release").returns({ count = 1, isEmpty = false, isPaused = false }))

      AmphibiousAssault.launchACV(amphibOps, zoneStates, ship)

      assert.stub(stubRelease).was.called_with(amphibOps, zone2, zoneStates.ZoneBravo, ship)
    end)

    it("should release into the first zone when several ACV areas hold the ship", function()
      local zone1 = buildZone({ name = "ZoneAlpha" })
      local amphibOps = buildAmphibOpsConfig({ zones = { zone1, buildZone({ name = "ZoneBravo" }) } })
      local zoneStates = {
        ZoneAlpha = { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING },
        ZoneBravo = { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING },
      }
      local ship = buildLaunchShip()
      local stubRelease = trackStub(stub(AcvWave, "release").returns({ count = 1, isEmpty = false, isPaused = false }))

      AmphibiousAssault.launchACV(amphibOps, zoneStates, ship)

      assert.stub(stubRelease).was.called_with(amphibOps, zone1, zoneStates.ZoneAlpha, ship)
    end)

    it("should return false when there are no operational zones", function()
      local stubRelease = trackStub(stub(AcvWave, "release"))

      local result = AmphibiousAssault.launchACV(buildAmphibOpsConfig({ zones = {} }), {}, buildLaunchShip())

      assert.is_false(result)
      assert.stub(stubRelease).was_not.called()
    end)

    it("should host the ship back to base and RTB when the ship is empty", function()
      local wasRTB = false
      local ship = buildLaunchShip({ RTB = function(_, force) wasRTB = force end })
      local amphibOps = buildAmphibOpsConfig({ zones = { buildZone({ movement = { baseGUID = "BASE-001" } }) } })
      local zoneStates = buildZoneStates(constants.AMPHIBIOUS_PHASES.COMPLETED)
      trackStub(stub(AcvWave, "release").returns({ count = 0, isEmpty = true, isPaused = false }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent").returns(true))

      local result = AmphibiousAssault.launchACV(amphibOps, zoneStates, ship)

      assert.is_true(result)
      assert.is_true(wasRTB)
      assert.stub(stubHost).was.called_with({ HostedUnitNameOrID = ship.guid, SelectedBaseNameOrID = "BASE-001" })
    end)

    it("should not RTB the ship when the wave is paused", function()
      local wasRTB = false
      local ship = buildLaunchShip({ RTB = function() wasRTB = true end })
      local zoneStates = buildZoneStates(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AcvWave, "release").returns({ count = 0, isEmpty = false, isPaused = true }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent"))

      local result = AmphibiousAssault.launchACV(buildAmphibOpsConfig(), zoneStates, ship)

      assert.is_true(result)
      assert.is_false(wasRTB)
      assert.stub(stubHost).was_not.called()
    end)
  end)

  describe("hasUnreleasedACV", function()
    local ships = { { guid = "SHIP-001" } }

    ---@param units table<string, table>
    local function stubUnits(units)
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return units[guid] end))
    end

    it("should return true when a ship in the ACV area still carries ACVs", function()
      local zone = buildZone()
      stubUnits({ ["SHIP-001"] = buildUnit({ inArea = function() return true end }) })

      assert.is_true(AmphibiousAssault.hasUnreleasedACV(zone, ships))
    end)

    it("should return false when the ship carries no ZBD or ZTD", function()
      local zone = buildZone()
      local ship = buildUnit({
        inArea = function() return true end,
        cargo = { [1] = { cargo = { { guid = "C-1", dbid = constants.PLATFORMS.PLL05 } } } },
      })
      stubUnits({ ["SHIP-001"] = ship })

      assert.is_false(AmphibiousAssault.hasUnreleasedACV(zone, ships))
    end)

    it("should ignore a loaded ship outside the ACV area", function()
      local zone = buildZone()
      stubUnits({ ["SHIP-001"] = buildUnit({ inArea = function() return false end }) })

      assert.is_false(AmphibiousAssault.hasUnreleasedACV(zone, ships))
    end)

    it("should ignore a loaded ship that is not an LST or ferry", function()
      local zone = buildZone()
      stubUnits({ ["SHIP-001"] = buildUnit({ dbid = 1, inArea = function() return true end }) })

      assert.is_false(AmphibiousAssault.hasUnreleasedACV(zone, ships))
    end)

    it("should skip a unit that no longer exists", function()
      local zone = buildZone()
      stubUnits({})

      assert.is_false(AmphibiousAssault.hasUnreleasedACV(zone, ships))
    end)
  end)
end)
