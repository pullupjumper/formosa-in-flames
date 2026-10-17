---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- ShipMovement Unit Tests
local ShipMovement = require("src.modules.landingOps.shipMovement")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("ShipMovement", function()
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

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "SHIP-001",
      name = "TestShip",
      dbid = constants.PLATFORMS.TYPE_075,
      course = {},
      manualSpeed = 0,
      inArea = function() return false end,
      group = nil,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create a location coordinate
  ---@param overrides? table
  ---@return table
  local function makeLocation(overrides)
    local loc = { latitude = 25.0, longitude = 121.0 }
    if overrides then
      for k, v in pairs(overrides) do loc[k] = v end
    end
    return loc
  end

  ---Create a ship calculation result entry
  ---@param overrides? table
  ---@return table
  local function makeShipCalcResult(overrides)
    local r = {
      locations = { makeLocation(), makeLocation({ latitude = 25.1 }) },
      locationIndex = 1,
      dbid = constants.PLATFORMS.TYPE_075,
    }
    if overrides then
      for k, v in pairs(overrides) do r[k] = v end
    end
    return r
  end

  ---Create a full result table for all ship types
  ---@param overrides? table
  ---@return table
  local function makeResultTable(overrides)
    local result = {
      type075 = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_075 }),
      type076 = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_076 }),
      type072iii = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_072III }),
      type072a = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_072A }),
      type073a = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_073A }),
      type071 = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_071 }),
      ferry = makeShipCalcResult({ dbid = constants.PLATFORMS.FERRY }),
      roro = makeShipCalcResult({ dbid = constants.PLATFORMS.FERRY }),
      barge = makeShipCalcResult({ dbid = constants.PLATFORMS.BARGE }),
      type082 = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_082 }),
    }
    if overrides then
      for k, v in pairs(overrides) do result[k] = v end
    end
    return result
  end

  ---Create formation settings
  ---@param overrides? table
  ---@return table
  local function makeFormationSettings(overrides)
    local settings = {
      shipSpeed = 12,
      horizontalDistance = 0.5,
      verticalDistance = 1.0,
      deployLineSetback = 2.0,
      transitDistance = 5.0,
      rowBearingOffset = 90,
    }
    if overrides then
      for k, v in pairs(overrides) do settings[k] = v end
    end
    return settings
  end

  ---Create a SAG descriptor
  ---@param overrides? table
  ---@return table
  local function makeSAGDescriptor(overrides)
    local desc = {
      groupName = "SAG Alpha",
      to = {
        holdingArea = {
          { latitude = 24.0, longitude = 120.0 },
          { latitude = 24.1, longitude = 120.1 },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do desc[k] = v end
    end
    return desc
  end

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function makeZone(overrides)
    local zone = {
      name = "Taoyuan",
      heading = 180,
      sags = {},
      fleet = {
        stagingArea = { "RP-STAGING-1", "RP-STAGING-2" },
        groups = {
          {
            from = { heading = 220, startingPoint = { "RP-FROM-075" } },
            to = {
              startingPoint = { "RP-075-1" },
            },
            shipCounts = {
              type075 = 2,
              type071 = 2,
              type076 = 1,
              type072iii = 2,
              type072a = 2,
              type073a = 1,
              ferry = 1,
              roro = 1,
              barge = 1,
              type082 = 1,
            },
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do zone[k] = v end
    end
    return zone
  end

  ---Create an amphibOpsConfig; `sags` overrides land in the zone
  ---@param overrides? table
  ---@return table
  local function makeAmphibOpsConfig(overrides)
    local cfg = {
      formationSettings = makeFormationSettings(),
      zones = { makeZone() },
    }
    if overrides then
      for k, v in pairs(overrides) do
        if k == "sags" then cfg.zones[1].sags = v else cfg[k] = v end
      end
    end
    return cfg
  end

  ---Create a calculationResult map indexed by zone name
  ---@param result? table Taoyuan ship calculation table (defaults to makeResultTable())
  ---@return table
  local function makeCalculationResult(result)
    return {
      Taoyuan = {
        name = "Taoyuan",
        result = result or makeResultTable(),
      },
    }
  end

  -- ============================================================================
  -- moveToHoldingAreas
  -- ============================================================================

  describe("moveToHoldingAreas", function()
    -- Positive: standard ship type movement
    it("should move a Type 075 ship to the first calculated location", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.type075.locations[1]
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_true(result)
      assert.are.equal(targetLocation, unit.course[1])
      assert.are.equal(12, unit.manualSpeed)
      assert.stub(logStub).was.called(1)
    end)

    -- Positive: Type 071 normal movement within LPD area
    it("should move a Type 071 ship to LPD area location when index is within range", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.type071.locations[1]
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_071,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(targetLocation, unit.course[1])
    end)

    -- Negative: no overflow row; a Type 071 beyond the configured count is skipped in place
    it("should skip a Type 071 ship when its row locations are exhausted", function()
      local resultTable = makeResultTable({
        type071 = makeShipCalcResult({
          dbid = constants.PLATFORMS.TYPE_071,
          locations = { makeLocation() },
          locationIndex = 2,
        }),
      })
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_071,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.same({}, unit.course)
    end)

    -- Positive: name-based matching for Ferry
    it("should move a Ferry ship matched by name", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.ferry.locations[1]
      local unit = makeUnit({
        name = "Ferry",
        dbid = 99999,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(targetLocation, unit.course[1])
    end)

    -- Positive: name-based matching for RORO
    it("should move a RORO ship matched by name", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.roro.locations[1]
      local unit = makeUnit({
        name = "RORO",
        dbid = 99999,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(targetLocation, unit.course[1])
    end)

    -- Positive: name-based matching for Barge
    it("should move a Barge ship matched by name", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.barge.locations[1]
      local unit = makeUnit({
        name = "Barge",
        dbid = 99999,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(targetLocation, unit.course[1])
    end)

    -- Positive: location index increments after each movement
    it("should increment locationIndex after moving a ship", function()
      local resultTable = makeResultTable()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" }, { guid = "SHIP-002" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(3, resultTable.type075.locationIndex)
    end)

    -- Positive: testing mode teleports ship via ScenEdit_SetUnit
    it("should teleport ship via SetUnit when debug is enabled", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.type075.locations[1]
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig({ debug = { enabled = true } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.stub(stubSetUnit).was.called(1)
      assert.stub(stubSetUnit).was.called_with({
        guid = "SHIP-001",
        latitude = targetLocation.latitude,
        longitude = targetLocation.longitude,
      })
      assert.are.equal(0, unit.manualSpeed)
    end)

    -- Positive: SAG groups are handled
    it("should issue course to SAG group ships", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = {} },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sags = { sagDesc } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.same(sagDesc.to.holdingArea, sagUnit.course)
    end)

    -- Positive: SAG testing mode positions Type 052D ships in formation
    it("should position Type 052D destroyer at holding point in testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local destroyer = makeUnit({
        guid = "DDG-001",
        dbid = constants.PLATFORMS.TYPE_052D,
      })
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "DDG-001" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "DDG-001" then return destroyer end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.stub(stubSetUnit).was.called(1)
      local callArgs = stubSetUnit.calls[1].vals[1]
      assert.are.equal("DDG-001", callArgs.guid)
      assert.are.equal(sagDesc.to.holdingArea[2].latitude, callArgs.latitude)
      assert.are.equal(sagDesc.to.holdingArea[2].longitude, callArgs.longitude)
      assert.are.equal(180, destroyer.heading)
    end)

    -- Positive: SAG testing mode positions second Type 052D behind first
    it("should position second Type 052D behind the first one in testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local ddg1 = makeUnit({ guid = "DDG-001", dbid = constants.PLATFORMS.TYPE_052D })
      local ddg2 = makeUnit({ guid = "DDG-002", dbid = constants.PLATFORMS.TYPE_052D })
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "DDG-001", "DDG-002" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()
      local behindPoint = makeLocation({ latitude = 24.5, longitude = 120.5 })
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing").returns(behindPoint))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "DDG-001" then return ddg1 end
        if id == "DDG-002" then return ddg2 end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.stub(stubSetUnit).was.called(2)
      local secondCall = stubSetUnit.calls[2].vals[1]
      assert.are.equal("DDG-002", secondCall.guid)
      assert.are.equal(behindPoint.latitude, secondCall.latitude)
      assert.are.equal(behindPoint.longitude, secondCall.longitude)
    end)

    -- Positive: SAG testing mode positions Type 054A frigates at flanks
    it("should position Type 054A frigates at flanking angles in testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local frigate1 = makeUnit({ guid = "FFG-001", dbid = constants.PLATFORMS.TYPE_054A })
      local frigate2 = makeUnit({ guid = "FFG-002", dbid = constants.PLATFORMS.TYPE_054A })
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "FFG-001", "FFG-002" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()
      local flankPoint = makeLocation({ latitude = 24.3, longitude = 120.3 })
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing").returns(flankPoint))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "FFG-001" then return frigate1 end
        if id == "FFG-002" then return frigate2 end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.stub(stubSetUnit).was.called(2)
      assert.stub(stubGetPoint).was.called(2)

      local firstBearingCall = stubGetPoint.calls[1].vals[1]
      local secondBearingCall = stubGetPoint.calls[2].vals[1]
      assert.are.equal(180 - (-45), firstBearingCall.bearing)
      assert.are.equal(180 - 45, secondBearingCall.bearing)
    end)

    -- Negative: unit not found by GetUnit returns nil
    it("should skip units that cannot be retrieved", function()
      local filteredUnits = { { guid = "MISSING-001" } }
      local calculationResult = makeCalculationResult()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_true(result)
    end)

    -- Negative: unit not in staging area
    it("should skip units not in any staging area", function()
      local resultTable = makeResultTable()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return false end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.equal(1, resultTable.type075.locationIndex)
    end)

    -- Negative: SAG group unit not found
    it("should fail and log SAG group when group unit is not found", function()
      local sagDesc = makeSAGDescriptor()
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local config = makeAmphibOpsConfig({ sags = { sagDesc } })
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=sag_group_not_found"))
    end)

    -- Negative: missing calculation result should fail before issuing movement orders
    it("should fail and log when operation calculation result is missing", function()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = {}

      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_false(result)
      assert.stub(stubGetUnit).was_not.called()
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=calculation_result_missing"))
    end)

    -- Boundary: absent calculationResult map must fail the same way as a missing zone entry
    it("should fail and log when calculationResult is nil", function()
      local filteredUnits = { { guid = "SHIP-001" } }

      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, nil, filteredUnits, config)

      assert.is_false(result)
      assert.stub(stubGetUnit).was_not.called()
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=calculation_result_missing"))
    end)

    -- Negative: malformed ship calculation entry should fail without crashing
    it("should fail and log when a ship calculation entry is missing", function()
      local resultTable = makeResultTable()
      resultTable.type075 = nil
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=calculation_entry_missing"))
    end)

    -- Negative: SAG testing mode requires a group unit list
    it("should fail and log when SAG unitlist is missing in testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = nil,
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=sag_unitlist_missing"))
    end)

    -- Negative: SAG holding area is required
    it("should fail and log when SAG holding area is missing", function()
      local sagDesc = makeSAGDescriptor({ to = {} })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local config = makeAmphibOpsConfig({ sags = { sagDesc } })
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_false(result)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=holding_area_missing"))
    end)

    -- Negative: SAG individual ship not found in testing mode
    it("should skip missing ships in SAG unitlist during testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "MISSING-DDG" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_true(result)
      assert.stub(stubSetUnit).was_not.called()
      assert.truthy(string.find(logStub.calls[1].vals[2], "skipped=1"))
    end)

    -- Negative: SAG getNextPosition returns nil
    it("should skip positioning when getNextPosition returns nil for SAG ships", function()
      local sagDesc = makeSAGDescriptor()
      local frigate = makeUnit({ guid = "FFG-001", dbid = constants.PLATFORMS.TYPE_054A })
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "FFG-001" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "World_GetPointFromBearing").returns(nil))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "FFG-001" then return frigate end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sags = { sagDesc }, debug = { enabled = true } })
      local zone = config.zones[1]
      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.is_true(result)
      assert.stub(stubSetUnit).was_not.called()
      assert.truthy(string.find(logStub.calls[1].vals[2], "skipped=1"))
    end)

    -- Boundary: debug disabled should not call ScenEdit_SetUnit for normal ships
    it("should not teleport ship when debug is disabled", function()
      local resultTable = makeResultTable()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local calculationResult = makeCalculationResult(resultTable)

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Boundary: empty filteredUnits
    it("should return true when filteredUnits is empty", function()
      local calculationResult = makeCalculationResult()
      local config = makeAmphibOpsConfig()
      local zone = config.zones[1]
      trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local result = ShipMovement.moveToHoldingAreas(zone, calculationResult, {}, config)

      assert.is_true(result)
    end)

    -- Boundary: SAG not in testing mode should not call ScenEdit_SetUnit
    it("should only set course for SAG and not position ships when not testing", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "DDG-001" } },
      })
      local filteredUnits = {}
      local calculationResult = makeCalculationResult()

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sags = { sagDesc } })
      local zone = config.zones[1]
      ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, config)

      assert.are.same(sagDesc.to.holdingArea, sagUnit.course)
      assert.stub(stubSetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- planHoldingPositions
  -- ============================================================================

  describe("planHoldingPositions", function()
    local stubGetRPs, stubGetPoint, stubInsertList, stubGenerateLocations

    before_each(function()
      stubGetRPs = trackStub(stub(GameApi, "ScenEdit_GetReferencePoints"))
      stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
      stubGenerateLocations = trackStub(stub(GameUtils, "buildLocations"))
      stubInsertList = trackStub(stub(Utils, "addAll"))
    end)

    -- Positive: initializes calculation result structure
    it("should create the operation entry in calculationResult when it does not exist", function()
      local rp075 = makeLocation({ latitude = 25.0 })
      local derivedPoint = makeLocation({ latitude = 26.0 })

      stubGetRPs.invokes(function(rpName)
        if rpName == "RP-075-1" then return { rp075 } end
        return { makeLocation() }
      end)
      stubGetPoint.returns(derivedPoint)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.is_not_nil(calculationResult.Taoyuan)
      assert.are.equal("Taoyuan", calculationResult.Taoyuan.name)
      assert.is_not_nil(calculationResult.Taoyuan.result.type075)
      assert.is_not_nil(calculationResult.Taoyuan.result.type071)
      assert.is_not_nil(calculationResult.Taoyuan.result.type076)
      assert.is_not_nil(calculationResult.Taoyuan.result.type072iii)
      assert.is_not_nil(calculationResult.Taoyuan.result.type072a)
      assert.is_not_nil(calculationResult.Taoyuan.result.type073a)
      assert.is_not_nil(calculationResult.Taoyuan.result.ferry)
      assert.is_not_nil(calculationResult.Taoyuan.result.roro)
      assert.is_not_nil(calculationResult.Taoyuan.result.barge)
    end)

    -- Positive: uses correct DBIDs for each ship type
    it("should assign correct DBIDs for all ship types in the result", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      local result = calculationResult.Taoyuan.result
      assert.are.equal(constants.PLATFORMS.TYPE_075, result.type075.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_071, result.type071.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_076, result.type076.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_072III, result.type072iii.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_072A, result.type072a.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_073A, result.type073a.dbid)
      assert.are.equal(constants.PLATFORMS.FERRY, result.ferry.dbid)
      assert.are.equal(constants.PLATFORMS.FERRY, result.roro.dbid)
      assert.are.equal(constants.PLATFORMS.BARGE, result.barge.dbid)
    end)

    -- Positive: calls buildLocations for each ship type
    it("should call buildLocations for all 10 ship types per area", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.stub(stubGenerateLocations).was.called(10)
    end)

    -- Positive: Type 071 is derived from Type 075, and Type 076 from Type 071, by vertical distance
    it("should derive Type 071 from Type 075 and Type 076 from Type 071 using vertical distance", function()
      local rp075 = makeLocation({ latitude = 25.0 })
      local derivedRp071 = makeLocation({ latitude = 25.5 })

      stubGetRPs.invokes(function(rpTable)
        if rpTable.area and rpTable.area[1] == "RP-075-1" then return { rp075 } end
        return { makeLocation() }
      end)
      stubGetPoint.invokes(function(params)
        if params.latitude == rp075.latitude and params.distance == 1.0 then
          return derivedRp071
        end
        return makeLocation()
      end)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      local found = false
      for _, call in ipairs(stubGetPoint.calls) do
        local p = call.vals[1]
        if p.latitude == derivedRp071.latitude
            and p.longitude == derivedRp071.longitude
            and p.distance == 1.0 then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    -- Positive: derives barge position from Type 075 using deployLineSetback
    it("should derive barge position from Type 075 using deployLineSetback", function()
      local rp075 = makeLocation({ latitude = 25.0 })

      stubGetRPs.invokes(function(rpTable)
        if rpTable.area and rpTable.area[1] == "RP-075-1" then return { rp075 } end
        return { makeLocation() }
      end)
      stubGetPoint.returns(makeLocation())
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      local found = false
      for _, call in ipairs(stubGetPoint.calls) do
        local p = call.vals[1]
        if p.latitude == rp075.latitude
            and p.longitude == rp075.longitude
            and p.distance == 2.0 then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    -- Positive: does not overwrite existing calculation result
    it("should not overwrite existing operation entry in calculationResult", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local existingResult = makeResultTable()
      local calculationResult = {
        Taoyuan = { name = "Taoyuan", result = existingResult },
      }
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.are.equal(existingResult, calculationResult.Taoyuan.result)
    end)

    -- Positive: handles multiple operations
    it("should process multiple operations independently", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local config = makeAmphibOpsConfig({})
      config.zones = { makeZone(), makeZone({ name = "Penghu" }) }
      local calculationResult = {}

      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.is_not_nil(calculationResult.Taoyuan)
      assert.is_not_nil(calculationResult.Penghu)
    end)

    -- Positive: passes horizontal distance and bearing to buildLocations
    it("should pass correct horizontal distance and bearing to buildLocations", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      for _, call in ipairs(stubGenerateLocations.calls) do
        local params = call.vals[1]
        assert.are.equal(0.5, params.distance)
        assert.are.equal(90, params.bearing)
      end
    end)

    -- Negative: missing starting reference point should fail and log
    it("should fail and log when a starting reference point is missing", function()
      stubGetRPs.invokes(function(rpTable)
        if rpTable.area and rpTable.area[1] == "RP-075-1" then return {} end
        return { makeLocation() }
      end)
      stubGetPoint.returns(makeLocation())
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      local result = ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.is_false(result)
      assert.stub(stubGenerateLocations).was_not.called()
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=reference_point_missing"))
    end)

    -- Negative: derived starting point calculation should fail and log
    it("should fail and log when a derived starting point cannot be calculated", function()
      stubGetRPs.returns({ makeLocation() })
      stubGetPoint.returns(nil)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      local result = ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      assert.is_false(result)
      assert.stub(stubGenerateLocations).was_not.called()
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=derived_point_failed"))
    end)

    -- Boundary: area with zero ships of a type
    it("should still call buildLocations with num=0 for types not present", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local config = makeAmphibOpsConfig()
      config.zones[1].fleet.groups[1].shipCounts.type075 = 0
      local calculationResult = {}

      ShipMovement.planHoldingPositions(config.zones, config.formationSettings, calculationResult)

      local found = false
      for _, call in ipairs(stubGenerateLocations.calls) do
        local params = call.vals[1]
        if params.num == 0 then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)
end)
