-- FsemBuilder Unit Tests
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")
local BaseConfig = require("src.core.config")


describe("FsemBuilder", function()
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
      name = overrides.name or "Battery-1",
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
          reconTriggeredOperationBatches = overrides.reconTriggeredOperationBatches or {},
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }
  end

  ---Create full typed config for FsemBuilder tests
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

      assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
    end)

    -- Negative: dynamicOperations is nil
    it("should return false when dynamicOperations is nil", function()
      local saveData = { c = {} }

      assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
    end)

    -- Negative: no ground operations available
    it("should return false when no ground operations are available", function()
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = true,
            reconTriggeredOperationBatches = {}
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      local stubFilterOps = trackStub(stub(DynamicState, "filterOperationsByType").returns({}))

      assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
            reconTriggeredOperationBatches = { reconEntry }
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
      trackStub(stub(DynamicState, "filterOperationsByType").returns({
        { operationBatch = reconEntry, operation = operation }
      }))
      markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

      assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
      assert.stub(markOperationExecutedStub).was_not.called()
    end)

    -- Negative: template is missing
    it("should abandon the operation and return false when template is missing", function()
      local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
      local operation = { type = "ground", executed = false }
      reconEntry.operations = { operation }
      local saveData = {
        c = {
          dynamicOperations = {
            enabled = true,
            reconTriggeredOperationBatches = { reconEntry }
          }
        }
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(100))
      trackStub(stub(DynamicState, "filterOperationsByType").returns({
        { operationBatch = reconEntry, operation = operation }
      }))
      markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

      assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
      assert.stub(markOperationExecutedStub).was_not.called()
      -- Dropped from the batch, so OperationScheduler re-opens this wave instead of
      -- treating it as a completed predecessor.
      assert.are.equal(0, #reconEntry.operations)
    end)

    -- ============================================================================
    -- Operation Processing (recon triggered, template present)
    -- ============================================================================

    describe("with triggered ground operations", function()
      before_each(function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(DynamicState, "generateUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))
        registerGeneratedOperationStub = trackStub(stub(DynamicState, "registerGeneratedOperation"))
      end)

      -- ============================================================================
      -- Successful FSEM Creation
      -- ============================================================================

      -- Positive: standard successful creation
      it("should create and insert FSEM when targets and firing units are available", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = FsemBuilder.execute(makeConfig(), saveData, {})

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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        FsemBuilder.execute(makeConfig(), saveData, {})

        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_true(fsem.isActivated)
        assert.is_false(fsem.isFinished)
        assert.are.equal(0, fsem.strikeInterval)
      end)

      -- Positive: createdAt stamped for stale retirement tracking
      it("should stamp createdAt with matrix start time on new FSEM", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        FsemBuilder.execute(makeConfig(), saveData, {})

        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.are.equal(1000, fsem.createdAt)
      end)

      -- ============================================================================
      -- Target Evaluation
      -- ============================================================================

      -- Negative: insufficient targets
      it("should return false and keep operation pending when targets are insufficient", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: unit not found in game
      it("should not create FSEM when firing unit is not found in game", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: battery context not found in saveData
      it("should not create FSEM when firing unit context is not found in saveData", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({
          srbmFiringUnits = {},
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(registerGeneratedOperationStub).was_not.called()
      end)

      -- Negative: low ammunition
      it("should not create FSEM when firing unit has low ammunition", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(true))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = FsemBuilder.execute(makeConfig(), saveData, {})
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
            ["Battery-2"] = makeBatteryContext({
              name = "Battery-2",
              state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
            }),
            ["Battery-3"] = makeBatteryContext({ name = "Battery-3" })
          },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = FsemBuilder.execute(makeConfig(), saveData, {})
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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = FsemBuilder.execute(makeConfig(), saveData, {})
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
            ["Battery-2"] = makeBatteryContext({ name = "Battery-2" })
          },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        FsemBuilder.execute(makeConfig(), saveData, {})

        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.are.equal(2, #fsem.fireSupportTasks)
        -- taskIndex=1: 1000 + (1*120) = 1120, taskIndex=2: 1000 + (2*120) = 1240
        local expectedTime1 = os.date(constants.DATE_FORMAT, 1120)
        local expectedTime2 = os.date(constants.DATE_FORMAT, 1240)
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
            ["Battery-2"] = makeBatteryContext({ name = "Battery-2" })
          },
          reconTriggeredOperationBatches = { reconEntry1, reconEntry2 }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        local result = FsemBuilder.execute(makeConfig(), saveData, {})
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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry1, reconEntry2 } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        FsemBuilder.execute(makeConfig(), saveData, {})

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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry1, reconEntry2 } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry1, operation = operation1 },
          { operationBatch = reconEntry2, operation = operation2 }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        FsemBuilder.execute(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(1)
        assert.stub(errorStub).was.called(1)
        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[OK%]"))
        assert.truthy(logMessage:find("total=1"))
        local errorMessage = errorStub.calls[1].vals[1]
        assert.truthy(errorMessage:find("%[ERROR%]"))
        assert.truthy(errorMessage:find("reason=missing_fsem_template", 1, true))
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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(500))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
        assert.stub(logStub).was_not.called()
      end)

      -- Negative: window expired (current time past trigger + windowSec)
      it("should abandon the operation and emit warning log when window expires", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation()
        reconEntry.operations = { operation }
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        local config = makeConfig()
        local triggerTime = 1000
        local pastDeadline = triggerTime + config.c.recon.observationWindowSec + 1

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(pastDeadline))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(triggerTime))
        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

        assert.is_false(FsemBuilder.execute(config, saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
        assert.are.equal(0, #reconEntry.operations)
        -- Emptying the batch closes it, so it stops being scanned altogether
        assert.is_true(reconEntry.executed)
        assert.stub(logStub).was.called(1)
        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[WARN%]"))
        assert.truthy(logMessage:find("reason=observation_window_expired"))
        assert.truthy(logMessage:find("state=abandoned"))
      end)

      -- Negative: insufficient targets keeps operation pending (no markExecuted)
      it("should keep operation pending when targets are insufficient inside window", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))
        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
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
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
      end)

      -- Positive: SKIP log emitted every tick the operation is still observing
      it("should emit [SKIP] log every tick while operation is observing", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ minTargetCount = 5 })
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))
        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(DynamicState, "markOperationExecuted"))

        FsemBuilder.execute(makeConfig(), saveData, {})
        FsemBuilder.execute(makeConfig(), saveData, {})
        FsemBuilder.execute(makeConfig(), saveData, {})

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
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        local processTargetsStub = trackStub(stub(TargetingProcess, "processTargets").returns({}))

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
        trackStub(stub(DynamicState, "generateUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        trackStub(stub(DynamicState, "registerGeneratedOperation"))
        markOperationExecutedStub = trackStub(stub(DynamicState, "markOperationExecuted"))

        -- Tick 1: insufficient targets, stays pending
        assert.is_false(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()

        -- Tick 2: targets accumulated, FSEM inserted
        processTargetsStub:revert()
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1", "TGT-2" }))

        assert.is_true(FsemBuilder.execute(makeConfig(), saveData, {}))
        assert.stub(markOperationExecutedStub).was.called(1)
        assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
      end)
    end)

    -- ============================================================================
    -- Stale Matrix Retirement
    -- ============================================================================

    describe("stale matrix retirement", function()
      ---Build an active unfinished matrix holding Battery-1 by default
      ---@param overrides? table
      ---@return table matrix
      local function makeActiveMatrix(overrides)
        overrides = overrides or {}
        return {
          name = overrides.name or "STALE-FSEM",
          isActivated = true,
          isFinished = false,
          allFiringUnitsInPosition = false,
          createdAt = overrides.createdAt,
          fireSupportTasks = overrides.fireSupportTasks or {
            {
              name = "FST-HELD",
              missileSystem = "SRBM",
              isFinished = false,
              firingUnits = { { name = "Battery-1" } }
            }
          }
        }
      end

      ---Count entries of a map-shaped fireSupportPlan table
      ---@param fireSupportPlan table<string, any>
      ---@return integer count
      local function countMatrices(fireSupportPlan)
        local count = 0
        for _ in pairs(fireSupportPlan) do
          count = count + 1
        end
        return count
      end

      -- Boundary: age exactly at the threshold does not retire, units stay assigned
      it("should keep matrix active and units assigned at exactly the stale boundary", function()
        local config = makeConfig()
        local currentTime = 1000 + config.c.recon.fsemStaleAfterSec

        local operation = makeOperation()
        local reconEntry = makeReconEntry()
        reconEntry.operations = { operation }
        local matrix = makeActiveMatrix({ createdAt = 1000 })
        local saveData = makeSaveData({
          fireSupportPlan = { [matrix.name] = matrix },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(currentTime))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(currentTime))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        assert.is_false(FsemBuilder.execute(config, saveData, {}))
        assert.is_false(matrix.isFinished)
        -- Battery-1 still assigned: no new FSEM built, operation stays pending for retry
        assert.are.equal(1, countMatrices(saveData.c.ground.fireSupportPlan))
        assert.are.equal(1, #reconEntry.operations)
      end)

      -- Positive: stale FSEM retired and its units re-assigned end to end
      it("should retire stale FSEM and let a new operation reuse its firing units", function()
        local config = makeConfig()
        local staleAfterSec = config.c.recon.fsemStaleAfterSec

        local operation1 = makeOperation()
        local operation2 = makeOperation()
        local batch1 = makeReconEntry({ time = "BATCH-1" })
        local batch2 = makeReconEntry({ time = "BATCH-2" })
        batch1.operations = { operation1 }
        batch2.operations = { operation2 }
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { batch1, batch2 } })

        local triggerTimes = { ["BATCH-1"] = 1000, ["BATCH-2"] = 2000 }
        local timeStub = trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(timeStr)
          return triggerTimes[timeStr]
        end))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        -- Tick 1: first operation builds an FSEM holding Battery-1
        assert.is_true(FsemBuilder.execute(config, saveData, {}))
        local firstFsem = saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-01"]
        assert.is_table(firstFsem)
        assert.are.equal(1000, firstFsem.createdAt)
        assert.is_true(operation1.executed)

        -- Tick 2 (not yet stale): competing operation stays blocked on Battery-1
        timeStub.returns(1000 + staleAfterSec)
        assert.is_false(FsemBuilder.execute(config, saveData, {}))
        assert.is_false(firstFsem.isFinished)
        assert.is_nil(saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-02"])

        -- Tick 3 (stale): FSEM retired, Battery-1 released and re-assigned
        timeStub.returns(1000 + staleAfterSec + 1)
        assert.is_true(FsemBuilder.execute(config, saveData, {}))
        assert.is_true(firstFsem.isFinished)
        assert.is_true(operation2.executed)
        local secondFsem = saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-02"]
        assert.is_table(secondFsem)
        assert.are.equal("Battery-1", secondFsem.fireSupportTasks[1].firingUnits[1].name)

        local retireLogMessage = logStub.calls[3].vals[2]
        assert.truthy(retireLogMessage:find("%[WARN%]"))
        assert.truthy(retireLogMessage:find("reason=fsem_stale_timeout"))
        assert.truthy(retireLogMessage:find("ageSec=" .. (staleAfterSec + 1)))
      end)

      -- Negative: legacy matrix without createdAt never goes stale
      it("should never retire matrices without createdAt", function()
        local config = makeConfig()
        local farFuture = 1000 + config.c.recon.fsemStaleAfterSec * 10

        local operation = makeOperation()
        local reconEntry = makeReconEntry()
        reconEntry.operations = { operation }
        local matrix = makeActiveMatrix({ createdAt = nil })
        local saveData = makeSaveData({
          fireSupportPlan = { [matrix.name] = matrix },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(farFuture))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(farFuture))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        assert.is_false(FsemBuilder.execute(config, saveData, {}))
        assert.is_false(matrix.isFinished)
        assert.are.equal(1, countMatrices(saveData.c.ground.fireSupportPlan))
      end)

      -- Positive: retire starts the stow countdown only for deployed non-SAM units
      it("should stamp stowStartTime on deployed units when retiring, skipping SAM and existing countdowns", function()
        local config = makeConfig()
        local currentTime = 1000 + config.c.recon.fsemStaleAfterSec + 1

        local operation = makeOperation()
        local reconEntry = makeReconEntry()
        reconEntry.operations = { operation }
        local matrix = makeActiveMatrix({
          createdAt = 1000,
          fireSupportTasks = {
            {
              name = "FST-SRBM",
              missileSystem = "SRBM",
              isFinished = false,
              firingUnits = {
                { name = "Battery-S" },
                { name = "Battery-R" },
                { name = "Battery-H" },
                { name = "Battery-P" }
              }
            },
            {
              name = "FST-SAM",
              missileSystem = "SAM",
              isFinished = false,
              firingUnits = { { name = "Sam-1" } }
            },
            {
              name = "FST-DONE",
              missileSystem = "SRBM",
              isFinished = true,
              firingUnits = { { name = "Battery-F" } }
            }
          }
        })
        local saveData = makeSaveData({
          fireSupportPlan = { [matrix.name] = matrix },
          srbmFiringUnits = {
            ["Battery-S"] = makeBatteryContext({ name = "Battery-S", state = constants.MISSILE_SYSTEM_STATE.STATIC }),
            ["Battery-R"] = makeBatteryContext({
              name = "Battery-R",
              state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
            }),
            ["Battery-H"] = makeBatteryContext({ name = "Battery-H", state = constants.MISSILE_SYSTEM_STATE.HIDE }),
            ["Battery-P"] = makeBatteryContext({ name = "Battery-P", state = constants.MISSILE_SYSTEM_STATE.STATIC }),
            ["Battery-F"] = makeBatteryContext({ name = "Battery-F", state = constants.MISSILE_SYSTEM_STATE.STATIC })
          },
          reconTriggeredOperationBatches = { reconEntry }
        })
        saveData.c.ground.srbm.firingUnits["Battery-P"].stowStartTime = 500
        saveData.c.ground.sam = {
          firingUnits = {
            ["Sam-1"] = makeBatteryContext({ name = "Sam-1", state = constants.MISSILE_SYSTEM_STATE.STATIC })
          }
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(currentTime))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(currentTime))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))

        FsemBuilder.execute(config, saveData, {})

        assert.is_true(matrix.isFinished)
        local srbmUnits = saveData.c.ground.srbm.firingUnits
        assert.are.equal(currentTime, srbmUnits["Battery-S"].stowStartTime)
        assert.are.equal(currentTime, srbmUnits["Battery-R"].stowStartTime)
        assert.is_nil(srbmUnits["Battery-H"].stowStartTime)
        assert.are.equal(500, srbmUnits["Battery-P"].stowStartTime)
        assert.is_nil(srbmUnits["Battery-F"].stowStartTime)
        assert.is_nil(saveData.c.ground.sam.firingUnits["Sam-1"].stowStartTime)

        local logMessage = logStub.calls[1].vals[2]
        assert.truthy(logMessage:find("%[WARN%]"))
        assert.truthy(logMessage:find("matrix=STALE%-FSEM"))
        assert.truthy(logMessage:find("reason=fsem_stale_timeout"))
      end)

      -- Negative: retire pass tolerates saveData without ground context or plan
      it("should not crash when saveData has no ground context or fireSupportPlan", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(100))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))

        local operation = makeOperation()
        local reconEntry = makeReconEntry()
        reconEntry.operations = { operation }
        local saveDataWithoutGround = {
          c = {
            dynamicOperations = {
              enabled = true,
              reconTriggeredOperationBatches = { reconEntry }
            }
          }
        }

        assert.is_false(FsemBuilder.execute(makeConfig(), saveDataWithoutGround, {}))

        local operation2 = makeOperation()
        local reconEntry2 = makeReconEntry()
        reconEntry2.operations = { operation2 }
        local saveDataWithoutPlan = {
          c = {
            ground = { srbm = { firingUnits = {} } },
            dynamicOperations = {
              enabled = true,
              reconTriggeredOperationBatches = { reconEntry2 }
            }
          }
        }

        assert.is_false(FsemBuilder.execute(makeConfig(), saveDataWithoutPlan, {}))
      end)
    end)
  end)
end)
