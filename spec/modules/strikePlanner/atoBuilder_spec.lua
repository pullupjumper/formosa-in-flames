-- AtoBuilder Unit Tests
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local BaseConfig = require("src.core.config")

-- Note: package timing math (flight time, lead times, durations, tanker coordination)
-- is covered by packageTiming_spec. These tests focus on AtoBuilder's own
-- responsibilities: target gating, aircraft validation, wave assembly, orchestration,
-- and logging. Timing is only asserted to be applied end-to-end, not recomputed here.

describe("AtoBuilder", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local warnStub

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  -- ============================================================================
  -- Shared Mock Data Builders
  -- ============================================================================

  ---Create reconEntry with defaults: time="2026-02-14 00:00:00", delay=0, type="satellite"
  local function makeReconEntry(overrides)
    local entry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a striker deployment descriptor with defaults; overrides replace fields.
  local function makeStriker(overrides)
    local striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 }
    if overrides then
      for k, v in pairs(overrides) do striker[k] = v end
    end
    return striker
  end

  ---Create a fixed HSINCHU/Radar target config with defaults; overrides replace fields.
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

  ---Create a strike package template with defaults; overrides replace top-level fields.
  local function makeStrikePackage(overrides)
    local pkg = {
      timeToReady = 5,
      striker = makeStriker(),
      target = makeTarget()
    }
    if overrides then
      for k, v in pairs(overrides) do pkg[k] = v end
    end
    return pkg
  end

  ---Create an air operation. Pass false for a templateless operation; otherwise a table of template overrides.
  local function makeAirOperation(templateOverrides)
    if templateOverrides == false then
      return { type = "air", executed = false }
    end
    local template = {
      name = "STRIKE/1",
      isFirstWave = true,
      strikeInterval = 0,
      packages = { makeStrikePackage() }
    }
    if templateOverrides then
      for k, v in pairs(templateOverrides) do template[k] = v end
    end
    return { type = "air", executed = false, template = template }
  end

  ---Create full saveData structure for tests
  local function makeSaveData(reconTriggeredOperations, opts)
    opts = opts or {}
    return {
      c = {
        air = { airTaskingOrder = opts.airTaskingOrder or {} },
        targetlist = opts.targetlist or {},
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperations = reconTriggeredOperations,
          generatedOperations = opts.generatedOperations or { air = {}, ground = {} }
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
  -- Shared Stub Helpers
  -- ============================================================================

  ---Stub current time and datetime parsing to the same fixed timestamp.
  ---@param timestamp? integer Defaults to 1000
  local function stubClock(timestamp)
    timestamp = timestamp or 1000
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(timestamp))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(timestamp))
  end

  ---Stub filterOperationsByType to yield a single recon-triggered operation.
  local function stubSingleOperation(reconEntry, operation)
    trackStub(stub(DynamicState, "filterOperationsByType").returns({
      { operationBatch = reconEntry, operation = operation }
    }))
  end

  ---Stub the recon trigger gate.
  ---@param value? boolean Defaults to true
  local function stubTriggered(value)
    if value == nil then value = true end
    trackStub(stub(GameUtils, "isAfterStartTime").returns(value))
  end

  ---Stub target evaluation to return a fixed target list.
  local function stubTargets(list)
    trackStub(stub(TargetingProcess, "processTargets").returns(list or { "TGT-1" }))
  end

  ---Stub aircraft availability. `bases` maps baseGUID to its embarked aircraft GUIDs.
  ---`aircraftFn` resolves individual aircraft units; defaults to dbid 100, unassigned.
  local function stubBases(bases, aircraftFn)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if bases and bases[guid] then
        return { guid = guid, embarkedUnits = { Aircraft = bases[guid] } }
      end
      if aircraftFn then
        return aircraftFn(guid)
      end
      return { dbid = 100, mission = nil }
    end))
  end

  ---Stub the DynamicState registration/marking calls for a successful insertion.
  ---@param waveName string Generated wave name
  ---@return luassert.spy markExecuted The markOperationExecuted stub for call assertions
  local function stubDynamicStateSuccess(waveName)
    trackStub(stub(DynamicState, "generateUniqueAirOperationName").returns(waveName))
    trackStub(stub(DynamicState, "registerGeneratedOperation"))
    return trackStub(stub(DynamicState, "markOperationExecuted"))
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
    warnStub = trackStub(stub(Logger, "warn"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Positive: Configuration and Basic Flow
  -- ============================================================================

  -- Positive: lastEvaluationTime updated
  it("should update lastEvaluationTime in saveData", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperations = {}
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(5000))

    AtoBuilder.process(makeConfig(), saveData, {})

    assert.are.equal(5000, saveData.c.dynamicOperations.lastEvaluationTime)
  end)

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
    stubTriggered()
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })
    trackStub(stub(DynamicState, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/AB/1/1"))
    local stubRegister = trackStub(stub(DynamicState, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicState, "markOperationExecuted"))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(stubRegister).was.called(1)
    assert.are.equal("air", stubRegister.calls[1].vals[1])
    assert.stub(stubMarkExecuted).was.called(1)
    assert.is_true(stubMarkExecuted.calls[1].vals[3])
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
    stubTriggered()
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    AtoBuilder.process(makeConfig(), saveData, {})

    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]

    -- Verify wave structure
    assert.are.equal("DYNAMIC/SATELLITE/STRIKE/1/1", wave.name)
    assert.is_true(wave.isActivated)
    assert.is_true(wave.isFirstWave)
    assert.is_false(wave.hasLaunched)
    assert.are.equal(180, wave.strikeInterval)

    -- Verify package structure
    local pkg = wave.packages[1]
    assert.are.equal(8, pkg.timeToReady)
    assert.is_false(pkg.hasLaunched)
    assert.is_table(pkg.loadoutStatus)
    assert.is_false(pkg.loadoutStatus.isLoadoutInitiated)
    assert.is_nil(pkg.loadoutStatus.loadoutInitiatedTime)
    assert.is_nil(pkg.loadoutStatus.expectedReadyTime)
    assert.is_nil(pkg.loadoutStatus.loadoutStartTime)

    -- Timing is applied by PackageTiming (values verified in packageTiming_spec)
    assert.is_string(pkg.striker.startTime)
    assert.is_string(pkg.striker.endTime)
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
    stubTriggered()
    stubTargets({ "SHIP-1", "SHIP-2" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3" } })
    stubDynamicStateSuccess("DYNAMIC/AIRCRAFT/ANTISHIP/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
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

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      if targetConfig and targetConfig.objs and targetConfig.objs[1]
          and targetConfig.objs[1].baseName == "TAOYUAN" then
        return { "TGT-1" }
      end
      return { "TGT-2" }
    end))
    stubBases({ ["BASE-2"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    assert.are.equal(1, #wave.packages)
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
    assert.is_string(wave.packages[1].striker.startTime)
  end)

  -- Positive: at least one operation succeeds among multiple
  it("should return true when at least one air operation is processed successfully", function()
    local reconEntry1 = makeReconEntry()
    local reconEntry2 = makeReconEntry({ time = "2026-02-14 01:00:00", type = "aircraft" })
    local operation1 = makeAirOperation(false) -- No template => skipped
    local operation2 = makeAirOperation({ name = "STRIKE/2", isFirstWave = false })

    local saveData = makeSaveData({ reconEntry1, reconEntry2 })

    stubClock(5000)
    trackStub(stub(DynamicState, "filterOperationsByType").returns({
      { operationBatch = reconEntry1, operation = operation1 },
      { operationBatch = reconEntry2, operation = operation2 }
    }))
    stubTriggered()
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    trackStub(stub(DynamicState, "generateUniqueAirOperationName").returns("DYNAMIC/AIRCRAFT/STRIKE/2/1"))
    trackStub(stub(DynamicState, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicState, "markOperationExecuted"))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    -- markOperationExecuted called for operation2 (the one with template)
    assert.stub(stubMarkExecuted).was.called(1)
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

    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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

    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    -- parseDatetimeToTimestamp returns 1000, plus delay 500 = 1500
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    stubSingleOperation(reconEntry, operation)
    -- isAfterStartTime(1500) with current time 2000 => true
    stubTriggered()
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    local stubMarkExecuted = stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(stubMarkExecuted).was.called(1)
  end)

  -- ============================================================================
  -- Negative: Configuration Guards
  -- ============================================================================

  -- Negative: dynamicOperations not configured
  it("should return false when dynamicOperations is not configured", function()
    local saveData = { c = {} }
    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
  end)

  -- Negative: dynamicOperations disabled
  it("should return false when dynamicOperations is disabled", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = false }
      }
    }
    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
  end)

  -- Negative: reconTriggeredOperations nil
  it("should return false when reconTriggeredOperations is nil", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = true, reconTriggeredOperations = nil }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
  end)

  -- Negative: reconTriggeredOperations empty
  it("should return false when reconTriggeredOperations is empty", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = true, reconTriggeredOperations = {} }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
  end)

  -- Negative: no air operations pending
  it("should return false when no air operations are pending", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperations = { { time = "2026-02-14 00:00:00", operations = {} } }
        }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    local stubFilterOps = trackStub(stub(DynamicState, "filterOperationsByType").returns({}))

    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
    assert.stub(stubFilterOps).was.called(1)
    assert.are.equal("air", stubFilterOps.calls[1].vals[2])
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
          reconTriggeredOperations = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    -- parseDatetimeToTimestamp returns 50, plus delay 600 = 650 > 100 (current time from isAfterStartTime)
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
    stubSingleOperation(reconEntry, operation)
    stubTriggered(false)
    local stubMarkExecuted = trackStub(stub(DynamicState, "markOperationExecuted"))

    assert.is_false(AtoBuilder.process(makeConfig(), saveData, {}))
    assert.stub(stubMarkExecuted).was_not.called()
  end)

  -- Negative: operation has no template
  it("should not insert ATO wave when operation has no template", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation(false)
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperations = { reconEntry }
        }
      }
    }

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    local stubGenName = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))
    local stubMarkExecuted = trackStub(stub(DynamicState, "markOperationExecuted"))

    AtoBuilder.process(makeConfig(), saveData, {})

    assert.stub(stubGenName).was_not.called()
    -- MISSING_TEMPLATE reason skips markOperationExecuted
    assert.stub(stubMarkExecuted).was_not.called()
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
        timeToReady = nil,
        striker = makeStriker({ unitCount = 2 }),
        target = makeTarget({ minTargetCount = 5 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    -- Returns only 1 target but minTargetCount = 5
    stubTargets({ "TGT-1" })
    local stubGenName = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- No valid packages => no ATO wave inserted
    assert.is_false(result)
    assert.stub(stubGenName).was_not.called()
  end)

  -- Negative: insufficient aircraft at base
  it("should skip package when base has insufficient aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/AB/1",
      isFirstWave = false,
      strikeInterval = 120,
      packages = { makeStrikePackage({
        timeToReady = nil,
        striker = makeStriker({ unitCount = 4 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base has only 1 aircraft; package requires 4 (below the half-strength threshold of 2)
    stubBases({ ["BASE-1"] = { "AC-1" } })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
    -- Exactly 3 targets = exactly minTargetCount
    stubTargets({ "TGT-1", "TGT-2", "TGT-3" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.are.equal(1, #saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"].packages)
  end)

  -- Boundary: target count one below minTargetCount
  it("should reject package when target count is one below minTargetCount", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ timeToReady = nil, target = makeTarget({ minTargetCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    -- Only 2 targets, minTargetCount = 3
    stubTargets({ "TGT-1", "TGT-2" })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: default minTargetCount used when not specified
  it("should use default minTargetCount of 1 when not specified", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({
        -- No minTargetCount specified, defaults to 1
        target = { objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } }, contactAge = 300 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    -- Only 1 target, no minTargetCount => defaults to 1 => pass
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
  end)

  -- ============================================================================
  -- Boundary: Aircraft Assignment
  -- ============================================================================

  -- Boundary: assigned aircraft counted from existing ATO waves
  it("should account for already assigned aircraft in existing ATO waves", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ timeToReady = nil, striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry }, {
      airTaskingOrder = {
        -- Existing wave with 3 aircraft already assigned from BASE-1
        ["EXISTING-WAVE"] = {
          isActivated = true,
          hasLaunched = false,
          packages = {
            {
              hasLaunched = false,
              striker = { baseGUID = "BASE-1", unitCount = 3 }
            }
          }
        }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base has 4 aircraft total available, 3 already assigned, needs 4 => 4-3=1 < half-strength threshold (2)
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- 4 available - 3 assigned = 1, below half-strength threshold (2) => fail
    assert.is_false(result)
  end)

  -- Boundary: launched wave packages not counted
  it("should not count launched wave packages in assigned aircraft", function()
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
            { hasLaunched = true, striker = { baseGUID = "BASE-1", unitCount = 10 } }
          }
        },
        -- Active but package already launched should NOT be counted
        ["ACTIVE-WAVE"] = {
          isActivated = true,
          hasLaunched = false,
          packages = {
            { hasLaunched = true, striker = { baseGUID = "BASE-1", unitCount = 10 } }
          }
        }
      }
    })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base has 4 aircraft available
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- Launched waves not counted: 4 available - 0 assigned >= 3 required => pass
    assert.is_true(result)
  end)

  -- Boundary: aircraft on missions not counted as available
  it("should not count aircraft already on missions as available", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ timeToReady = nil, striker = makeStriker({ unitCount = 4 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base has 3 aircraft: AC-1 free, AC-2 on mission, AC-3 wrong DBID => only 1 available
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2", "AC-3" } }, function(guid)
      if guid == "AC-1" then return { dbid = 100, mission = nil } end
      if guid == "AC-2" then return { dbid = 100, mission = "CAP Mission" } end
      if guid == "AC-3" then return { dbid = 999, mission = nil } end
      return nil
    end)

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
      packages = { makeStrikePackage({ timeToReady = nil, striker = makeStriker({ unitCount = 2 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base exists but has no embarked aircraft
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
      guid = "BASE-1",
      name = "Empty Air Base",
      embarkedUnits = nil
    }))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: base unit not found
  it("should fail aircraft validation when base unit not found", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { makeStrikePackage({ timeToReady = nil, striker = makeStriker({ baseGUID = "INVALID-BASE", unitCount = 2 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- Base not found
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: ATO structure not initialized
  it("should return false when ATO structure is not initialized", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation()

    local saveData = makeSaveData({ reconEntry })
    saveData.c.air.airTaskingOrder = nil -- Not initialized

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/SATELLITE/STRIKE/1/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- insertATOWave returns false when airTaskingOrder is nil
    assert.is_false(result)
  end)

  -- Boundary: empty packages array
  it("should return false when template has empty packages", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({ packages = {} })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- No valid packages (empty) => no wave inserted
    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Edge Cases
  -- ============================================================================

  -- Boundary: target configuration nil
  it("should skip package when target configuration is nil", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      packages = { { striker = makeStriker() } } -- target absent => nil
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    -- No valid packages (target is nil, processTargets returns empty) => rejected
    assert.is_false(result)
  end)

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
    stubTriggered()

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1 has 1 aircraft (below half-strength threshold of 2); BASE-2 has 4 (full strength)
    stubBases({
      ["BASE-1"] = { "AC-1" },
      ["BASE-2"] = { "AC-3", "AC-4", "AC-5", "AC-6" }
    })
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
        timeToReady = nil,
        striker = makeStriker({ baseGUIDCandidates = { "BASE-2", "BASE-3" }, unitCount = 4 })
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- All three bases have 1 aircraft, none reaches the half-strength threshold of 2
    stubBases({
      ["BASE-1"] = { "AC-1" },
      ["BASE-2"] = { "AC-2" },
      ["BASE-3"] = { "AC-3" }
    })

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_false(result)
    assert.stub(logStub).was.called()
    local logMessage = logStub.calls[1].vals[2]
    assert.truthy(string.find(logMessage, "validationErrors=", 1, true))
    assert.truthy(string.find(logMessage, "package=1", 1, true))
    assert.truthy(string.find(logMessage, "role=striker", 1, true))
    assert.truthy(string.find(logMessage, "reason=insufficient_aircraft", 1, true))
    assert.truthy(string.find(logMessage, "BASE-1:available=1:assigned=0", 1, true))
    assert.truthy(string.find(logMessage, "BASE-2:available=1:assigned=0", 1, true))
    assert.truthy(string.find(logMessage, "BASE-3:available=1:assigned=0", 1, true))
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
    stubTriggered()
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

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      return { targetConfig.objs[1].baseName }
    end))
    stubBases({ ["BASE-1"] = { "S1", "S2" } })
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/TRANSACTION/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1 has exactly 4 aircraft (one package's worth); BASE-2 has 4 (the second package's fallback)
    stubBases({
      ["BASE-1"] = { "AC-1", "AC-2", "AC-3", "AC-4" },
      ["BASE-2"] = { "AC-5", "AC-6", "AC-7", "AC-8" }
    })
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/4")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
        tanker = { baseGUID = "BASE-1", baseGUIDCandidates = { "BASE-2" }, unitCount = 2, unitDBID = 102 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1: 1 striker (dbid 100) + 1 tanker (dbid 102) -> tanker insufficient (need 2)
    -- BASE-2: 2 tankers (dbid 102) -> tanker fallback satisfied
    stubBases({
      ["BASE-1"] = { "AC-S1", "AC-T1" },
      ["BASE-2"] = { "AC-T2", "AC-T3" }
    }, function(guid)
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 102, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/TANKER")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
        jammer = { baseGUID = "BASE-1", baseGUIDCandidates = { "BASE-2" }, unitCount = 2, unitDBID = 103 }
      }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1: 1 striker + 1 jammer -> jammer insufficient (need 2)
    -- BASE-2: 2 jammers -> jammer fallback satisfied
    stubBases({
      ["BASE-1"] = { "AC-S1", "AC-J1" },
      ["BASE-2"] = { "AC-J2", "AC-J3" }
    }, function(guid)
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 103, mission = nil }
    end)
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    stubDynamicStateSuccess("DYNAMIC/FALLBACK/JAMMER")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

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
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1 has exactly 2 of dbid 100 = half of the required 4 -> accepted at half strength
    stubBases({ ["BASE-1"] = { "AC-1", "AC-2" } })
    stubDynamicStateSuccess("DYNAMIC/PARTIAL/1")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/1"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    -- Current behavior: unitCount is NOT rewritten, so it stays at the requested 4
    assert.are.equal(4, wave.packages[1].striker.unitCount)
  end)

  -- Boundary: available strictly below the fractional half-strength threshold is rejected
  it("should reject when available aircraft are below the fractional half-strength threshold", function()
    local reconEntry = makeReconEntry()
    local operation = makeAirOperation({
      name = "STRIKE/PARTIAL/2",
      packages = { makeStrikePackage({ timeToReady = nil, striker = makeStriker({ unitCount = 3 }) }) }
    })

    local saveData = makeSaveData({ reconEntry })

    stubClock(1000)
    stubSingleOperation(reconEntry, operation)
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- required=3 -> threshold is 1.5; 1 available is below it (would wrongly pass if the threshold were floored to 1)
    stubBases({ ["BASE-1"] = { "AC-1" } })
    local stubGenName = trackStub(stub(DynamicState, "generateUniqueAirOperationName"))

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_false(result)
    assert.stub(stubGenName).was_not.called()
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
    stubTriggered()
    stubTargets({ "TGT-1" })
    -- BASE-1 has 3 (>= half of 4, < full): package 1 is accepted at half strength and reserves BASE-1
    -- BASE-2 has 4 (full strength) so package 2 falls back there
    stubBases({
      ["BASE-1"] = { "AC-1", "AC-2", "AC-3" },
      ["BASE-2"] = { "AC-4", "AC-5", "AC-6", "AC-7" }
    })
    stubDynamicStateSuccess("DYNAMIC/PARTIAL/3")

    local result = AtoBuilder.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/3"]
    assert.is_table(wave)
    assert.are.equal(2, #wave.packages)
    -- Package 1 reserved BASE-1 at half strength; package 2 must fall back to BASE-2
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[2].striker.baseGUID)
  end)
end)
