-- AmphibiousLogistics Unit Tests
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local AssignMission = require("src.modules.assignMission")
local constants = require("src.core.constants")
---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
describe("AmphibiousLogistics", function()
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
    trackStub(stub(Logger, "warn"))
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

  ---Create a cargo element (as stored in unit.cargo[1].cargo)
  ---@param overrides? table
  ---@return table
  local function makeCargoElement(overrides)
    local el = {
      dbid = 1001,
      guid = "CARGO-" .. tostring(math.random(10000)),
    }
    if overrides then
      for k, v in pairs(overrides) do el[k] = v end
    end
    return el
  end

  ---Create a cargo descriptor (request to transfer/delete)
  ---@param overrides? table
  ---@return table
  local function makeCargoItem(overrides)
    local item = {
      type = 1,
      dbid = 1001,
      num = 2,
    }
    if overrides then
      for k, v in pairs(overrides) do item[k] = v end
    end
    return item
  end

  ---Create a unit with cargo and utility methods
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "UNIT-001",
      name = "TestUnit",
      dbid = constants.PLATFORMS.TYPE_075,
      unitstate = "Unassigned",
      cargo = {
        [1] = {
          cargo = {
            makeCargoElement({ guid = "C-1", dbid = 1001 }),
            makeCargoElement({ guid = "C-2", dbid = 1001 }),
            makeCargoElement({ guid = "C-3", dbid = 2002 }),
          },
        },
      },
      embarkedUnits = { Aircraft = {}, Boats = {} },
      loadoutdbid = 100,
      deleteUnitCargo = function() end,
      createUnitCargo = function() end,
      inArea = function() return false end,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function makeOperationalZone(overrides)
    local zone = {
      name = "ZoneAlpha",
      anchorage = {
        area = { "RP-ANC-1", "RP-ANC-2" },
        lstArea = { "RP-LST-1", "RP-LST-2" },
      },
      landing = {
        boat = {
          dbid = 3001,
          zone = { "RP-BOAT-1" },
          settings = { throttle = "Full" },
          missions = {
            { name = "BoatMission-1", loadoutId = 10, unitCount = 2, startTime = 0 },
          },
          transferManifest = {
            type075 = {
              [1] = { loadoutId = 10, cargoItems = { [1] = { makeCargoItem() } } },
            },
            type071 = {
              [1] = { loadoutId = 10, cargoItems = { [1] = { makeCargoItem() } } },
            },
          },
        },
      },
      air = {
        transportHelicopter = {
          dbid = 4001,
          zone = { "RP-HELO-1" },
          settings = { throttle = "Full" },
          missions = {
            { name = "HeloMission-1", loadoutId = 20, unitCount = 2, startTime = 0 },
          },
          transferManifest = {
            type075 = {
              [1] = { loadoutId = 20, cargoItems = { [1] = { makeCargoItem() } } },
              [2] = { loadoutId = 21, cargoItems = { [1] = { makeCargoItem({ dbid = 2002 }) } } },
            },
            type071 = {
              [1] = { loadoutId = 20, cargoItems = { [1] = { makeCargoItem() } } },
            },
          },
        },
        attackHelicopter = {
          dbid = 5001,
          missions = {
            { name = "AttackHeloMission-1", loadoutId = 30, unitCount = 1, startTime = 0 },
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        if type(zone[k]) == "table" and (k == "anchorage" or k == "air" or k == "landing") then
          for groupKey, groupValue in pairs(v) do zone[k][groupKey] = groupValue end
        else
          zone[k] = v
        end
      end
    end
    return zone
  end

  ---Create a transport aircraft configuration item
  ---@param overrides? table
  ---@return table
  local function makeTransportAircraftItem(overrides)
    local item = {
      name = "AirBase-1",
      guid = "BASE-001",
      dbid = 6001,
      missions = {
        { name = "AirliftMission-1", loadoutId = 40, unitCount = 1, startTime = 0 },
      },
      cargoItemsForTransfer = {
        [1] = { loadoutId = 40, cargoItems = { [1] = { makeCargoItem() } } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do item[k] = v end
    end
    return item
  end

  ---Units resolvable through the GameApi.ScenEdit_GetUnit stub installed by cargo transfer blocks
  ---@type table<string, table>
  local unitsByGuid

  ---Make units resolvable by GUID through the GameApi.ScenEdit_GetUnit stub
  ---@param units table[]
  local function registerUnits(units)
    for _, u in ipairs(units) do unitsByGuid[u.guid] = u end
  end

  ---Install a GameApi.ScenEdit_GetUnit stub that resolves registered units only
  ---@return luassert.spy
  local function stubUnitLookup()
    unitsByGuid = {}
    return trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      return unitsByGuid[guid]
    end))
  end

  ---Create a registered amphibious ship carrying one boat and two transport helicopters
  ---(loadouts 20 and 21), matching the platforms in makeOperationalZone's manifests.
  ---The boat keeps makeUnit's default loadout, which differs from the manifest's, because
  ---boats must receive cargo regardless of loadout.
  ---@param guid string
  ---@param dbid number
  ---@return table ship
  ---@return {boat: luassert.spy, helo: luassert.spy, heloAlt: luassert.spy} creates createUnitCargo stubs per embarked unit
  local function makeFleetShip(guid, dbid)
    local boat = makeUnit({ guid = guid .. "-BOAT", dbid = 3001 })
    local helo = makeUnit({ guid = guid .. "-HELO20", dbid = 4001, loadoutdbid = 20 })
    local heloAlt = makeUnit({ guid = guid .. "-HELO21", dbid = 4001, loadoutdbid = 21 })
    local ship = makeUnit({
      guid = guid,
      dbid = dbid,
      embarkedUnits = { Aircraft = { helo.guid, heloAlt.guid }, Boats = { boat.guid } },
      inArea = function() return true end,
    })
    registerUnits({ ship, boat, helo, heloAlt })

    return ship, {
      boat = trackStub(stub(boat, "createUnitCargo")),
      helo = trackStub(stub(helo, "createUnitCargo")),
      heloAlt = trackStub(stub(heloAlt, "createUnitCargo")),
    }
  end

  -- ============================================================================
  -- removeCargo
  -- ============================================================================

  describe("removeCargo", function()
    -- Positive: should delete matching cargo and return count
    it("should delete matching cargo and return count", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(true))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(2, result)
    end)

    -- Positive: should count only successful deletions
    it("should count only successful deletions", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 2 })

      local callCount = 0
      trackStub(stub(fromUnit, "deleteUnitCargo").invokes(function()
        callCount = callCount + 1
        return callCount == 1
      end))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)

    -- Negative: should return 0 when fromUnit is nil
    it("should return 0 when fromUnit is nil", function()
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.removeCargo(nil, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when fromUnit.cargo is nil
    it("should return 0 when fromUnit cargo is nil", function()
      local fromUnit = makeUnit({ cargo = nil })
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when cargo[1] is nil
    it("should return 0 when cargo first element is nil", function()
      local fromUnit = makeUnit({ cargo = {} })
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when cargoItem.num is 0
    it("should return 0 when requested quantity is zero", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 0 })

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when deleteUnitCargo returns falsy
    it("should return 0 when all deletions fail", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(nil))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Boundary: should delete only up to matching count when fewer exist
    it("should delete only available matching cargo when fewer exist than requested", function()
      local fromUnit = makeUnit({
        cargo = {
          [1] = {
            cargo = {
              makeCargoElement({ guid = "C-SINGLE", dbid = 1001 }),
            },
          },
        },
      })
      local cargoItem = makeCargoItem({ num = 5 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(true))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)
  end)

  -- ============================================================================
  -- getUnitsInAnchorageArea
  -- ============================================================================

  describe("getUnitsInAnchorageArea", function()
    local stubGetUnit

    -- Positive: should collect amphibious ships in anchorage area
    it("should collect amphibious ships that are in anchorage area", function()
      local unit = makeUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Unassigned",
        inArea = function(_, area)
          if area == "RP-ANC-1" then return false end
          return true
        end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(1, #result.units)
      assert.are.equal(unit, result.units[1])
    end)

    -- Positive: should collect ships in LST anchorage area
    it("should collect ships that are in LST anchorage area", function()
      local zone = makeOperationalZone()
      local lstArea = zone.anchorage.lstArea
      local unit = makeUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_072III,
        unitstate = "Unassigned",
        inArea = function(_, area)
          return area == lstArea
        end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(1, #result.units)
    end)

    -- Positive: should recognize all amphibious ship types
    it("should recognize all amphibious ship types", function()
      local shipDBIDs = {
        constants.PLATFORMS.TYPE_075,
        constants.PLATFORMS.TYPE_071,
        constants.PLATFORMS.TYPE_072III,
        constants.PLATFORMS.TYPE_072A,
        constants.PLATFORMS.TYPE_073A,
        constants.PLATFORMS.TYPE_072A_2,
        constants.PLATFORMS.TYPE_076,
        constants.PLATFORMS.FERRY,
        constants.PLATFORMS.BARGE,
      }
      local filteredUnits = {}
      local unitMap = {}

      for i, dbid in ipairs(shipDBIDs) do
        local guid = "SHIP-" .. tostring(i)
        table.insert(filteredUnits, { guid = guid })
        unitMap[guid] = makeUnit({
          guid = guid,
          dbid = dbid,
          unitstate = "Unassigned",
          inArea = function() return true end,
        })
      end

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return unitMap[guid]
      end))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(#shipDBIDs, #result.units)
    end)

    -- Positive: should set isUnitMoving true when a ship has non-Unassigned state
    it("should set isUnitMoving true when any ship is actively moving", function()
      local unit = makeUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Tasked",
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_true(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Positive: should stop processing once a moving unit is found
    it("should stop processing remaining units once a moving unit is found", function()
      local movingUnit = makeUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Tasked",
      })
      local stationaryUnit = makeUnit({
        guid = "SHIP-002",
        dbid = constants.PLATFORMS.TYPE_071,
        unitstate = "Unassigned",
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" }, { guid = "SHIP-002" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SHIP-001" then return movingUnit end
        if guid == "SHIP-002" then return stationaryUnit end
        return nil
      end))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_true(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Negative: should skip units that are not amphibious ships
    it("should skip non-amphibious ship types", function()
      local unit = makeUnit({
        guid = "SHIP-001",
        dbid = 99999,
        unitstate = "Unassigned",
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Negative: should skip units that cannot be retrieved
    it("should skip units that cannot be retrieved from API", function()
      local filteredUnits = { { guid = "GHOST-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Negative: should not collect ships outside the zone
    it("should not collect ships outside the operational zone", function()
      local unit = makeUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Unassigned",
        inArea = function() return false end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Boundary: should return empty results for empty filtered units
    it("should return empty results for empty filtered units list", function()
      local zone = makeOperationalZone()
      local filteredUnits = {}
      local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)
  end)

  -- ============================================================================
  -- createCargoMissions
  -- ============================================================================

  describe("createCargoMissions", function()
    local stubAddMission, stubSetMission, stubSetDoctrine

    before_each(function()
      stubAddMission = trackStub(stub(GameApi, "ScenEdit_AddMission").returns({}))
      stubSetMission = trackStub(stub(GameApi, "ScenEdit_SetMission").returns({}))
      stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine").returns({}))
    end)

    -- Positive: should create cargo missions for boats and helicopters
    it("should create cargo missions for all boat and helicopter missions", function()
      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_true(result)
      assert.stub(stubAddMission).was.called(2)
      assert.stub(stubSetMission).was.called(2)
      assert.stub(stubSetDoctrine).was.called(2)
      assert.stub(logStub).was.called(1)
    end)

    -- Positive: should create missions with correct parameters
    it("should pass correct side and mission type to AddMission", function()
      local zone = makeOperationalZone()
      AmphibiousLogistics.createCargoMissions(zone)

      assert.stub(stubAddMission).was.called_with(
        "China", "BoatMission-1", "Cargo",
        { zone = zone.landing.boat.zone }
      )
      assert.stub(stubAddMission).was.called_with(
        "China", "HeloMission-1", "Cargo",
        { zone = zone.air.transportHelicopter.zone }
      )
    end)

    -- Positive: should set doctrine with automatic_evasion disabled
    it("should disable automatic evasion in mission doctrine", function()
      local zone = makeOperationalZone()
      AmphibiousLogistics.createCargoMissions(zone)

      assert.stub(stubSetDoctrine).was.called_with(
        { side = "China", mission = "BoatMission-1" },
        { automatic_evasion = false }
      )
    end)

    -- Positive: should handle zone with multiple missions per platform type
    it("should create missions for all missions in a zone", function()
      local zone = makeOperationalZone({
        landing = {
          boat = {
            dbid = 3001,
            zone = { "RP-BOAT-1" },
            settings = { throttle = "Full" },
            missions = {
              { name = "BoatMission-1A", loadoutId = 10, unitCount = 1, startTime = 0 },
              { name = "BoatMission-1B", loadoutId = 11, unitCount = 1, startTime = 0 },
            },
            transferManifest = { type075 = {}, type071 = {} },
          },
        },
        air = {
          transportHelicopter = {
            dbid = 4001,
            zone = { "RP-HELO-1" },
            settings = { throttle = "Full" },
            missions = {
              { name = "HeloMission-1", loadoutId = 20, unitCount = 1, startTime = 0 },
            },
            transferManifest = { type075 = {}, type071 = {} },
          },
        },
      })

      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_true(result)
      -- 2 boat missions + 1 helo mission = 3
      assert.stub(stubAddMission).was.called(3)
    end)

    -- Negative: should return false when AddMission fails
    it("should return false when AddMission fails for boat mission", function()
      stubAddMission.returns(nil)

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=add_mission_failed"))
    end)

    -- Negative: should return false when SetMission fails
    it("should return false when SetMission fails", function()
      stubSetMission.returns(nil)

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=set_mission_failed"))
    end)

    -- Negative: should return false when SetDoctrine fails
    it("should return false when SetDoctrine fails", function()
      stubSetDoctrine.returns(nil)

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=set_doctrine_failed"))
    end)
  end)

  -- ============================================================================
  -- transferAndAssign
  -- ============================================================================

  describe("transferAndAssign", function()
    local stubAssignMission

    before_each(function()
      stubUnitLookup()
      stubAssignMission = trackStub(stub(AssignMission, "assignEmbarkedUnitsToMissions"))
    end)

    -- Positive: should load boats and both helicopter loadouts on Type 075 ships
    it("should transfer cargo and assign missions for Type 075 ships", function()
      local ship, creates = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was.called()
      -- transport helo + attack helo; hovercraft are assigned after routing, not here
      assert.stub(stubAssignMission).was.called(2)
      assert.stub(stubAssignMission).was.called_with(
        "SHIP-075", "Aircraft", zone.air.attackHelicopter.dbid, zone.air.attackHelicopter.missions)
      assert.stub(stubAssignMission).was_not.called_with(
        "SHIP-075", constants.PLATFORM_TYPES.BOATS, zone.landing.boat.dbid, zone.landing.boat.missions)
    end)

    -- Positive: should treat Type 076 ships like Type 075
    it("should transfer cargo and assign missions for Type 076 ships", function()
      local ship, creates = makeFleetShip("SHIP-076", constants.PLATFORMS.TYPE_076)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.heloAlt).was.called()
      assert.stub(stubAssignMission).was.called(2)
    end)

    -- Positive: should load boats and one helicopter loadout on Type 071 ships
    it("should transfer cargo and assign missions for Type 071 ships", function()
      local ship, creates = makeFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      -- Type 071 manifest has no second helicopter loadout
      assert.stub(creates.heloAlt).was_not.called()
      -- transport helo only; no attack helo, hovercraft assigned later
      assert.stub(stubAssignMission).was.called(1)
    end)

    -- Positive: should handle mixed fleet in anchorage
    it("should process both Type 075 and Type 071 ships in same zone", function()
      local ship075, creates075 = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local ship071, creates071 = makeFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship075, ship071 })

      assert.is_true(result)
      assert.stub(creates075.heloAlt).was.called()
      assert.stub(creates071.boat).was.called()
      assert.stub(stubAssignMission).was.called(3)
    end)

    -- Negative: should skip units not in anchorage area
    it("should skip ships not in anchorage area", function()
      local ship, creates = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      ship.inArea = function() return false end
      local zone = makeOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.stub(creates.boat).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)

    -- Negative: should skip non-amphibious unit types
    it("should skip units that are not Type 075/076 or Type 071", function()
      local ship, creates = makeFleetShip("SHIP-OTHER", constants.PLATFORMS.TYPE_072III)
      local zone = makeOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.stub(creates.boat).was_not.called()
      assert.stub(creates.helo).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)

    -- Boundary: should return true with empty units list
    it("should return true with empty units list", function()
      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.transferAndAssign(zone, {})

      assert.is_true(result)
      assert.stub(stubAssignMission).was_not.called()
    end)
  end)

  -- ============================================================================
  -- transferAndAssignTransportAircraft
  -- ============================================================================

  describe("transferAndAssignTransportAircraft", function()
    local stubAssignMission

    ---Create an embarked transport aircraft matching makeTransportAircraftItem's dbid and loadout
    ---@param overrides? table
    ---@return table
    local function makeAircraft(overrides)
      local aircraft = makeUnit({ guid = "AC-001", dbid = 6001, loadoutdbid = 40 })
      if overrides then
        for k, v in pairs(overrides) do aircraft[k] = v end
      end
      return aircraft
    end

    ---Create a registered air base (makeTransportAircraftItem's GUID) embarking the given aircraft
    ---@param aircraftList table[]
    ---@param overrides? table
    ---@return table
    local function makeAirBase(aircraftList, overrides)
      local guids = {}
      for _, aircraft in ipairs(aircraftList) do table.insert(guids, aircraft.guid) end

      local base = makeUnit({ guid = "BASE-001", embarkedUnits = { Aircraft = guids, Boats = {} } })
      if overrides then
        for k, v in pairs(overrides) do base[k] = v end
      end

      registerUnits({ base })
      registerUnits(aircraftList)
      return base
    end

    ---Create a transport aircraft item transferring the given cargo lists
    ---@param cargoItems table<integer, table[]>
    ---@return table
    local function makeItemWithCargo(cargoItems)
      return makeTransportAircraftItem({
        cargoItemsForTransfer = { [1] = { loadoutId = 40, cargoItems = cargoItems } },
      })
    end

    before_each(function()
      stubUnitLookup()
      stubAssignMission = trackStub(stub(AssignMission, "assignEmbarkedUnitsToMissions"))
    end)

    -- Positive: should move matching cargo from the base onto the aircraft and assign it
    it("should move matching cargo from the base onto a matching aircraft", function()
      local aircraft = makeAircraft()
      local base = makeAirBase({ aircraft })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))
      local item = makeTransportAircraftItem()

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft({ item })

      assert.is_true(result)
      assert.stub(stubDelete).was.called(2)
      assert.stub(stubDelete).was.called_with(base, "C-1")
      assert.stub(stubDelete).was.called_with(base, "C-2")
      assert.stub(stubCreate).was.called(2)
      assert.stub(stubCreate).was.called_with(aircraft, 1, 1001)
      assert.stub(stubAssignMission).was.called_with("BASE-001", "Aircraft", 6001, item.missions)
    end)

    -- Positive: should only transfer up to the requested quantity
    it("should only transfer up to the requested quantity", function()
      local aircraft = makeAircraft()
      local base = makeAirBase({ aircraft })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({
        makeItemWithCargo({ [1] = { makeCargoItem({ num = 1 }) } }),
      })

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubCreate).was.called(1)
    end)

    -- Positive: should skip non-matching cargo elements
    it("should skip non-matching cargo elements", function()
      local aircraft = makeAircraft()
      local base = makeAirBase({ aircraft }, {
        cargo = {
          [1] = {
            cargo = {
              makeCargoElement({ guid = "C-X", dbid = 9999 }),
              makeCargoElement({ guid = "C-Y", dbid = 9999 }),
              makeCargoElement({ guid = "C-Z", dbid = 1001 }),
            },
          },
        },
      })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({
        makeItemWithCargo({ [1] = { makeCargoItem({ num = 1 }) } }),
      })

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubDelete).was.called_with(base, "C-Z")
      assert.stub(stubCreate).was.called(1)
    end)

    -- Positive: should give each aircraft its own cargo list when several are provided
    it("should use per-unit cargo lists when multiple lists are provided", function()
      local ac1 = makeAircraft({ guid = "AC-001" })
      local ac2 = makeAircraft({ guid = "AC-002" })
      makeAirBase({ ac1, ac2 })
      local stubCreate1 = trackStub(stub(ac1, "createUnitCargo"))
      local stubCreate2 = trackStub(stub(ac2, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({
        makeItemWithCargo({
          [1] = { makeCargoItem({ dbid = 1001, num = 1 }) },
          [2] = { makeCargoItem({ dbid = 2002, num = 1 }) },
        }),
      })

      assert.stub(stubCreate1).was.called(1)
      assert.stub(stubCreate1).was.called_with(ac1, 1, 1001)
      assert.stub(stubCreate2).was.called(1)
      assert.stub(stubCreate2).was.called_with(ac2, 1, 2002)
    end)

    -- Positive: should handle multiple transport aircraft entries
    it("should process all transport aircraft entries", function()
      local transportAircraft = {
        makeTransportAircraftItem(),
        makeTransportAircraftItem({ name = "AirBase-2", guid = "BASE-002", dbid = 6002 }),
      }

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)

      assert.is_true(result)
      assert.stub(stubAssignMission).was.called(2)
    end)

    -- Negative: should not look for embarked aircraft when the base is not found
    it("should not transfer cargo when the base unit is not found", function()
      local aircraft = makeAircraft()
      registerUnits({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft({ makeTransportAircraftItem() })

      assert.is_true(result)
      assert.stub(stubCreate).was_not.called()
      assert.stub(stubAssignMission).was.called(1)
    end)

    -- Negative: should skip aircraft that do not match the platform DBID
    it("should skip aircraft that do not match platform DBID", function()
      local aircraft = makeAircraft({ dbid = 9999 })
      makeAirBase({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({ makeTransportAircraftItem() })

      assert.stub(stubCreate).was_not.called()
    end)

    -- Negative: should skip aircraft that do not match the loadout
    it("should skip aircraft that do not match loadout DBID", function()
      local aircraft = makeAircraft({ loadoutdbid = 999 })
      makeAirBase({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({ makeTransportAircraftItem() })

      assert.stub(stubCreate).was_not.called()
    end)

    -- Negative: should skip embarked units that cannot be retrieved and keep going
    it("should skip embarked units that cannot be retrieved", function()
      local aircraft = makeAircraft({ guid = "AC-002" })
      makeAirBase({ aircraft })
      unitsByGuid["BASE-001"].embarkedUnits.Aircraft = { "GHOST-001", "AC-002" }
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({
        makeItemWithCargo({ [1] = { makeCargoItem({ num = 1 }) } }),
      })

      -- AC-002 is second in the embarked list, so the shared list (index 1) applies to it
      assert.stub(stubCreate).was.called(1)
    end)

    -- Negative: should still assign missions when the base has no embarked aircraft list
    it("should skip the transfer when the base has no embarked aircraft", function()
      makeAirBase({}, { embarkedUnits = { Boats = {} } })

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft({ makeTransportAircraftItem() })

      assert.is_true(result)
      assert.stub(stubAssignMission).was.called(1)
    end)

    -- Negative: should not create cargo when the base cargo list is missing
    it("should not transfer when the base cargo list is nil", function()
      local aircraft = makeAircraft()
      makeAirBase({ aircraft }, { cargo = { [1] = { cargo = nil } } })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({ makeTransportAircraftItem() })

      assert.stub(stubCreate).was_not.called()
    end)

    -- Boundary: should create only as many items as actually matched
    it("should handle when fewer cargo items exist than requested", function()
      local aircraft = makeAircraft()
      local base = makeAirBase({ aircraft }, {
        cargo = { [1] = { cargo = { makeCargoElement({ guid = "C-ONLY", dbid = 1001 }) } } },
      })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft({
        makeItemWithCargo({ [1] = { makeCargoItem({ num = 5 }) } }),
      })

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubCreate).was.called(1)
    end)

    -- Boundary: should return true with empty transport aircraft list
    it("should return true with empty transport aircraft list", function()
      local result = AmphibiousLogistics.transferAndAssignTransportAircraft({})

      assert.is_true(result)
      assert.stub(stubAssignMission).was_not.called()
    end)
  end)

  -- ============================================================================
  -- retransferCargos
  -- ============================================================================

  describe("retransferCargos", function()
    before_each(function()
      stubUnitLookup()
    end)

    ---Convert ships to the side unit list shape retransferCargos receives
    ---@param ships table[]
    ---@return table[]
    local function toSideUnits(ships)
      local units = {}
      for _, ship in ipairs(ships) do table.insert(units, { guid = ship.guid }) end
      return units
    end

    -- Positive: should retransfer cargo for Type 075 ships
    it("should retransfer cargo to boats and helicopters on Type 075 ships", function()
      local ship, creates = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.retransferCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was.called()
    end)

    -- Positive: should retransfer cargo for Type 076 ships
    it("should retransfer cargo to boats and helicopters on Type 076 ships", function()
      local ship, creates = makeFleetShip("SHIP-076", constants.PLATFORMS.TYPE_076)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.retransferCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.heloAlt).was.called()
    end)

    -- Positive: should retransfer cargo for Type 071 ships
    it("should retransfer cargo to boats and helicopters on Type 071 ships", function()
      local ship, creates = makeFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.retransferCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was_not.called()
    end)

    -- Positive: should handle mixed fleet
    it("should retransfer cargo for both Type 075 and Type 071 ships", function()
      local ship075, creates075 = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local ship071, creates071 = makeFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.retransferCargos(zone, toSideUnits({ ship075, ship071 }))

      assert.is_true(result)
      assert.stub(creates075.heloAlt).was.called()
      assert.stub(creates071.boat).was.called()
    end)

    -- Negative: should skip unretrievable units and continue
    it("should skip unretrievable units and continue", function()
      local ship, creates = makeFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = makeOperationalZone()
      local units = { { guid = "GHOST-001" }, { guid = ship.guid } }

      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
    end)

    -- Negative: should skip non-LHD/LPD ship types
    it("should skip ships that are not Type 075/076/071", function()
      local ship, creates = makeFleetShip("SHIP-OTHER", constants.PLATFORMS.TYPE_072III)
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.retransferCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was_not.called()
      assert.stub(creates.helo).was_not.called()
    end)

    -- Boundary: should return true for empty units list
    it("should return true when no units are provided", function()
      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, {})

      assert.is_true(result)
    end)
  end)
end)
