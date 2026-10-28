---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps AmphibiousLogistics Unit Tests
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("AmphibiousLogistics", function()
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

  ---Create a cargo element (as stored in unit.cargo[1].cargo)
  ---@param overrides? table
  ---@return table
  local function buildCargoElement(overrides)
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
  local function buildCargoItem(overrides)
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
  local function buildUnit(overrides)
    local unit = {
      guid = "UNIT-001",
      name = "TestUnit",
      dbid = constants.PLATFORMS.TYPE_075,
      unitstate = "Unassigned",
      cargo = {
        [1] = {
          cargo = {
            buildCargoElement({ guid = "C-1", dbid = 1001 }),
            buildCargoElement({ guid = "C-2", dbid = 1001 }),
            buildCargoElement({ guid = "C-3", dbid = 2002 }),
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
  local function buildOperationalZone(overrides)
    local zone = {
      name = "ZoneAlpha",
      fleet = { stagingArea = { "RP-STG-1" } },
      movement = {
        holdingAreas = {
          mothership = { "RP-ANC-1", "RP-ANC-2" },
          deployLine = { "RP-LST-1", "RP-LST-2" },
        },
      },
      landing = {
        hovercraft = {
          dbid = 3001,
          zone = { "RP-BOAT-1" },
          transferManifest = {
            type075 = {
              [1] = { loadoutId = 10, cargoItems = { [1] = { buildCargoItem() } } },
            },
            type071 = {
              [1] = { loadoutId = 10, cargoItems = { [1] = { buildCargoItem() } } },
            },
          },
        },
      },
      air = {
        transportHelicopter = {
          dbid = 4001,
          zone = { "RP-HELO-1" },
          missions = {
            { name = "HeloMission-1", loadoutId = 20, unitCount = 2, startTime = 0 },
          },
          transferManifest = {
            type075 = {
              [1] = { loadoutId = 20, cargoItems = { [1] = { buildCargoItem() } } },
              [2] = { loadoutId = 21, cargoItems = { [1] = { buildCargoItem({ dbid = 2002 }) } } },
            },
            type071 = {
              [1] = { loadoutId = 20, cargoItems = { [1] = { buildCargoItem() } } },
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
        if type(zone[k]) == "table" and (k == "movement" or k == "air" or k == "landing") then
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
  local function buildTransportAircraftItem(overrides)
    local item = {
      name = "AirBase-1",
      guid = "BASE-001",
      dbid = 6001,
      missions = {
        { name = "AirliftMission-1", loadoutId = 40, unitCount = 1, startTime = 0 },
      },
      cargoItemsForTransfer = {
        [1] = { loadoutId = 40, cargoItems = { [1] = { buildCargoItem() } } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do item[k] = v end
    end
    return item
  end

  ---Units resolvable through the GameApi.ScenEdit_GetUnit stub installed by cargo transfer blocks
  ---@type table<string, table>
  local unitMap

  ---Make units resolvable by GUID through the GameApi.ScenEdit_GetUnit stub
  ---@param units table[]
  local function registerUnits(units)
    for _, u in ipairs(units) do unitMap[u.guid] = u end
  end

  ---Install a GameApi.ScenEdit_GetUnit stub that resolves registered units only
  ---@return luassert.spy
  local function stubUnitLookup()
    unitMap = {}
    return trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      return unitMap[guid]
    end))
  end

  ---Create a registered amphibious ship carrying one boat and two transport helicopters
  ---(loadouts 20 and 21), matching the platforms in buildOperationalZone's manifests.
  ---The boat keeps buildUnit's default loadout, which differs from the manifest's, because
  ---boats must receive cargo regardless of loadout.
  ---@param guid string
  ---@param dbid number
  ---@return table ship
  ---@return {boat: luassert.spy, helo: luassert.spy, heloAlt: luassert.spy} creates createUnitCargo stubs per embarked unit
  local function buildFleetShip(guid, dbid)
    local boat = buildUnit({ guid = guid .. "-BOAT", dbid = 3001 })
    local helo = buildUnit({ guid = guid .. "-HELO20", dbid = 4001, loadoutdbid = 20 })
    local heloAlt = buildUnit({ guid = guid .. "-HELO21", dbid = 4001, loadoutdbid = 21 })
    local ship = buildUnit({
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

  describe("removeCargo", function()
    it("should delete matching cargo and return count", function()
      local fromUnit = buildUnit()
      local cargoItem = buildCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(true))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(2, result)
    end)

    it("should count only successful deletions", function()
      local fromUnit = buildUnit()
      local cargoItem = buildCargoItem({ num = 2 })

      local callCount = 0
      trackStub(stub(fromUnit, "deleteUnitCargo").invokes(function()
        callCount = callCount + 1
        return callCount == 1
      end))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)

    it("should return 0 when fromUnit is nil", function()
      local cargoItem = buildCargoItem()

      local result = AmphibiousLogistics.removeCargo(nil, cargoItem)

      assert.are.equal(0, result)
    end)

    it("should return 0 when fromUnit cargo is nil", function()
      local fromUnit = buildUnit({ cargo = nil })
      local cargoItem = buildCargoItem()

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    it("should return 0 when cargo first element is nil", function()
      local fromUnit = buildUnit({ cargo = {} })
      local cargoItem = buildCargoItem()

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    it("should return 0 when requested quantity is zero", function()
      local fromUnit = buildUnit()
      local cargoItem = buildCargoItem({ num = 0 })

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    it("should return 0 when all deletions fail", function()
      local fromUnit = buildUnit()
      local cargoItem = buildCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(nil))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    it("should delete only available matching cargo when fewer exist than requested", function()
      local fromUnit = buildUnit({
        cargo = {
          [1] = {
            cargo = {
              buildCargoElement({ guid = "C-SINGLE", dbid = 1001 }),
            },
          },
        },
      })
      local cargoItem = buildCargoItem({ num = 5 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(true))

      local result = AmphibiousLogistics.removeCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)
  end)

  describe("getUnitsInHoldingAreas", function()
    local stubGetUnit

    it("should collect amphibious ships that are in holding area", function()
      local unit = buildUnit({
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

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(1, #result.units)
      assert.are.equal(unit, result.units[1])
    end)

    it("should collect ships that are in LST holding area", function()
      local zone = buildOperationalZone()
      local deployLine = zone.movement.holdingAreas.deployLine
      local unit = buildUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_072III,
        unitstate = "Unassigned",
        inArea = function(_, area)
          return area == deployLine
        end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(1, #result.units)
    end)

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
      local shipUnitMap = {}

      for i, dbid in ipairs(shipDBIDs) do
        local guid = "SHIP-" .. tostring(i)
        table.insert(filteredUnits, { guid = guid })
        shipUnitMap[guid] = buildUnit({
          guid = guid,
          dbid = dbid,
          unitstate = "Unassigned",
          inArea = function() return true end,
        })
      end

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return shipUnitMap[guid]
      end))

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(#shipDBIDs, #result.units)
    end)

    it("should set isUnitMoving true when any ship is actively moving", function()
      local unit = buildUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Tasked",
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_true(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    -- Ships of other zones (outside staging and holding areas) must not block arrival
    it("should ignore moving ships that belong to another zone", function()
      local otherZoneShip = buildUnit({
        guid = "SHIP-OTHER",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Tasked",
      })
      local filteredUnits = { { guid = "SHIP-OTHER" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(otherZoneShip))

      local result = AmphibiousLogistics.getUnitsInHoldingAreas(buildOperationalZone(), filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    it("should stop processing remaining units once a moving unit is found", function()
      local movingUnit = buildUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Tasked",
        inArea = function() return true end,
      })
      local stationaryUnit = buildUnit({
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

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_true(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    it("should skip non-amphibious ship types", function()
      local unit = buildUnit({
        guid = "SHIP-001",
        dbid = 99999,
        unitstate = "Unassigned",
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    it("should skip units that cannot be retrieved from API", function()
      local filteredUnits = { { guid = "GHOST-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    it("should not collect ships outside the operational zone", function()
      local unit = buildUnit({
        guid = "SHIP-001",
        dbid = constants.PLATFORMS.TYPE_075,
        unitstate = "Unassigned",
        inArea = function() return false end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)

    it("should return empty results for empty filtered units list", function()
      local zone = buildOperationalZone()
      local filteredUnits = {}
      local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)

      assert.is_false(result.isUnitMoving)
      assert.are.equal(0, #result.units)
    end)
  end)

  describe("transferAndAssign", function()
    before_each(function()
      stubUnitLookup()
    end)

    -- Load boats and both helicopter loadouts on Type 075 ships
    it("should transfer cargo for Type 075 ships", function()
      local ship, creates = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was.called()
    end)

    it("should transfer cargo for Type 076 ships", function()
      local ship, creates = buildFleetShip("SHIP-076", constants.PLATFORMS.TYPE_076)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.heloAlt).was.called()
    end)

    -- Load boats and one helicopter loadout on Type 071 ships
    it("should transfer cargo for Type 071 ships", function()
      local ship, creates = buildFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      -- Type 071 manifest has no second helicopter loadout
      assert.stub(creates.heloAlt).was_not.called()
    end)

    it("should process both Type 075 and Type 071 ships in same zone", function()
      local ship075, creates075 = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local ship071, creates071 = buildFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { ship075, ship071 })

      assert.is_true(result)
      assert.stub(creates075.heloAlt).was.called()
      assert.stub(creates071.boat).was.called()
    end)

    it("should assign no mission to the helicopters", function()
      local stubAssignMission = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission"))
      local ship = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)

      AmphibiousLogistics.transferAndAssign(buildOperationalZone(), { ship })

      assert.stub(stubAssignMission).was_not.called()
    end)

    it("should skip ships not in holding area", function()
      local ship, creates = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      ship.inArea = function() return false end
      local zone = buildOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.stub(creates.boat).was_not.called()
    end)

    it("should skip units that are not Type 075/076 or Type 071", function()
      local ship, creates = buildFleetShip("SHIP-OTHER", constants.PLATFORMS.TYPE_072III)
      local zone = buildOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { ship })

      assert.stub(creates.boat).was_not.called()
      assert.stub(creates.helo).was_not.called()
    end)

    it("should return true with empty units list", function()
      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.transferAndAssign(zone, {})

      assert.is_true(result)
    end)
  end)

  describe("transferAndAssignTransportAircraft", function()
    local stubAssignMission

    ---Create an embarked transport aircraft matching buildTransportAircraftItem's dbid and loadout
    ---@param overrides? table
    ---@return table
    local function buildAircraft(overrides)
      local aircraft = buildUnit({ guid = "AC-001", dbid = 6001, loadoutdbid = 40 })
      if overrides then
        for k, v in pairs(overrides) do aircraft[k] = v end
      end
      return aircraft
    end

    ---Create a registered air base (buildTransportAircraftItem's GUID) embarking the given aircraft
    ---@param aircraftList table[]
    ---@param overrides? table
    ---@return table
    local function buildAirBase(aircraftList, overrides)
      local guids = {}
      for _, aircraft in ipairs(aircraftList) do table.insert(guids, aircraft.guid) end

      local base = buildUnit({ guid = "BASE-001", embarkedUnits = { Aircraft = guids, Boats = {} } })
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
    local function buildItemWithCargo(cargoItems)
      return buildTransportAircraftItem({
        cargoItemsForTransfer = { [1] = { loadoutId = 40, cargoItems = cargoItems } },
      })
    end

    before_each(function()
      stubUnitLookup()
      stubAssignMission = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))
    end)

    it("should move matching cargo from the base onto a matching aircraft", function()
      local aircraft = buildAircraft()
      local base = buildAirBase({ aircraft })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))
      local item = buildTransportAircraftItem()

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(item)

      assert.is_true(result)
      assert.stub(stubDelete).was.called(2)
      assert.stub(stubDelete).was.called_with(base, "C-1")
      assert.stub(stubDelete).was.called_with(base, "C-2")
      assert.stub(stubCreate).was.called(2)
      assert.are.same({ 1, 1001 }, { stubCreate.calls[1].vals[2], stubCreate.calls[1].vals[3] })
      assert.stub(stubAssignMission).was.called_with("AC-001", "AirliftMission-1", false)
    end)

    it("should only transfer up to the requested quantity", function()
      local aircraft = buildAircraft()
      local base = buildAirBase({ aircraft })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(
        buildItemWithCargo({ [1] = { buildCargoItem({ num = 1 }) } })
      )

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubCreate).was.called(1)
    end)

    it("should skip non-matching cargo elements", function()
      local aircraft = buildAircraft()
      local base = buildAirBase({ aircraft }, {
        cargo = {
          [1] = {
            cargo = {
              buildCargoElement({ guid = "C-X", dbid = 9999 }),
              buildCargoElement({ guid = "C-Y", dbid = 9999 }),
              buildCargoElement({ guid = "C-Z", dbid = 1001 }),
            },
          },
        },
      })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(
        buildItemWithCargo({ [1] = { buildCargoItem({ num = 1 }) } })
      )

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubDelete).was.called_with(base, "C-Z")
      assert.stub(stubCreate).was.called(1)
    end)

    it("should use per-unit cargo lists when multiple lists are provided", function()
      local ac1 = buildAircraft({ guid = "AC-001" })
      local ac2 = buildAircraft({ guid = "AC-002" })
      buildAirBase({ ac1, ac2 })
      local stubCreate1 = trackStub(stub(ac1, "createUnitCargo"))
      local stubCreate2 = trackStub(stub(ac2, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(
        buildItemWithCargo({
          [1] = { buildCargoItem({ dbid = 1001, num = 1 }) },
          [2] = { buildCargoItem({ dbid = 2002, num = 1 }) },
        })
      )

      assert.stub(stubCreate1).was.called(1)
      assert.are.same({ 1, 1001 }, { stubCreate1.calls[1].vals[2], stubCreate1.calls[1].vals[3] })
      assert.stub(stubCreate2).was.called(1)
      assert.are.same({ 1, 2002 }, { stubCreate2.calls[1].vals[2], stubCreate2.calls[1].vals[3] })
    end)

    it("should not transfer cargo when the base unit is not found", function()
      local aircraft = buildAircraft()
      registerUnits({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(buildTransportAircraftItem())

      assert.is_true(result)
      assert.stub(stubCreate).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)

    it("should skip aircraft that do not match platform DBID", function()
      local aircraft = buildAircraft({ dbid = 9999 })
      buildAirBase({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(buildTransportAircraftItem())

      assert.stub(stubCreate).was_not.called()
    end)

    it("should skip aircraft that do not match loadout DBID", function()
      local aircraft = buildAircraft({ loadoutdbid = 999 })
      buildAirBase({ aircraft })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(buildTransportAircraftItem())

      assert.stub(stubCreate).was_not.called()
    end)

    it("should skip embarked units that cannot be retrieved", function()
      local aircraft = buildAircraft({ guid = "AC-002" })
      buildAirBase({ aircraft })
      unitMap["BASE-001"].embarkedUnits.Aircraft = { "GHOST-001", "AC-002" }
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(
        buildItemWithCargo({ [1] = { buildCargoItem({ num = 1 }) } })
      )

      -- AC-002 is second in the embarked list, so the shared list (index 1) applies to it
      assert.stub(stubCreate).was.called(1)
    end)

    it("should skip the transfer when the base has no embarked aircraft", function()
      buildAirBase({}, { embarkedUnits = { Aircraft = {}, Boats = {} } })

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(buildTransportAircraftItem())

      assert.is_true(result)
      assert.stub(stubAssignMission).was_not.called()
    end)

    it("should not transfer when the base cargo list is nil", function()
      local aircraft = buildAircraft()
      buildAirBase({ aircraft }, { cargo = { [1] = { cargo = nil } } })
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(buildTransportAircraftItem())

      assert.stub(stubCreate).was_not.called()
    end)

    it("should handle when fewer cargo items exist than requested", function()
      local aircraft = buildAircraft()
      local base = buildAirBase({ aircraft }, {
        cargo = { [1] = { cargo = { buildCargoElement({ guid = "C-ONLY", dbid = 1001 }) } } },
      })
      local stubDelete = trackStub(stub(base, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(aircraft, "createUnitCargo"))

      AmphibiousLogistics.transferAndAssignTransportAircraft(
        buildItemWithCargo({ [1] = { buildCargoItem({ num = 5 }) } })
      )

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubCreate).was.called(1)
    end)
  end)

  describe("transferRemainingCargos", function()
    before_each(function()
      stubUnitLookup()
    end)

    ---Convert ships to the side unit list shape transferRemainingCargos receives
    ---@param ships table[]
    ---@return table[]
    local function toSideUnits(ships)
      local units = {}
      for _, ship in ipairs(ships) do table.insert(units, { guid = ship.guid }) end
      return units
    end

    it("should transfer remaining cargo to boats and helicopters on Type 075 ships", function()
      local ship, creates = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferRemainingCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was.called()
    end)

    it("should transfer remaining cargo to boats and helicopters on Type 076 ships", function()
      local ship, creates = buildFleetShip("SHIP-076", constants.PLATFORMS.TYPE_076)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferRemainingCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.heloAlt).was.called()
    end)

    it("should transfer remaining cargo to boats and helicopters on Type 071 ships", function()
      local ship, creates = buildFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferRemainingCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
      assert.stub(creates.helo).was.called()
      assert.stub(creates.heloAlt).was_not.called()
    end)

    it("should transfer remaining cargo for both Type 075 and Type 071 ships", function()
      local ship075, creates075 = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local ship071, creates071 = buildFleetShip("SHIP-071", constants.PLATFORMS.TYPE_071)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferRemainingCargos(zone, toSideUnits({ ship075, ship071 }))

      assert.is_true(result)
      assert.stub(creates075.heloAlt).was.called()
      assert.stub(creates071.boat).was.called()
    end)

    it("should skip unretrievable units and continue", function()
      local ship, creates = buildFleetShip("SHIP-075", constants.PLATFORMS.TYPE_075)
      local zone = buildOperationalZone()
      local units = { { guid = "GHOST-001" }, { guid = ship.guid } }

      local result = AmphibiousLogistics.transferRemainingCargos(zone, units)

      assert.is_true(result)
      assert.stub(creates.boat).was.called()
    end)

    it("should skip ships that are not Type 075/076/071", function()
      local ship, creates = buildFleetShip("SHIP-OTHER", constants.PLATFORMS.TYPE_072III)
      local zone = buildOperationalZone()

      local result = AmphibiousLogistics.transferRemainingCargos(zone, toSideUnits({ ship }))

      assert.is_true(result)
      assert.stub(creates.boat).was_not.called()
      assert.stub(creates.helo).was_not.called()
    end)

    it("should return true when no units are provided", function()
      local zone = buildOperationalZone()
      local result = AmphibiousLogistics.transferRemainingCargos(zone, {})

      assert.is_true(result)
    end)
  end)
end)
