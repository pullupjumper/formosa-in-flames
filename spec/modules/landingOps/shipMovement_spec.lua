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
      type071InLSTArea = makeShipCalcResult({ dbid = constants.PLATFORMS.TYPE_071 }),
      ferry = makeShipCalcResult({ dbid = constants.PLATFORMS.FERRY }),
      roro = makeShipCalcResult({ dbid = constants.PLATFORMS.FERRY }),
      barge = makeShipCalcResult({ dbid = constants.PLATFORMS.BARGE }),
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
      distanceBetweenLSTAndLPDArea = 2.0,
      transitDistance = 5.0,
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
        anchorageArea = {
          { latitude = 24.0, longitude = 120.0 },
          { latitude = 24.1, longitude = 120.1 },
        },
        heading = 180,
      },
    }
    if overrides then
      for k, v in pairs(overrides) do desc[k] = v end
    end
    return desc
  end

  ---Create an amphibious operation descriptor
  ---@param overrides? table
  ---@return table
  local function makeOperation(overrides)
    local op = {
      name = "Taoyuan",
      from = { stagingArea = { "RP-STAGING-1", "RP-STAGING-2" } },
      sagNames = { "SAG Alpha" },
      to = {
        areas = {
          {
            startingPoints = {
              type075 = { "RP-075-1" },
              type071 = { "RP-071-1" },
            },
            heading = { horizontal = 90, vertical = 0 },
            shipCounts = {
              type075 = 2,
              type071 = 2,
              type076 = 1,
              type072iii = 2,
              type072a = 2,
              type073a = 1,
              type071InLSTArea = 1,
              ferry = 1,
              roro = 1,
              barge = 1,
            },
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do op[k] = v end
    end
    return op
  end

  ---Create an amphibOpsConfig
  ---@param overrides? table
  ---@return table
  local function makeAmphibOpsConfig(overrides)
    local cfg = {
      formationSettings = makeFormationSettings(),
      operations = { makeOperation() },
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
          isTesting = false,
          calculationResult = {
            Taoyuan = {
              name = "Taoyuan",
              result = makeResultTable(),
            },
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do sd[k] = v end
    end
    return sd
  end

  -- ============================================================================
  -- moveToStagingArea
  -- ============================================================================

  describe("moveToStagingArea", function()
    -- Positive: standard ship type movement
    it("should move a Type 075 ship to the first calculated location", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.type075.locations[1]
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.equal(targetLocation, unit.course[1])
    end)

    -- Positive: Type 071 overflow to LST area
    it("should move a Type 071 ship to LST area when LPD area locations are exhausted", function()
      local lstLocation = makeLocation({ latitude = 26.0 })
      local resultTable = makeResultTable({
        type071 = makeShipCalcResult({
          dbid = constants.PLATFORMS.TYPE_071,
          locations = { makeLocation() },
          locationIndex = 2,
        }),
        type071InLSTArea = makeShipCalcResult({
          dbid = constants.PLATFORMS.TYPE_071,
          locations = { lstLocation },
        }),
      })
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_071,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.equal(lstLocation, unit.course[1])
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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.equal(3, resultTable.type075.locationIndex)
    end)

    -- Positive: testing mode teleports ship via ScenEdit_SetUnit
    it("should teleport ship via SetUnit when isTesting is true", function()
      local resultTable = makeResultTable()
      local targetLocation = resultTable.type075.locations[1]
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig({ isTesting = true })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.stub(stubSetUnit).was.called(1)
      assert.stub(stubSetUnit).was.called_with({
        guid = "SHIP-001",
        latitude = targetLocation.latitude,
        longitude = targetLocation.longitude,
        manualSpeed = 0,
      })
    end)

    -- Positive: SAG groups are handled
    it("should issue course to SAG group ships", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = {} },
      })
      local filteredUnits = {}
      local saveData = makeSaveData()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc } })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.same(sagDesc.to.anchorageArea, sagUnit.course)
    end)

    -- Positive: SAG testing mode positions Type 052D ships in formation
    it("should position Type 052D destroyer at anchorage in testing mode", function()
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
      local saveData = makeSaveData()
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "DDG-001" then return destroyer end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.stub(stubSetUnit).was.called(1)
      local callArgs = stubSetUnit.calls[1].vals[1]
      assert.are.equal("DDG-001", callArgs.guid)
      assert.are.equal(sagDesc.to.anchorageArea[2].latitude, callArgs.latitude)
      assert.are.equal(sagDesc.to.anchorageArea[2].longitude, callArgs.longitude)
      assert.are.equal(180, callArgs.heading)
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
      local saveData = makeSaveData()
      local behindPoint = makeLocation({ latitude = 24.5, longitude = 120.5 })
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing").returns(behindPoint))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "DDG-001" then return ddg1 end
        if id == "DDG-002" then return ddg2 end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      local flankPoint = makeLocation({ latitude = 24.3, longitude = 120.3 })
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing").returns(flankPoint))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "FFG-001" then return frigate1 end
        if id == "FFG-002" then return frigate2 end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.equal(1, resultTable.type075.locationIndex)
    end)

    -- Negative: SAG group unit not found
    it("should fail and log SAG group when group unit is not found", function()
      local sagDesc = makeSAGDescriptor()
      local filteredUnits = {}
      local saveData = makeSaveData()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc } })
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.is_false(result)
      assert.stub(logStub).was.called(1)
      assert.truthy(string.find(logStub.calls[1].vals[2], "reason=sag_group_not_found"))
    end)

    -- Negative: missing calculation result should fail before issuing movement orders
    it("should fail and log when operation calculation result is missing", function()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult = {}

      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.is_false(result)
      assert.stub(logStub).was.called(1)
      assert.truthy(string.find(logStub.calls[1].vals[2], "reason=calculation_entry_missing"))
    end)

    -- Negative: SAG testing mode requires a group unit list
    it("should fail and log when SAG unitlist is missing in testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = nil,
      })
      local filteredUnits = {}
      local saveData = makeSaveData()

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.is_false(result)
      assert.stub(logStub).was.called(1)
      assert.truthy(string.find(logStub.calls[1].vals[2], "reason=sag_unitlist_missing"))
    end)

    -- Negative: SAG anchorage area is required
    it("should fail and log when SAG anchorage area is missing", function()
      local sagDesc = makeSAGDescriptor({ to = { heading = 180 } })
      local filteredUnits = {}
      local saveData = makeSaveData()

      trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc } })
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.is_false(result)
      assert.stub(logStub).was.called(1)
      assert.truthy(string.find(logStub.calls[1].vals[2], "reason=anchorage_area_missing"))
    end)

    -- Negative: SAG individual ship not found in testing mode
    it("should skip missing ships in SAG unitlist during testing mode", function()
      local sagDesc = makeSAGDescriptor()
      local sagUnit = makeUnit({
        guid = "SAG-001",
        group = { unitlist = { "MISSING-DDG" } },
      })
      local filteredUnits = {}
      local saveData = makeSaveData()

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

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
      local saveData = makeSaveData()

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "World_GetPointFromBearing").returns(nil))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "SAG Alpha" then return sagUnit end
        if id == "FFG-001" then return frigate end
        return nil
      end))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc }, isTesting = true })
      local operation = config.operations[1]
      local result = ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.is_true(result)
      assert.stub(stubSetUnit).was_not.called()
      assert.truthy(string.find(logStub.calls[1].vals[2], "skipped=1"))
    end)

    -- Boundary: isTesting false should not call ScenEdit_SetUnit for normal ships
    it("should not teleport ship when isTesting is false", function()
      local resultTable = makeResultTable()
      local unit = makeUnit({
        dbid = constants.PLATFORMS.TYPE_075,
        inArea = function() return true end,
      })
      local filteredUnits = { { guid = "SHIP-001" } }
      local saveData = makeSaveData()
      saveData.c.amphibOps.isTesting = false
      saveData.c.amphibOps.calculationResult.Taoyuan.result = resultTable

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))

      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Boundary: empty filteredUnits
    it("should return true when filteredUnits is empty", function()
      local saveData = makeSaveData()
      local config = makeAmphibOpsConfig()
      local operation = config.operations[1]
      trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      local result = ShipMovement.moveToStagingArea(config, saveData, {}, operation)

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
      local saveData = makeSaveData()
      saveData.c.amphibOps.isTesting = false

      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sagUnit))

      local config = makeAmphibOpsConfig({ sag = { ["SAG Alpha"] = sagDesc } })
      local operation = config.operations[1]
      ShipMovement.moveToStagingArea(config, saveData, filteredUnits, operation)

      assert.are.same(sagDesc.to.anchorageArea, sagUnit.course)
      assert.stub(stubSetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- calculateDestination
  -- ============================================================================

  describe("calculateDestination", function()
    local stubGetRPs, stubGetPoint, stubInsertList, stubGenerateLocations

    before_each(function()
      stubGetRPs = trackStub(stub(GameApi, "ScenEdit_GetReferencePoints"))
      stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
      stubGenerateLocations = trackStub(stub(GameUtils, "generateLocations"))
      stubInsertList = trackStub(stub(Utils, "insertList"))
    end)

    -- Positive: initializes calculation result structure
    it("should create the operation entry in calculationResult when it does not exist", function()
      local rp075 = makeLocation({ latitude = 25.0 })
      local rp071 = makeLocation({ latitude = 25.5 })
      local derivedPoint = makeLocation({ latitude = 26.0 })

      stubGetRPs.invokes(function(rpName)
        if rpName == "RP-075-1" then return { rp075 } end
        if rpName == "RP-071-1" then return { rp071 } end
        return { makeLocation() }
      end)
      stubGetPoint.returns(derivedPoint)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.calculateDestination(config, calculationResult)

      assert.is_not_nil(calculationResult.Taoyuan)
      assert.are.equal("Taoyuan", calculationResult.Taoyuan.name)
      assert.is_not_nil(calculationResult.Taoyuan.result.type075)
      assert.is_not_nil(calculationResult.Taoyuan.result.type071)
      assert.is_not_nil(calculationResult.Taoyuan.result.type076)
      assert.is_not_nil(calculationResult.Taoyuan.result.type072iii)
      assert.is_not_nil(calculationResult.Taoyuan.result.type072a)
      assert.is_not_nil(calculationResult.Taoyuan.result.type073a)
      assert.is_not_nil(calculationResult.Taoyuan.result.type071InLSTArea)
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
      ShipMovement.calculateDestination(config, calculationResult)

      local result = calculationResult.Taoyuan.result
      assert.are.equal(constants.PLATFORMS.TYPE_075, result.type075.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_071, result.type071.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_076, result.type076.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_072III, result.type072iii.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_072A, result.type072a.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_073A, result.type073a.dbid)
      assert.are.equal(constants.PLATFORMS.TYPE_071, result.type071InLSTArea.dbid)
      assert.are.equal(constants.PLATFORMS.FERRY, result.ferry.dbid)
      assert.are.equal(constants.PLATFORMS.FERRY, result.roro.dbid)
      assert.are.equal(constants.PLATFORMS.BARGE, result.barge.dbid)
    end)

    -- Positive: calls generateLocations for each ship type
    it("should call generateLocations for all 10 ship types per area", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.calculateDestination(config, calculationResult)

      assert.stub(stubGenerateLocations).was.called(10)
    end)

    -- Positive: derives ship positions from reference points using vertical distance
    it("should derive Type 076 starting position from Type 071 using vertical distance", function()
      local rp075 = makeLocation({ latitude = 25.0 })
      local rp071 = makeLocation({ latitude = 25.5 })
      local derivedRp076 = makeLocation({ latitude = 26.0 })

      stubGetRPs.invokes(function(rpTable)
        if rpTable.area and rpTable.area[1] == "RP-075-1" then return { rp075 } end
        if rpTable.area and rpTable.area[1] == "RP-071-1" then return { rp071 } end
        return { makeLocation() }
      end)
      stubGetPoint.invokes(function(params)
        if params.latitude == rp071.latitude and params.distance == 1.0 then
          return derivedRp076
        end
        return makeLocation()
      end)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.calculateDestination(config, calculationResult)

      -- Verify that World_GetPointFromBearing was called with rp071 coords and verticalDistance
      local found = false
      for _, call in ipairs(stubGetPoint.calls) do
        local p = call.vals[1]
        if p.latitude == rp071.latitude
            and p.longitude == rp071.longitude
            and p.distance == 1.0 then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    -- Positive: derives barge position from Type 075 using distanceBetweenLSTAndLPDArea
    it("should derive barge position from Type 075 using distanceBetweenLSTAndLPDArea", function()
      local rp075 = makeLocation({ latitude = 25.0 })
      local rp071 = makeLocation({ latitude = 25.5 })

      stubGetRPs.invokes(function(rpTable)
        if rpTable.area and rpTable.area[1] == "RP-075-1" then return { rp075 } end
        if rpTable.area and rpTable.area[1] == "RP-071-1" then return { rp071 } end
        return { makeLocation() }
      end)
      stubGetPoint.returns(makeLocation())
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.calculateDestination(config, calculationResult)

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
      ShipMovement.calculateDestination(config, calculationResult)

      assert.are.equal(existingResult, calculationResult.Taoyuan.result)
    end)

    -- Positive: handles multiple operations
    it("should process multiple operations independently", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local op1 = makeOperation()
      local op2 = makeOperation({ name = "Penghu" })
      local config = makeAmphibOpsConfig({ operations = { op1, op2 } })
      local calculationResult = {}

      ShipMovement.calculateDestination(config, calculationResult)

      assert.is_not_nil(calculationResult.Taoyuan)
      assert.is_not_nil(calculationResult.Penghu)
    end)

    -- Positive: passes horizontal distance and bearing to generateLocations
    it("should pass correct horizontal distance and bearing to generateLocations", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local calculationResult = {}
      local config = makeAmphibOpsConfig()
      ShipMovement.calculateDestination(config, calculationResult)

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
      local result = ShipMovement.calculateDestination(config, calculationResult)

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
      local result = ShipMovement.calculateDestination(config, calculationResult)

      assert.is_false(result)
      assert.stub(stubGenerateLocations).was_not.called()
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=derived_point_failed"))
    end)

    -- Boundary: area with zero ships of a type
    it("should still call generateLocations with num=0 for types not present", function()
      local rp = makeLocation()
      stubGetRPs.returns({ rp })
      stubGetPoint.returns(rp)
      stubGenerateLocations.returns({})
      stubInsertList.invokes(function(list) return list end)

      local op = makeOperation()
      op.to.areas[1].shipCounts.type075 = 0
      local config = makeAmphibOpsConfig({ operations = { op } })
      local calculationResult = {}

      ShipMovement.calculateDestination(config, calculationResult)

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
