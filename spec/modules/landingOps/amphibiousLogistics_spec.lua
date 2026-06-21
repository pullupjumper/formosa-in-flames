-- AmphibiousLogistics Unit Tests
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local AssignMission = require("src.modules.assignMission")
local constants = require("src.core.constants")

describe("AmphibiousLogistics", function()
  ---@type luassert.spy[]
  local activeStubs
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
      anchorageArea = { "RP-ANC-1", "RP-ANC-2" },
      lstAnchorageArea = { "RP-LST-1", "RP-LST-2" },
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
    }
    if overrides then
      for k, v in pairs(overrides) do zone[k] = v end
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
        [1] = { loadoutId = 40, cargoItems = { [1] = { makeCargoItem({ dbid = 3003 }) } } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do item[k] = v end
    end
    return item
  end

  -- ============================================================================
  -- updateCargo
  -- ============================================================================

  describe("updateCargo", function()
    -- Positive: should delete matching cargo from source and create on destination
    it("should delete matching cargo from source and create on destination", function()
      local fromUnit = makeUnit()
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem({ num = 2 })

      local stubDelete = trackStub(stub(fromUnit, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)

      assert.stub(stubDelete).was.called(2)
      assert.stub(stubDelete).was.called_with(fromUnit, "C-1")
      assert.stub(stubDelete).was.called_with(fromUnit, "C-2")
      assert.stub(stubCreate).was.called(2)
      assert.stub(stubCreate).was.called_with(toUnit, 1, 1001)
    end)

    -- Positive: should only transfer up to the requested quantity
    it("should only transfer up to the requested quantity", function()
      local fromUnit = makeUnit()
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem({ num = 1 })

      local stubDelete = trackStub(stub(fromUnit, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubCreate).was.called(1)
    end)

    -- Positive: should skip non-matching cargo elements
    it("should skip non-matching cargo elements", function()
      local fromUnit = makeUnit({
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
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem({ dbid = 1001, num = 1 })

      local stubDelete = trackStub(stub(fromUnit, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubDelete).was.called_with(fromUnit, "C-Z")
      assert.stub(stubCreate).was.called(1)
    end)

    -- Negative: should return early when fromUnit is nil
    it("should return early when fromUnit is nil", function()
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem()

      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(nil, toUnit, cargoItem)

      assert.stub(stubCreate).was_not.called()
    end)

    -- Negative: should return early when fromUnit cargo is nil
    it("should return early when fromUnit cargo list is nil", function()
      local fromUnit = makeUnit({ cargo = { [1] = { cargo = nil } } })
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem()

      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)

      assert.stub(stubCreate).was_not.called()
    end)

    -- Boundary: should handle when fewer cargo items exist than requested
    it("should handle when fewer cargo items exist than requested", function()
      local fromUnit = makeUnit({
        cargo = {
          [1] = {
            cargo = {
              makeCargoElement({ guid = "C-ONLY", dbid = 1001 }),
            },
          },
        },
      })
      local toUnit = makeUnit({ guid = "UNIT-002" })
      local cargoItem = makeCargoItem({ num = 5 })

      local stubDelete = trackStub(stub(fromUnit, "deleteUnitCargo"))
      local stubCreate = trackStub(stub(toUnit, "createUnitCargo"))

      AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)

      assert.stub(stubDelete).was.called(1)
      -- Create count matches actual matched cargo (1), not requested num (5)
      assert.stub(stubCreate).was.called(1)
    end)
  end)

  -- ============================================================================
  -- deleteCargo
  -- ============================================================================

  describe("deleteCargo", function()
    -- Positive: should delete matching cargo and return count
    it("should delete matching cargo and return count", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(true))

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

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

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)

    -- Negative: should return 0 when fromUnit is nil
    it("should return 0 when fromUnit is nil", function()
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.deleteCargo(nil, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when fromUnit.cargo is nil
    it("should return 0 when fromUnit cargo is nil", function()
      local fromUnit = makeUnit({ cargo = nil })
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when cargo[1] is nil
    it("should return 0 when cargo first element is nil", function()
      local fromUnit = makeUnit({ cargo = {} })
      local cargoItem = makeCargoItem()

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when cargoItem.num is 0
    it("should return 0 when requested quantity is zero", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 0 })

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

      assert.are.equal(0, result)
    end)

    -- Negative: should return 0 when deleteUnitCargo returns falsy
    it("should return 0 when all deletions fail", function()
      local fromUnit = makeUnit()
      local cargoItem = makeCargoItem({ num = 2 })

      trackStub(stub(fromUnit, "deleteUnitCargo").returns(nil))

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

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

      local result = AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)

      assert.are.equal(1, result)
    end)
  end)

  -- ============================================================================
  -- transferCargo
  -- ============================================================================

  describe("transferCargo", function()
    local stubGetUnit, stubUpdateCargo

    before_each(function()
      stubUpdateCargo = trackStub(stub(AmphibiousLogistics, "updateCargo"))
    end)

    -- Positive: should transfer cargo to matching Aircraft with single cargo list
    it("should transfer cargo to matching Aircraft with single cargo list", function()
      local aircraft = makeUnit({
        guid = "AC-001",
        dbid = 4001,
        loadoutdbid = 20,
      })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = { "AC-001" }, Boats = {} },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return aircraft end
        return nil
      end))

      local cargoItems = { [1] = { makeCargoItem() } }

      AmphibiousLogistics.transferCargo("BASE-001", "Aircraft", 4001, 20, cargoItems)

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubUpdateCargo).was.called_with(base, aircraft, cargoItems[1][1])
    end)

    -- Positive: should transfer cargo to matching Boats (ignores loadout)
    it("should transfer cargo to matching Boats", function()
      local boat = makeUnit({
        guid = "BOAT-001",
        dbid = 3001,
      })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = {}, Boats = { "BOAT-001" } },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "BOAT-001" then return boat end
        return nil
      end))

      local cargoItems = { [1] = { makeCargoItem() } }

      AmphibiousLogistics.transferCargo("BASE-001", "Boats", 3001, 0, cargoItems)

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubUpdateCargo).was.called_with(base, boat, cargoItems[1][1])
    end)

    -- Positive: should use per-unit cargo lists when count > 1
    it("should use per-unit cargo lists when multiple cargo lists are provided", function()
      local boat1 = makeUnit({ guid = "BOAT-001", dbid = 3001 })
      local boat2 = makeUnit({ guid = "BOAT-002", dbid = 3001 })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = {}, Boats = { "BOAT-001", "BOAT-002" } },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "BOAT-001" then return boat1 end
        if guid == "BOAT-002" then return boat2 end
        return nil
      end))

      local cargoA = makeCargoItem({ dbid = 1001 })
      local cargoB = makeCargoItem({ dbid = 2002 })
      local cargoItems = {
        [1] = { cargoA },
        [2] = { cargoB },
      }

      AmphibiousLogistics.transferCargo("BASE-001", "Boats", 3001, 0, cargoItems)

      assert.stub(stubUpdateCargo).was.called(2)
      assert.stub(stubUpdateCargo).was.called_with(base, boat1, cargoA)
      assert.stub(stubUpdateCargo).was.called_with(base, boat2, cargoB)
    end)

    -- Positive: should use per-unit cargo lists for Aircraft when count > 1
    it("should use per-unit cargo lists for Aircraft when multiple lists provided", function()
      local ac1 = makeUnit({ guid = "AC-001", dbid = 4001, loadoutdbid = 20 })
      local ac2 = makeUnit({ guid = "AC-002", dbid = 4001, loadoutdbid = 20 })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = { "AC-001", "AC-002" }, Boats = {} },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return ac1 end
        if guid == "AC-002" then return ac2 end
        return nil
      end))

      local cargoA = makeCargoItem({ dbid = 1001 })
      local cargoB = makeCargoItem({ dbid = 2002 })
      local cargoItems = {
        [1] = { cargoA },
        [2] = { cargoB },
      }

      AmphibiousLogistics.transferCargo("BASE-001", "Aircraft", 4001, 20, cargoItems)

      assert.stub(stubUpdateCargo).was.called(2)
      assert.stub(stubUpdateCargo).was.called_with(base, ac1, cargoA)
      assert.stub(stubUpdateCargo).was.called_with(base, ac2, cargoB)
    end)

    -- Negative: should return early when base unit is not found
    it("should return early when base unit is not found", function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      AmphibiousLogistics.transferCargo("INVALID", "Boats", 3001, 0, { [1] = { makeCargoItem() } })

      assert.stub(stubUpdateCargo).was_not.called()
    end)

    -- Negative: should skip Aircraft that do not match DBID
    it("should skip Aircraft that do not match platform DBID", function()
      local aircraft = makeUnit({
        guid = "AC-001",
        dbid = 9999,
        loadoutdbid = 20,
      })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = { "AC-001" }, Boats = {} },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return aircraft end
        return nil
      end))

      AmphibiousLogistics.transferCargo("BASE-001", "Aircraft", 4001, 20, { [1] = { makeCargoItem() } })

      assert.stub(stubUpdateCargo).was_not.called()
    end)

    -- Negative: should skip Aircraft that do not match loadout
    it("should skip Aircraft that do not match loadout DBID", function()
      local aircraft = makeUnit({
        guid = "AC-001",
        dbid = 4001,
        loadoutdbid = 999,
      })
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = { "AC-001" }, Boats = {} },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return aircraft end
        return nil
      end))

      AmphibiousLogistics.transferCargo("BASE-001", "Aircraft", 4001, 20, { [1] = { makeCargoItem() } })

      assert.stub(stubUpdateCargo).was_not.called()
    end)

    -- Negative: should skip embarked units that return nil from GetUnit
    it("should skip embarked units that cannot be retrieved", function()
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = {}, Boats = { "GHOST-001" } },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        return nil
      end))

      AmphibiousLogistics.transferCargo("BASE-001", "Boats", 3001, 0, { [1] = { makeCargoItem() } })

      assert.stub(stubUpdateCargo).was_not.called()
    end)

    -- Negative: should not transfer when no platforms of specified type exist
    it("should not transfer when no embarked platforms exist", function()
      local base = makeUnit({
        guid = "BASE-001",
        embarkedUnits = { Aircraft = {}, Boats = {} },
      })

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        return nil
      end))

      AmphibiousLogistics.transferCargo("BASE-001", "Boats", 3001, 0, { [1] = { makeCargoItem() } })

      assert.stub(stubUpdateCargo).was_not.called()
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
      local lstArea = zone.lstAnchorageArea
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
        { zone = zone.boat.zone }
      )
      assert.stub(stubAddMission).was.called_with(
        "China", "HeloMission-1", "Cargo",
        { zone = zone.transportHelicopter.zone }
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
        transportHelicopter = {
          dbid = 4001,
          zone = { "RP-HELO-1" },
          settings = { throttle = "Full" },
          missions = {
            { name = "HeloMission-1", loadoutId = 20, unitCount = 1, startTime = 0 },
          },
          transferManifest = { type075 = {}, type071 = {} },
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
    end)

    -- Negative: should return false when SetMission fails
    it("should return false when SetMission fails", function()
      stubSetMission.returns(nil)

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_false(result)
    end)

    -- Negative: should return false when SetDoctrine fails
    it("should return false when SetDoctrine fails", function()
      stubSetDoctrine.returns(nil)

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.createCargoMissions(zone)

      assert.is_false(result)
    end)
  end)

  -- ============================================================================
  -- transferAndAssign
  -- ============================================================================

  describe("transferAndAssign", function()
    local stubTransferCargo, stubAssignMission

    before_each(function()
      stubTransferCargo = trackStub(stub(AmphibiousLogistics, "transferCargo"))
      stubAssignMission = trackStub(stub(AssignMission, "assignEmbarkedUnitsToMissions"))
    end)

    -- Positive: should transfer and assign for Type 075 in anchorage area
    it("should transfer cargo and assign missions for Type 075 ships", function()
      local unit075 = makeUnit({
        guid = "SHIP-075",
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { unit075 })

      assert.is_true(result)
      -- Type 075: 3 transferCargo calls (boats + 2 helo loadouts)
      assert.stub(stubTransferCargo).was.called(3)
      -- Type 075: 3 assignMission calls (boats + helo + attack helo)
      assert.stub(stubAssignMission).was.called(3)
      assert.stub(logStub).was.called(1)
    end)

    -- Positive: should transfer and assign for Type 076 in anchorage area
    it("should transfer cargo and assign missions for Type 076 ships", function()
      local unit076 = makeUnit({
        guid = "SHIP-076",
        dbid = constants.PLATFORMS.TYPE_076,
        inArea = function() return true end,
      })
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { unit076 })

      assert.is_true(result)
      -- Type 076 uses same path as Type 075: 3 transfers
      assert.stub(stubTransferCargo).was.called(3)
    end)

    -- Positive: should transfer and assign for Type 071 in anchorage area
    it("should transfer cargo and assign missions for Type 071 ships", function()
      local unit071 = makeUnit({
        guid = "SHIP-071",
        dbid = constants.PLATFORMS.TYPE_071,
        inArea = function() return true end,
      })
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { unit071 })

      assert.is_true(result)
      -- Type 071: 2 transferCargo calls (boats + helo)
      assert.stub(stubTransferCargo).was.called(2)
      -- Type 071: 2 assignMission calls (boats + helo) - no attack helo
      assert.stub(stubAssignMission).was.called(2)
    end)

    -- Positive: should handle mixed fleet in anchorage
    it("should process both Type 075 and Type 071 ships in same zone", function()
      local unit075 = makeUnit({
        guid = "SHIP-075",
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local unit071 = makeUnit({
        guid = "SHIP-071",
        dbid = constants.PLATFORMS.TYPE_071,
        inArea = function() return true end,
      })
      local zone = makeOperationalZone()

      local result = AmphibiousLogistics.transferAndAssign(zone, { unit075, unit071 })

      assert.is_true(result)
      -- Type 075: 3 transfers + Type 071: 2 transfers = 5
      assert.stub(stubTransferCargo).was.called(5)
    end)

    -- Negative: should skip units not in anchorage area
    it("should skip ships not in anchorage area", function()
      local unit075 = makeUnit({
        guid = "SHIP-075",
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return false end,
      })
      local zone = makeOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { unit075 })

      assert.stub(stubTransferCargo).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)

    -- Negative: should skip non-amphibious unit types
    it("should skip units that are not Type 075/076 or Type 071", function()
      local otherUnit = makeUnit({
        guid = "SHIP-OTHER",
        dbid = constants.PLATFORMS.TYPE_072III,
        inArea = function() return true end,
      })
      local zone = makeOperationalZone()

      AmphibiousLogistics.transferAndAssign(zone, { otherUnit })

      -- No matching transfer spec for TYPE_072III, so no transfers or assignments
      assert.stub(stubTransferCargo).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)

    -- Boundary: should return true with empty units list
    it("should return true with empty units list", function()
      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.transferAndAssign(zone, {})

      assert.is_true(result)
      assert.stub(stubTransferCargo).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)
  end)

  -- ============================================================================
  -- transferAndAssignTransportAircraft
  -- ============================================================================

  describe("transferAndAssignTransportAircraft", function()
    local stubTransferCargo, stubAssignMission

    before_each(function()
      stubTransferCargo = trackStub(stub(AmphibiousLogistics, "transferCargo"))
      stubAssignMission = trackStub(stub(AssignMission, "assignEmbarkedUnitsToMissions"))
    end)

    -- Positive: should transfer cargo and assign missions for transport aircraft
    it("should transfer cargo and assign missions for transport aircraft", function()
      local transportAircraft = { makeTransportAircraftItem() }

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)

      assert.is_true(result)
      assert.stub(stubTransferCargo).was.called(1)
      assert.stub(stubAssignMission).was.called(1)

      assert.stub(stubTransferCargo).was.called_with(
        "BASE-001", "Aircraft", 6001, 40,
        transportAircraft[1].cargoItemsForTransfer[1].cargoItems
      )
    end)

    -- Positive: should handle multiple transport aircraft entries
    it("should process all transport aircraft entries", function()
      local transportAircraft = {
        makeTransportAircraftItem(),
        makeTransportAircraftItem({ name = "AirBase-2", guid = "BASE-002", dbid = 6002 }),
      }

      local result = AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)

      assert.is_true(result)
      assert.stub(stubTransferCargo).was.called(2)
      assert.stub(stubAssignMission).was.called(2)
    end)

    -- Boundary: should return true with empty transport aircraft list
    it("should return true with empty transport aircraft list", function()
      local result = AmphibiousLogistics.transferAndAssignTransportAircraft({})

      assert.is_true(result)
      assert.stub(stubTransferCargo).was_not.called()
      assert.stub(stubAssignMission).was_not.called()
    end)
  end)

  -- ============================================================================
  -- retransferCargos
  -- ============================================================================

  describe("retransferCargos", function()
    local stubGetUnit, stubTransferCargo

    before_each(function()
      stubTransferCargo = trackStub(stub(AmphibiousLogistics, "transferCargo"))
    end)

    -- Positive: should retransfer cargo for Type 075 ships
    it("should retransfer cargo to boats and helicopters on Type 075 ships", function()
      local unit075 = makeUnit({
        guid = "SHIP-075",
        dbid = constants.PLATFORMS.TYPE_075,
      })
      local units = { { guid = "SHIP-075" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit075))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      -- Type 075: 3 transferCargo calls (boats + 2 helo loadouts)
      assert.stub(stubTransferCargo).was.called(3)
      assert.stub(logStub).was.called(1)
    end)

    -- Positive: should retransfer cargo for Type 076 ships
    it("should retransfer cargo to boats and helicopters on Type 076 ships", function()
      local unit076 = makeUnit({
        guid = "SHIP-076",
        dbid = constants.PLATFORMS.TYPE_076,
      })
      local units = { { guid = "SHIP-076" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit076))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      assert.stub(stubTransferCargo).was.called(3)
    end)

    -- Positive: should retransfer cargo for Type 071 ships
    it("should retransfer cargo to boats and helicopters on Type 071 ships", function()
      local unit071 = makeUnit({
        guid = "SHIP-071",
        dbid = constants.PLATFORMS.TYPE_071,
      })
      local units = { { guid = "SHIP-071" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit071))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      -- Type 071: 2 transferCargo calls (boats + helo)
      assert.stub(stubTransferCargo).was.called(2)
    end)

    -- Positive: should handle mixed fleet
    it("should retransfer cargo for both Type 075 and Type 071 ships", function()
      local unit075 = makeUnit({ guid = "SHIP-075", dbid = constants.PLATFORMS.TYPE_075 })
      local unit071 = makeUnit({ guid = "SHIP-071", dbid = constants.PLATFORMS.TYPE_071 })
      local units = { { guid = "SHIP-075" }, { guid = "SHIP-071" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SHIP-075" then return unit075 end
        if guid == "SHIP-071" then return unit071 end
        return nil
      end))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      -- Type 075: 3 + Type 071: 2 = 5
      assert.stub(stubTransferCargo).was.called(5)
    end)

    -- Negative: should skip unretrievable units and continue
    it("should skip unretrievable units and continue", function()
      local units = { { guid = "GHOST-001" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      assert.stub(stubTransferCargo).was_not.called()
      assert.stub(logStub).was.called(1)
    end)

    -- Negative: should skip non-LHD/LPD ship types
    it("should skip ships that are not Type 075/076/071", function()
      local otherUnit = makeUnit({
        guid = "SHIP-OTHER",
        dbid = constants.PLATFORMS.TYPE_072III,
      })
      local units = { { guid = "SHIP-OTHER" } }

      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(otherUnit))

      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, units)

      assert.is_true(result)
      assert.stub(stubTransferCargo).was_not.called()
    end)

    -- Boundary: should return true for empty units list
    it("should return true when no units are provided", function()
      local zone = makeOperationalZone()
      local result = AmphibiousLogistics.retransferCargos(zone, {})

      assert.is_true(result)
      assert.stub(stubTransferCargo).was_not.called()
    end)
  end)

  -- ============================================================================
  -- loadCargo
  -- ============================================================================

  describe("loadCargo", function()
    local stubGetUnit, stubUpdateCargo, stubClearMags, stubUpdateUnit, stubAddReloads, stubDeleteUnit

    ---Create a mount weapon descriptor
    ---@param overrides? table
    ---@return table
    local function makeMountWeapon(overrides)
      local wpn = {
        wpn_dbid = 500,
        wpn_current = 10,
      }
      if overrides then
        for k, v in pairs(overrides) do wpn[k] = v end
      end
      return wpn
    end

    ---Create a mount descriptor
    ---@param overrides? table
    ---@return table
    local function makeMount(overrides)
      local mount = {
        mount_dbid = 100,
        mount_guid = "MNT-001",
        mount_weapons = {},
      }
      if overrides then
        for k, v in pairs(overrides) do mount[k] = v end
      end
      return mount
    end

    ---Create a unit with mounts for loadCargo testing
    ---@param overrides? table
    ---@return table
    local function makeLoadCargoUnit(overrides)
      local unit = {
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        group = nil,
        mounts = {},
      }
      if overrides then
        for k, v in pairs(overrides) do unit[k] = v end
      end
      return unit
    end

    before_each(function()
      stubUpdateCargo = trackStub(stub(GameApi, "ScenEdit_UpdateUnitCargo"))
      stubClearMags = trackStub(stub(GameApi, "ScenEdit_ClearAllMagazines"))
      stubUpdateUnit = trackStub(stub(GameApi, "ScenEdit_UpdateUnit"))
      stubAddReloads = trackStub(stub(GameApi, "ScenEdit_AddReloadsToUnit"))
      stubDeleteUnit = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
    end)

    -- Positive: should convert single unit (no group) to cargo
    it("should convert single unit (no group) to cargo", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-S1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 10 }) },
          }),
        },
      })

      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        name = "CargoProxy",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }) },
          }),
        },
      })

      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1", weaponDBID = 500 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubClearMags).was.called(1)
      -- 1 remove_mount (proxy's existing mount) + 1 add_mount (source's mount) = 2
      assert.stub(stubUpdateUnit).was.called(2)
      -- 1 clear reload + 1 set reload = 2
      assert.stub(stubAddReloads).was.called(2)
      assert.stub(stubDeleteUnit).was.called(1)
      assert.stub(stubDeleteUnit).was.called_with({ guid = "SRC-001" })
    end)

    -- Positive: should convert group members to cargo
    it("should convert group members to cargo", function()
      local groupObj = { name = "Alpha", unitlist = { "MEM-001", "MEM-002" } }
      local member1 = makeLoadCargoUnit({
        guid = "MEM-001",
        name = "Inf-1",
        dbid = 7001,
        group = groupObj,
        mounts = { makeMount({ mount_dbid = 100, mount_guid = "MNT-1", mount_weapons = {} }) },
      })
      local member2 = makeLoadCargoUnit({
        guid = "MEM-002",
        name = "Inf-2",
        dbid = 7001,
        group = groupObj,
        mounts = { makeMount({ mount_dbid = 101, mount_guid = "MNT-2", mount_weapons = {} }) },
      })
      local cargo1 = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local cargo2 = makeLoadCargoUnit({ guid = "CARGO-002", mounts = {} })

      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = {
          [1] = {
            cargo = {
              [1] = { guid = "CARGO-001" },
              [2] = { guid = "CARGO-002" },
            }
          }
        },
      })
      local unitCtx = { name = "Infantry-1" }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return member1 end
        if identifier == "MEM-001" then return member1 end
        if identifier == "MEM-002" then return member2 end
        if identifier == "CARGO-001" then return cargo1 end
        if identifier == "CARGO-002" then return cargo2 end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.stub(stubUpdateCargo).was.called(2)
      assert.stub(stubDeleteUnit).was.called(2)
    end)

    -- Negative: should return early when unit not found
    it("should return early when unit not found", function()
      local unitCtx = { name = "NonExistent" }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      AmphibiousLogistics.loadCargo(makeUnit({ guid = "BASE-001" }), unitCtx, "Red")

      assert.stub(stubUpdateCargo).was_not.called()
      assert.stub(stubDeleteUnit).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Negative: should skip group member when unit not found
    it("should skip group member when unit not found", function()
      local member1 = makeLoadCargoUnit({
        guid = "MEM-001",
        name = "Inf-1",
        dbid = 7001,
        group = { name = "Alpha", unitlist = { "MEM-001", "GHOST-002" } },
        mounts = {},
      })
      local cargo1 = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })

      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return member1 end
        if identifier == "MEM-001" then return member1 end
        if identifier == "CARGO-001" then return cargo1 end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      -- Only 1 cargo addition (for member1, not GHOST-002)
      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubDeleteUnit).was.called(1)
    end)

    -- Negative: should skip when cargo proxy creation fails
    it("should skip when cargo proxy creation fails", function()
      local sourceUnit = makeLoadCargoUnit({ guid = "SRC-001", name = "Infantry-1", dbid = 7001, mounts = {} })
      local base = makeUnit({ guid = "BASE-001", name = "BaseShip", cargo = nil })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubClearMags).was_not.called()
      assert.stub(stubDeleteUnit).was_not.called()
    end)

    -- Positive: should handle weaponDBID as single number
    it("should handle weaponDBID as single number", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 5 }) },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }) },
          }),
        },
      })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1", weaponDBID = 500 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      -- 1 clear (remove=true) + 1 set = 2
      assert.stub(stubAddReloads).was.called(2)
      assert.stub(stubAddReloads).was.called_with({
        side = "Red", guid = "CARGO-001", wpn_dbid = 500, number = 999, remove = true
      })
      assert.stub(stubAddReloads).was.called_with({
        side = "Red", guid = "CARGO-001", wpn_dbid = 500, number = 5
      })
    end)

    -- Positive: should handle weaponDBID as table of numbers
    it("should handle weaponDBID as table of numbers", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = {
              makeMountWeapon({ wpn_dbid = 500, wpn_current = 5 }),
              makeMountWeapon({ wpn_dbid = 600, wpn_current = 3 }),
            },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = {
              makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }),
              makeMountWeapon({ wpn_dbid = 600, wpn_default = 10 }),
            },
          }),
        },
      })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1", weaponDBID = { 500, 600 } }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      -- 2 clears + 2 sets = 4
      assert.stub(stubAddReloads).was.called(4)
    end)

    -- Positive: should skip weapon tally when weaponDBID is nil
    it("should skip weapon tally when weaponDBID is nil", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 10 }) },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.stub(stubAddReloads).was_not.called()
    end)

    -- Positive: should set group name on cargo when source has group
    it("should set group name on cargo when source has group", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        group = { name = "Alpha", unitlist = { "SRC-001" } },
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.are.equal("Alpha", cargoProxy.group)
      assert.are.equal("Infantry-1", cargoProxy.name)
    end)

    -- Negative: should not set group when source has no group
    it("should not set group when source has no group", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.is_nil(cargoProxy.group)
      assert.are.equal("Infantry-1", cargoProxy.name)
    end)

    -- Positive: should log results
    it("should log results", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeUnit({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })
      local unitCtx = { name = "Infantry-1" }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end))

      AmphibiousLogistics.loadCargo(base, unitCtx, "Red")

      assert.stub(logStub).was.called(1)
      local callArgs = logStub.calls[1].vals
      assert.are.equal("amphibiousLogistics", callArgs[1])
      assert.truthy(string.find(callArgs[2], "%[ship=BaseShip%] Load cargo"))
      assert.truthy(string.find(callArgs[2], "total=1 ok=1 skip=0 fail=0 error=0"))
      assert.truthy(string.find(callArgs[2], "%[OK%]"))
    end)
  end)
end)
