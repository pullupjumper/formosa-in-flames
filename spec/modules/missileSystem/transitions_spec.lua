---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem Transitions Unit Tests
local stub = require("luassert.stub")
local match = require("luassert.match")
local Transitions = require("src.modules.missileSystem.transitions")
local Movement = require("src.modules.missileSystem.movement")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")

describe("MissileSystem Transitions", function()
  local STATE = constants.MISSILE_UNIT_POSTURE

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
    applyModeStub = trackStub(Movement, "setMode")
    trackStub(GameApi, "ScenEdit_CurrentTime").returns(9000)
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  describe("startMove", function()
    -- Positive: a move order that went out marks the unit repositioning
    it("should mark the unit REPOSITIONING when the move succeeded", function()
      local unitState = { state = STATE.STATIC }

      local unit = { guid = "U1" }
      local row = { tag = "OK", fields = { unit = "U1", action = "move_to_hide_area" } }
      local moveStub = trackStub(Movement, "moveTo").returns(row)

      local result = Transitions.startMove(unitState, unit, Movement.ORDER.HIDE_AREA)

      assert.are.equal(row, result)
      assert.stub(moveStub).was.called_with(match.is_ref(unitState), match.is_ref(unit), match.is_ref(Movement.ORDER.HIDE_AREA))
      assert.are.equal(STATE.REPOSITIONING, unitState.state)
    end)

    -- Negative: a failed move keeps the old state so the unit is not stuck as REPOSITIONING
    it("should keep the state and pass the failure through when the move failed", function()
      local unitState = { state = STATE.HIDE }
      local row = { tag = "FAIL", fields = { reason = "no_positions_available" } }
      trackStub(Movement, "moveTo").returns(row)

      local result = Transitions.startMove(unitState, { guid = "U1" }, Movement.ORDER.HIDE_AREA)

      assert.are.equal(row, result)
      assert.are.equal(STATE.HIDE, unitState.state)
    end)
  end)

  describe("arriveAtFiringPoint", function()
    -- Positive: the unit stands ready with weapons free
    it("should set STATIC and free weapons", function()
      local launcherState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.arriveAtFiringPoint(launcherState, unit, true)

      assert.are.equal(STATE.STATIC, launcherState.state)
      assert.stub(applyModeStub).was.called_with(unit, true, constants.WCS.FREE)
    end)
  end)

  describe("hide", function()
    -- Positive: the unit hides with weapons held
    it("should set HIDE and hold weapons", function()
      local launcherState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.hide(launcherState, unit, false)

      assert.are.equal(STATE.HIDE, launcherState.state)
      assert.stub(applyModeStub).was.called_with(unit, false, constants.WCS.HOLD)
    end)
  end)

  describe("startReload", function()
    -- Positive: the reload clock starts now and weapons are held
    it("should set RELOAD, start the clock and hold weapons", function()
      local unitState = { state = STATE.REPOSITIONING }
      local unit = { guid = "F1" }

      Transitions.startReload(unitState, unit, true)

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

  describe("completeReload", function()
    -- Positive: the unit stands still and the clock stops
    it("should set STATIC and clear the reload clock", function()
      local unitState = { state = STATE.RELOAD, reloadStartTime = 500 }

      Transitions.completeReload(unitState)

      assert.are.equal(STATE.STATIC, unitState.state)
      assert.is_nil(unitState.reloadStartTime)
    end)
  end)

  describe("completeArrival", function()
    local systemState

    before_each(function()
      systemState = {
        launchers = { ["FU1"] = { name = "FU1", state = STATE.RELOAD, reloadStartTime = 500 } },
        transloaders = { ["RU1"] = { name = "RU1", state = STATE.REPOSITIONING, reloadStartTime = 600 } }
      }
    end)

    -- Positive: a launcher stands still with weapons held
    it("should settle a launcher", function()
      local unit = { name = "FU1" }

      Transitions.completeArrival(systemState, unit, false)

      assert.are.equal(STATE.STATIC, systemState.launchers["FU1"].state)
      assert.is_nil(systemState.launchers["FU1"].reloadStartTime)
      assert.stub(applyModeStub).was.called_with(unit, false, constants.WCS.HOLD)
    end)

    -- Positive: a transloader is settled the same way
    it("should settle a transloader", function()
      Transitions.completeArrival(systemState, { name = "RU1" }, true)

      assert.are.equal(STATE.STATIC, systemState.transloaders["RU1"].state)
      assert.is_nil(systemState.transloaders["RU1"].reloadStartTime)
    end)

    -- Boundary: a name in both maps settles the launcher
    it("should prefer the launcher when the name is in both maps", function()
      systemState.transloaders["FU1"] = { name = "FU1", state = STATE.REPOSITIONING }

      Transitions.completeArrival(systemState, { name = "FU1" }, true)

      assert.are.equal(STATE.STATIC, systemState.launchers["FU1"].state)
      assert.are.equal(STATE.REPOSITIONING, systemState.transloaders["FU1"].state)
    end)

    -- Negative: an unknown unit is left alone
    it("should do nothing for an unknown unit", function()
      Transitions.completeArrival(systemState, { name = "Unknown" }, true)

      assert.stub(applyModeStub).was_not.called()
    end)
  end)

  describe("startStow / completeStow", function()
    -- Positive: a new countdown starts now
    it("should start a countdown and report it", function()
      local launcherState = {}

      assert.is_true(Transitions.startStow(launcherState))
      assert.are.equal(9000, launcherState.stowStartTime)
    end)

    -- Negative: a running countdown is kept
    it("should keep a running countdown", function()
      local launcherState = { stowStartTime = 500 }

      assert.is_false(Transitions.startStow(launcherState))
      assert.are.equal(500, launcherState.stowStartTime)
    end)

    -- Positive: ending clears the countdown
    it("should clear the countdown on end", function()
      local launcherState = { stowStartTime = 500 }

      Transitions.completeStow(launcherState)

      assert.is_nil(launcherState.stowStartTime)
    end)
  end)
end)
