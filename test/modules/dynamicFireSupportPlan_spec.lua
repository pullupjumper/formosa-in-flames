-- DynamicFireSupportPlan Unit Tests
---@diagnostic disable: undefined-field
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local MissileSystem = require("src.modules.missileSystem")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

describe("DynamicFireSupportPlan", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  -- ============================================================================
  -- Test Data Factories
  -- ============================================================================

  local function createBatteryContext(state)
    return {
      state = state or constants.MISSILE_SYSTEM_STATE.HIDE,
      ammoThreshold = 40,
      weaponDBID = 3104
    }
  end

  local function createReconEntry(overrides)
    overrides = overrides or {}
    return {
      time = overrides.time or "2026-02-14 00:00:00",
      delay = overrides.delay or 0,
      type = overrides.type or "satellite"
    }
  end

  local function createOperation(opts)
    opts = opts or {}
    return {
      type = "ground",
      executed = false,
      template = {
        name = opts.templateName or "TEST-OP/1",
        isFirstWave = true,
        strikeInterval = opts.strikeInterval or 60,
        fireSupportTasks = opts.fireSupportTasks or {
          {
            name = "FST-TEST",
            missileSystem = "SRBM",
            firingUnits = opts.firingUnits or { { name = "Battery-1" } },
            target = { minTargetCount = opts.minTargetCount or 1, ammoPerTarget = 2 }
          }
        }
      }
    }
  end

  local function createSaveData(opts)
    opts = opts or {}
    return {
      c = {
        ground = opts.ground or {
          fireSupportPlan = opts.fireSupportPlan or {},
          srbm = {
            firingUnits = opts.srbmFiringUnits or {
              ["Battery-1"] = createBatteryContext()
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconSchedule = opts.reconSchedule or {},
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }
  end

  local function stubCommonDeps(filterResult, opts)
    opts = opts or {}
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns(filterResult))
    trackStub(stub(TargetingProcess, "processTargets").returns({ "TGT-1" }))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns(
      opts.matrixName or "DYNAMIC/SAT/TEST/1"
    ))
    return {
      markExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted")),
      register = trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    }
  end

  -- ============================================================================
  -- Setup / Teardown
  -- ============================================================================

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Early Exit
  -- ============================================================================

  it("should return false when dynamic operations are disabled", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = false
        }
      }
    }

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
  end)

  it("should return false when no ground operations are available", function()
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconSchedule = {}
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    local stubFilterOps = trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({}))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubFilterOps).was.called(1)
    assert.are.equal("ground", stubFilterOps.calls[1].vals[2])
  end)

  it("should skip operation when trigger time has not been reached", function()
    local reconEntry = { time = "2026-02-14 00:00:00", delay = 100, type = "satellite" }
    local operation = { type = "ground", executed = false }
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(50))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubMarkExecuted).was_not.called()
  end)

  it("should mark operation executed and return false when template is missing", function()
    local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
    local operation = { type = "ground", executed = false }
    local saveData = {
      c = {
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(100))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubMarkExecuted).was.called(1)
    assert.is_true(stubMarkExecuted.calls[1].vals[3])
  end)

  it("should return false when dynamicOperations is nil", function()
    local saveData = { c = {} }
    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
  end)

  -- ============================================================================
  -- Successful FSEM Creation
  -- ============================================================================

  it("should create and insert FSEM successfully for fixed target task", function()
    local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "satellite" }
    local operation = {
      type = "ground",
      executed = false,
      template = {
        name = "INFRASTRUCTURE/1",
        isFirstWave = true,
        strikeInterval = 60,
        fireSupportTasks = {
          {
            name = "FST-INFRA",
            missileSystem = "SRBM",
            firingUnits = { { name = "Battery-1" } },
            target = {
              objs = {
                { baseName = "HSINCHU", subTypes = { "Radar" } }
              },
              contactAge = 300,
              minTargetCount = 1,
              ammoPerTarget = 2
            }
          }
        }
      }
    }

    local saveData = {
      c = {
        targetlist = {
          { name = "HSINCHU/Radar", subType = "Radar", guid = "TGT-1" }
        },
        ground = {
          fireSupportPlan = {},
          srbm = {
            firingUnits = {
              ["Battery-1"] = createBatteryContext()
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry },
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(1000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    trackStub(stub(TargetingProcess, "filterTargetsByTypeAndBase").returns({ "TGT-1" }))
    trackStub(stub(TargetingProcess, "assessTargetsDamage").returns({ "TGT-1" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "UNIT-1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns("DYNAMIC/SATELLITE/INFRA/1"))
    local stubRegister = trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    local stubMarkExecuted = trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})

    assert.is_true(result)
    assert.stub(stubRegister).was.called(1)
    assert.stub(stubMarkExecuted).was.called(1)
    assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SATELLITE/INFRA/1"])
    assert.are.equal(1, #saveData.c.ground.fireSupportPlan["DYNAMIC/SATELLITE/INFRA/1"].fireSupportTasks)
  end)

  it("should use dynamic filter and pass shouldTrack for tracking filters", function()
    local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "aircraft" }
    local operation = {
      type = "ground",
      executed = false,
      template = {
        name = "ANTISHIP/1",
        isFirstWave = false,
        strikeInterval = 0,
        fireSupportTasks = {
          {
            name = "FST-SEA",
            missileSystem = "SRBM",
            firingUnits = { { name = "Battery-2" } },
            target = {
              areas = { { "RP-1", "RP-2", "RP-3", "RP-4" } },
              filterNames = { "findNavalTargets" },
              contactAge = 600,
              minTargetCount = 1,
              ammoPerTarget = 1
            }
          }
        }
      }
    }

    local saveData = {
      c = {
        targetlist = {},
        ground = {
          fireSupportPlan = {},
          srbm = {
            firingUnits = {
              ["Battery-2"] = {
                state = constants.MISSILE_SYSTEM_STATE.HIDE,
                ammoThreshold = 50,
                weaponDBID = 3104
              }
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry },
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2000))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    local stubFindNavalTargets = trackStub(stub(TargetingProcess, "findNavalTargets").returns({ "SEA-1" }))
    local stubFilterByType = trackStub(stub(TargetingProcess, "filterTargetsByTypeAndBase").returns({}))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "UNIT-2", name = "Battery-2" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns("DYNAMIC/AIRCRAFT/SEA/1"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})

    assert.is_true(result)
    assert.stub(stubFindNavalTargets).was.called(1)
    assert.is_true(stubFindNavalTargets.calls[1].vals[1].shouldTrack)
    assert.stub(stubFilterByType).was_not.called()
    assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/AIRCRAFT/SEA/1"])
  end)

  it("should set shouldTrack when tracking filter is not the first filter", function()
    local reconEntry = { time = "2026-02-14 00:00:00", delay = 0, type = "aircraft" }
    local operation = {
      type = "ground",
      executed = false,
      template = {
        name = "ANTISHIP/1",
        isFirstWave = false,
        strikeInterval = 0,
        fireSupportTasks = {
          {
            name = "FST-SEA-MULTI",
            missileSystem = "SRBM",
            firingUnits = { { name = "Battery-3" } },
            target = {
              areas = { { "RP-1", "RP-2", "RP-3", "RP-4" } },
              filterNames = { "findInfantry", "findNavalTargets" },
              contactAge = 600,
              minTargetCount = 1,
              ammoPerTarget = 1
            }
          }
        }
      }
    }

    local saveData = {
      c = {
        targetlist = {},
        ground = {
          fireSupportPlan = {},
          srbm = {
            firingUnits = {
              ["Battery-3"] = {
                state = constants.MISSILE_SYSTEM_STATE.HIDE,
                ammoThreshold = 50,
                weaponDBID = 3104
              }
            }
          }
        },
        dynamicOperations = {
          enabled = true,
          reconSchedule = { reconEntry },
          generatedOperations = { ground = {}, air = {} }
        }
      }
    }

    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(2100))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2100))
    trackStub(stub(DynamicOperationsUtils, "filterOperationsByType").returns({
      { reconEntry = reconEntry, operation = operation }
    }))
    local stubFindInfantry = trackStub(stub(TargetingProcess, "findInfantry").returns({}))
    local stubFindNavalTargets = trackStub(stub(TargetingProcess, "findNavalTargets").returns({ "SEA-2" }))
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "UNIT-3", name = "Battery-3" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
    trackStub(stub(DynamicOperationsUtils, "generateUniqueGroundOperationName").returns("DYNAMIC/AIRCRAFT/SEA/2"))
    trackStub(stub(DynamicOperationsUtils, "registerGeneratedOperation"))
    trackStub(stub(DynamicOperationsUtils, "markOperationExecuted"))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})

    assert.is_true(result)
    assert.stub(stubFindInfantry).was.called(1)
    assert.stub(stubFindNavalTargets).was.called(1)
    assert.is_true(stubFindNavalTargets.calls[1].vals[1].shouldTrack)
    assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/AIRCRAFT/SEA/2"])
  end)

  -- ============================================================================
  -- Target Evaluation
  -- ============================================================================

  it("should return false when targets are insufficient for all tasks", function()
    local reconEntry = createReconEntry()
    local operation = createOperation({ minTargetCount = 5 })
    local saveData = createSaveData({ reconSchedule = { reconEntry } })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.markExecuted).was.called(1)
  end)

  -- ============================================================================
  -- Firing Unit Validation
  -- ============================================================================

  it("should not create FSEM when firing unit name is missing", function()
    local reconEntry = createReconEntry()
    local operation = createOperation({ firingUnits = { {} } })
    local saveData = createSaveData({ reconSchedule = { reconEntry } })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should not create FSEM when firing unit is already assigned to active FSEM", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({
      fireSupportPlan = {
        ["EXISTING-FSEM"] = {
          isFinished = false,
          isActivated = true,
          fireSupportTasks = {
            { isFinished = false, firingUnits = { { name = "Battery-1" } } }
          }
        }
      },
      reconSchedule = { reconEntry }
    })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should not create FSEM when firing unit is not found in game", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({ reconSchedule = { reconEntry } })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should not create FSEM when firing unit context is not found in saveData", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({
      srbmFiringUnits = {},
      reconSchedule = { reconEntry }
    })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should not create FSEM when firing unit is not in HIDE state", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({
      srbmFiringUnits = {
        ["Battery-1"] = createBatteryContext(constants.MISSILE_SYSTEM_STATE.REPOSITIONING)
      },
      reconSchedule = { reconEntry }
    })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should not create FSEM when firing unit has low ammunition", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({ reconSchedule = { reconEntry } })

    local stubs = stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(true))

    assert.is_false(DynamicFireSupportPlan.execute({}, saveData, {}))
    assert.stub(stubs.register).was_not.called()
  end)

  it("should treat firing units in finished or inactive FSEMs as available", function()
    local reconEntry = createReconEntry()
    local operation = createOperation()
    local saveData = createSaveData({
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
      reconSchedule = { reconEntry }
    })

    stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})
    assert.is_true(result)
    assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"])
  end)

  -- ============================================================================
  -- FSEM Construction Edge Cases
  -- ============================================================================

  it("should create FSEM with only available firing units when some are unavailable", function()
    local reconEntry = createReconEntry()
    local operation = createOperation({
      firingUnits = {
        { name = "Battery-1" },
        { name = "Battery-2" },
        { name = "Battery-3" }
      }
    })
    local saveData = createSaveData({
      srbmFiringUnits = {
        ["Battery-1"] = createBatteryContext(),
        ["Battery-2"] = createBatteryContext(constants.MISSILE_SYSTEM_STATE.REPOSITIONING),
        ["Battery-3"] = createBatteryContext()
      },
      reconSchedule = { reconEntry }
    })

    stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
      return { guid = "U-" .. name, name = name }
    end))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})
    assert.is_true(result)
    local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
    assert.is_table(fsem)
    local firingUnits = fsem.fireSupportTasks[1].firingUnits
    assert.are.equal(2, #firingUnits)
    assert.are.equal("Battery-1", firingUnits[1].name)
    assert.are.equal("Battery-3", firingUnits[2].name)
  end)

  it("should prevent same firing unit from being assigned to multiple FSTs in same build cycle", function()
    local reconEntry = createReconEntry()
    local operation = createOperation({
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
    local saveData = createSaveData({ reconSchedule = { reconEntry } })

    stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})
    assert.is_true(result)
    local fsem = saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/TEST/1"]
    assert.is_table(fsem)
    assert.are.equal(1, #fsem.fireSupportTasks)
    assert.are.equal("FST-1", fsem.fireSupportTasks[1].name)
  end)

  it("should apply strikeInterval to sequential FST start times", function()
    local reconEntry = createReconEntry()
    local operation = createOperation({
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
    local saveData = createSaveData({
      srbmFiringUnits = {
        ["Battery-1"] = createBatteryContext(),
        ["Battery-2"] = createBatteryContext()
      },
      reconSchedule = { reconEntry }
    })

    stubCommonDeps({ { reconEntry = reconEntry, operation = operation } })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
      return { guid = "U-" .. name, name = name }
    end))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

    DynamicFireSupportPlan.execute({}, saveData, {})

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

  it("should handle mixed results across multiple ground operations", function()
    local reconEntry1 = createReconEntry()
    local reconEntry2 = createReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
    local operation1 = createOperation({ templateName = "GOOD-OP/1" })
    local operation2 = createOperation({ templateName = "BAD-OP/1", minTargetCount = 10 })
    local saveData = createSaveData({
      srbmFiringUnits = {
        ["Battery-1"] = createBatteryContext(),
        ["Battery-2"] = createBatteryContext()
      },
      reconSchedule = { reconEntry1, reconEntry2 }
    })

    local stubs = stubCommonDeps({
      { reconEntry = reconEntry1, operation = operation1 },
      { reconEntry = reconEntry2, operation = operation2 }
    }, { matrixName = "DYNAMIC/SAT/GOOD/1" })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
      return { guid = "U-" .. name, name = name }
    end))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))

    local result = DynamicFireSupportPlan.execute({}, saveData, {})
    assert.is_true(result)
    assert.is_table(saveData.c.ground.fireSupportPlan["DYNAMIC/SAT/GOOD/1"])
    assert.stub(stubs.markExecuted).was.called(2)
  end)

  -- ============================================================================
  -- Consolidated Log Output
  -- ============================================================================

  it("should output single info log for successful and skipped operations without error log", function()
    local reconEntry1 = createReconEntry()
    local reconEntry2 = createReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
    local operation1 = createOperation({ templateName = "GOOD-OP/1" })
    local operation2 = createOperation({ templateName = "SKIP-OP/1", minTargetCount = 10 })
    local saveData = createSaveData({ reconSchedule = { reconEntry1, reconEntry2 } })

    stubCommonDeps({
      { reconEntry = reconEntry1, operation = operation1 },
      { reconEntry = reconEntry2, operation = operation2 }
    }, { matrixName = "DYNAMIC/SAT/GOOD/1" })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
    local stubLog = trackStub(stub(Logger, "log"))
    local stubError = trackStub(stub(Logger, "error"))

    DynamicFireSupportPlan.execute({}, saveData, {})

    assert.stub(stubLog).was.called(1)
    assert.stub(stubError).was_not.called()
    local logMessage = stubLog.calls[1].vals[2]
    assert.truthy(logMessage:find("%[OK%]"))
    assert.truthy(logMessage:find("%[SKIP%]"))
    assert.truthy(logMessage:find("2 items"))
  end)

  it("should output both info and error logs when results are mixed", function()
    local reconEntry1 = createReconEntry()
    local reconEntry2 = createReconEntry({ time = "2026-02-14 00:10:00", type = "aircraft" })
    local operation1 = createOperation({ templateName = "GOOD-OP/1" })
    local operation2 = { type = "ground", executed = false }
    local saveData = createSaveData({ reconSchedule = { reconEntry1, reconEntry2 } })

    stubCommonDeps({
      { reconEntry = reconEntry1, operation = operation1 },
      { reconEntry = reconEntry2, operation = operation2 }
    }, { matrixName = "DYNAMIC/SAT/GOOD/1" })
    trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
    trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
    local stubLog = trackStub(stub(Logger, "log"))
    local stubError = trackStub(stub(Logger, "error"))

    DynamicFireSupportPlan.execute({}, saveData, {})

    assert.stub(stubLog).was.called(1)
    assert.stub(stubError).was.called(1)
    local logMessage = stubLog.calls[1].vals[2]
    assert.truthy(logMessage:find("%[OK%]"))
    assert.truthy(logMessage:find("1 items"))
    local errorMessage = stubError.calls[1].vals[1]
    assert.truthy(errorMessage:find("%[ERROR%]"))
    assert.truthy(errorMessage:find("1 items"))
  end)
end)
