-- AtoBuilder Unit Tests
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local BaseConfig = require("src.core.config")

-- Note: package timing math (flight time, lead times, durations, tanker coordination)
-- is covered by packageTiming_spec. These tests focus on AtoBuilder's own
-- responsibilities: target gating, aircraft validation, wave assembly, orchestration,
-- and logging. Timing is only asserted to be applied end-to-end, not recomputed here.
--
-- Observation window: stubClock pins the current time and the parsed batch time to the
-- same timestamp, which puts every operation inside its window. Tests that need
-- pre-trigger or expired states stub the two values apart.

describe("AtoBuilder", function()
  -- The two reports AtoBuilder emits, told apart by scope rather than tag
  local OPERATIONS_LOG_SCOPE = "dynamicAirOperations"
  local TIMING_LOG_SCOPE = "dynamicAirTiming"

  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  ---@type luassert.spy
  local warnStub

  ---Register a stub or spy so after_each reverts it
  ---@param testDouble luassert.spy Stub or spy to track
  ---@return luassert.spy # The same double, so calls can be chained inline
  local function trackStub(testDouble)
    table.insert(activeStubs, testDouble)
    return testDouble
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
    warnStub = trackStub(stub(Logger, "warn"))
  end)

  after_each(function()
    for _, testDouble in ipairs(activeStubs) do
      testDouble:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a recon-triggered operation batch entry
  ---@param overrides? table
  ---@return table
  local function makeReconEntry(overrides)
    local entry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a striker deployment descriptor
  ---@param overrides? table
  ---@return table
  local function makeStriker(overrides)
    local striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 }
    if overrides then
      for k, v in pairs(overrides) do striker[k] = v end
    end
    return striker
  end

  ---Create a fixed HSINCHU/Radar target configuration
  ---@param overrides? table
  ---@return table
  local function makeTarget(overrides)
    local target = {
      objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
      contactAge = 300,
      minTargetCount = 1
    }
    if overrides then
      for k, v in pairs(overrides) do target[k] = v end
    end
    return target
  end

  ---Create a strike package template
  ---@param overrides? table
  ---@return table
  local function makeStrikePackage(overrides)
    local packageTemplate = {
      timeToReady = 5,
      striker = makeStriker(),
      target = makeTarget()
    }
    if overrides then
      for k, v in pairs(overrides) do packageTemplate[k] = v end
    end
    return packageTemplate
  end

  ---Create an air operation carrying a wave template
  ---@param overrides? table Wave template fields
  ---@return table
  local function makeAirOperation(overrides)
    local waveTemplate = {
      name = "STRIKE/1",
      isFirstWave = true,
      strikeInterval = 0,
      packages = { makeStrikePackage() }
    }
    if overrides then
      for k, v in pairs(overrides) do waveTemplate[k] = v end
    end
    return { type = "air", executed = false, template = waveTemplate }
  end

  ---Create an air operation with no wave template, which can never be executed
  ---@return table
  local function makeTemplatelessAirOperation()
    return { type = "air", executed = false }
  end

  ---Create the full saveData structure AtoBuilder reads
  ---@param operationBatches table[] Recon-triggered operation batches
  ---@param overrides? table Optional airTaskingOrder, targetlist or generatedOperations
  ---@return table
  local function makeSaveData(operationBatches, overrides)
    overrides = overrides or {}
    return {
      c = {
        air = { airTaskingOrder = overrides.airTaskingOrder or {} },
        targetlist = overrides.targetlist or {},
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperationBatches = operationBatches,
          generatedOperations = overrides.generatedOperations or { air = {}, ground = {} }
        }
      }
    }
  end

  ---Create full typed config for AtoBuilder tests
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  -- ============================================================================
  -- Shared stub helpers
  -- ============================================================================

  ---Stub current time and datetime parsing to the same fixed timestamp
  ---@param timestamp? integer Defaults to 1000
  local function stubClock(timestamp)
    timestamp = timestamp or 1000
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(timestamp))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(timestamp))
  end

  ---Stub filterOperationsByType to yield a single recon-triggered operation
  ---The batch also gets a real operations array so abandonment can be asserted.
  ---@param reconEntry table Batch owning the operation; mutated in place
  ---@param operation table The single air operation the batch yields
  local function stubSingleOperation(reconEntry, operation)
    reconEntry.operations = { operation }
    trackStub(stub(DynamicState, "filterOperationsByType").returns({
      { operationBatch = reconEntry, operation = operation }
    }))
  end

  ---Stub target evaluation to return a fixed target list
  ---@param targets? string[] Defaults to a single "TGT-1"
  local function stubTargets(targets)
    trackStub(stub(TargetingProcess, "processTargets").returns(targets or { "TGT-1" }))
  end

  ---Stub aircraft availability for every base and aircraft read in one pass
  ---@param bases? table<string, string[]> Embarked aircraft GUIDs keyed by base GUID
  ---@param aircraftResolver? fun(guid: string): table|nil Resolves a single aircraft; defaults to dbid 100, unassigned
  ---@return luassert.spy # The ScenEdit_GetUnit stub, for counting base reads
  local function stubBases(bases, aircraftResolver)
    return trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if bases and bases[guid] then
        return { guid = guid, embarkedUnits = { Aircraft = bases[guid] } }
      end
      if aircraftResolver then
        return aircraftResolver(guid)
      end
      return { dbid = 100, mission = nil }
    end))
  end

  ---Stub the DynamicState registration/marking calls for a successful insertion
  ---@param waveName string Generated wave name
  ---@return luassert.spy # The markOperationExecuted stub, for call assertions
  local function stubDynamicStateSuccess(waveName)
    trackStub(stub(DynamicState, "generateUniqueAirOperationName").returns(waveName))
    trackStub(stub(DynamicState, "registerGeneratedOperation"))
    return trackStub(stub(DynamicState, "markOperationExecuted"))
  end

  ---Count how many times a base unit was read through the given ScenEdit_GetUnit stub
  ---@param getUnitStub luassert.spy The stub returned by stubBases
  ---@param baseGUID string GUID of the base to count reads for
  ---@return integer # Number of reads of that base
  local function countBaseReads(getUnitStub, baseGUID)
    local reads = 0
    for _, call in ipairs(getUnitStub.calls) do
      if call.vals[1] == baseGUID then
        reads = reads + 1
      end
    end
    return reads
  end

  ---Find a Logger.log call for the given report scope containing the text
  ---Both reports share one tag, so the scope is what tells them apart.
  ---@param logScope string Report scope, OPERATIONS_LOG_SCOPE or TIMING_LOG_SCOPE
  ---@param text string Plain substring to search for in the message
  ---@return boolean # Whether a matching call was found
  local function hasLogCall(logScope, text)
    for _, call in ipairs(logStub.calls) do
      local message = call.vals[2]
      if message and string.find(message, logScope, 1, true) and string.find(message, text, 1, true) then
        return true
      end
    end
    return false
  end

  ---Find a Logger.error call containing the text
  ---@param text string Plain substring to search for in the message
  ---@return boolean # Whether a matching call was found
  local function hasErrorCall(text)
    for _, call in ipairs(errorStub.calls) do
      if call.vals[1] and string.find(call.vals[1], text, 1, true) then
        return true
      end
    end
    return false
  end

  -- ============================================================================
  -- Positive: Configuration and Basic Flow
  -- ============================================================================

  -- Positive: successful ATO wave insertion with fixed targets
  it("should create and insert ATO wave for fixed target package", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AB/1",
      strikeInterval = 120,
      packages = { makeStrikePackage({ timeToReady = 10, striker = makeStriker({ unitCount = 2 }) }) }
    })

    local saveData = makeSaveData({ reconEntry }, {
      targetlist = {
        { name = "HSINCHU/Radar", subType = "Radar", guid = "TGT-1" }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })
    trackStub(stub(DynamicState, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/AB/1/1"))
    local registerGeneratedOperationStub = trackStub(stub(DynamicState, "registerGeneratedOperation"))
    local markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(registerGeneratedOperationStub).was.called(1)
    assert.are.equal("air", registerGeneratedOperationStub.calls[1].vals[1])
    assert.stub(markOperationExecutedStub).was.called(1)
    -- calls[].vals holds deep copies, so the operation is matched by value
    assert.are.same(operation, markOperationExecutedStub.calls[1].vals[2])
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/AB/1/1"]
    assert.is_table(wave)
    assert.is_true(wave.isActivated)
    assert.is_false(wave.hasLaunched)
    assert.are.equal(1, #wave.packages)
  end)

  -- Positive: wave structure has correct fields and timing is applied end-to-end
  it("should create wave with correct structural fields", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      strikeInterval = 180,
      packages = { makeStrikePackage({ timeToReady = 8 }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    AtoBuilder.execute(makeConfig(), saveData, {})

    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]

    -- Verify wave structure
    assert.are.equal("DYNAMIC/SATELLITE/STRIKE/1/1", wave.name)
    assert.is_true(wave.isActivated)
    assert.is_true(wave.isFirstWave)
    assert.is_false(wave.hasLaunched)
    assert.are.equal(180, wave.strikeInterval)

    -- Verify package structure
    local packageData = wave.packages[1]
    assert.are.equal(8, packageData.timeToReady)
    assert.is_false(packageData.hasLaunched)
    assert.is_table(packageData.loadoutStatus)
    assert.is_false(packageData.loadoutStatus.isLoadoutInitiated)
    assert.is_nil(packageData.loadoutStatus.loadoutInitiatedTime)
    assert.is_nil(packageData.loadoutStatus.expectedReadyTime)
    assert.is_nil(packageData.loadoutStatus.loadoutStartTime)

    -- Timing is applied by PackageTiming (values verified in packageTiming_spec)
    assert.is_string(packageData.striker.startTime)
    assert.is_string(packageData.striker.endTime)
  end)

  -- ============================================================================
  -- Positive: Dynamic Target Filtering
  -- ============================================================================

  -- Positive: dynamic target filtering
  it("should create ATO wave with dynamic target filtering", function()
    local reconEntry = makeReconEntry({ type = "aircraft" })
    local operation = makeAirOperation({
      name = "ANTISHIP/1",
      isFirstWave = false,
      packages = { makeStrikePackage({
        striker = makeStriker({ unitCount = 2 }),
        target = {
          areas = { { "RP-1", "RP-2", "RP-3", "RP-4" } },
          filterNames = { "findNavalTargets" },
          contactAge = 600,
          minTargetCount = 1
        }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(2000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "SHIP-1", "SHIP-2" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3" } })
    stubDynamicStateSuccess("DYNAMIC/AIRCRAFT/ANTISHIP/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.is_table(saveData.c.air.airTaskingOrder["DYNAMIC/AIRCRAFT/ANTISHIP/1/1"])
  end)

  -- ============================================================================
  -- Positive: Partial Validation and Multiple Operations
  -- ============================================================================

  -- Positive: partial validation passes valid packages only
  it("should insert wave with only validated packages when some fail", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      strikeInterval = 300,
      packages = {
        -- Package 1: has targets
        makeStrikePackage({
          striker = makeStriker({ unitCount = 2 }),
          target = makeTarget({ objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } } })
        }),
        -- Package 2: insufficient targets (needs 10)
        makeStrikePackage({
          striker = makeStriker({ baseGUID = "BASE-2", unitCount = 2 }),
          target = makeTarget({ minTargetCount = 10 })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    -- Package 1 (TAOYUAN) gets 3 targets, Package 2 (HSINCHU) gets 1 target (needs 10)
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      if targetConfig and targetConfig.objs and targetConfig.objs[1]
          and targetConfig.objs[1].baseName == "TAOYUAN" then
        return { "TGT-1", "TGT-2", "TGT-3" }
      end
      return { "TGT-4" }
    end))
    stubBases({
      ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" },
      ["BASE-2"] = { "AC-1", "AC-2", "AC-3", "AC-4" }
    })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    assert.is_table(wave)
    -- Only package 1 should be in the wave (package 2 failed target validation)
    assert.are.equal(1, #wave.packages)
  end)

  -- Positive: first executable package can come from a later template index
  it("should calculate timing when earlier package is skipped", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      strikeInterval = 300,
      packages = {
        makeStrikePackage({
          striker = makeStriker({ baseGUID = "BASE-1" }),
          target = makeTarget({ objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } }, minTargetCount = 10 })
        }),
        makeStrikePackage({
          striker = makeStriker({ baseGUID = "BASE-2" }),
          target = makeTarget({ minTargetCount = 1 })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(datetime)
      if type(datetime) ~= "string" then
        error("expected datetime string")
      end
      return 1000
    end))
    stubSingleOperation(reconEntry, operation)
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      if targetConfig and targetConfig.objs and targetConfig.objs[1]
          and targetConfig.objs[1].baseName == "TAOYUAN" then
        return { "TGT-1" }
      end
      return { "TGT-2" }
    end))
    stubBases({ ["BASE-2"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    assert.are.equal(1, #wave.packages)
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
    assert.is_string(wave.packages[1].striker.startTime)
  end)

  -- ============================================================================
  -- Negative: Tanker Mission Validation
  -- ============================================================================

  -- Negative: tanker unit count cannot be divided evenly
  it("should reject non-divisible tanker mission allocation", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/TANKER/INVALID-COUNT",
      packages = {
        {
          striker = makeStriker(),
          tanker = {
            baseGUID = "BASE-2",
            unitCount = 3,
            unitDBID = 102,
            weaponDBID = 0,
            missionCreationParams = {
              { name = "AAR-1", type = "support", opts = {} },
              { name = "AAR-2", type = "support", opts = {} }
            }
          },
          target = { contactAge = 300, minTargetCount = 1 }
        }
      }
    })
    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
    assert.is_nil(saveData.c.air.airTaskingOrder["STRIKE/TANKER/INVALID-COUNT"])
  end)

  -- Negative: tanker mission names must be unique
  it("should reject duplicate tanker mission names", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/TANKER/DUPLICATE-NAME",
      packages = {
        {
          striker = makeStriker(),
          tanker = {
            baseGUID = "BASE-2",
            unitCount = 2,
            unitDBID = 102,
            weaponDBID = 0,
            missionCreationParams = {
              { name = "AAR-DUPLICATE", type = "support", opts = {} },
              { name = "AAR-DUPLICATE", type = "support", opts = {} }
            }
          },
          target = { contactAge = 300, minTargetCount = 1 }
        }
      }
    })
    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- ============================================================================
  -- Positive: Recon Trigger Timing
  -- ============================================================================

  -- Positive: recon entry delay handled
  it("should handle recon entry delay correctly", function()
    local reconEntry = makeReconEntry({ delay = 500 })
    local operation = makeAirOperation()

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2000))
    -- parseDatetimeToTimestamp returns 1000, plus delay 500 = window opens at 1500
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    local markOperationExecutedStub = stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(markOperationExecutedStub).was.called(1)
  end)

  -- ============================================================================
  -- Negative: Configuration Guards
  -- ============================================================================

  -- Negative: dynamicOperations disabled
  it("should return false when dynamicOperations is disabled", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = false }
      }
    }
    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))
  end)

  -- Negative: reconTriggeredOperationBatches empty
  it("should return false when reconTriggeredOperationBatches is empty", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = true, reconTriggeredOperationBatches = {} }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))
  end)

  -- Negative: no air operations pending
  it("should return false when no air operations are pending", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperationBatches = { { time = "2026-02-14 00:00:00", operations = {} } }
        }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    local filterOperationsByTypeStub = trackStub(stub(DynamicState, "filterOperationsByType").returns({}))

    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))
    assert.stub(filterOperationsByTypeStub).was.called(1)
    assert.are.equal("air", filterOperationsByTypeStub.calls[1].vals[2])
  end)

  -- ============================================================================
  -- Negative: Trigger and Template
  -- ============================================================================

  -- Negative: trigger time not reached
  it("should return false when trigger time has not been reached", function()
    local reconEntry = makeReconEntry({ time = "2026-02-14 12:00:00", delay = 600 })
    local operation = { type = "air", executed = false, template = { name = "STRIKE/1" } }
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperationBatches = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    -- parseDatetimeToTimestamp returns 50, plus delay 600 => window opens at 650 > 100
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
    stubSingleOperation(reconEntry, operation)
    local markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))
    assert.stub(markOperationExecutedStub).was_not.called()
    -- Pre-trigger is a silent skip: the operation stays queued for a later tick
    assert.are.equal(1, #reconEntry.operations)
    assert.stub(logStub).was_not.called()
  end)

  -- ============================================================================
  -- Negative: Target and Aircraft Validation
  -- ============================================================================

  -- Negative: insufficient targets
  it("should skip package with insufficient targets", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AB/1",
      strikeInterval = 120,
      packages = { makeStrikePackage({
        striker = makeStriker({ unitCount = 2 }),
        target = makeTarget({ minTargetCount = 5 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    -- Returns only 1 target but minTargetCount = 5
    stubTargets({ "TGT-1" })
    local generateUniqueAirOperationNameStub = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- No valid packages => no ATO wave inserted
    assert.is_false(result)
    assert.stub(generateUniqueAirOperationNameStub).was_not.called()
  end)

  -- Negative: insufficient aircraft at base
  it("should skip package when base has insufficient aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AB/1",
      isFirstWave = false,
      strikeInterval = 120,
      packages = { makeStrikePackage({
        striker = makeStriker({ unitCount = 4 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base has only 1 aircraft; package requires 4 (below the half-strength threshold of 2)
    stubBases({ ["BASE-1"] = { "AC-1" } })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Target Count
  -- ============================================================================

  -- Boundary: exactly minTargetCount targets
  it("should accept package when target count exactly equals minTargetCount", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ target = makeTarget({ minTargetCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    -- Exactly 3 targets = exactly minTargetCount
    stubTargets({ "TGT-1", "TGT-2", "TGT-3" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.are.equal(1, #saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"].packages)
  end)

  -- Boundary: target count one below minTargetCount
  it("should reject package when target count is one below minTargetCount", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ target = makeTarget({ minTargetCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    -- Only 2 targets, minTargetCount = 3
    stubTargets({ "TGT-1", "TGT-2" })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Aircraft Reservation
  -- ============================================================================

  -- Boundary: aircraft reserved by existing ATO waves are counted
  it("should account for aircraft already reserved by existing ATO waves", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry }, {
      airTaskingOrder = {
        -- Existing wave already holding 3 aircraft of the same type at BASE-1
        ["EXISTING-WAVE"] = {
          isActivated = true,
          hasLaunched = false,
          packages = {
            {
              hasLaunched = false,
              striker = { baseGUID = "BASE-1", unitCount = 3, unitDBID = 100 }
            }
          }
        }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base has 4 free, 3 reserved, needs 4 => 4-3=1 < the half-strength threshold of 2
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- 4 available - 3 assigned = 1, below half-strength threshold (2) => fail
    assert.is_false(result)
  end)

  -- Boundary: launched wave packages not counted
  it("should not count launched wave packages as reserved", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry }, {
      airTaskingOrder = {
        -- Launched wave should NOT be counted
        ["LAUNCHED-WAVE"] = {
          isActivated = true,
          hasLaunched = true,
          packages = {
            { hasLaunched = true, striker = { baseGUID = "BASE-1", unitCount = 10, unitDBID = 100 } }
          }
        },
        -- Active but package already launched should NOT be counted
        ["ACTIVE-WAVE"] = {
          isActivated = true,
          hasLaunched = false,
          packages = {
            { hasLaunched = true, striker = { baseGUID = "BASE-1", unitCount = 10, unitDBID = 100 } }
          }
        }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base has 4 aircraft available
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- Launched waves not counted: 4 available - 0 assigned >= 3 required => pass
    assert.is_true(result)
  end)

  -- Boundary: aircraft on missions not counted as available
  it("should not count aircraft already on missions as available", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base has 3 aircraft: AC-1 free, AC-2 on mission, AC-3 wrong DBID => only 1 available
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3" } }, function(guid)
      if guid == "AC-1" then return { dbid = 100, mission = nil } end
      if guid == "AC-2" then return { dbid = 100, mission = "CAP Mission" } end
      if guid == "AC-3" then return { dbid = 999, mission = nil } end
      return nil
    end)

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- Only 1 available (AC-1), requires 4 => 1 < half-strength threshold (2) => fail
    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Base and Structure
  -- ============================================================================

  -- Boundary: base with no embarked aircraft
  it("should return false when base has no embarked aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 2 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base exists but has no embarked aircraft
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
      guid = "BASE-1",
      name = "Empty Air Base",
      embarkedUnits = nil
    }))

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: base unit not found
  it("should fail aircraft validation when base unit not found", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ striker = makeStriker({ baseGUID = "INVALID-BASE", unitCount = 2 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Base not found
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: empty packages array
  it("should return false when template has empty packages", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({ packages = {} })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- No valid packages (empty) => no wave inserted
    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Edge Cases
  -- ============================================================================

  -- Boundary: fixed targets with no objs
  it("should return no targets when fixed target objs is nil", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      -- No filterNames and no objs
      packages = { { striker = makeStriker(), target = { contactAge = 300, minTargetCount = 1 } } }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- Fixed path with no objs => empty targets => insufficient
    assert.is_false(result)
  end)

  -- Boundary: unknown dynamic filter function
  it("should handle unknown dynamic filter function gracefully", function()
    local reconEntry = makeReconEntry({ type = "aircraft" })
    local operation = makeAirOperation({
      isFirstWave = false,
      packages = { {
        striker = makeStriker(),
        target = {
          areas = { { "RP-1", "RP-2" } },
          filterNames = { "nonExistentFilter" },
          contactAge = 600,
          minTargetCount = 1
        }
      } }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(2000)
    stubSingleOperation(reconEntry, operation)

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    -- Unknown filter => no targets found => package invalid => false
    assert.is_false(result)
    assert.stub(warnStub).was.called(1)
  end)

  -- ============================================================================
  -- Multi-Base Fallback (baseGUIDCandidates)
  -- ============================================================================

  -- Positive: primary base insufficient, fallback candidate satisfies the role
  it("should fallback to baseGUIDCandidates when primary base is insufficient", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/1",
      packages = { makeStrikePackage({
        striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1 has 1 aircraft (below half-strength threshold of 2); BASE-2 has 4 (full strength)
    stubBases({
      ["BASE-1"] = { "AC-1" },
      ["BASE-2"] = { "AC-3", "AC-4", "AC-5", "AC-6" }
    })
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/1"]
    assert.is_table(wave)
    assert.are.equal(1, #wave.packages)
    -- Resolved baseGUID must be a single string pointing at BASE-2
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
  end)

  -- Negative: every candidate (primary and fallback) lacks sufficient aircraft
  it("should fail when all baseGUIDCandidates lack sufficient aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/2",
      packages = { makeStrikePackage({
        striker = makeStriker({ baseGUIDCandidates = { "BASE-2", "BASE-3" }, unitCount = 4 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- All three bases have 1 aircraft, none reaches the half-strength threshold of 2
    stubBases({
      ["BASE-1"] = { "AC-1" },
      ["BASE-2"] = { "AC-2" },
      ["BASE-3"] = { "AC-3" }
    })

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
    -- The rejected package is a detail row, so the rollup counts only the operation
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "total=1 skip=1"))
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "[SKIP] package=1 role=striker"))
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "reason=insufficient_aircraft"))
    -- All three candidates hold 1 free aircraft against a required 4
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "available=1 bases=3 required=4"))
  end)

  -- Positive: each role resolves its base independently within the same package
  it("should resolve each role's base independently within a package", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/3",
      packages = { makeStrikePackage({
        striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 }),
        escort = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 101, weaponDBID = 300 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- striker(dbid100, need4, half-threshold=2): BASE-1 has 1 (reject) -> falls back to BASE-2 (4)
    -- escort(dbid101, need2, half-threshold=1): BASE-1 has 2 -> resolves on BASE-1
    stubBases({
      ["BASE-1"] = { "S1", "E1", "E2" },
      ["BASE-2"] = { "S2", "S3", "S4", "S5" }
    }, function(guid)
      if guid == "E1" or guid == "E2" then return { dbid = 101, mission = nil } end
      return { dbid = 100, mission = nil }
    end)
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/3")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/3"]
    assert.is_table(wave)
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-1", wave.packages[1].escort.baseGUID)
  end)

  -- Positive: a failed package does not retain staged aircraft reservations
  it("should release staged reservations when a later role invalidates the package", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/TRANSACTION/1",
      packages = {
        makeStrikePackage({
          striker = makeStriker({ unitCount = 2 }),
          escort = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 101, weaponDBID = 300 },
          target = makeTarget({ objs = { { baseName = "FIRST", subTypes = { "Radar" } } } })
        }),
        makeStrikePackage({
          striker = makeStriker({ unitCount = 2 }),
          target = makeTarget({ objs = { { baseName = "SECOND", subTypes = { "Radar" } } } })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    stubSingleOperation(reconEntry, operation)
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      return { targetConfig.objs[1].baseName }
    end))
    stubBases({ ["BASE-1"] = { "S1", "S2" } })
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/TRANSACTION/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/TRANSACTION/1"]
    assert.are.equal(1, #wave.packages)
    assert.are.equal("SECOND", wave.packages[1].target.list[1])
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
  end)

  -- Positive: second package in same wave falls back because first package consumed primary
  it("should deduct same-wave bookings so later packages fallback to candidates", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/4",
      packages = {
        makeStrikePackage({
          striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 }),
          target = makeTarget({ objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } } })
        }),
        makeStrikePackage({
          striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1 has exactly 4 aircraft (one package's worth); BASE-2 has 4 (the second package's fallback)
    stubBases({
      ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" },
      ["BASE-2"] = { "AC-5", "AC-6", "AC-7", "AC-8" }
    })
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/4")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/4"]
    assert.is_table(wave)
    assert.are.equal(2, #wave.packages)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[2].striker.baseGUID)
  end)

  -- Positive: tanker role also resolves baseGUIDCandidates
  it("should fallback tanker to baseGUIDCandidates when primary lacks tankers", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/TANKER",
      packages = { makeStrikePackage({
        tanker = { baseGUID = "BASE-1", baseGUIDCandidates = { "BASE-2" }, unitCount = 4, unitDBID = 102 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1: 1 striker (dbid 100) + 1 tanker (dbid 102); 1 tanker is below the
    -- half-strength threshold of 2, and the striker booking must not be what decides it
    -- BASE-2: 4 tankers (dbid 102) -> tanker fallback satisfied at full strength
    stubBases({
      ["BASE-1"] = { "AC-S1", "AC-T1" },
      ["BASE-2"] = { "AC-T2", "AC-T3", "AC-T4", "AC-T5" }
    }, function(guid)
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 102, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/TANKER")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/TANKER"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[1].tanker.baseGUID)
  end)

  -- Positive: jammer role also resolves baseGUIDCandidates
  it("should fallback jammer to baseGUIDCandidates when primary lacks jammers", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/FALLBACK/JAMMER",
      packages = { makeStrikePackage({
        jammer = { baseGUID = "BASE-1", baseGUIDCandidates = { "BASE-2" }, unitCount = 4, unitDBID = 103 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1: 1 striker + 1 jammer; 1 jammer is below the half-strength threshold of 2
    -- BASE-2: 4 jammers -> jammer fallback satisfied at full strength
    stubBases({
      ["BASE-1"] = { "AC-S1", "AC-J1" },
      ["BASE-2"] = { "AC-J2", "AC-J3", "AC-J4", "AC-J5" }
    }, function(guid)
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 103, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/JAMMER")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/JAMMER"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[1].jammer.baseGUID)
  end)

  -- ============================================================================
  -- Partial Package (half-strength dispatch)
  -- ============================================================================

  -- Positive: accept and dispatch at half strength when no base can fill the full count
  it("should dispatch at half strength when only half the required aircraft exist", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/1",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1 has exactly 2 of dbid 100 = half of the required 4 -> accepted at half strength
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/PARTIAL/1")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/1"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    -- Current behavior: unitCount is NOT rewritten, so it stays at the requested 4
    assert.are.equal(4, wave.packages[1].striker.unitCount)
  end)

  -- Boundary: the threshold comes from config, it is not baked into the validator
  it("should reject a half-strength base when the configured ratio demands full strength", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/4",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })
    local config = makeConfig()
    config.c.air.minimumStrengthRatio = 1

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- 2 of the required 4: enough under the default 0.5, not enough at 1
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    local generateUniqueAirOperationNameStub = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))

    assert.is_false(AtoBuilder.execute(config, saveData, {}))
    assert.stub(generateUniqueAirOperationNameStub).was_not.called()
  end)

  -- Positive: lowering the ratio lets a thinner base through
  it("should accept a base below half strength when the configured ratio allows it", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/5",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })
    local config = makeConfig()
    config.c.air.minimumStrengthRatio = 0.25

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- 1 of the required 4 is below the default 0.5 but clears 0.25
    stubBases({ ["BASE-1"] = { "AC-1" } })
    stubDynamicStateSuccess("DYNAMIC/PARTIAL/5")

    assert.is_true(AtoBuilder.execute(config, saveData, {}))
    assert.are.equal("BASE-1", saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/5"].packages[1].striker.baseGUID)
  end)

  -- ============================================================================
  -- Template Isolation
  -- ============================================================================

  -- Positive: the persisted template must survive a wave being built from it
  it("should leave the operation template untouched when a wave is built", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/TEMPLATE/1",
      packages = { makeStrikePackage({
        striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 })
      }) }
    })
    local templatePackage = operation.template.packages[1]

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Forces the striker onto the fallback base, so a leaked write would be visible
    stubBases({
      ["BASE-1"] = { "AC-1" },
      ["BASE-2"] = { "AC-2", "AC-3", "AC-4", "AC-5" }
    })
    stubDynamicStateSuccess("DYNAMIC/TEMPLATE/1")

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))

    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/TEMPLATE/1"]
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
    -- The next wave off this template must still start from the authored base and
    -- an empty target list
    assert.are.equal("BASE-1", templatePackage.striker.baseGUID)
    assert.is_nil(templatePackage.target.list)
  end)

  -- Boundary: an operation that finds no targets must not pay for a template copy
  it("should not copy the template when no package has targets", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ target = makeTarget({ minTargetCount = 5 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })
    -- Built before deepCopy is stubbed; makeConfig deep-copies the real config
    local config = makeConfig()

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    local deepCopyStub = trackStub(stub(Utils, "deepCopy").invokes(function(value) return value end))

    assert.is_false(AtoBuilder.execute(config, saveData, {}))

    -- The wave template copy sits behind the target gate; nothing else on this path
    -- copies, so any call at all means it moved back in front of it
    assert.stub(deepCopyStub).was_not.called()
  end)

  -- ============================================================================
  -- Timing Report
  -- ============================================================================

  -- Negative: reconUAV has no package timing, so it must not appear in the report
  it("should not emit timing rows for reconUAV", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/TIMING/1",
      packages = { makeStrikePackage({
        reconUAV = {
          type = "UAV",
          templateId = "BZK005_RECON_1",
          baseGUID = "BASE-9",
          unitDBID = 900,
          course = {},
          speed = 300
        }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/TIMING/1")

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))

    assert.is_true(hasLogCall(TIMING_LOG_SCOPE, "role=striker"))
    -- PackageTiming never schedules reconUAV, so a row for it could only read unknown
    assert.is_false(hasLogCall(TIMING_LOG_SCOPE, "reconUAV"))
    assert.is_false(hasLogCall(TIMING_LOG_SCOPE, "unknown"))
  end)

  -- Boundary: available strictly below the fractional half-strength threshold is rejected
  it("should reject when available aircraft are below the fractional half-strength threshold", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/2",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- required=3 -> threshold is 1.5; 1 available is below it (would wrongly pass if the threshold were floored to 1)
    stubBases({ ["BASE-1"] = { "AC-1" } })
    local generateUniqueAirOperationNameStub = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_false(result)
    assert.stub(generateUniqueAirOperationNameStub).was_not.called()
  end)

  -- Positive: a package accepted at half strength still reserves its base, forcing the next package to fall back
  it("should reserve a half-strength base so a later package falls back to candidates", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/3",
      packages = {
        makeStrikePackage({
          striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 }),
          target = makeTarget({ objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } } })
        }),
        makeStrikePackage({
          striker = makeStriker({ baseGUIDCandidates = { "BASE-2" }, unitCount = 4 })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1 has 3 (>= half of 4, < full): package 1 is accepted at half strength and reserves BASE-1
    -- BASE-2 has 4 (full strength) so package 2 falls back there
    stubBases({
      ["BASE-1"] = { "AC-1", "AC-2", "AC-3" },
      ["BASE-2"] = { "AC-4", "AC-5", "AC-6", "AC-7" }
    })
    stubDynamicStateSuccess("DYNAMIC/PARTIAL/3")

    local result = AtoBuilder.execute(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/3"]
    assert.is_table(wave)
    assert.are.equal(2, #wave.packages)
    -- Package 1 reserved BASE-1 at half strength; package 2 must fall back to BASE-2
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[2].striker.baseGUID)
  end)

  -- ============================================================================
  -- Per-Airframe Reservations
  -- ============================================================================

  -- Positive: bookings of one airframe type must not consume another type's aircraft
  it("should book each airframe type separately within one package", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AIRFRAME/1",
      packages = { makeStrikePackage({
        striker = makeStriker({ unitCount = 2 }),
        tanker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 102 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1 holds exactly what the package asks for: 2 strikers and 2 tankers, all free
    stubBases({ ["BASE-1"] = { "S1", "S2", "T1", "T2" } }, function(guid)
      if guid == "S1" or guid == "S2" then return { dbid = 100, mission = nil } end
      return { dbid = 102, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/AIRFRAME/1")

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))

    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/AIRFRAME/1"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-1", wave.packages[1].tanker.baseGUID)
  end)

  -- Positive: an existing wave's strikers must not make the same base's tankers look busy
  it("should not let an existing wave's strikers block another airframe type", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AIRFRAME/2",
      packages = { makeStrikePackage({
        striker = makeStriker({ unitCount = 2 }),
        tanker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 102 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry }, {
      airTaskingOrder = {
        -- An active wave already holds 3 of the 4 strikers at BASE-1
        ["EXISTING-WAVE"] = {
          isActivated = true,
          hasLaunched = false,
          packages = {
            { hasLaunched = false, striker = { baseGUID = "BASE-1", unitCount = 3, unitDBID = 100 } }
          }
        }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- BASE-1: 4 strikers (3 booked, 1 free -> half strength of the required 2) and
    -- 2 untouched tankers. The striker bookings must not spill onto the tankers.
    stubBases({ ["BASE-1"] = { "S1", "S2", "S3", "S4", "T1", "T2" } }, function(guid)
      if guid == "T1" or guid == "T2" then return { dbid = 102, mission = nil } end
      return { dbid = 100, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/AIRFRAME/2")

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))

    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/AIRFRAME/2"]
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-1", wave.packages[1].tanker.baseGUID)
  end)

  -- ============================================================================
  -- Free Aircraft Cache
  -- ============================================================================

  -- Positive: one pass reads each base once, however many roles and packages use it
  it("should read a base only once per pass", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/CACHE/1",
      packages = {
        makeStrikePackage({
          striker = makeStriker({ unitCount = 1 }),
          escort = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 101, weaponDBID = 300 },
          target = makeTarget({ objs = { { baseName = "FIRST", subTypes = { "Radar" } } } })
        }),
        makeStrikePackage({
          striker = makeStriker({ unitCount = 1 }),
          escort = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 101, weaponDBID = 300 },
          target = makeTarget({ objs = { { baseName = "SECOND", subTypes = { "Radar" } } } })
        })
      }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      return { targetConfig.objs[1].baseName }
    end))
    -- 2 packages x 2 roles all draw from BASE-1; without the cache that is 4 reads
    local getUnitStub = stubBases({ ["BASE-1"] = { "S1", "S2", "E1", "E2" } }, function(guid)
      if guid == "E1" or guid == "E2" then return { dbid = 101, mission = nil } end
      return { dbid = 100, mission = nil }
    end)
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/CACHE/1")

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))

    assert.are.equal(1, countBaseReads(getUnitStub, "BASE-1"))
  end)

  -- Boundary: the cache dies with the pass, so a later tick sees aircraft losses
  it("should re-read a base on the next pass", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/CACHE/2",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Short of aircraft, so the operation stays queued and the second tick reprocesses it
    local getUnitStub = stubBases({ ["BASE-1"] = { "AC-1" } })
    trackStub(stub(DynamicState, "markOperationExecuted"))

    AtoBuilder.execute(makeConfig(), saveData, {})
    AtoBuilder.execute(makeConfig(), saveData, {})

    -- A cache that outlived the pass would still read 1; aircraft destroyed between
    -- ticks would then never be noticed.
    assert.are.equal(2, countBaseReads(getUnitStub, "BASE-1"))
  end)

  -- ============================================================================
  -- Observation Window
  -- ============================================================================

  -- Positive: a temporary aircraft shortage keeps the operation queued for a later tick
  it("should keep the operation pending when packages are unavailable inside the window", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/WINDOW/1",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    -- Only 1 of the 4 required aircraft is free, below the half-strength threshold
    stubBases({ ["BASE-1"] = { "AC-1" } })
    local markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))

    assert.stub(markOperationExecutedStub).was_not.called()
    assert.are.equal(1, #reconEntry.operations)
    assert.is_false(operation.executed)
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "state=observing"))
  end)

  -- Positive: the aircraft come back mid-window and the retried operation launches
  it("should insert the wave when aircraft free up on a later tick inside the window", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/WINDOW/2",
      packages = { makeStrikePackage({ striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTargets({ "TGT-1" })
    local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = guid, embarkedUnits = { Aircraft = { "AC-1" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    local markOperationExecutedStub = stubDynamicStateSuccess("DYNAMIC/WINDOW/2")

    -- Tick 1: not enough aircraft, operation stays queued
    assert.is_false(AtoBuilder.execute(makeConfig(), saveData, {}))
    assert.stub(markOperationExecutedStub).was_not.called()

    -- Tick 2: the rest of the squadron is back on the ramp
    getUnitStub:revert()
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })

    assert.is_true(AtoBuilder.execute(makeConfig(), saveData, {}))
    assert.stub(markOperationExecutedStub).was.called(1)
    assert.is_table(saveData.c.air.airTaskingOrder["DYNAMIC/WINDOW/2"])
  end)

  -- Negative: the window closes on an operation that never found its packages
  it("should abandon the operation when the observation window expires", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({ name = "STRIKE/WINDOW/3" })

    local saveData = makeSaveData({ reconEntry })
    local config = makeConfig()

    trackStub(stub(GameApi, "ScenEdit_CurrentTime")
      .returns(1000 + config.c.recon.observationWindowSec + 1))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    stubSingleOperation(reconEntry, operation)
    local generateUniqueAirOperationNameStub = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))
    local markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

    assert.is_false(AtoBuilder.execute(config, saveData, {}))

    assert.stub(generateUniqueAirOperationNameStub).was_not.called()
    assert.stub(markOperationExecutedStub).was_not.called()
    -- Dropped from the batch, which also closes the emptied batch
    assert.are.equal(0, #reconEntry.operations)
    assert.is_true(reconEntry.executed)
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "[WARN]"))
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "reason=observation_window_expired"))
    assert.is_true(hasLogCall(OPERATIONS_LOG_SCOPE, "state=abandoned"))
  end)
end)
