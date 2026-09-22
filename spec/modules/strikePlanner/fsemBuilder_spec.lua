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
  ---Register a stub or spy so after_each reverts it
  ---@param testDouble luassert.spy Stub or spy to track
  ---@return luassert.spy # The same double, so calls can be chained inline
  local function trackStub(testDouble)
    table.insert(activeStubs, testDouble)
    return testDouble
  end

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a mock firing unit battery context
  ---@param overrides? table
  ---@return table
  local function makeBatteryContext(overrides)
    local context = {
      name = "Battery-1",
      state = constants.MISSILE_SYSTEM_STATE.HIDE,
      ammoThreshold = 40,
      weaponDBID = 3104
    }
    if overrides then
      for k, v in pairs(overrides) do context[k] = v end
    end
    return context
  end

  ---Create a mock reconnaissance trigger entry
  ---@param overrides? table
  ---@return table
  local function makeReconEntry(overrides)
    local entry = {
      time = "2026-02-14 00:00:00",
      delay = 0,
      type = "satellite"
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a mock strike operation with firing unit and target requirements
  ---@param overrides? table
  ---@return table
  local function makeOperation(overrides)
    local operation = {
      type = "ground",
      executed = false,
      template = {
        name = "TEST-OP/1",
        isFirstWave = true,
        strikeInterval = 60,
        fireSupportTasks = {
          {
            name = "FST-TEST",
            missileSystem = "SRBM",
            firingUnits = { { name = "Battery-1" } },
            target = { minTargetCount = 1, ammoPerTarget = 2 }
          }
        }
      }
    }
    if overrides then
      if overrides.templateName then
        operation.template.name = overrides.templateName
      end
      if overrides.isFirstWave ~= nil then
        operation.template.isFirstWave = overrides.isFirstWave
      end
      if overrides.strikeInterval then
        operation.template.strikeInterval = overrides.strikeInterval
      end
      if overrides.fireSupportTasks then
        operation.template.fireSupportTasks = overrides.fireSupportTasks
      end
      if overrides.firingUnits then
        operation.template.fireSupportTasks[1].firingUnits = overrides.firingUnits
      end
      if overrides.minTargetCount then
        operation.template.fireSupportTasks[1].target.minTargetCount = overrides.minTargetCount
      end
    end
    return operation
  end

  ---Create a mock scenario save data with ground operations state
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    local saveData = {
      c = {
        ground = {
          fireSupportPlan = {},
          srbm = {
            firingUnits = {
              ["Battery-1"] = makeBatteryContext()
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconTriggeredOperationBatches = {},
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }
    if overrides then
      if overrides.ground then
        saveData.c.ground = overrides.ground
      end
      if overrides.fireSupportPlan then
        saveData.c.ground.fireSupportPlan = overrides.fireSupportPlan
      end
      if overrides.srbmFiringUnits then
        saveData.c.ground.srbm.firingUnits = overrides.srbmFiringUnits
      end
      if overrides.reconTriggeredOperationBatches then
        saveData.c.dynamicOperations.reconTriggeredOperationBatches = overrides.reconTriggeredOperationBatches
      end
    end
    return saveData
  end

  ---Create full typed config for FsemBuilder tests
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  ---Find a Logger.log call matching the given message pattern
  ---@param pattern string Lua pattern to search for in the message
  ---@return boolean # Whether a matching call was found
  local function hasLogCall(pattern)
    for _, call in ipairs(logStub.calls) do
      if string.find(call.vals[2], pattern) then
        return true
      end
    end
    return false
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

      assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
    end)

    -- Negative: no ground operations available
    it("should return false when no ground operations are available", function()
      local saveData = makeSaveData({ reconTriggeredOperationBatches = { { type = "air" } } })

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      local filterOpsStub = trackStub(stub(DynamicState, "filterOperationsByType").returns({}))

      assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
      assert.stub(filterOpsStub).was.called(1)
      assert.are.equal("ground", filterOpsStub.calls[1].vals[2])
    end)

    -- Negative: trigger time not reached
    it("should skip operation when trigger time has not been reached", function()
      local reconEntry = makeReconEntry({ time = "2026-02-14 00:00:00", delay = 100 })
      local operation = { type = "ground", executed = false }
      local saveData = {
        c = {
          ground = { fireSupportPlan = {} },
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
      local markExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

      assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
      assert.stub(markExecutedStub).was_not.called()
    end)

    -- ============================================================================
    -- Operation Processing (recon triggered, template present)
    -- ============================================================================

    describe("with triggered ground operations", function()
      local markOperationExecutedStub
      local registerGeneratedOperationStub

      before_each(function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(DynamicState, "buildUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        markOperationExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))
        registerGeneratedOperationStub = trackStub(stub(DynamicState, "addGeneratedOperation"))
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

        local result = FsemBuilder.build(makeConfig(), saveData, {})

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

        FsemBuilder.build(makeConfig(), saveData, {})

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

        FsemBuilder.build(makeConfig(), saveData, {})

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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
        -- Observation window: insufficient targets keeps operation in schedule for retry
        assert.stub(markOperationExecutedStub).was_not.called()
      end)

      -- ============================================================================
      -- Firing Unit Validation
      -- ============================================================================

      -- Negative: nameless template entry resolves no context and is never assigned
      it("should not create FSEM when firing unit name is missing", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({ firingUnits = { {} } })
        local saveData = makeSaveData({ reconTriggeredOperationBatches = { reconEntry } })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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

        local result = FsemBuilder.build(makeConfig(), saveData, {})
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

        local result = FsemBuilder.build(makeConfig(), saveData, {})
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

        local result = FsemBuilder.build(makeConfig(), saveData, {})
        assert.is_true(result)
        local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
        assert.is_table(fsem)
        assert.are.equal(1, #fsem.fireSupportTasks)
        assert.are.equal("FST-1", fsem.fireSupportTasks[1].name)
      end)

      -- Pass-scoped cache: one CMO lookup per firing unit name within a single pass
      it("should look up each firing unit at most once per pass across FSTs", function()
        local reconEntry = makeReconEntry()
        local operation = makeOperation({
          fireSupportTasks = {
            {
              name = "FST-1",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            },
            {
              name = "FST-2",
              missileSystem = "SRBM",
              firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } },
              target = { minTargetCount = 1, ammoPerTarget = 2 }
            }
          }
        })
        -- Battery-2 never becomes assigned, so without a cache it is re-queried by every FST.
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext(),
            ["Battery-2"] = makeBatteryContext({
              name = "Battery-2",
              state = constants.MISSILE_SYSTEM_STATE.RELOAD
            })
          },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = operation }
        }))
        local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        assert.is_true(FsemBuilder.build(makeConfig(), saveData, {}))
        assert.are.equal(2, #getUnitStub.calls)
      end)

      -- Pass-scoped cache: assignment map is seeded once and shared across operations
      it("should share the firing unit cache and assignment map across operations in one pass", function()
        local reconEntry = makeReconEntry()
        local firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } }
        local firstOperation = makeOperation({ templateName = "TEST-OP/1", firingUnits = firingUnits })
        local secondOperation = makeOperation({ templateName = "TEST-OP/2", firingUnits = firingUnits })
        -- Battery-1 becomes assigned after the first operation; Battery-2 never does,
        -- so only the shared cache keeps the second operation from re-querying it.
        local saveData = makeSaveData({
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext(),
            ["Battery-2"] = makeBatteryContext({
              name = "Battery-2",
              state = constants.MISSILE_SYSTEM_STATE.RELOAD
            })
          },
          reconTriggeredOperationBatches = { reconEntry }
        })

        trackStub(stub(DynamicState, "filterOperationsByType").returns({
          { operationBatch = reconEntry, operation = firstOperation },
          { operationBatch = reconEntry, operation = secondOperation }
        }))
        local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
          return { guid = "U-" .. name, name = name }
        end))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        assert.is_true(FsemBuilder.build(makeConfig(), saveData, {}))
        -- Only the first operation gets Battery-1; the second sees it as already assigned.
        assert.spy(markOperationExecutedStub).was.called(1)
        assert.are.equal(2, #getUnitStub.calls)
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

        FsemBuilder.build(makeConfig(), saveData, {})

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

        local result = FsemBuilder.build(makeConfig(), saveData, {})
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

        FsemBuilder.build(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(1)
        assert.stub(errorStub).was_not.called()
        assert.is_true(hasLogCall("%[OK%]"))
        assert.is_true(hasLogCall("%[SKIP%]"))
        assert.is_true(hasLogCall("reason=insufficient_targets"))
        assert.is_true(hasLogCall("total=2"))
      end)
    end)

    -- ============================================================================
    -- Observation Window
    -- ============================================================================

    describe("observation window", function()
      local markOperationExecutedStub

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
        markOperationExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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
        markOperationExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

        assert.is_false(FsemBuilder.build(config, saveData, {}))
        assert.stub(markOperationExecutedStub).was_not.called()
        assert.are.equal(0, #reconEntry.operations)
        -- Emptying the batch closes it, so it stops being scanned altogether
        assert.is_true(reconEntry.executed)
        assert.stub(logStub).was.called(1)
        assert.is_true(hasLogCall("%[WARN%]"))
        assert.is_true(hasLogCall("reason=observation_window_expired"))
        assert.is_true(hasLogCall("state=abandoned"))
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
        markOperationExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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
        markOperationExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
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
        trackStub(stub(DynamicState, "setOperationExecuted"))

        FsemBuilder.build(makeConfig(), saveData, {})
        FsemBuilder.build(makeConfig(), saveData, {})
        FsemBuilder.build(makeConfig(), saveData, {})

        assert.stub(logStub).was.called(3)
        for i = 1, 3 do
          assert.is_true(hasLogCall("%[SKIP%]"))
          assert.is_true(hasLogCall("state=observing"))
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
        trackStub(stub(DynamicState, "buildUniqueGroundOperationName").returns("DYNAMIC/SAT/TEST/1"))
        trackStub(stub(DynamicState, "addGeneratedOperation"))
        local markExecutedStub = trackStub(stub(DynamicState, "setOperationExecuted"))

        -- Tick 1: insufficient targets, stays pending
        assert.is_false(FsemBuilder.build(makeConfig(), saveData, {}))
        assert.stub(markExecutedStub).was_not.called()

        -- Tick 2: targets accumulated, FSEM inserted
        processTargetsStub:revert()
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1", "TGT-2" }))

        assert.is_true(FsemBuilder.build(makeConfig(), saveData, {}))
        assert.stub(markExecutedStub).was.called(1)
        assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
      end)
    end)

    -- ============================================================================
    -- Stale Matrix Retirement
    -- ============================================================================

    describe("stale matrix retirement", function()
      ---Create an active unfinished fire support execution matrix (FSEM)
      ---@param overrides? table
      ---@return table
      local function makeActiveMatrix(overrides)
        local matrix = {
          name = "STALE-FSEM",
          isActivated = true,
          isFinished = false,
          allFiringUnitsInPosition = false,
          createdAt = nil,
          fireSupportTasks = {
            {
              name = "FST-HELD",
              missileSystem = "SRBM",
              isFinished = false,
              firingUnits = { { name = "Battery-1" } }
            }
          }
        }
        if overrides then
          for k, v in pairs(overrides) do matrix[k] = v end
        end
        return matrix
      end

      ---Count entries in a fire support plan map
      ---@param fireSupportPlan table<string, any>
      ---@return integer # Number of matrices in the plan
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

        assert.is_false(FsemBuilder.build(config, saveData, {}))
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
        local currentTimeStub = trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(timeStr)
          return triggerTimes[timeStr]
        end))
        trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
        trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

        -- Tick 1: first operation builds an FSEM holding Battery-1
        assert.is_true(FsemBuilder.build(config, saveData, {}))
        local firstFsem = saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-01"]
        assert.is_table(firstFsem)
        assert.are.equal(1000, firstFsem.createdAt)
        assert.is_true(operation1.executed)

        -- Tick 2 (not yet stale): competing operation stays blocked on Battery-1
        currentTimeStub.returns(1000 + staleAfterSec)
        assert.is_false(FsemBuilder.build(config, saveData, {}))
        assert.is_false(firstFsem.isFinished)
        assert.is_nil(saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-02"])

        -- Tick 3 (stale): FSEM retired, Battery-1 released and re-assigned
        currentTimeStub.returns(1000 + staleAfterSec + 1)
        assert.is_true(FsemBuilder.build(config, saveData, {}))
        assert.is_true(firstFsem.isFinished)
        assert.is_true(operation2.executed)
        local secondFsem = saveData.c.ground.fireSupportPlan["TEST-OP/1/DYN-SAT-02"]
        assert.is_table(secondFsem)
        assert.are.equal("Battery-1", secondFsem.fireSupportTasks[1].firingUnits[1].name)

        assert.is_true(hasLogCall("%[WARN%]"))
        assert.is_true(hasLogCall("reason=fsem_stale_timeout"))
        assert.is_true(hasLogCall("ageSec=" .. (staleAfterSec + 1)))
      end)

      -- Regression: retirement must survive a tick with nothing pending. A matrix whose
      -- targets vanished never fires, so no other path releases its firing units.
      it("should retire stale FSEM even when no ground operation is pending", function()
        local config = makeConfig()
        local currentTime = 1000 + config.c.recon.fsemStaleAfterSec + 1

        local matrix = makeActiveMatrix({ createdAt = 1000 })
        local saveData = makeSaveData({
          fireSupportPlan = { [matrix.name] = matrix },
          srbmFiringUnits = {
            ["Battery-1"] = makeBatteryContext({ state = constants.MISSILE_SYSTEM_STATE.STATIC })
          },
          reconTriggeredOperationBatches = {}
        })

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(currentTime))

        assert.is_false(FsemBuilder.build(config, saveData, {}))
        assert.is_true(matrix.isFinished)
        -- Retired, not deleted: the matrix stays in the FSP for name uniqueness checks
        assert.are.equal(1, countMatrices(saveData.c.ground.fireSupportPlan))
        assert.are.equal(currentTime, saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime)

        assert.is_true(hasLogCall("%[WARN%]"))
        assert.is_true(hasLogCall("matrix=STALE%-FSEM"))
        assert.is_true(hasLogCall("reason=fsem_stale_timeout"))
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

        assert.is_false(FsemBuilder.build(config, saveData, {}))
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

        FsemBuilder.build(config, saveData, {})

        assert.is_true(matrix.isFinished)
        local srbmUnits = saveData.c.ground.srbm.firingUnits
        assert.are.equal(currentTime, srbmUnits["Battery-S"].stowStartTime)
        assert.are.equal(currentTime, srbmUnits["Battery-R"].stowStartTime)
        assert.is_nil(srbmUnits["Battery-H"].stowStartTime)
        assert.are.equal(500, srbmUnits["Battery-P"].stowStartTime)
        assert.is_nil(srbmUnits["Battery-F"].stowStartTime)
        assert.is_nil(saveData.c.ground.sam.firingUnits["Sam-1"].stowStartTime)

        assert.is_true(hasLogCall("%[WARN%]"))
        assert.is_true(hasLogCall("matrix=STALE%-FSEM"))
        assert.is_true(hasLogCall("reason=fsem_stale_timeout"))
      end)

      -- Retire pass behavior with populated and empty FSP
      it("should handle both populated and empty fireSupportPlan correctly", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
        trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(100))
        trackStub(stub(TargetingProcess, "processTargets").returns({}))

        local operation = makeOperation()
        local reconEntry = makeReconEntry()
        reconEntry.operations = { operation }
        local saveDataWithEmptyFSP = {
          c = {
            ground = { fireSupportPlan = {} },
            dynamicOperations = {
              enabled = true,
              reconTriggeredOperationBatches = { reconEntry }
            }
          }
        }

        assert.is_false(FsemBuilder.build(makeConfig(), saveDataWithEmptyFSP, {}))

        local operation2 = makeOperation()
        local reconEntry2 = makeReconEntry()
        reconEntry2.operations = { operation2 }
        local saveDataWithAnotherEmptyFSP = {
          c = {
            ground = { fireSupportPlan = {}, srbm = { firingUnits = {} } },
            dynamicOperations = {
              enabled = true,
              reconTriggeredOperationBatches = { reconEntry2 }
            }
          }
        }

        assert.is_false(FsemBuilder.build(makeConfig(), saveDataWithAnotherEmptyFSP, {}))
      end)
    end)
  end)
end)
