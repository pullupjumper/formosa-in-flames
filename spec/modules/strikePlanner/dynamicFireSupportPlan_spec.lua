-- DynamicFireSupportPlan Unit Tests
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")
local BaseConfig = require("src.core.config")

describe("DynamicFireSupportPlan", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  ---@type luassert.spy
  local markOperationExecutedStub
  ---@type luassert.spy
  local registerGeneratedOperationStub
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  local function makeBatteryContext(overrides)
    overrides = overrides or {}
    return {
      state = overrides.state or constants.MISSILE_SYSTEM_STATE.HIDE,
      ammoThreshold = overrides.ammoThreshold or 40,
      weaponDBID = overrides.weaponDBID or 3104
    }
  end

  local function makeReconEntry(overrides)
    overrides = overrides or {}
    return {
      time = overrides.time or "2026-02-14 00:00:00",
      delay = overrides.delay or 0,
      type = overrides.type or "satellite"
    }
  end

  local function makeOperation(overrides)
    overrides = overrides or {}
    return {
      type = "ground",
      executed = false,
      template = {
        name = overrides.templateName or "TEST-OP/1",
        isFirstWave = overrides.isFirstWave ~= nil and overrides.isFirstWave or true,
        strikeInterval = overrides.strikeInterval or 60,
        fireSupportTasks = overrides.fireSupportTasks or {
          {
            name = "FST-TEST",
            missileSystem = "SRBM",
            firingUnits = overrides.firingUnits or { { name = "Battery-1" } },
            target = { minTargetCount = overrides.minTargetCount or 1, ammoPerTarget = 2 }
          }
        }
      }
    }
  end

  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        ground = overrides.ground or {
          fireSupportPlan = overrides.fireSupportPlan or {},
          srbm = {
            firingUnits = overrides.srbmFiringUnits or {
              ["Battery-1"] = makeBatteryContext()
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperations = overrides.reconTriggeredOperations or {},
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }
  end

  ---Create full typed config for DynamicFireSupportPlan tests
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  -- ============================================================================
  -- Setup / Teardown
  -- ============================================================================

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  describe("execute", function()
    -- ============================================================================
    -- Early Exit
    -- ============================================================================

    -- Negative: dynamicOperations disabled
    it("should return false when dynamic operations are disabled", function()
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = false
          }
        }
      }

      assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
    end)

    -- Negative: dynamicOperations is nil
    it("should return false when dynamicOperations is nil", function()
      local saveData = { c = {} }

      assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
    end)

    -- Negative: no ground operations available
    it("should return false when no ground operations are available", function()
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = true,
            reconTriggeredOperations = {}
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      local stubFilterOps = trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({}))

      assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
      assert.stub(stubFilterOps).was.called(1)
      assert.are.equal("ground", stubFilterOps.calls[1].vals[2])
    end)

    -- Negative: trigger time not reached
    it("should skip operation when trigger time has not been reached", function()
      local reconEntry = { time = "2026-02-14 00:00:00", delay = 100, type = "satellite" }
      local operation = { type = "ground", executed = false }
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = true,
            reconTriggeredOperations = { reconEntry }
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
      trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
        { operationBatch = reconEntry, operation = operation }
      }))
      markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

      assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
      assert.stub(markOperationExecutedStub).was_not.called()
    end)

    -- Negative: template is missing
    it("should mark operation executed and return false when template is missing", function()
      local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
      local operation = { type = "ground", executed = false }
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = true,
            reconTriggeredOperations = { reconEntry }
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(100))
      trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
        { operationBatch = reconEntry, operation = operation }
      }))
      markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

      assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
      assert.stub(markOperationExecutedStub).was.called(1)
      assert.is_false(markOperationExecutedStub.calls[1].vals[3])
    end)

    -- ============================================================================
    -- Operation Processing (recon triggered, template present)
    -- ============================================================================

    describe("with triggered ground operations", function()
      before_each(function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))
        registerGeneratedOperationStub = trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
      end)

      -- ============================================================================
      -- Successful FSEM Creation
      -- ============================================================================

      -- Positive: standard successful creation
      it("should create and insert FSEM when targets and firing units are available", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        assert.is_true(result)
        assert.stub(registerGeneratedOperationStub).was.called(1)
        assert.stub(markOperationExecutedStub).was.called(1)
        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_table(fsem)
        assert.are.equal(1, #fsem.fireSupportTasks)
      end)

      -- Positive: FSEM structure fields
      it("should set FSEM fields correctly with isActivated true and strikeInterval 0", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_true(fsem.isActivated)
        assert.is_false(fsem.isFinished)
        assert.are.equal(0, fsem.strikeInterval)
      end)

      -- ============================================================================
      -- Target Evaluation
      -- ============================================================================

      -- Negative: insufficient targets
      it("should return false and keep operation pending when targets are insufficient", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        -- Observation window: insufficient targets keeps operation in schedule for retry
        assert.stub(markOperationExecutedStub).was_not.called()
      end)

      -- ============================================================================
      -- Firing Unit Validation
      -- ============================================================================

      -- Negative: firing unit name is missing
      it("should not create FSEM when firing unit name is missing", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ firingUnits = { {} } })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: firing unit already assigned to active FSEM
      it("should not create FSEM when firing unit is already assigned to active FSEM", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          fireSupportPlan = {
            ["EXISTING-FSEM"] = {
              isFinished = false,
              isActivated = true,
              fireSupportTasks = {
                { isFinished = false, firingUnits = { { name = "Battery-1" } } }
              }
            }
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: unit not found in game
      it("should not create FSEM when firing unit is not found in game", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: battery context not found in saveData
      it("should not create FSEM when firing unit context is not found in saveData", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          srbmFiringUnits = {},
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: battery not in HIDE state
      it("should not create FSEM when firing unit is not in HIDE state", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext({ state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING })
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: low ammunition
      it("should not create FSEM when firing unit has low ammunition", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(true))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Boundary: finished/inactive FSEM should not block assignment
      it("should treat firing units in finished or inactive FSEMs as available", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          fireSupportPlan = {
            ["FINISHED-FSEM"] = {
              isFinished = true,
              isActivated = true,
              fireSupportTasks = {
                { isFinished = true, firingUnits = { { name = "Battery-1" } } }
              }
            },
            ["INACTIVE-FSEM"] = {
              isFinished = false,
              isActivated = false,
              fireSupportTasks = {
                { isFinished = false, firingUnits = { { name = "Battery-1" } } }
              }
            }
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        assert.is_true(result)
        assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
      end)

      -- ============================================================================
      -- FSEM Construction Edge Cases
      -- ============================================================================

      -- Positive: partial firing unit availability
      it("should create FSEM with only available firing units when some are unavailable", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({
          firingUnits = {
            { name = "Battery-1" },
            { name = "Battery-2" },
            { name = "Battery-3" }
          }
        })
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext(),
            ["Battery-2"] = makeBatteryContext({ state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING }),
            ["Battery-3"] = makeBatteryContext()
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        assert.is_true(result)
        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_table(fsem)
        local firingUnits = fsem.fireSupportTasks[1].firingUnits
        assert.are.equal(2, #firingUnits)
        assert.are.equal("Battery-1", firingUnits[1].name)
        assert.are.equal("Battery-3", firingUnits[2].name)
      end)

      -- Boundary: same firing unit referenced by multiple FSTs
      it("should prevent same firing unit from being assigned to multiple FSTs in same build cycle", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({
          fireSupportTasks = {
            {
              name = "FST-1",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-1" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            },
            {
              name = "FST-2",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-1" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            }
          }
        })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        assert.is_true(result)
        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_table(fsem)
        assert.are.equal(1, #fsem.fireSupportTasks)
        assert.are.equal("FST-1", fsem.fireSupportTasks[1].name)
      end)

      -- Positive: strikeInterval applied to sequential FSTs
      it("should apply strikeInterval to sequential FST start times", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({
          strikeInterval = 120,
          fireSupportTasks = {
            {
              name = "FST-1",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-1" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            },
            {
              name = "FST-2",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-2" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            }
          }
        })
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext(),
            ["Battery-2"] = makeBatteryContext()
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.are.equal(2, #fsem.fireSupportTasks)
        -- taskIndex=1: 1000 + (1*120) = 1120, taskIndex=2: 1000 + (2*120) = 1240
        local expectedTime1 = os.date("!%Y-%m-%d %H:%M:%S", 1120)
        local expectedTime2 = os.date("!%Y-%m-%d %H:%M:%S", 1240)
        assert.are.equal(expectedTime1, fsem.fireSupportTasks[1].startTime)
        assert.are.equal(expectedTime2, fsem.fireSupportTasks[2].startTime)
      end)

      -- ============================================================================
      -- Multiple Operations
      -- ============================================================================

      -- Positive: mixed success/failure across operations
      it("should handle mixed results across multiple ground operations", function()
        local reconEntry1 = makeReconEntry()
        local reconEntry2 = makeReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
        local operation1 = makeOperation({ templateName = "GOOD-OP/1" })
        local operation2 = makeOperation({ templateName = "BAD-OP/1", minTargetCount = 10 })
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext(),
            ["Battery-2"] = makeBatteryContext()
          },
          reconTriggeredOperations = { reconEntry1, reconEntry2 }
        })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        assert.is_true(result)
        assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
        -- operation1 (success) marks executed; operation2 (insufficient targets) stays pending
        assert.stub(markOperationExecutedStub).was.called(1)
      end)

      -- ============================================================================
      -- Consolidated Log Output
      -- ============================================================================

      -- Positive: info log for successful and waiting operations
      it("should output single info log mixing OK and SKIP outcomes without error log", function()
        local reconEntry1 = makeReconEntry()
        local reconEntry2 = makeReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
        local operation1 = makeOperation({ templateName = "GOOD-OP/1" })
        local operation2 = makeOperation({ templateName = "WAIT-OP/1", minTargetCount = 10 })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry1, reconEntry2 } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(1)
        assert.stub(errorStub).was_not.called()
        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[OK%]"))
        assert.truthy(logMessage:find("%[SKIP%]"))
        assert.truthy(logMessage:find("reason=insufficient_targets"))
        assert.truthy(logMessage:find("total=2"))
      end)

      -- Positive: both info and error logs for mixed results
      it("should output both info and error logs when results are mixed", function()
        local reconEntry1 = makeReconEntry()
        local reconEntry2 = makeReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
        local operation1 = makeOperation({ templateName = "GOOD-OP/1" })
        local operation2 = { type = "ground", executed = false }
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry1, reconEntry2 } })

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(1)
        assert.stub(errorStub).was.called(1)
        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[OK%]"))
        assert.truthy(logMessage:find("total=1"))
        local errorMessage = errorStub.calls[1].vals[1]
        assert.truthy(errorMessage:find("%[ERROR%]"))
        assert.truthy(errorMessage:find("total=1"))
      end)
    end)

    -- ============================================================================
    -- Observation Window
    -- ============================================================================

    describe("observation window", function()
      -- Negative: pre-trigger (current time before reconEntry trigger time)
      it("should silently skip operations before observation window opens", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(500))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
        assert.stub(logStub).was_not.called()
      end)

      -- Negative: window expired (current time past trigger + windowSec)
      it("should mark operation executed=false and emit warning log when window expires", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        local config = makeConfig()
        local triggerTime = 1000
        local pastDeadline = triggerTime + config.c.recon.observationWindowSec + 1

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(pastDeadline))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(triggerTime))
        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        assert.is_false(DynamicFireSupportPlan.execute(config, saveData, {}))
        assert.stub(markOperationExecutedStub).was.called(1)
        assert.is_false(markOperationExecutedStub.calls[1].vals[3])
        assert.stub(logStub).was.called(1)
        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[WARN%]"))
        assert.truthy(logMessage:find("reason=observation_window_expired"))
      end)

      -- Negative: insufficient targets keeps operation pending (no markExecuted)
      it("should keep operation pending when targets are insufficient inside window", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))
        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
      end)

      -- Negative: no firing units available keeps operation pending
      it("should keep operation pending when no firing units are available inside window", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext({ state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING })
          },
          reconTriggeredOperations = { reconEntry }
        })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
      end)

      -- Positive: SKIP log emitted every tick the operation is still observing
      it("should emit [SKIP] log every tick while operation is observing", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))
        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})
        DynamicFireSupportPlan.execute(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(3)
        for i = 1, 3 do
          assert.truthy(logStub.calls[i].vals[2]:find("%[SKIP%]"))
          assert.truthy(logStub.calls[i].vals[2]:find("state=observing"))
        end
      end)

      -- Positive: targets accumulating mid-window leads to FSEM insertion
      it("should insert FSEM when targets accumulate to satisfy minTargetCount mid-window", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 2 })
        local saveData = makeSaveData({ reconTriggeredOperations = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        local processTargetsStub = trackStub(stub(TargetingProcess, "processTargets").returns({}))

        trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
        trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
        markOperationExecutedStub = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

        -- Tick 1: insufficient targets, stays pending
        assert.is_false(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()

        -- Tick 2: targets accumulated, FSEM inserted
        processTargetsStub:revert()
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1", "TGT-2" }))

        assert.is_true(DynamicFireSupportPlan.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was.called(1)
        assert.is_true(markOperationExecutedStub.calls[1].vals[3])
        assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
      end)
    end)
  end)
end)
