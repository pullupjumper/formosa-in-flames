---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem Transitions Unit Tests
local stub = require("luassert.stub")
local Transitions = require("src.modules.missileSystem.transitions")
local Movement = require("src.modules.missileSystem.movement")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")

describe("MissileSystem Transitions", function()
  local STATE = constants.MISSILE_SYSTEM_STATE

  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local applyModeStub

  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    applyModeStub = trackStub(Movement, "applyMode")
    trackStub(GameApi, "ScenEdit_CurrentTime").returns(9000)
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  describe("staysDeployed", function()
    -- Positive: SAM stays deployed in any letter case
    it("should be true for SAM in any case", function()
      assert.is_true(Transitions.staysDeployed("sam"))
      assert.is_true(Transitions.staysDeployed("SAM"))
    end)

    -- Negative: other systems stow
    it("should be false for other systems", function()
      assert.is_false(Transitions.staysDeployed("srbm"))
    end)
  end)

  describe("isRepositioning", function()
    -- Boundary: no state means not repositioning
    it("should return false when firingUnitState is nil", function()
      assert.is_false(Transitions.isRepositioning(nil, true))
    end)

    -- Positive: auto mode follows the state
    it("should follow the REPOSITIONING state in auto mode", function()
      assert.is_true(Transitions.isRepositioning({ state = STATE.REPOSITIONING }, true))
      assert.is_false(Transitions.isRepositioning({ state = STATE.STATIC }, true))
    end)

    -- Positive: manual mode has no REPOSITIONING, so every arrival counts
    it("should always return true in manual mode", function()
      assert.is_true(Transitions.isRepositioning({ state = STATE.STATIC }, false))
    end)
  end)

  describe("depart", function()
    -- Positive: a move order that went out marks the unit repositioning
    it("should mark the unit REPOSITIONING when the move succeeded", function()
      local unitState = { state = STATE.STATIC }

      local success, errorFields = Transitions.depart(unitState, true, nil)

      assert.is_true(success)
      assert.is_nil(errorFields)
      assert.are.equal(STATE.REPOSITIONING, unitState.state)
    end)

    -- Negative: a failed move keeps the old state so the unit is not stuck as REPOSITIONING
    it("should keep the state and pass the failure through when the move failed", function()
      local unitState = { state = STATE.HIDE }
      local failure = { reason = "no_positions_available" }

      local success, errorFields = Transitions.depart(unitState, false, failure)

      assert.is_false(success)
      assert.are.equal(failure, errorFields)
      assert.are.equal(STATE.HIDE, unitState.state)
    end)
  end)

  describe("arriveAtFiringPoint", function()
    -- Positive: the unit stands ready with weapons free
    it("should set STATIC and free weapons", function()
      local firingUnitState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.arriveAtFiringPoint(firingUnitState, unit, true)

      assert.are.equal(STATE.STATIC, firingUnitState.state)
      assert.stub(applyModeStub).was.called_with(unit, true, constants.WCS.FREE)
    end)
  end)

  describe("hide", function()
    -- Positive: the unit hides with weapons held
    it("should set HIDE and hold weapons", function()
      local firingUnitState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.hide(firingUnitState, unit, false)

      assert.are.equal(STATE.HIDE, firingUnitState.state)
      assert.stub(applyModeStub).was.called_with(unit, false, constants.WCS.HOLD)
    end)
  end)

  describe("beginReload", function()
    -- Positive: the reload clock starts now and weapons are held
    it("should set RELOAD, start the clock and hold weapons", function()
      local unitState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.beginReload(unitState, unit, true)

      assert.are.equal(STATE.RELOAD, unitState.state)
      assert.are.equal(9000, unitState.reloadStartTime)
      assert.stub(applyModeStub).was.called_with(unit, true, constants.WCS.HOLD)
    end)
  end)

  describe("ensureReloadClock", function()
    -- Positive: a missing clock starts now
    it("should start a missing clock", function()
      local unitState = { state = STATE.RELOAD }

      Transitions.ensureReloadClock(unitState)

      assert.are.equal(9000, unitState.reloadStartTime)
    end)

    -- Negative: a running clock is kept
    it("should keep a running clock", function()
      local unitState = { state = STATE.RELOAD, reloadStartTime = 500 }

      Transitions.ensureReloadClock(unitState)

      assert.are.equal(500, unitState.reloadStartTime)
    end)
  end)

  describe("finishReload", function()
    -- Positive: the unit stands still and the clock stops
    it("should set STATIC and clear the reload clock", function()
      local unitState = { state = STATE.RELOAD, reloadStartTime = 500 }

      Transitions.finishReload(unitState)

      assert.are.equal(STATE.STATIC, unitState.state)
      assert.is_nil(unitState.reloadStartTime)
    end)
  end)

  describe("settle", function()
    local systemState

    before_each(function()
      systemState = {
        firingUnits = { ["FU1"] = { name = "FU1", state = STATE.RELOAD, reloadStartTime = 500 } },
        resupplyUnits = { ["RU1"] = { name = "RU1", state = STATE.REPOSITIONING, reloadStartTime = 600 } }
      }
    end)

    -- Positive: a firing unit stands still with weapons held
    it("should settle a firing unit", function()
      local unit = { name = "FU1" }

      Transitions.settle(systemState, unit, false)

      assert.are.equal(STATE.STATIC, systemState.firingUnits["FU1"].state)
      assert.is_nil(systemState.firingUnits["FU1"].reloadStartTime)
      assert.stub(applyModeStub).was.called_with(unit, false, constants.WCS.HOLD)
    end)

    -- Positive: a resupply unit is settled the same way
    it("should settle a resupply unit", function()
      Transitions.settle(systemState, { name = "RU1" }, true)

      assert.are.equal(STATE.STATIC, systemState.resupplyUnits["RU1"].state)
      assert.is_nil(systemState.resupplyUnits["RU1"].reloadStartTime)
    end)

    -- Boundary: a name in both maps settles the firing unit
    it("should prefer the firing unit when the name is in both maps", function()
      systemState.resupplyUnits["FU1"] = { name = "FU1", state = STATE.REPOSITIONING }

      Transitions.settle(systemState, { name = "FU1" }, true)

      assert.are.equal(STATE.STATIC, systemState.firingUnits["FU1"].state)
      assert.are.equal(STATE.REPOSITIONING, systemState.resupplyUnits["FU1"].state)
    end)

    -- Negative: an unknown unit is left alone
    it("should do nothing for an unknown unit", function()
      Transitions.settle(systemState, { name = "Unknown" }, true)

      assert.stub(applyModeStub).was_not.called()
    end)
  end)

  describe("beginStow / endStow", function()
    -- Positive: a new countdown starts now
    it("should start a countdown and report it", function()
      local firingUnitState = {}

      assert.is_true(Transitions.beginStow(firingUnitState))
      assert.are.equal(9000, firingUnitState.stowStartTime)
    end)

    -- Negative: a running countdown is kept
    it("should keep a running countdown", function()
      local firingUnitState = { stowStartTime = 500 }

      assert.is_false(Transitions.beginStow(firingUnitState))
      assert.are.equal(500, firingUnitState.stowStartTime)
    end)

    -- Positive: ending clears the countdown
    it("should clear the countdown on end", function()
      local firingUnitState = { stowStartTime = 500 }

      Transitions.endStow(firingUnitState)

      assert.is_nil(firingUnitState.stowStartTime)
    end)
  end)
end)
