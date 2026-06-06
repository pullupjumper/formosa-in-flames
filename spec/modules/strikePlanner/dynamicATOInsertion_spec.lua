-- DynamicATOInsertion Unit Tests
local DynamicATOInsertion = require("src.modules.strikePlanner.dynamicATOInsertion")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local BaseConfig = require("src.core.config")

describe("DynamicATOInsertion", function()
  ---@type luassert.spy[]
  local activeStubs
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
  -- Shared Test Utilities
  -- ============================================================================

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

  ---Create full saveData structure for tests
  local function makeSaveData(reconSchedule, opts)
    opts = opts or {}
    return {
      c = {
        air = { airTaskingOrder = opts.airTaskingOrder or {} },
        targetlist = opts.targetlist or {},
        dynamicOperations = {
          enabled = true,
          reconSchedule = reconSchedule,
          generatedOperations = opts.generatedOperations or { air = {}, ground = {} }
        }
      }
    }
  end

  ---Create full typed config for DynamicATOInsertion tests
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
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
          reconSchedule = {}
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(5000))

    DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.are.equal(5000, saveData.c.dynamicOperations.lastEvaluationTime)
  end)

  -- Positive: successful ATO wave insertion with fixed targets
  it("should create and insert ATO wave for fixed target package", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/AB/1",
        isFirstWave = true,
        strikeInterval = 120,
        packages = {
          {
            timeToReady = 10,
            striker = {
              baseGUID = "BASE-1",
              unitCount = 2,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry }, {
      targetlist = {
        { name = "HSINCHU/Radar", subType = "Radar", guid = "TGT-1" }
      }
    })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))

    -- Aircraft availability: base has 4 aircraft, 2 required
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base Alpha",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/AB/1/1"))
    local stubRegister = trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(stubRegister).was.called(1)
    assert.are.equal("air", stubRegister.calls[1].vals[1])
    assert.stub(stubMarkExecuted).was.called(1)
    assert.is_true(stubMarkExecuted.calls[1].vals[3])
    assert.is_table(saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/AB/1/1"])
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/AB/1/1"]
    assert.is_true(wave.isActivated)
    assert.is_false(wave.hasLaunched)
    assert.are.equal(1, #wave.packages)
  end)

  -- Positive: wave structure has correct fields
  it("should create wave with correct structural fields", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 180,
        packages = {
          {
            timeToReady = 8,
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    DynamicATOInsertion.process(makeConfig(), saveData, {})

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
  end)

  -- ============================================================================
  -- Positive: Dynamic Target Filtering
  -- ============================================================================

  -- Positive: dynamic target filtering
  it("should create ATO wave with dynamic target filtering", function()
    local reconEntry = makeReconEntry({ type = "aircraft" })
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "ANTISHIP/1",
        isFirstWave = false,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              unitCount = 2,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              areas = { { "RP-1", "RP-2", "RP-3", "RP-4" } },
              filterNames = { "findNavalTargets" },
              contactAge = 600,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "SHIP-1", "SHIP-2" }))

    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base Bravo",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/AIRCRAFT/ANTISHIP/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.is_table(saveData.c.air.airTaskingOrder["DYNAMIC/AIRCRAFT/ANTISHIP/1/1"])
  end)

  -- ============================================================================
  -- Positive: Partial Validation and Multiple Operations
  -- ============================================================================

  -- Positive: partial validation passes valid packages only
  it("should insert wave with only validated packages when some fail", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 300,
        packages = {
          -- Package 1: has targets
          {
            timeToReady = 5,
            striker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          },
          -- Package 2: insufficient targets (needs 10)
          {
            timeToReady = 5,
            striker = { baseGUID = "BASE-2", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 10
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    -- Package 1 (TAOYUAN) gets 3 targets, Package 2 (HSINCHU) gets 1 target (needs 10)
    trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      if targetConfig and targetConfig.objs and targetConfig.objs[1]
          and targetConfig.objs[1].baseName == "TAOYUAN" then
        return { "TGT-1", "TGT-2", "TGT-3" }
      end
      return { "TGT-4" }
    end))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" or guid == "BASE-2" then
        return {
          guid = guid,
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    assert.is_table(wave)
    -- Only package 1 should be in the wave (package 2 failed target validation)
    assert.are.equal(1, #wave.packages)
  end)

  -- Positive: at least one operation succeeds among multiple
  it("should return true when at least one air operation is processed successfully", function()
    local reconEntry1 = makeReconEntry()
    local reconEntry2 = makeReconEntry({ time = "2026-02-14 01:00:00", type = "aircraft" })
    local operation1 = {
      type = "air",
      executed = false
      -- No template => skipped
    }
    local operation2 = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/2",
        isFirstWave = false,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry1, reconEntry2 })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(5000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry1, operation = operation1 },
      { reconEntry = reconEntry2, operation = operation2 }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/AIRCRAFT/STRIKE/2/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    -- markOperationExecuted called for operation2 (the one with template)
    assert.stub(stubMarkExecuted).was.called(1)
  end)

  -- ============================================================================
  -- Positive: Timing and Duration
  -- ============================================================================

  -- Positive: timing calculated for support roles
  it("should calculate timing for package with support roles", function()
    local baseTimestamp = 1770000000 -- Realistic future timestamp
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            timeToReady = 5,
            striker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            escort = {
              baseGUID = "BASE-2",
              unitCount = 2,
              unitDBID = 101,
              missionCreationParams = {
                opts = { patrolZone = { "RP-ESCORT-1" } }
              }
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(baseTimestamp))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function()
      return baseTimestamp
    end))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))

    -- Aircraft availability
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" or guid == "BASE-2" then
        return {
          guid = guid,
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } }
        }
      end
      return { dbid = (guid == "AC-1" or guid == "AC-2") and 100 or 101, mission = nil }
    end))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns({
      latitude = 25.0, longitude = 121.0
    }))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({
      ranges = { land = { max = 50 } }
    }))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    local pkg = wave.packages[1]

    -- Verify timing fields were set
    assert.is_string(pkg.striker.startTime)
    assert.is_string(pkg.striker.endTime)
    assert.is_string(pkg.escort.endTime)
    assert.is_false(pkg.hasLaunched)
    assert.is_false(pkg.loadoutStatus.isLoadoutInitiated)
  end)

  -- Positive: tanker duration applied
  it("should use tanker duration when package includes tanker", function()
    local baseTimestamp = 1770000000 -- Realistic future timestamp
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            timeToReady = 5,
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            tanker = { baseGUID = "BASE-2", unitCount = 1, unitDBID = 102 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(baseTimestamp))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function()
      return baseTimestamp
    end))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" or guid == "BASE-2" then
        return {
          guid = guid,
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      if guid == "AC-1" then return { dbid = 100, mission = nil } end
      return { dbid = 102, mission = nil }
    end))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({
      ranges = { land = { max = 50 } }
    }))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"]
    local pkg = wave.packages[1]

    -- Verify that striker endTime reflects tanker duration (120 min = 7200 sec)
    -- Revert stubs to use real parseDatetimeToTimestamp for assertion
    for _, s in ipairs(activeStubs) do s:revert() end
    activeStubs = {}

    local startTs = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    local endTs = Utils.parseDatetimeToTimestamp(pkg.striker.endTime)
    local duration = endTs - startTs
    -- With tanker: duration ~7200 (TANKER_DURATION), not ~2400 (MISSION_DURATION)
    assert.is_true(duration > 5000)
    assert.is_true(duration <= 7200)
  end)

  -- Positive: recon entry delay handled
  it("should handle recon entry delay correctly", function()
    local reconEntry = makeReconEntry({ delay = 500 })
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2000))
    -- parseDatetimeToTimestamp returns 1000, plus delay 500 = 1500
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    -- isAfterStartTime(1500) with current time 2000 => true
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.stub(stubMarkExecuted).was.called(1)
  end)

  -- ============================================================================
  -- Negative: Configuration Guards
  -- ============================================================================

  -- Negative: dynamicOperations not configured
  it("should return false when dynamicOperations is not configured", function()
    local saveData = { c = {} }
    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
  end)

  -- Negative: dynamicOperations disabled
  it("should return false when dynamicOperations is disabled", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = false }
      }
    }
    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
  end)

  -- Negative: reconSchedule nil
  it("should return false when reconSchedule is nil", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = true, reconSchedule = nil }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
  end)

  -- Negative: reconSchedule empty
  it("should return false when reconSchedule is empty", function()
    local saveData = {
      c = {
        dynamicOperations = { enabled = true, reconSchedule = {} }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
  end)

  -- Negative: no air operations pending
  it("should return false when no air operations are pending", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconSchedule = { { time = "2026-02-14 00:00:00", operations = {} } }
        }
      }
    }
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    local stubFilterOps = trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({}))

    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
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
          reconSchedule = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    -- parseDatetimeToTimestamp returns 50, plus delay 600 = 650 > 100 (current time from isAfterStartTime)
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    assert.is_false(DynamicATOInsertion.process(makeConfig(), saveData, {}))
    assert.stub(stubMarkExecuted).was_not.called()
  end)

  -- Negative: operation has no template
  it("should not insert ATO wave when operation has no template", function()
    local reconEntry = makeReconEntry()
    local operation = { type = "air", executed = false }
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    local stubGenName = trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName"))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/AB/1",
        isFirstWave = true,
        strikeInterval = 120,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 5
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    -- Returns only 1 target but minTargetCount = 5
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    local stubGenName = trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- No valid packages => no ATO wave inserted
    assert.is_false(result)
    assert.stub(stubGenName).was_not.called()
  end)

  -- Negative: insufficient aircraft at base
  it("should skip package when base has insufficient aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/AB/1",
        isFirstWave = false,
        strikeInterval = 120,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 4, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base has only 1 aircraft; package requires 4 (below the half-strength threshold of 2)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base Alpha",
          embarkedUnits = { Aircraft = { "AC-1" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Target Count
  -- ============================================================================

  -- Boundary: exactly minTargetCount targets
  it("should accept package when target count exactly equals minTargetCount", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 3
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    -- Exactly 3 targets = exactly minTargetCount
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1", "TGT-2", "TGT-3" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    assert.are.equal(1, #saveData.c.air.airTaskingOrder["DYNAMIC/SATELLITE/STRIKE/1/1"].packages)
  end)

  -- Boundary: target count one below minTargetCount
  it("should reject package when target count is one below minTargetCount", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 3
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    -- Only 2 targets, minTargetCount = 3
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1", "TGT-2" }))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: default minTargetCount used when not specified
  it("should use default minTargetCount of 1 when not specified", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300
              -- No minTargetCount specified, defaults to 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    -- Only 1 target, no minTargetCount => defaults to 1 => pass
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
  end)

  -- ============================================================================
  -- Boundary: Aircraft Assignment
  -- ============================================================================

  -- Boundary: assigned aircraft counted from existing ATO waves
  it("should account for already assigned aircraft in existing ATO waves", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 4, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

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

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base has 4 aircraft total available, 3 already assigned, needs 4 => 4-3=1 < half-strength threshold (2)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- 4 available - 3 assigned = 1, below half-strength threshold (2) => fail
    assert.is_false(result)
  end)

  -- Boundary: launched wave packages not counted
  it("should not count launched wave packages in assigned aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 3, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

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

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base has 4 aircraft available
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- Launched waves not counted: 4 available - 0 assigned >= 3 required => pass
    assert.is_true(result)
  end)

  -- Boundary: aircraft on missions not counted as available
  it("should not count aircraft already on missions as available", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 4, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base has 3 aircraft: AC-1 free, AC-2 on mission, AC-3 wrong DBID => only 1 available
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
        }
      end
      if guid == "AC-1" then return { dbid = 100, mission = nil } end
      if guid == "AC-2" then return { dbid = 100, mission = "CAP Mission" } end
      if guid == "AC-3" then return { dbid = 999, mission = nil } end
      return nil
    end))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- Only 1 available (AC-1), requires 4 => 1 < half-strength threshold (2) => fail
    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Base and Structure
  -- ============================================================================

  -- Boundary: base with no embarked aircraft
  it("should return false when base has no embarked aircraft", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base exists but has no embarked aircraft
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
      guid = "BASE-1",
      name = "Empty Air Base",
      embarkedUnits = nil
    }))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: base unit not found
  it("should fail aircraft validation when base unit not found", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "INVALID-BASE", unitCount = 2, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- Base not found
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Boundary: ATO structure not initialized
  it("should return false when ATO structure is not initialized", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })
    saveData.c.air.airTaskingOrder = nil -- Not initialized

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return {
          guid = "BASE-1",
          name = "Air Base",
          embarkedUnits = { Aircraft = { "AC-1", "AC-2" } }
        }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/SATELLITE/STRIKE/1/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- insertATOWave returns false when airTaskingOrder is nil
    assert.is_false(result)
  end)

  -- Boundary: empty packages array
  it("should return false when template has empty packages", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {}
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- No valid packages (empty) => no wave inserted
    assert.is_false(result)
  end)

  -- ============================================================================
  -- Boundary: Edge Cases
  -- ============================================================================

  -- Boundary: target configuration nil
  it("should skip package when target configuration is nil", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = nil
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- No valid packages (target is nil, processTargets returns empty) => rejected
    assert.is_false(result)
  end)

  -- Boundary: fixed targets with no objs
  it("should return no targets when fixed target objs is nil", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              contactAge = 300,
              minTargetCount = 1
              -- No filterNames and no objs
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    -- Fixed path with no objs => empty targets => insufficient
    assert.is_false(result)
  end)

  -- Boundary: unknown dynamic filter function
  it("should handle unknown dynamic filter function gracefully", function()
    local reconEntry = makeReconEntry({ type = "aircraft" })
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/1",
        isFirstWave = false,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            target = {
              areas = { { "RP-1", "RP-2" } },
              filterNames = { "nonExistentFilter" },
              contactAge = 600,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1 has 1 aircraft (below half-strength threshold of 2); BASE-2 has 4 (full strength)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", name = "Base Alpha", embarkedUnits = { Aircraft = { "AC-1" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", name = "Base Bravo", embarkedUnits = { Aircraft = { "AC-3", "AC-4", "AC-5", "AC-6" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/FALLBACK/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/2",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2", "BASE-3" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- All three bases have 1 aircraft, none reaches the half-strength threshold of 2
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "AC-1" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "AC-2" } } }
      elseif guid == "BASE-3" then
        return { guid = "BASE-3", embarkedUnits = { Aircraft = { "AC-3" } } }
      end
      return { dbid = 100, mission = nil }
    end))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
  end)

  -- Positive: each role resolves its base independently within the same package
  it("should resolve each role's base independently within a package", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/3",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            escort = {
              baseGUID = "BASE-1",
              unitCount = 2,
              unitDBID = 101,
              weaponDBID = 300
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- striker(dbid100, need4, half-threshold=2): BASE-1 has 1 (reject) -> falls back to BASE-2 (4)
    -- escort(dbid101, need2, half-threshold=1): BASE-1 has 2 -> resolves on BASE-1
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "S1", "E1", "E2" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "S2", "S3", "S4", "S5" } } }
      end
      if guid == "E1" or guid == "E2" then return { dbid = 101, mission = nil } end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/FALLBACK/3"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/3"]
    assert.is_table(wave)
    assert.are.equal("BASE-2", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-1", wave.packages[1].escort.baseGUID)
  end)

  -- Positive: second package in same wave falls back because first package consumed primary
  it("should deduct same-wave bookings so later packages fallback to candidates", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/4",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          },
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1 has exactly 4 aircraft (one package's worth); BASE-2 has 4 (the second package's fallback)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3", "AC-4" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "AC-5", "AC-6", "AC-7", "AC-8" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/FALLBACK/4"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/TANKER",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            tanker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 2,
              unitDBID = 102
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1: 1 striker (dbid 100) + 1 tanker (dbid 102) -> tanker insufficient (need 2)
    -- BASE-2: 2 tankers (dbid 102) -> tanker fallback satisfied
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "AC-S1", "AC-T1" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "AC-T2", "AC-T3" } } }
      end
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 102, mission = nil }
    end))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/FALLBACK/TANKER"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/FALLBACK/TANKER"]
    assert.is_table(wave)
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[1].tanker.baseGUID)
  end)

  -- Positive: jammer role also resolves baseGUIDCandidates
  it("should fallback jammer to baseGUIDCandidates when primary lacks jammers", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/FALLBACK/JAMMER",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 1, unitDBID = 100, weaponDBID = 200 },
            jammer = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 2,
              unitDBID = 103
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1: 1 striker + 1 jammer -> jammer insufficient (need 2)
    -- BASE-2: 2 jammers -> jammer fallback satisfied
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "AC-S1", "AC-J1" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "AC-J2", "AC-J3" } } }
      end
      if guid == "AC-S1" then return { dbid = 100, mission = nil } end
      return { dbid = 103, mission = nil }
    end))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(nil))
    trackStub(stub(GameApi, "Tool_Range").returns(200))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/FALLBACK/JAMMER"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/PARTIAL/1",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 4, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1 has exactly 2 of dbid 100 = half of the required 4 -> accepted at half strength
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", name = "Air Base", embarkedUnits = { Aircraft = { "AC-1", "AC-2" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/PARTIAL/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

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
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/PARTIAL/2",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = { baseGUID = "BASE-1", unitCount = 3, unitDBID = 100, weaponDBID = 200 },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- required=3 -> threshold is 1.5; 1 available is below it (would wrongly pass if the threshold were floored to 1)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", name = "Air Base", embarkedUnits = { Aircraft = { "AC-1" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    local stubGenName = trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_false(result)
    assert.stub(stubGenName).was_not.called()
  end)

  -- Positive: a package accepted at half strength still reserves its base, forcing the next package to fall back
  it("should reserve a half-strength base so a later package falls back to candidates", function()
    local reconEntry = makeReconEntry()
    local operation = {
      type = "air",
      executed = false,
      template = {
        name = "STRIKE/PARTIAL/3",
        isFirstWave = true,
        strikeInterval = 0,
        packages = {
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "TAOYUAN", subTypes = { "Runway" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          },
          {
            striker = {
              baseGUID = "BASE-1",
              baseGUIDCandidates = { "BASE-2" },
              unitCount = 4,
              unitDBID = 100,
              weaponDBID = 200
            },
            target = {
              objs = { { baseName = "HSINCHU", subTypes = { "Radar" } } },
              contactAge = 300,
              minTargetCount = 1
            }
          }
        }
      }
    }

    local saveData = makeSaveData({ reconEntry })

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    -- BASE-1 has 3 (>= half of 4, < full): package 1 is accepted at half strength and reserves BASE-1
    -- BASE-2 has 4 (full strength) so package 2 falls back there
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      if guid == "BASE-1" then
        return { guid = "BASE-1", embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } } }
      elseif guid == "BASE-2" then
        return { guid = "BASE-2", embarkedUnits = { Aircraft = { "AC-4", "AC-5", "AC-6", "AC-7" } } }
      end
      return { dbid = 100, mission = nil }
    end))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueAirOperationName").returns("DYNAMIC/PARTIAL/3"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicATOInsertion.process(makeConfig(), saveData, {})

    assert.is_true(result)
    local wave = saveData.c.air.airTaskingOrder["DYNAMIC/PARTIAL/3"]
    assert.is_table(wave)
    assert.are.equal(2, #wave.packages)
    -- Package 1 reserved BASE-1 at half strength; package 2 must fall back to BASE-2
    assert.are.equal("BASE-1", wave.packages[1].striker.baseGUID)
    assert.are.equal("BASE-2", wave.packages[2].striker.baseGUID)
  end)
end)
