---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- FireSupportPlan Unit Tests
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local AttackManager = require("src.modules.attackManager")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

describe("FireSupportPlan", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local currentTimeStub
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
    currentTimeStub = trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(0))
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

  ---China SRBM config for the batteries the tests task
  local CONFIG = { red = { ground = { missileSystemTypes = { srbm = { launchers = {
    ["Battery-1"] = { name = "Battery-1", ammoThreshold = 40, weaponDBID = 3104 },
    ["Battery-2"] = { name = "Battery-2", ammoThreshold = 40, weaponDBID = 3105 },
  } } } } } }

  ---@param overrides? table
  ---@return table plannerState
  local function makePlannerState(overrides)
    overrides = overrides or {}
    local task = {
      name = overrides.taskName or "FST-ALPHA",
      missileSystemType = overrides.missileSystemType or "SRBM",
      isFinished = overrides.taskFinished or false,
      startTime = overrides.startTime or "2026-02-14 00:00:00",
      launcherNames = overrides.launcherNames or { "Battery-1" },
      target = {
        list = overrides.targetList or { "TGT-1", "TGT-2" },
        objs = {},
        areas = {},
        minTargetCount = overrides.minTargetCount or 1,
        ammoPerTarget = overrides.ammoPerTarget or 2
      }
    }

    local matrix = {
      name = overrides.matrixName or "FSEM-1",
      isActivated = overrides.isActivated == nil and true or overrides.isActivated,
      isFinished = overrides.matrixFinished or false,
      allLaunchersInPosition = overrides.allLaunchersInPosition or false,
      fireSupportTasks = { task }
    }

    return {
      ground = {
        fireSupportPlan = { [matrix.name] = matrix },
        missileSystemTypes = {
          srbm = {
            launchers = {
              ["Battery-1"] = {
                name = "Battery-1",
                state = overrides.launcherState or constants.MISSILE_UNIT_POSTURE.HIDE,
              }
            }
          }
        }
      }
    }
  end

  -- ============================================================================
  -- Matrix Filtering
  -- ============================================================================

  describe("matrix filtering", function()
    -- Negative: finished matrix skipped
    it("should skip finished matrices", function()
      local plannerState = makePlannerState({ matrixFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Negative: non-activated matrix skipped
    it("should skip non-activated matrices", function()
      local plannerState = makePlannerState({ isActivated = false })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Boundary: empty plan
    it("should handle empty fireSupportPlan without errors", function()
      local plannerState = { ground = { fireSupportPlan = {} } }

      FireSupportPlan.process(CONFIG, plannerState)

      assert.are.same({}, plannerState.ground.fireSupportPlan)
    end)
  end)

  -- ============================================================================
  -- Task Processing
  -- ============================================================================

  describe("task processing", function()
    -- Negative: finished task skipped
    it("should skip finished tasks", function()
      local plannerState = makePlannerState({ taskFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Negative: start time not reached
    it("should skip tasks whose start time has not been reached", function()
      local plannerState = makePlannerState({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubGetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Launcher Deployment
  -- ============================================================================

  describe("launcher deployment", function()
    -- Positive: each unit is handed to missileSystem by its ground state, system and name
    it("should send each launcher to its firing point through MissileSystem", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.HIDE })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local stubSend = trackStub(stub(MissileSystem, "sendToFiringPoint").returns(false, false))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubSend).was.called(1)
      assert.stub(stubSend).was.called_with(CONFIG, plannerState.ground, constants.SIDES.RED, {
        missileSystemType = "SRBM", launcherName = "Battery-1"
      })
    end)

    -- Positive: all units at firing point
    it("should set allLaunchersInPosition to true when all units are at STATIC state", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.allLaunchersInPosition)
    end)

    -- Boundary: destroyed unit is removed and the emptied task closes (dead unit cleanup)
    it("should remove destroyed unit, close emptied task and finish matrix", function()
      local plannerState = makePlannerState({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts"))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      local task = matrix.fireSupportTasks[1]
      assert.are.equal(0, #task.launcherNames)
      assert.is_true(task.isFinished)
      assert.is_true(matrix.allLaunchersInPosition)
      assert.is_true(matrix.isFinished)
      assert.stub(stubAttack).was_not.called()
    end)

    -- Boundary: a unit without runtime state is dropped like a destroyed one
    it("should remove a launcher that has no runtime context", function()
      local plannerState = makePlannerState({})
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"] = nil
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "UNIT-1", name = "Battery-1" }))

      FireSupportPlan.process(CONFIG, plannerState)

      local task = plannerState.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.are.equal(0, #task.launcherNames)
      assert.is_true(task.isFinished)
    end)

    -- Negative: not at STATIC state
    it("should set allLaunchersInPosition to false when unit is not at STATIC state", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.REPOSITIONING })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allLaunchersInPosition)
    end)

    -- Boundary: mixed states across multiple units
    it("should set allLaunchersInPosition to false when any unit is not at STATIC state", function()
      local plannerState = makePlannerState({
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-1" then return { guid = "U1", name = "Battery-1" } end
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      trackStub(stub(MissileSystem, "sendToFiringPoint").returns(false, false))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allLaunchersInPosition)
    end)
  end)

  -- ============================================================================
  -- Dead Unit Cleanup
  -- ============================================================================

  describe("dead unit cleanup", function()
    -- Positive: destroyed unit removed while the survivor fires
    it("should remove destroyed unit and let surviving unit fire", function()
      local plannerState = makePlannerState({
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.STATIC
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      local task = matrix.fireSupportTasks[1]
      assert.are.same({ "Battery-2" }, task.launcherNames)
      assert.is_true(matrix.allLaunchersInPosition)
      assert.stub(stubAttack).was.called(1)
      assert.are.same({ { name = "Battery-2", weaponDBID = 3105 } }, stubAttack.calls[1].vals[1].attackingUnits)
      assert.is_true(task.isFinished)
    end)

    -- Positive: emptied task no longer blocks sibling task strikes in the same matrix
    it("should not block sibling task strike when another task loses all units", function()
      local plannerState = makePlannerState({})
      table.insert(plannerState.ground.fireSupportPlan["FSEM-1"].fireSupportTasks, {
        name = "FST-BETA",
        missileSystemType = "SRBM",
        isFinished = false,
        startTime = "2026-02-14 00:00:00",
        launcherNames = { "Battery-2" },
        target = {
          list = { "TGT-9" },
          objs = {},
          areas = {},
          minTargetCount = 1,
          ammoPerTarget = 1
        }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.STATIC
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(1))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.fireSupportTasks[1].isFinished)
      assert.is_true(matrix.fireSupportTasks[2].isFinished)
      assert.stub(stubAttack).was.called(1)
      assert.are.same({ { name = "Battery-2", weaponDBID = 3105 } }, stubAttack.calls[1].vals[1].attackingUnits)
      assert.is_true(matrix.isFinished)
    end)
  end)

  -- ============================================================================
  -- Strike Execution
  -- ============================================================================

  describe("strike execution", function()
    -- Positive: attack succeeds and marks task finished
    it("should call attackContacts and mark task finished when result > 0", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubAttack).was.called(1)
      assert.are.same({ "TGT-1", "TGT-2" }, stubAttack.calls[1].vals[1].contacts)
      assert.are.equal(2, stubAttack.calls[1].vals[1].qty)

      local task = plannerState.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.is_true(task.isFinished)
    end)

    -- Positive: each launcher attacks with the weapon its config names
    it("should pair each launcher with its configured weapon for attackContacts", function()
      local plannerState = makePlannerState({
        launcherState = constants.MISSILE_UNIT_POSTURE.STATIC,
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.STATIC
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubAttack).was.called(1)
      assert.are.same({
        { name = "Battery-1", weaponDBID = 3104 },
        { name = "Battery-2", weaponDBID = 3105 },
      }, stubAttack.calls[1].vals[1].attackingUnits)
    end)

    -- Negative: attack returns 0
    it("should not mark task finished when attackContacts returns 0", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      local task = plannerState.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.is_false(task.isFinished)
    end)

    -- Positive: target threshold is handled before FSP execution
    it("should pass existing targets to attackContacts without checking minTargetCount", function()
      local plannerState = makePlannerState({
        launcherState = constants.MISSILE_UNIT_POSTURE.STATIC,
        targetList = {},
        minTargetCount = 2
      })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubAttack).was.called_with({
        contacts = {},
        qty = 2,
        attackingUnits = { { name = "Battery-1", weaponDBID = 3104 } },
      })
    end)

    -- Negative: units not in position blocks all strikes
    it("should not execute strikes when launchers are not all in position", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "sendToFiringPoint").returns(false, false))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts"))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(stubAttack).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Stow Window Trigger
  -- ============================================================================

  describe("stow window trigger", function()
    -- Positive: non-SAM strike stamps stowStartTime on launchers
    it("should set stowStartTime on launchers after non-SAM strike succeeds", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.are.equal(5000, plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"].stowStartTime)
    end)

    -- Negative: SAM strike does not stamp stowStartTime
    it("should not set stowStartTime when missile system is SAM", function()
      local plannerState = makePlannerState({
        missileSystemType = "SAM",
        launcherState = constants.MISSILE_UNIT_POSTURE.STATIC
      })
      plannerState.ground.missileSystemTypes.sam = {
        launchers = {
          ["Battery-1"] = {
            state = constants.MISSILE_UNIT_POSTURE.STATIC
          }
        }
      }
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.is_nil(plannerState.ground.missileSystemTypes.sam.launchers["Battery-1"].stowStartTime)
    end)

    -- Negative: zero-result strike leaves stowStartTime untouched
    it("should not set stowStartTime when attackContacts returns 0", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.is_nil(plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"].stowStartTime)
    end)

    -- Boundary: existing stowStartTime is preserved
    it("should not overwrite existing stowStartTime when strike succeeds", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"].stowStartTime = 1000
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.are.equal(1000, plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"].stowStartTime)
    end)

    -- Boundary: every launcher in a multi-unit task gets stowStartTime
    it("should set stowStartTime on every launcher in a multi-unit task", function()
      local plannerState = makePlannerState({
        launcherState = constants.MISSILE_UNIT_POSTURE.STATIC,
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.STATIC
      }
      currentTimeStub.returns(7777)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-1" then return { guid = "U1", name = "Battery-1" } end
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.are.equal(7777, plannerState.ground.missileSystemTypes.srbm.launchers["Battery-1"].stowStartTime)
      assert.are.equal(7777, plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- Matrix Completion
  -- ============================================================================

  describe("matrix completion", function()
    -- Positive: all tasks finished
    it("should mark matrix as finished when all tasks are finished", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").invokes(function(opts)
        return #opts.contacts > 0 and 2 or 0
      end))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)

    -- Positive: tasks pre-finished before strike
    it("should mark matrix finished when tasks were already finished before strike", function()
      local plannerState = makePlannerState({ taskFinished = true })

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)

    -- Negative: some tasks not finished
    it("should not mark matrix as finished when some tasks are not finished", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      table.insert(plannerState.ground.fireSupportPlan["FSEM-1"].fireSupportTasks, {
        name = "FST-BETA",
        missileSystemType = "SRBM",
        isFinished = false,
        startTime = "2026-02-14 00:00:00",
        launcherNames = { "Battery-1" },
        target = {
          list = {},
          objs = {},
          areas = {},
          minTargetCount = 5,
          ammoPerTarget = 2
        }
      })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").invokes(function(opts)
        return #opts.contacts > 0 and 2 or 0
      end))

      FireSupportPlan.process(CONFIG, plannerState)

      local matrix = plannerState.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.isFinished)
    end)
  end)

  -- ============================================================================
  -- Multiple Matrices
  -- ============================================================================

  describe("multiple matrices", function()
    -- Positive: independent processing
    it("should process multiple matrices independently", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })
      plannerState.ground.fireSupportPlan["FSEM-2"] = {
        name = "FSEM-2",
        isActivated = false,
        isFinished = false,
        allLaunchersInPosition = false,
        fireSupportTasks = {
          {
            name = "FST-BRAVO",
            missileSystemType = "SRBM",
            isFinished = false,
            startTime = "2026-02-14 00:00:00",
            launcherNames = { "Battery-1" },
            target = {
              list = { "TGT-3" },
              objs = {},
              areas = {},
              minTargetCount = 1,
              ammoPerTarget = 1
            }
          }
        }
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.is_true(plannerState.ground.fireSupportPlan["FSEM-1"].isFinished)
      assert.is_false(plannerState.ground.fireSupportPlan["FSEM-2"].isFinished)
    end)
  end)

  -- ============================================================================
  -- Logging
  -- ============================================================================

  describe("logging", function()
    -- Positive: strike results logged
    it("should log strike results when attacks are executed", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      assert.are.equal("ground", logStub.calls[1].vals[1])
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[OK%]"))
      assert.is_truthy(string.find(logMessage, "action=strike"))
      assert.is_truthy(string.find(logMessage, "task=FST%-ALPHA action=strike fired=4"))
    end)

    -- Positive: pending units logged
    it("should log pending info when launchers are not in position", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "sendToFiringPoint").returns(false, false))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[SKIP%]"))
      assert.is_truthy(string.find(logMessage, "reason=launchers_not_in_position"))
      assert.is_truthy(string.find(logMessage, "task=FST%-ALPHA"))
      -- Separator-free values stay unquoted under the single escaping rule
      assert.is_truthy(string.find(logMessage, "units=Battery%-1 reason=launchers_not_in_position"))
    end)

    -- Positive: completion logged without strike info
    it("should log completion without strike info when tasks were pre-finished", function()
      local plannerState = makePlannerState({ taskFinished = true })

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[OK%]"))
      assert.is_truthy(string.find(logMessage, "state=finished"))
      assert.is_falsy(string.find(logMessage, "action=strike"))
    end)

    -- Negative: no log on empty plan
    it("should not log when no active matrices exist", function()
      local plannerState = { ground = { fireSupportPlan = {} } }

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was_not.called()
    end)

    -- Negative: no log when attack returns zero
    it("should not log when attack returns zero and units are in position", function()
      local plannerState = makePlannerState({ launcherState = constants.MISSILE_UNIT_POSTURE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was_not.called()
    end)

    -- Positive: WARN dead_unit_cleanup carries removed unit names and closed-task flag
    it("should log WARN dead_unit_cleanup with removed unit names and taskClosed", function()
      local plannerState = makePlannerState({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[WARN%]"))
      assert.is_truthy(string.find(logMessage, "action=dead_unit_cleanup"))
      assert.is_truthy(string.find(logMessage, "units=Battery%-1"))
      assert.is_truthy(string.find(logMessage, "taskClosed=true"))
    end)

    -- Positive: taskClosed=false when survivors keep the task open after cleanup
    it("should log taskClosed=false when surviving units remain after cleanup", function()
      local plannerState = makePlannerState({
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.STATIC
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "action=dead_unit_cleanup"))
      assert.is_truthy(string.find(logMessage, "units=Battery%-1"))
      assert.is_truthy(string.find(logMessage, "taskClosed=false"))
    end)

    -- Regression: surviving multi-unit not-ready names keep the original order
    it("should keep notReadyNames in original unit order for surviving units", function()
      local plannerState = makePlannerState({
        launcherNames = { "Battery-1", "Battery-2" }
      })
      plannerState.ground.missileSystemTypes.srbm.launchers["Battery-2"] = {
        state = constants.MISSILE_UNIT_POSTURE.HIDE
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        return { guid = "U-" .. name, name = name }
      end))
      trackStub(stub(MissileSystem, "sendToFiringPoint").returns(false, false))

      FireSupportPlan.process(CONFIG, plannerState)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[SKIP%]"))
      assert.is_truthy(string.find(logMessage, "units=Battery%-1,Battery%-2"))
    end)
  end)
end)
