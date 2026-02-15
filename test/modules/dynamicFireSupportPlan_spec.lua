-- DynamicFireSupportPlan Unit Tests
---@diagnostic disable: undefined-field
local DynamicFireSupportPlan = require("src.modules.strikePlanner.dynamicFireSupportPlan")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local MissileSystem = require("src.modules.missileSystem")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")

describe("DynamicFireSupportPlan", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

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
              ["Battery-1"] = {
                state = constants.MISSILE_SYSTEM_STATE.HIDE,
                ammoThreshold = 40,
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
end)
