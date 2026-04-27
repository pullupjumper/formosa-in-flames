-- GnssJamming Unit Tests
local GnssJamming = require("src.modules.ew.gnssJamming")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("GnssJamming", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
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
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a GNSS jammer descriptor with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeDescriptor(overrides)
    local d = {
      name = "GNSS Jammer Alpha",
      zoneName = "GNSS Zone Alpha",
      point = { latitude = 25.0, longitude = 121.0 },
      randomRadius = 5,
      radius = 50,
    }
    if overrides then
      for k, v in pairs(overrides) do d[k] = v end
    end
    return d
  end

  ---Create a CMO unit mock
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local u = {
      guid = "UNIT-001",
      name = "UNIT-001",
      dbid = 0,
      latitude = 25.0,
      longitude = 121.0,
    }
    if overrides then
      for k, v in pairs(overrides) do u[k] = v end
    end
    return u
  end

  ---Create a weapon unit mock with course data
  ---@param overrides? table
  ---@return table
  local function makeWeaponUnit(overrides)
    local w = {
      guid = "WPN-001",
      name = "AGM-84 Harpoon",
      dbid = 1001,
      course = {
        { latitude = 24.5, longitude = 120.5, TypeOf = "TerminalPoint" },
      },
      target = { latitude = 24.5, longitude = 120.5 },
    }
    if overrides then
      for k, v in pairs(overrides) do w[k] = v end
    end
    return w
  end

  ---Create a GNSS jamming config section
  ---@param overrides? table
  ---@return table
  local function makeGnssJammingConfig(overrides)
    local cfg = {
      gnssGuidedWeapons = {
        { dbid = 1001, jammingResistance = 30 },
        { dbid = 1002, jammingResistance = 80 },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a config object with the gnssJamming section
  ---@param sideField? string Side field key ("c", "t", "u")
  ---@param gnssOverrides? table Overrides for gnssJamming config
  ---@return table
  local function makeConfig(sideField, gnssOverrides)
    sideField = sideField or "t"
    local cfg = {}
    cfg[sideField] = { gnssJamming = makeGnssJammingConfig(gnssOverrides) }
    return cfg
  end

  ---Create a zone mock
  ---@param overrides? table
  ---@return table
  local function makeZone(overrides)
    local z = {
      guid = "ZONE-001",
      description = "GNSS Zone Alpha",
    }
    if overrides then
      for k, v in pairs(overrides) do z[k] = v end
    end
    return z
  end

  ---Create a side object mock with standard zones
  ---@param zones? table
  ---@param getStandardZoneResult? table
  ---@return table
  local function makeSideObj(zones, getStandardZoneResult)
    return {
      standardzones = zones or {},
      getstandardzone = function(_, guid)
        return getStandardZoneResult
      end,
    }
  end

  -- ============================================================================
  -- jamming
  -- ============================================================================

  describe("jamming", function()
    local cachedSideConfigStub
    before_each(function()
      cachedSideConfigStub = trackStub(stub(GameUtils, "getCachedSideConfig").returns({
        field = "t",
        enemySide = "China",
        displayName = "Taiwan",
      }))
    end)

    -- ============================================================================
    -- Weapon Resolution
    -- ============================================================================

    describe("weapon resolution", function()
      -- Negative: returns false when no weapon unit found in event
      it("should return false when ScenEdit_UnitX returns nil", function()
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns(nil))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
        assert.stub(errorStub).was.called(1)
      end)

      -- Negative: returns false when weapon unit wrapper fails
      it("should return false when ScenEdit_GetUnit returns nil", function()
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = "WPN-001" }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
        assert.stub(errorStub).was.called(1)
      end)
    end)

    -- ============================================================================
    -- Weapon Matching
    -- ============================================================================

    describe("weapon matching", function()
      -- Negative: returns false when weapon is not in gnssGuidedWeapons list
      it("should return false when weapon dbid does not match any guided weapon", function()
        local weapon = makeWeaponUnit({ dbid = 9999 })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
      end)
    end)

    -- ============================================================================
    -- Jamming Success and Course Modification
    -- ============================================================================

    describe("jamming success and course modification", function()
      -- Positive: jams weapon with single waypoint (count == 1)
      it("should modify terminal point for weapon with single waypoint", function()
        local weapon = makeWeaponUnit({ dbid = 1001 })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        -- jamChance > jammingResistance(30): random(100) returns 50
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 50 end
          if a == -100 and b == 100 then return 10 end
          if a and b then return a end
          return 50
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_true(result)
        assert.are.equal("BOL", weapon.target.guid)
        assert.are.equal("TerminalPoint", weapon.course[1].TypeOf)
      end)

      -- Positive: jams weapon with zero waypoints (count == 0), uses target coordinates
      it("should use target coordinates when weapon has no course waypoints", function()
        local weapon = makeWeaponUnit({
          dbid = 1001,
          course = {},
          target = { latitude = 24.0, longitude = 120.0 },
        })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 50 end
          if a == -100 and b == 100 then return 10 end
          if a and b then return a end
          return 50
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_true(result)
        assert.are.equal("BOL", weapon.target.guid)
      end)

      -- Positive: modifies last waypoint for weapon with multiple waypoints
      it("should modify only the last waypoint for weapon with multiple waypoints", function()
        local weapon = makeWeaponUnit({
          dbid = 1001,
          course = {
            { latitude = 25.0, longitude = 121.0, TypeOf = "ManualPlottedCourseWaypoint" },
            { latitude = 24.8, longitude = 120.8, TypeOf = "ManualPlottedCourseWaypoint" },
            { latitude = 24.5, longitude = 120.5, TypeOf = "TerminalPoint" },
          },
          target = { latitude = 24.5, longitude = 120.5 },
        })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 50 end
          if a == -100 and b == 100 then return 10 end
          if a and b then return a end
          return 50
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_true(result)
        -- First two waypoints should be preserved
        assert.are.equal("ManualPlottedCourseWaypoint", weapon.course[1].TypeOf)
        assert.are.equal(25.0, weapon.course[1].latitude)
        assert.are.equal("ManualPlottedCourseWaypoint", weapon.course[2].TypeOf)
        assert.are.equal(24.8, weapon.course[2].latitude)
        -- Last waypoint should be modified to TerminalPoint
        assert.are.equal("TerminalPoint", weapon.course[3].TypeOf)
        assert.are.equal("BOL", weapon.target.guid)
      end)
    end)

    -- ============================================================================
    -- Jamming Resistance
    -- ============================================================================

    describe("jamming resistance", function()
      -- Negative: weapon resists jamming when jamChance <= jammingResistance
      it("should return false when weapon resists jamming", function()
        local weapon = makeWeaponUnit({ dbid = 1001 })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        -- jamChance(20) <= jammingResistance(30) → resist
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 20 end
          return 0
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
        assert.stub(logStub).was.called(1)
      end)

      -- Boundary: high-resistance weapon almost always resists
      it("should resist jamming for high-resistance weapon", function()
        local weapon = makeWeaponUnit({ dbid = 1002 }) -- jammingResistance = 80
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        -- jamChance(75) <= jammingResistance(80) → resist
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 75 end
          return 0
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
      end)
    end)

    -- ============================================================================
    -- Missing Course Data
    -- ============================================================================

    describe("missing course data", function()
      -- Negative: returns false when weapon has no course data
      it("should return false and log error when weapon has nil course", function()
        local weapon = {
          guid = "WPN-001",
          name = "AGM-84 Harpoon",
          dbid = 1001,
          target = { latitude = 24.5, longitude = 120.5 },
        }
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 50 end
          return 0
        end))

        local result = GnssJamming.jamming(makeConfig(), "Taiwan")

        assert.is_false(result)
        assert.stub(errorStub).was.called(1)
      end)
    end)

    -- ============================================================================
    -- Side Configuration
    -- ============================================================================

    describe("side configuration", function()
      -- Positive: works correctly with China side config
      it("should use correct side config field for China", function()
        cachedSideConfigStub.returns({
          field = "c",
          enemySide = "Taiwan",
          displayName = "China",
        })

        local weapon = makeWeaponUnit({ dbid = 1001 })
        trackStub(stub(GameApi, "ScenEdit_UnitX").returns({ guid = weapon.guid }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(weapon))
        trackStub(stub(math, "random").invokes(function(a, b)
          if a == 100 and b == nil then return 50 end
          if a == -100 and b == 100 then return 10 end
          if a and b then return a end
          return 50
        end))

        local config = makeConfig("c")
        local result = GnssJamming.jamming(config, "China")

        assert.is_true(result)
      end)
    end)
  end)

  -- ============================================================================
  -- removeJammers
  -- ============================================================================

  describe("removeJammers", function()
    -- Positive: removes matching zones and units
    it("should remove all matching jamming zones and return count", function()
      local descriptor = makeDescriptor()
      local jammerDescriptors = { alpha = descriptor }
      local zone = makeZone({ description = "GNSS Zone Alpha" })
      local standardZone = {
        description = "GNSS Zone Alpha",
        area = { { name = "RP-001" }, { name = "RP-002" } },
      }
      local sideObj = makeSideObj({ zone }, standardZone)

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      local deleteReferencePointStub = trackStub(stub(GameApi, "ScenEdit_DeleteReferencePoint"))
      local removeZoneStub = trackStub(stub(GameApi, "ScenEdit_RemoveZone"))
      local deleteUnitStub = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      local unitEntersAreaEventStub = trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local count = GnssJamming.removeJammers(jammerDescriptors, "China")

      assert.are.equal(1, count)
      assert.stub(deleteReferencePointStub).was.called(2)
      assert.stub(removeZoneStub).was.called(1)
      assert.stub(deleteUnitStub).was.called(1)
      assert.stub(unitEntersAreaEventStub).was.called(1)
    end)

    -- Negative: returns 0 when VP_GetSide returns nil
    it("should return 0 when side object is nil", function()
      trackStub(stub(GameApi, "VP_GetSide").returns(nil))

      local count = GnssJamming.removeJammers({ alpha = makeDescriptor() }, "China")

      assert.are.equal(0, count)
    end)

    -- Negative: returns 0 when no zones match descriptors
    it("should return 0 when no zones match any descriptor", function()
      local sideObj = makeSideObj({
        makeZone({ description = "Unrelated Zone" }),
      })

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local count = GnssJamming.removeJammers({ alpha = makeDescriptor() }, "China")

      assert.are.equal(0, count)
    end)

    -- Positive: removes multiple matching zones
    it("should remove multiple matching zones for different descriptors", function()
      local descAlpha = makeDescriptor({ zoneName = "GNSS Zone Alpha" })
      local descBravo = makeDescriptor({ name = "GNSS Jammer Bravo", zoneName = "GNSS Zone Bravo" })
      local jammerDescriptors = { alpha = descAlpha, bravo = descBravo }

      local zoneAlpha = makeZone({ guid = "ZONE-A", description = "GNSS Zone Alpha" })
      local zoneBravo = makeZone({ guid = "ZONE-B", description = "GNSS Zone Bravo" })

      local sideObj = {
        standardzones = { zoneAlpha, zoneBravo },
        getstandardzone = function(_, guid)
          if guid == "ZONE-A" then
            return { description = "GNSS Zone Alpha", area = { { name = "RP-A1" } } }
          end
          if guid == "ZONE-B" then
            return { description = "GNSS Zone Bravo", area = { { name = "RP-B1" } } }
          end
          return nil
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      trackStub(stub(GameApi, "ScenEdit_DeleteReferencePoint"))
      trackStub(stub(GameApi, "ScenEdit_RemoveZone"))
      trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local count = GnssJamming.removeJammers(jammerDescriptors, "China")

      assert.are.equal(2, count)
    end)

    -- Negative: returns 0 when getstandardzone returns nil
    it("should not count removal when getstandardzone returns nil", function()
      local descriptor = makeDescriptor()
      local zone = makeZone({ description = "GNSS Zone Alpha" })
      local sideObj = makeSideObj({ zone }, nil)

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local count = GnssJamming.removeJammers({ alpha = descriptor }, "China")

      assert.are.equal(0, count)
    end)
  end)

  -- ============================================================================
  -- addGnssJammer
  -- ============================================================================

  describe("addGnssJammer", function()
    before_each(function()
      trackStub(stub(GameUtils, "getCachedSideConfig").returns({
        field = "c",
        enemySide = "Taiwan",
        displayName = "China",
      }))
    end)

    -- Positive: creates jammer unit and jamming zone successfully
    it("should create jammer unit and set up jamming zone", function()
      local descriptor = makeDescriptor()
      local createdUnit = makeUnit({ guid = "NEW-JAMMER", name = "GNSS Jammer Alpha" })

      local addUnitStub = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(createdUnit))
      local setEMCONStub = trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns({ "RP-001", "RP-002" }))
      local addZoneStub = trackStub(stub(GameApi, "ScenEdit_AddZone"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local success, unit = GnssJamming.addGnssJammer(descriptor, "China")

      assert(unit ~= nil)
      assert.is_true(success)
      assert.are.equal("NEW-JAMMER", unit.guid)
      assert.stub(addUnitStub).was.called(1)
      -- EMCON is set once in createJammingZone (consolidated from duplicate calls)
      assert.stub(setEMCONStub).was.called(1)
      assert.stub(addZoneStub).was.called(1)
    end)

    -- Positive: passes correct parameters to ScenEdit_AddUnit
    it("should pass correct parameters when creating unit", function()
      local descriptor = makeDescriptor({
        point = { latitude = 26.0, longitude = 122.0 },
      })

      local addUnitStub = trackStub(stub(GameApi, "ScenEdit_AddUnit").invokes(function(params)
        assert.are.equal("China", params.side)
        assert.are.equal("GNSS Jammer Alpha", params.unitname)
        assert.are.equal(constants.PLATFORMS.GPS_JAMMER, params.dbid)
        assert.are.equal("Facility", params.type)
        assert.are.equal(26.0, params.latitude)
        assert.are.equal(122.0, params.longitude)
        return makeUnit({ guid = "UNIT-NEW" })
      end))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns({ "RP-001" }))
      trackStub(stub(GameApi, "ScenEdit_AddZone"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      GnssJamming.addGnssJammer(descriptor, "China")

      assert.stub(addUnitStub).was.called(1)
    end)

    -- Negative: returns false when unit creation fails
    it("should return false and nil when ScenEdit_AddUnit returns nil", function()
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(nil))

      local success, unit = GnssJamming.addGnssJammer(makeDescriptor(), "China")

      assert.is_false(success)
      assert.is_nil(unit)
    end)

    -- Negative: returns false when area creation fails
    it("should return false when newArea returns non-table result", function()
      local createdUnit = makeUnit({ guid = "NEW-JAMMER" })
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(createdUnit))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns(false))

      local success, unit = GnssJamming.addGnssJammer(makeDescriptor(), "China")

      assert(unit ~= nil)
      assert.is_false(success)
      assert.are.equal("NEW-JAMMER", unit.guid)
    end)
  end)

  -- ============================================================================
  -- addGnssJammers
  -- ============================================================================

  describe("addGnssJammers", function()
    before_each(function()
      trackStub(stub(GameUtils, "getCachedSideConfig").returns({
        field = "c",
        enemySide = "Taiwan",
        displayName = "China",
      }))
    end)

    -- Positive: creates multiple jammers successfully
    it("should create multiple jammers and return success count", function()
      local descriptors = {
        alpha = makeDescriptor({ name = "Jammer A", zoneName = "Zone A" }),
        bravo = makeDescriptor({ name = "Jammer B", zoneName = "Zone B" }),
      }

      trackStub(stub(GameUtils, "tryAddUnit", function(name)
        return makeUnit({ name = name }), { latitude = 25.0, longitude = 121.0 }
      end))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns({ "RP-001" }))
      trackStub(stub(GameApi, "ScenEdit_AddZone"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local count = GnssJamming.addGnssJammers(descriptors, "China")

      assert.are.equal(2, count)
    end)

    -- Negative: skips failed unit creations
    it("should skip descriptors where tryAddUnit fails", function()
      local descriptors = {
        alpha = makeDescriptor({ name = "Jammer A", zoneName = "Zone A" }),
        bravo = makeDescriptor({ name = "Jammer B", zoneName = "Zone B" }),
      }

      trackStub(stub(GameUtils, "tryAddUnit", function(name)
        if name == "Jammer A" then
          return makeUnit({ name = name }), { latitude = 25.0, longitude = 121.0 }
        end
        return nil, nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns({ "RP-001" }))
      trackStub(stub(GameApi, "ScenEdit_AddZone"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local count = GnssJamming.addGnssJammers(descriptors, "China")

      assert.are.equal(1, count)
    end)

    -- Negative: returns 0 when area creation fails for all
    it("should return 0 when jamming zone creation fails", function()
      local descriptors = {
        alpha = makeDescriptor({ name = "Jammer A", zoneName = "Zone A" }),
      }

      trackStub(stub(GameUtils, "tryAddUnit").returns(
        makeUnit(), { latitude = 25.0, longitude = 121.0 }
      ))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON"))
      trackStub(stub(GameUtils, "newArea").returns(false))

      local count = GnssJamming.addGnssJammers(descriptors, "China")

      assert.are.equal(0, count)
    end)

    -- Boundary: empty descriptors returns 0
    it("should return 0 for empty descriptors table", function()
      local tryAddUnitStub = trackStub(stub(GameUtils, "tryAddUnit"))

      local count = GnssJamming.addGnssJammers({}, "China")

      assert.are.equal(0, count)
      assert.stub(tryAddUnitStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- removeJammingZoneByName
  -- ============================================================================

  describe("removeJammingZoneByName", function()
    -- Positive: removes matching zone by descriptor name
    it("should remove zone matching the named descriptor", function()
      local descriptor = makeDescriptor()
      local jammerDescriptors = { alpha = descriptor }
      local zone = makeZone({ description = "GNSS Zone Alpha" })
      local standardZone = {
        description = "GNSS Zone Alpha",
        area = { { name = "RP-001" }, { name = "RP-002" } },
      }
      local sideObj = makeSideObj({ zone }, standardZone)

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      local deleteReferencePointStub = trackStub(stub(GameApi, "ScenEdit_DeleteReferencePoint"))
      local removeZoneStub = trackStub(stub(GameApi, "ScenEdit_RemoveZone"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      local result = GnssJamming.removeJammingZoneByName(jammerDescriptors, "China", "alpha")

      assert.is_true(result)
      assert.stub(deleteReferencePointStub).was.called(2)
      assert.stub(removeZoneStub).was.called(1)
      -- Should NOT delete unit (isDeleted is not passed)
    end)

    -- Positive: does not delete the jammer unit itself
    it("should not delete the jammer unit when removing zone", function()
      local descriptor = makeDescriptor()
      local zone = makeZone({ description = "GNSS Zone Alpha" })
      local standardZone = {
        description = "GNSS Zone Alpha",
        area = { { name = "RP-001" } },
      }
      local sideObj = makeSideObj({ zone }, standardZone)

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      trackStub(stub(GameApi, "ScenEdit_DeleteReferencePoint"))
      trackStub(stub(GameApi, "ScenEdit_RemoveZone"))
      local deleteUnitStub = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      trackStub(stub(GameUtils, "unitEntersAreaEvent").returns(true))

      GnssJamming.removeJammingZoneByName({ alpha = descriptor }, "China", "alpha")

      assert.stub(deleteUnitStub).was_not.called()
    end)

    -- Negative: returns false when VP_GetSide returns nil
    it("should return false when side object is nil", function()
      trackStub(stub(GameApi, "VP_GetSide").returns(nil))

      local result = GnssJamming.removeJammingZoneByName({ alpha = makeDescriptor() }, "China", "alpha")

      assert.is_false(result)
    end)

    -- Negative: returns false when descriptor name not found
    it("should return false when descriptor key does not exist", function()
      local sideObj = makeSideObj()
      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local result = GnssJamming.removeJammingZoneByName({ alpha = makeDescriptor() }, "China", "nonexistent")

      assert.is_false(result)
    end)

    -- Negative: returns false when no zone matches descriptor
    it("should return false when no zone matches the descriptor zoneName", function()
      local sideObj = makeSideObj({
        makeZone({ description = "Some Other Zone" }),
      })

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local result = GnssJamming.removeJammingZoneByName({ alpha = makeDescriptor() }, "China", "alpha")

      assert.is_false(result)
    end)

    -- Negative: returns false when getstandardzone returns nil
    it("should return false when getstandardzone returns nil for matching zone", function()
      local zone = makeZone({ description = "GNSS Zone Alpha" })
      local sideObj = makeSideObj({ zone }, nil)

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local result = GnssJamming.removeJammingZoneByName({ alpha = makeDescriptor() }, "China", "alpha")

      assert.is_false(result)
    end)
  end)
end)
