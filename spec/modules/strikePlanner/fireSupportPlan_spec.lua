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

  ---@param overrides? table
  ---@return table saveData
  local function makeSaveData(overrides)
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
  -- Matrix Filtering
  -- ============================================================================

  describe("matrix filtering", function()
    -- Negative: finished matrix skipped
    it("should skip finished matrices", function()
      local saveData = makeSaveData({ matrixFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Negative: non-activated matrix skipped
    it("should skip non-activated matrices", function()
      local saveData = makeSaveData({ isActivated = false })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Boundary: empty plan
    it("should handle empty fireSupportPlan without errors", function()
      local saveData = { c = { ground = { fireSupportPlan = {} } } }

      FireSupportPlan.strike(saveData)

      assert.are.same({}, saveData.c.ground.fireSupportPlan)
    end)
  end)

  -- ============================================================================
  -- Task Processing
  -- ============================================================================

  describe("task processing", function()
    -- Negative: finished task skipped
    it("should skip finished tasks", function()
      local saveData = makeSaveData({ taskFinished = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubIsAfter).was_not.called()
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Negative: start time not reached
    it("should skip tasks whose start time has not been reached", function()
      local saveData = makeSaveData({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubGetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Firing Unit Deployment
  -- ============================================================================

  describe("firing unit deployment", function()
    -- Positive: unit ready triggers move
    it("should call moveToFiringPoint when unit is in HIDE state and not low ammo", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
      trackStub(stub(MissileSystem, "moveFromHideArea"))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was.called(1)
    end)

    -- Positive: all units at firing point
    it("should set allFiringUnitsInPosition to true when all units are at STATIC state", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.allFiringUnitsInPosition)
    end)

    -- Negative: unit not found
    it("should set allFiringUnitsInPosition to false when unit not found", function()
      local saveData = makeSaveData({})
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)

    -- Negative: not HIDE state
    it("should not call moveToFiringPoint when unit state is not HIDE", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(AttackManager, "attackContacts").returns(0))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was_not.called()
    end)

    -- Negative: low ammo
    it("should not call moveToFiringPoint when unit has low ammo", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(true))
      local stubMove = trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubMove).was_not.called()
    end)

    -- Negative: not at STATIC state
    it("should set allFiringUnitsInPosition to false when unit is not at STATIC state", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.REPOSITIONING })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)

    -- Boundary: mixed states across multiple units
    it("should set allFiringUnitsInPosition to false when any unit is not at STATIC state", function()
      local saveData = makeSaveData({
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
      trackStub(stub(MissileSystem, "moveFromHideArea"))
      trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.allFiringUnitsInPosition)
    end)
  end)

  -- ============================================================================
  -- Strike Execution
  -- ============================================================================

  describe("strike execution", function()
    -- Positive: attack succeeds and marks task finished
    it("should call attackContacts and mark task finished when result > 0", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

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

    -- Positive: firingUnits forwarded to attackContacts
    it("should pass firingUnits to attackContacts", function()
      local firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } }
      local saveData = makeSaveData({
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

    -- Negative: attack returns 0
    it("should not mark task finished when attackContacts returns 0", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      local task = saveData.c.ground.fireSupportPlan["FSEM-1"].fireSupportTasks[1]
      assert.is_false(task.isFinished)
    end)

    -- Positive: target threshold is handled before FSP execution
    it("should pass existing targets to attackContacts without checking minTargetCount", function()
      local saveData = makeSaveData({
        firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC,
        targetList = {},
        minTargetCount = 2
      })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      assert.stub(stubAttack).was.called_with({
        contacts = {},
        qty = 2,
        firingUnits = { { name = "Battery-1" } },
      })
    end)

    -- Negative: units not in position blocks all strikes
    it("should not execute strikes when firing units are not all in position", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
      trackStub(stub(MissileSystem, "moveFromHideArea"))
      trackStub(stub(MissileSystem, "moveToFiringPoint"))
      local stubAttack = trackStub(stub(AttackManager, "attackContacts"))

      FireSupportPlan.strike(saveData)

      assert.stub(stubAttack).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Stow Window Trigger
  -- ============================================================================

  describe("stow window trigger", function()
    -- Positive: non-SAM strike stamps stowStartTime on firing units
    it("should set stowStartTime on firing units after non-SAM strike succeeds", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.are.equal(5000, saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime)
    end)

    -- Negative: SAM strike does not stamp stowStartTime
    it("should not set stowStartTime when missile system is SAM", function()
      local saveData = makeSaveData({
        missileSystem = "SAM",
        firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC
      })
      saveData.c.ground.sam = {
        firingUnits = {
          ["Battery-1"] = {
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            ammoThreshold = 40,
            weaponDBID = 3104
          }
        }
      }
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.is_nil(saveData.c.ground.sam.firingUnits["Battery-1"].stowStartTime)
    end)

    -- Negative: zero-result strike leaves stowStartTime untouched
    it("should not set stowStartTime when attackContacts returns 0", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      assert.is_nil(saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime)
    end)

    -- Boundary: existing stowStartTime is preserved
    it("should not overwrite existing stowStartTime when strike succeeds", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
      saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime = 1000
      currentTimeStub.returns(5000)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.are.equal(1000, saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime)
    end)

    -- Boundary: every firing unit in a multi-unit task gets stowStartTime
    it("should set stowStartTime on every firing unit in a multi-unit task", function()
      local saveData = makeSaveData({
        firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC,
        firingUnits = { { name = "Battery-1" }, { name = "Battery-2" } }
      })
      saveData.c.ground.srbm.firingUnits["Battery-2"] = {
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        ammoThreshold = 40,
        weaponDBID = 3104
      }
      currentTimeStub.returns(7777)

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Battery-1" then return { guid = "U1", name = "Battery-1" } end
        if name == "Battery-2" then return { guid = "U2", name = "Battery-2" } end
        return nil
      end))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.are.equal(7777, saveData.c.ground.srbm.firingUnits["Battery-1"].stowStartTime)
      assert.are.equal(7777, saveData.c.ground.srbm.firingUnits["Battery-2"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- Matrix Completion
  -- ============================================================================

  describe("matrix completion", function()
    -- Positive: all tasks finished
    it("should mark matrix as finished when all tasks are finished", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").invokes(function(opts)
        return #opts.contacts > 0 and 2 or 0
      end))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)

    -- Positive: tasks pre-finished before strike
    it("should mark matrix finished when tasks were already finished before strike", function()
      local saveData = makeSaveData({ taskFinished = true })

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_true(matrix.isFinished)
    end)

    -- Negative: some tasks not finished
    it("should not mark matrix as finished when some tasks are not finished", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
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
      trackStub(stub(AttackManager, "attackContacts").invokes(function(opts)
        return #opts.contacts > 0 and 2 or 0
      end))

      FireSupportPlan.strike(saveData)

      local matrix = saveData.c.ground.fireSupportPlan["FSEM-1"]
      assert.is_false(matrix.isFinished)
    end)
  end)

  -- ============================================================================
  -- Multiple Matrices
  -- ============================================================================

  describe("multiple matrices", function()
    -- Positive: independent processing
    it("should process multiple matrices independently", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })
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

      assert.is_true(saveData.c.ground.fireSupportPlan["FSEM-1"].isFinished)
      assert.is_false(saveData.c.ground.fireSupportPlan["FSEM-2"].isFinished)
    end)
  end)

  -- ============================================================================
  -- Logging
  -- ============================================================================

  describe("logging", function()
    -- Positive: strike results logged
    it("should log strike results when attacks are executed", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(4))

      FireSupportPlan.strike(saveData)

      assert.stub(logStub).was.called(1)
      assert.are.equal("ground", logStub.calls[1].vals[1])
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[OK%]"))
      assert.is_truthy(string.find(logMessage, "action=strike"))
      assert.is_truthy(string.find(logMessage, "task=FST%-ALPHA action=strike fired=4"))
    end)

    -- Positive: pending units logged
    it("should log pending info when firing units are not in position", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.HIDE })
      local mockUnit = { guid = "UNIT-1", name = "Battery-1" }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(mockUnit))
      trackStub(stub(MissileSystem, "isLowAmmo").returns(false))
      trackStub(stub(MissileSystem, "moveFromHideArea"))
      trackStub(stub(MissileSystem, "moveToFiringPoint"))

      FireSupportPlan.strike(saveData)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[SKIP%]"))
      assert.is_truthy(string.find(logMessage, "reason=firing_units_not_in_position"))
      assert.is_truthy(string.find(logMessage, "task=FST%-ALPHA"))
      -- Separator-free values stay unquoted under the single escaping rule
      assert.is_truthy(string.find(logMessage, "units=Battery%-1 reason=firing_units_not_in_position"))
    end)

    -- Positive: completion logged without strike info
    it("should log completion without strike info when tasks were pre-finished", function()
      local saveData = makeSaveData({ taskFinished = true })

      FireSupportPlan.strike(saveData)

      assert.stub(logStub).was.called(1)
      local logMessage = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(logMessage, "%[OK%]"))
      assert.is_truthy(string.find(logMessage, "state=finished"))
      assert.is_falsy(string.find(logMessage, "action=strike"))
    end)

    -- Negative: no log on empty plan
    it("should not log when no active matrices exist", function()
      local saveData = { c = { ground = { fireSupportPlan = {} } } }

      FireSupportPlan.strike(saveData)

      assert.stub(logStub).was_not.called()
    end)

    -- Negative: no log when attack returns zero
    it("should not log when attack returns zero and units are in position", function()
      local saveData = makeSaveData({ firingUnitState = constants.MISSILE_SYSTEM_STATE.STATIC })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U1", name = "Battery-1" }))
      trackStub(stub(AttackManager, "attackContacts").returns(0))

      FireSupportPlan.strike(saveData)

      assert.stub(logStub).was_not.called()
    end)
  end)
end)
