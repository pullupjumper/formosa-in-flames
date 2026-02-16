-- FireSupportPlan Unit Tests
---@diagnostic disable: undefined-field
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AttackManager = require("src.modules.attackManager")
local MissileSystem = require("src.modules.missileSystem")
local constants = require("src.core.constants")

describe("FireSupportPlan", function()
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

  -- ============================================================================
  -- Helper: build saveData with a single FSEM
  -- ============================================================================

  ---@param overrides? table
  ---@return table saveData
  local function buildSaveData(overrides)
    overrides = overrides or {}
    local task = {
      name = overrides.taskName or "FST-ALPHA",
      missileSystem = overrides.missileSystem or "SRBM",
      isFinished = overrides.taskFinished or false,
      startTime = overrides.startTime or "2026-02-14 00:00:00",
      firingUnits = overrides.firingUnits or { { name = "Battery-1" } },
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
      allFiringUnitsInPosition = overrides.allFiringUnitsInPosition or false,
      fireSupportTasks = { task }
    }

    return {
      c = {
        ground = {
          fireSupportPlan = { [matrix.name] = matrix },
          srbm = {
            firingUnits = {
              ["Battery-1"] = {
                state = overrides.firingUnitState or constants.MISSILE_SYSTEM_STATE.HIDE,
                ammoThreshold = 40,
                weaponDBID = 3104
              }
            }
          }
        }
      }
    }
  end

  -- ============================================================================
  -- Matrix filtering
  -- ============================================================================

  describe("matrix filtering", function()
    it("should handle empty fireSupportPlan", function()
      local saveData = { c = { ground = { fireSupportPlan = {} } } }

      FireSupportPlan.strike(saveData)

      -- No errors thrown, plan remains empty
      assert.are.same({}, saveData.c.ground.fireSupportPlan)
    end)

    it("should skip finished matrices", function()
      local saveData = buildSaveData({ matrixFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    it("should skip non-activated matrices", function()
      local saveData = buildSaveData({ isActivated = false })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Task processing (processFireSupportTask)
  -- ============================================================================

  describe("task processing", function()
    it("should skip finished tasks", function()
      local saveData = buildSaveData({ taskFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    it("should skip tasks whose start time has not been reached", function()
      local saveData = buildSaveData({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubGetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Firing unit deployment (shouldDeployToFiringPoint)
  -- ============================================================================

  describe("firing unit deployment", function()
    it("should set allFiringUnitsInPosition to false when unit not found", function()
      local saveData = buildSaveData({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)

    it("should call moveToFiringPoint when unit is in HIDE state and not low ammo", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was.called(1)
    end)

    it("should not call moveToFiringPoint when unit state is not HIDE", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(AttackManager, "attackContacts").returns(0))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was_not.called()
    end)

    it("should not call moveToFiringPoint when unit has low ammo", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(true))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was_not.called()
    end)

    it("should set allFiringUnitsInPosition to false when unit is not at STATIC state", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.REPOSITIONING })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)

    it("should set allFiringUnitsInPosition to true when all units are at STATIC state", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.allFiringUnitsInPosition)
    end)

    it("should handle multiple firing units with mixed states", function()
      local saveData = buildSaveData({
        firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } }
      })
      saveData.c.ground.srbm.firingUnits["Battery-2"] = {
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        ammoThreshold = 40,
        weaponDBID = 3104
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-1" then return { guid = "U1", name = "Battery-1" } end
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
      trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      -- Battery-1 is HIDE (not STATIC), Battery-2 is REPOSITIONING (not STATIC)
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)
  end)

  -- ============================================================================
  -- Strike execution (executeFireSupportTasks)
  -- ============================================================================

  describe("strike execution", function()
    it("should call attackContacts and mark task finished when result > 0", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.stub(stubAttack).was.called(1)
      assert.are.same({ "TGT-1", "TGT-2" }, stubAttack.calls[1].vals[1].contacts)
      assert.are.equal(2, stubAttack.calls[1].vals[1].qty)

      local task = saveData.c.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.is_true(task.isFinished)
    end)

    it("should not mark task finished when attackContacts returns 0", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      local task = saveData.c.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.is_false(task.isFinished)
    end)

    it("should not execute strike when target count is below minTargetCount", function()
      local saveData = buildSaveData({
        firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC,
        targetList = {},
        minTargetCount = 2
      })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubAttack).was_not.called()
    end)

    it("should pass firingUnits to attackContacts", function()
      local firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } }
      local saveData = buildSaveData({
        firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC,
        firingUnits = firingUnits
      })
      saveData.c.ground.srbm.firingUnits["Battery-2"] = {
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        ammoThreshold = 40,
        weaponDBID = 3104
      }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.strike(saveData)

      assert.stub(stubAttack).was.called(1)
      assert.are.same(firingUnits, stubAttack.calls[1].vals[1].firingUnits)
    end)
  end)

  -- ============================================================================
  -- Matrix completion (isMatrixFinished)
  -- ============================================================================

  describe("matrix completion", function()
    it("should mark matrix as finished when all tasks are finished", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)

    it("should not mark matrix as finished when some tasks are not finished", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      -- Add a second unfinished task
      table.insert(saveData.c.ground.fireSupportPlan["FSEM-1"].fireSupportTasks, {
        name = "FST-BETA",
        missileSystem = "SRBM",
        isFinished = false,
        startTime = "2026-02-14 00:00:00",
        firingUnits = { { name = "Battery-1" } },
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
      trackStub(stub(AttackManager, "attackContacts").returns(2))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      -- First task finished but second task has 0 targets < minTargetCount 5, so not executed
      assert.is_false(matrix.isFinished)
    end)

    it("should mark matrix finished when tasks were already finished before strike", function()
      local saveData = buildSaveData({ taskFinished = true })

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)
  end)

  -- ============================================================================
  -- Multiple matrices
  -- ============================================================================

  describe("multiple matrices", function()
    it("should process multiple matrices independently", function()
      local saveData = buildSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      -- Add second matrix that is not activated
      saveData.c.ground.fireSupportPlan["FSEM-2"] = {
        name = "FSEM-2",
        isActivated = false,
        isFinished = false,
        allFiringUnitsInPosition = false,
        fireSupportTasks = {
          {
            name = "FST-BRAVO",
            missileSystem = "SRBM",
            isFinished = false,
            startTime = "2026-02-14 00:00:00",
            firingUnits = { { name = "Battery-1" } },
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

      FireSupportPlan.strike(saveData)

      -- FSEM-1: active, units in position -> executed -> finished
      assert.is_true(saveData.c.ground.fireSupportPlan["FSEM-1"].isFinished)
      -- FSEM-2: not activated -> skipped, not finished
      assert.is_false(saveData.c.ground.fireSupportPlan["FSEM-2"].isFinished)
    end)
  end)
end)
