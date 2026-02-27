-- AmphibiousAssault Unit Tests
---@diagnostic disable: undefined-field
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local constants = require("src.core.constants")

describe("AmphibiousAssault", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a landing mission descriptor
  ---@param overrides? table
  ---@return table
  local function makeMission(overrides)
    local m = {
      name = "TestMission",
      startTime = 3600,
    }
    if overrides then
      for k, v in pairs(overrides) do m[k] = v end
    end
    return m
  end

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function makeZone(overrides)
    local z = {
      name = "ZoneAlpha",
      lstAnchorageArea = { "RP-LST-1", "RP-LST-2" },
      anchorageArea = { "RP-ANC-1", "RP-ANC-2" },
      transportHelicopter = { missions = { makeMission({ name = "HeloMission1" }) } },
      boat = { missions = { makeMission({ name = "BoatMission1" }) } },
      attackHelicopter = { missions = { makeMission({ name = "AtkHeloMission1" }) } },
      lstSettings = {
        speed = 10,
        course = { bearing = 270, distance = 5 },
      },
      acv = {
        area = { "RP-ACV-1", "RP-ACV-2" },
        bearing = 90,
        distance = 0.5,
        speed = 20,
        destination = { { latitude = 25.0, longitude = 121.0 } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do z[k] = v end
    end
    return z
  end

  ---Create an amphibOpsConfig
  ---@param overrides? table
  ---@return table
  local function makeAmphibOpsConfig(overrides)
    local cfg = {
      operationalZones = { makeZone() },
      sag = {},
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a saveData structure
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    local sd = {
      c = {
        amphibOps = {
          airlandingMissionStartTime = nil,
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do sd[k] = v end
    end
    return sd
  end

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
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
  local function makeContact(overrides)
    local c = {
      guid = "CONTACT-001",
      typed = 8,
      inArea = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do c[k] = v end
    end
    return c
  end

  -- ============================================================================
  -- setLandingMissionStartTime
  -- ============================================================================

  describe("setLandingMissionStartTime", function()
    local stubCurrentTime, stubGetMission

    before_each(function()
      stubCurrentTime = trackStub(stub(GameApi, "ScenEdit_CurrentTime"))
      stubGetMission = trackStub(stub(GameApi, "ScenEdit_GetMission"))
    end)

    -- Positive: sets start times for all missions in a zone
    it("should set start times for all missions in the operational zone", function()
      stubCurrentTime.returns(1000)
      local missionObj = { starttime = nil }
      stubGetMission.returns(missionObj)

      local zone = makeZone()
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      local result = AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      assert.is_true(result)
      assert.are.equal(1000, zoneState.airlandingMissionStartTime)
      -- 3 missions (helo + boat + atkHelo), each calls GetMission once
      assert.stub(stubGetMission).was.called(3)
      assert.stub(Logger.log).was.called()
    end)

    -- Positive: records current time into zoneState
    it("should store current time as airlandingMissionStartTime in zoneState", function()
      stubCurrentTime.returns(5000)
      stubGetMission.returns({ starttime = nil })

      local zone = makeZone()
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      assert.are.equal(5000, zoneState.airlandingMissionStartTime)
    end)

    -- Positive: correctly calculates start time string
    it("should set mission start time using os.date format", function()
      stubCurrentTime.returns(1000)
      local missionObj = { starttime = nil }
      stubGetMission.returns(missionObj)

      local zone = makeZone({
        transportHelicopter = { missions = { makeMission({ name = "Helo1", startTime = 600 }) } },
        boat = { missions = {} },
        attackHelicopter = { missions = {} },
      })
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      local expectedTime = os.date("%Y-%m-%d %H:%M:%S", 1600)
      assert.are.equal(expectedTime, missionObj.starttime)
    end)

    -- Positive: processes missions in a zone with specific categories
    it("should process missions in specified categories of a single zone", function()
      stubCurrentTime.returns(2000)
      stubGetMission.returns({ starttime = nil })

      local zone = makeZone({
        transportHelicopter = { missions = { makeMission({ name = "Z1Helo" }) } },
        boat = { missions = { makeMission({ name = "Z1Boat" }) } },
        attackHelicopter = { missions = {} },
      })
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      local result = AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      assert.is_true(result)
      assert.stub(stubGetMission).was.called(2)
    end)

    -- Negative: returns false when GetMission returns nil for a mission
    it("should return false when a mission cannot be found", function()
      stubCurrentTime.returns(1000)
      stubGetMission.returns(nil)

      local zone = makeZone()
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      local result = AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      assert.is_false(result)
      assert.stub(Logger.log).was.called()
    end)

    -- Boundary: zone with no missions in any category
    it("should return true when all mission lists are empty", function()
      stubCurrentTime.returns(1000)

      local zone = makeZone({
        transportHelicopter = { missions = {} },
        boat = { missions = {} },
        attackHelicopter = { missions = {} },
      })
      local saveData = makeSaveData()
      local zoneState = { phase = "assault", amphibiousAssaultStartTime = nil, airlandingMissionStartTime = nil }

      local result = AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)

      assert.is_true(result)
      assert.stub(stubGetMission).was_not.called()
    end)
  end)

  -- ============================================================================
  -- setCoursesForLSTs
  -- ============================================================================

  describe("setCoursesForLSTs", function()
    local stubGetUnit, stubGetPoint

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
      stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
    end)

    -- Positive: sets course and speed for LST units in anchorage area
    it("should set course and speed for LST ships in anchorage area", function()
      local destination = { latitude = 24.5, longitude = 120.5 }
      stubGetPoint.returns(destination)

      local zone = makeZone()
      local unit = makeUnit({
        name = "LST-001",
        inArea = function(_, area)
          return area == zone.lstAnchorageArea
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      local result = AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.is_true(result)
      assert.are.same({ destination }, unit.course)
      assert.are.equal(zone.lstSettings.speed, unit.manualSpeed)
      assert.stub(Logger.log).was.called()
    end)

    -- Positive: does not set course for RORO ships
    it("should not set course for RORO ships even when in anchorage area", function()
      local destination = { latitude = 24.5, longitude = 120.5 }
      stubGetPoint.returns(destination)

      local zone = makeZone()
      local unit = makeUnit({
        name = "RORO",
        inArea = function(_, area)
          return area == zone.lstAnchorageArea
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.are.same({}, unit.course)
      assert.are.equal(0, unit.manualSpeed)
    end)

    -- Positive: does not set course for Barge ships
    it("should not set course for Barge ships even when in anchorage area", function()
      local destination = { latitude = 24.5, longitude = 120.5 }
      stubGetPoint.returns(destination)

      local zone = makeZone()
      local unit = makeUnit({
        name = "Barge",
        inArea = function(_, area)
          return area == zone.lstAnchorageArea
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.are.same({}, unit.course)
    end)

    -- Positive: sets course for SAG groups
    it("should set course for SAG groups to staging area", function()
      local sagCourse = { { latitude = 24.0, longitude = 120.0 } }
      local sagUnit = makeUnit({ guid = "SAG-001" })
      stubGetUnit.invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        return nil
      end)

      local zone = makeZone()
      local operation = { sagNames = { "alpha" } }
      local sagLookup = {
        alpha = {
          groupName = "SAG Alpha",
          to = { amphibiousVehicleStagingArea = sagCourse },
        },
      }

      local result = AmphibiousAssault.setCoursesForLSTs(zone, {}, operation, sagLookup)

      assert.is_true(result)
      assert.are.same(sagCourse, sagUnit.course)
      assert.stub(Logger.log).was.called()
    end)

    -- Negative: returns false when World_GetPointFromBearing returns nil
    it("should return false when destination calculation fails", function()
      stubGetPoint.returns(nil)

      local zone = makeZone()
      local unit = makeUnit({
        inArea = function(_, area)
          return area == zone.lstAnchorageArea
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      local result = AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.is_false(result)
    end)

    -- Negative: returns false when SAG unit cannot be found
    it("should return false when SAG unit is not found", function()
      stubGetUnit.returns(nil)

      local zone = makeZone()
      local operation = { sagNames = { "alpha" } }
      local sagLookup = {
        alpha = {
          groupName = "SAG Alpha",
          to = { amphibiousVehicleStagingArea = {} },
        },
      }

      local result = AmphibiousAssault.setCoursesForLSTs(zone, {}, operation, sagLookup)

      assert.is_false(result)
    end)

    -- Negative: skips units not retrievable via GetUnit
    it("should skip units that cannot be retrieved", function()
      stubGetUnit.returns(nil)

      local zone = makeZone()
      local units = { { guid = "MISSING-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      local result = AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.is_true(result)
    end)

    -- Negative: skips non-Ship type units
    it("should skip units that are not of type Ship", function()
      local destination = { latitude = 24.5, longitude = 120.5 }
      stubGetPoint.returns(destination)

      local zone = makeZone()
      local unit = makeUnit({
        type = "Aircraft",
        inArea = function(_, area)
          return area == zone.lstAnchorageArea
        end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.are.same({}, unit.course)
    end)

    -- Boundary: ship not in any anchorage area
    it("should not set course for ships not in any anchorage area", function()
      local destination = { latitude = 24.5, longitude = 120.5 }
      stubGetPoint.returns(destination)

      local unit = makeUnit({
        inArea = function() return false end,
      })

      stubGetUnit.invokes(function(id)
        if id == "SHIP-001" then return unit end
        return nil
      end)

      local zone = makeZone()
      local units = { { guid = "SHIP-001" } }
      local operation = { sagNames = {} }
      local sagLookup = {}

      AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)

      assert.are.same({}, unit.course)
    end)

    -- Boundary: empty units list
    it("should return true when units list is empty and no SAG", function()
      local zone = makeZone()
      local operation = { sagNames = {} }
      local sagLookup = {}

      local result = AmphibiousAssault.setCoursesForLSTs(zone, {}, operation, sagLookup)

      assert.is_true(result)
    end)
  end)

  -- ============================================================================
  -- countContactsInArea
  -- ============================================================================

  describe("countContactsInArea", function()
    local area = { "RP-ZONE-1", "RP-ZONE-2" }

    -- Positive: counts ground contacts (typed == 8) in area
    it("should count ground contacts in the specified area", function()
      local contacts = {
        makeContact(),
        makeContact({ guid = "CONTACT-002" }),
        makeContact({ guid = "CONTACT-003" }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(3, count)
    end)

    -- Positive: filters out non-ground contacts
    it("should not count contacts with typed other than 8", function()
      local contacts = {
        makeContact({ typed = 8 }),
        makeContact({ guid = "CONTACT-002", typed = 1 }),
        makeContact({ guid = "CONTACT-003", typed = 3 }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(1, count)
    end)

    -- Positive: filters out contacts outside the area
    it("should not count contacts outside the area", function()
      local contacts = {
        makeContact({ inArea = function() return true end }),
        makeContact({ guid = "CONTACT-002", inArea = function() return false end }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(1, count)
    end)

    -- Negative: returns zero when no contacts match
    it("should return zero when no contacts are ground type in area", function()
      local contacts = {
        makeContact({ typed = 1 }),
        makeContact({ guid = "CONTACT-002", inArea = function() return false end }),
      }

      local count = AmphibiousAssault.countContactsInArea(contacts, area)

      assert.are.equal(0, count)
    end)

    -- Boundary: empty contacts list
    it("should return zero for empty contacts list", function()
      local count = AmphibiousAssault.countContactsInArea({}, area)

      assert.are.equal(0, count)
    end)
  end)

  -- ============================================================================
  -- launchACV
  -- ============================================================================

  describe("launchACV", function()
    local stubGenerateLocations, stubDeleteCargo, stubAddUnit, stubSetDoctrine

    before_each(function()
      stubGenerateLocations = trackStub(stub(GameUtils, "generateLocations"))
      stubDeleteCargo = trackStub(stub(AmphibiousLogistics, "deleteCargo"))
      stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
      stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
    end)

    -- Positive: launches ZBD-05 and ZTD-05 vehicles from ship
    it("should launch both ZBD and ZTD vehicles and return total count", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
        { latitude = 25.3, longitude = 121.3 },
        { latitude = 25.4, longitude = 121.4 },
      }
      stubGenerateLocations.returns(locations)
      -- deleteCargo: first call for ZBD (dbid=241), second for ZTD (dbid=240)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 2 end
        if cargoItem.dbid == 240 then return 2 end
        return 0
      end)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 4,
        bearing = 90,
        distance = 0.5,
      }

      local count = AmphibiousAssault.launchACV(params)

      assert.are.equal(4, count)
      assert.stub(stubAddUnit).was.called(4)
      assert.stub(stubSetDoctrine).was.called(4)
      assert.stub(Logger.log).was.called()
    end)

    -- Positive: launches only ZTD when no ZBD cargo available
    it("should launch only ZTD vehicles when ZBD cargo is zero", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 0 end
        if cargoItem.dbid == 240 then return 2 end
        return 0
      end)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
        bearing = 90,
        distance = 0.5,
      }

      local count = AmphibiousAssault.launchACV(params)

      assert.are.equal(2, count)
    end)

    -- Positive: launches only ZBD when ZTD cargo is zero
    it("should launch only ZBD vehicles when ZTD cargo request is zero", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      stubGenerateLocations.returns(locations)
      -- ZBD fills all requested slots, ZTD gets 0 remaining
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 2 end
        if cargoItem.dbid == 240 then return 0 end
        return 0
      end)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
        bearing = 90,
        distance = 0.5,
      }

      local count = AmphibiousAssault.launchACV(params)

      assert.are.equal(2, count)
    end)

    -- Positive: sets throttle and course on added units
    it("should set throttle to Full and assign destination course", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 0 end
        if cargoItem.dbid == 240 then return 1 end
        return 0
      end)
      local addedUnit = { guid = "NEW-UNIT", throttle = nil, course = nil }
      stubAddUnit.returns(addedUnit)
      stubSetDoctrine.returns(true)

      local destination = { { latitude = 25.0, longitude = 121.0 } }
      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = destination,
        num = 1,
        bearing = 90,
        distance = 0.5,
      }

      AmphibiousAssault.launchACV(params)

      assert.are.equal("Full", addedUnit.throttle)
      assert.are.same(destination, addedUnit.course)
    end)

    -- Negative: returns nil when ship is nil
    it("should return nil when ship is nil", function()
      local params = {
        ship = nil,
        destination = {},
        num = 2,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
    end)

    -- Negative: returns nil when ship is destroyed
    it("should return nil when ship is destroyed", function()
      local ship = makeUnit({ IsDestroyed = true })
      local params = {
        ship = ship,
        destination = {},
        num = 2,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
    end)

    -- Negative: returns nil when ScenEdit_AddUnit fails for ZTD
    it("should return nil when adding ZTD unit fails", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 0 end
        if cargoItem.dbid == 240 then return 1 end
        return 0
      end)
      stubAddUnit.returns(nil)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
      assert.stub(Logger.log).was.called()
    end)

    -- Negative: returns nil when ScenEdit_SetDoctrine fails for ZTD
    it("should return nil when setting doctrine fails for ZTD unit", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 0 end
        if cargoItem.dbid == 240 then return 1 end
        return 0
      end)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(nil)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
      assert.stub(Logger.log).was.called()
    end)

    -- Negative: returns nil when ScenEdit_AddUnit fails for ZBD
    it("should return nil when adding ZBD unit fails", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 1 end
        if cargoItem.dbid == 240 then return 0 end
        return 0
      end)
      -- ZTD has 0, so only ZBD is spawned. AddUnit fails for ZBD
      stubAddUnit.returns(nil)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
      assert.stub(Logger.log).was.called()
    end)

    -- Negative: returns nil when ScenEdit_SetDoctrine fails for ZBD
    it("should return nil when setting doctrine fails for ZBD unit", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.invokes(function(_, cargoItem)
        if cargoItem.dbid == 241 then return 1 end
        if cargoItem.dbid == 240 then return 0 end
        return 0
      end)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(nil)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
        bearing = 90,
        distance = 0.5,
      }

      local result = AmphibiousAssault.launchACV(params)

      assert.is_nil(result)
      assert.stub(Logger.log).was.called()
    end)

    -- Boundary: both ZBD and ZTD delete zero cargo
    it("should return zero when no cargo is available for deletion", function()
      local locations = {}
      stubGenerateLocations.returns(locations)
      stubDeleteCargo.returns(0)

      local ship = makeUnit()
      local params = {
        ship = ship,
        destination = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
        bearing = 90,
        distance = 0.5,
      }

      local count = AmphibiousAssault.launchACV(params)

      assert.are.equal(0, count)
      assert.stub(stubAddUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- isFerryOrLST
  -- ============================================================================

  describe("isFerryOrLST", function()
    -- Positive: returns true for Type 071
    it("should return true for Type 071 ship", function()
      local ship = makeUnit({ dbid = constants.PLATFORMS.TYPE_071 })
      assert.is_true(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Positive: returns true for Type 072III
    it("should return true for Type 072III ship", function()
      local ship = makeUnit({ dbid = constants.PLATFORMS.TYPE_072III })
      assert.is_true(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Positive: returns true for Type 072A
    it("should return true for Type 072A ship", function()
      local ship = makeUnit({ dbid = constants.PLATFORMS.TYPE_072A })
      assert.is_true(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Positive: returns true for Type 073A
    it("should return true for Type 073A ship", function()
      local ship = makeUnit({ dbid = constants.PLATFORMS.TYPE_073A })
      assert.is_true(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Positive: returns true for Ferry by name
    it("should return true for a ship named Ferry regardless of dbid", function()
      local ship = makeUnit({ name = "Ferry", dbid = 99999 })
      assert.is_true(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Negative: returns false for unrelated ship type
    it("should return false for a ship with unrecognized dbid and name", function()
      local ship = makeUnit({ name = "Destroyer", dbid = 99999 })
      assert.is_false(AmphibiousAssault.isFerryOrLST(ship))
    end)

    -- Negative: returns false for Type 075 (LHD, not LST)
    it("should return false for Type 075 LHD", function()
      local ship = makeUnit({ dbid = constants.PLATFORMS.TYPE_075, name = "Type075" })
      assert.is_false(AmphibiousAssault.isFerryOrLST(ship))
    end)
  end)

  -- ============================================================================
  -- getShipZone
  -- ============================================================================

  describe("getShipZone", function()
    -- Positive: returns zone when ship is in ACV area
    it("should return the matching zone when ship is in ACV area", function()
      local zone1 = makeZone({ name = "ZoneAlpha" })
      local zone2 = makeZone({ name = "ZoneBravo" })

      local ship = makeUnit({
        inArea = function(_, area)
          return area == zone2.acv.area
        end,
      })

      local config = makeAmphibOpsConfig({ operationalZones = { zone1, zone2 } })

      local result = AmphibiousAssault.getShipZone(config, ship)

      assert.is_not_nil(result)
      assert.are.equal("ZoneBravo", result.name)
    end)

    -- Positive: returns first matching zone when ship is in multiple zones
    it("should return the first matching zone", function()
      local zone1 = makeZone({ name = "ZoneAlpha" })
      local zone2 = makeZone({ name = "ZoneBravo" })

      local ship = makeUnit({
        inArea = function() return true end,
      })

      local config = makeAmphibOpsConfig({ operationalZones = { zone1, zone2 } })

      local result = AmphibiousAssault.getShipZone(config, ship)

      assert.are.equal("ZoneAlpha", result.name)
    end)

    -- Negative: returns nil when ship is not in any ACV area
    it("should return nil when ship is not in any zone", function()
      local ship = makeUnit({
        inArea = function() return false end,
      })

      local config = makeAmphibOpsConfig()

      local result = AmphibiousAssault.getShipZone(config, ship)

      assert.is_nil(result)
    end)

    -- Boundary: empty operational zones
    it("should return nil when there are no operational zones", function()
      local ship = makeUnit()
      local config = makeAmphibOpsConfig({ operationalZones = {} })

      local result = AmphibiousAssault.getShipZone(config, ship)

      assert.is_nil(result)
    end)
  end)
end)
