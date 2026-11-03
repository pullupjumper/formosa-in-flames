---@diagnostic disable: missing-fields, param-type-mismatch
-- MissileSystem Rules Unit Tests
-- Each row: observations in, ordered steps out. Rules is pure, so no stubs are needed.
local Rules = require("src.modules.missileSystem.rules")
local constants = require("src.core.constants")

local STATE = constants.MISSILE_SYSTEM_STATE
local POSITION = constants.POSITION_TYPES
local READINESS = constants.MISSILE_SYSTEM_READINESS
local STEP = Rules.STEP

---Ammo callback that answers isLowAmmo, or fails the test when called
---@param isLowAmmo boolean|nil nil means the rule must not read ammo
---@return fun(): boolean
local function answerLowAmmo(isLowAmmo)
  return function()
    assert.is_not_nil(isLowAmmo)
    return isLowAmmo --[[@as boolean]]
  end
end

---Copy defaults, then apply overrides
---@param defaults table
---@param overrides table|nil
---@return table
local function buildParams(defaults, overrides)
  local params = {}
  for k, v in pairs(defaults) do
    params[k] = v
  end
  for k, v in pairs(overrides or {}) do
    params[k] = v
  end
  return params
end

---Run each row through evaluate and compare the steps
---@param rows {name: string, params: table, steps: string[]}[]
---@param evaluate fun(params: table): string[]
local function runRows(rows, evaluate)
  for _, row in ipairs(rows) do
    it(row.name, function()
      assert.are.same(row.steps, evaluate(row.params))
    end)
  end
end

describe("MissileSystem Rules", function()
  describe("staysDeployed", function()
    it("should be true for SAM in any case", function()
      assert.is_true(Rules.staysDeployed("sam"))
      assert.is_true(Rules.staysDeployed("SAM"))
    end)

    it("should be false for other systems", function()
      assert.is_false(Rules.staysDeployed("srbm"))
    end)
  end)

  describe("isRepositioning", function()
    it("should return false when firingUnitState is nil", function()
      assert.is_false(Rules.isRepositioning(nil, true))
    end)

    it("should follow the REPOSITIONING state in auto mode", function()
      assert.is_true(Rules.isRepositioning({ state = STATE.REPOSITIONING }, true))
      assert.is_false(Rules.isRepositioning({ state = STATE.STATIC }, true))
    end)

    it("should always return true in manual mode", function()
      assert.is_true(Rules.isRepositioning({ state = STATE.STATIC }, false))
    end)
  end)

  describe("isInPosition", function()
    it("should be true only for a STATIC unit", function()
      assert.is_true(Rules.isInPosition({ state = STATE.STATIC }))
      assert.is_false(Rules.isInPosition({ state = STATE.REPOSITIONING }))
    end)
  end)

  describe("shouldStow", function()
    local rows = {
      { name = "no state", state = nil, opts = nil, expected = false },
      { name = "any state without opts", state = STATE.HIDE, opts = nil, expected = true },
      { name = "HIDE with onlyDeployed", state = STATE.HIDE, opts = { onlyDeployed = true }, expected = false },
      { name = "RELOAD with onlyDeployed", state = STATE.RELOAD, opts = { onlyDeployed = true }, expected = false },
      { name = "STATIC with onlyDeployed", state = STATE.STATIC, opts = { onlyDeployed = true }, expected = true },
      { name = "REPOSITIONING with onlyDeployed", state = STATE.REPOSITIONING, opts = { onlyDeployed = true }, expected = true },
    }

    for _, row in ipairs(rows) do
      it("should return " .. tostring(row.expected) .. " for " .. row.name, function()
        local firingUnitState = row.state and { state = row.state } or nil
        assert.are.equal(row.expected, Rules.shouldStow(firingUnitState, row.opts))
      end)
    end
  end)

  describe("evaluateReadiness", function()
    it("should report NOT_HIDDEN for a unit that is not hiding", function()
      assert.are.equal(READINESS.NOT_HIDDEN, Rules.evaluateReadiness({ state = STATE.STATIC }, answerLowAmmo(nil)))
    end)

    it("should report LOW_AMMO for a hiding unit with low ammo", function()
      assert.are.equal(READINESS.LOW_AMMO, Rules.evaluateReadiness({ state = STATE.HIDE }, answerLowAmmo(true)))
    end)

    it("should report READY for a hiding unit with enough ammo", function()
      assert.are.equal(READINESS.READY, Rules.evaluateReadiness({ state = STATE.HIDE }, answerLowAmmo(false)))
    end)
  end)

  describe("evaluateSendToFiringPoint", function()
    runRows({
      { name = "should unhide and move a hiding unit with enough ammo", params = { state = STATE.HIDE, isLowAmmo = false }, steps = { STEP.UNHIDE, STEP.MOVE_TO_FIRING_POINT } },
      { name = "should keep a hiding unit with low ammo", params = { state = STATE.HIDE, isLowAmmo = true }, steps = {} },
      { name = "should leave a STATIC unit alone", params = { state = STATE.STATIC }, steps = {} },
      { name = "should leave a REPOSITIONING unit alone", params = { state = STATE.REPOSITIONING }, steps = {} },
    }, function(params)
      return Rules.evaluateSendToFiringPoint({ state = params.state }, answerLowAmmo(params.isLowAmmo))
    end)
  end)

  describe("evaluateArrival", function()
    local function arrive(positionType)
      return function(params)
        return Rules.evaluateArrival(positionType, buildParams({ isAuto = true }, params))
      end
    end

    describe("FP", function()
      runRows({
        { name = "should arrive when repositioning in auto mode", params = { firingUnitState = { state = STATE.REPOSITIONING } }, steps = { STEP.ARRIVE_AT_FIRING_POINT } },
        { name = "should do nothing when static in auto mode", params = { firingUnitState = { state = STATE.STATIC } }, steps = {} },
        { name = "should arrive in manual mode whatever the state", params = { isAuto = false, firingUnitState = { state = STATE.STATIC } }, steps = { STEP.ARRIVE_AT_FIRING_POINT } },
        { name = "should do nothing for a unit that is not a firing unit", params = {}, steps = {} },
      }, arrive(POSITION.FIRING_POINT))
    end)

    describe("HA", function()
      local firingUnitState = { state = STATE.REPOSITIONING }
      runRows({
        { name = "should hide a firing unit with enough ammo when the policy hides on HA", params = { firingUnitState = firingUnitState, hideOnEnterHA = true, isLowAmmo = false }, steps = { STEP.HIDE_FIRING_UNIT } },
        { name = "should not hide a low-ammo firing unit", params = { firingUnitState = firingUnitState, hideOnEnterHA = true, isLowAmmo = true }, steps = {} },
        { name = "should not hide when the policy is off", params = { firingUnitState = firingUnitState, hideOnEnterHA = false, isLowAmmo = false }, steps = {} },
        { name = "should do nothing for a unit that is not a firing unit", params = { hideOnEnterHA = true, isLowAmmo = false }, steps = {} },
      }, arrive(POSITION.HIDE_AREA))
    end)

    describe("RL", function()
      local paired = {
        hideResupplyOnRLNoMeeting = true,
        resupplyUnitState = { name = "RS1" },
        pairedFiringUnitState = { name = "FU1" },
        hasPairedFiringUnit = true,
        isPairedFiringUnitLowAmmo = false,
      }
      runRows({
        { name = "should begin the reload after a meeting", params = { hasMet = true, hasFiringUnit = true }, steps = { STEP.BEGIN_RELOAD } },
        { name = "should warn when the met firing unit is gone", params = { hasMet = true, hasFiringUnit = false }, steps = { STEP.WARN_FIRING_UNIT_NOT_FOUND } },
        { name = "should stop in manual mode and hide the resupply unit when its firing unit has ammo", params = buildParams(paired, { hasMet = false }), steps = { STEP.STOP_IN_MANUAL_MODE, STEP.HIDE_RESUPPLY_UNIT } },
        { name = "should not hide when the policy is off", params = buildParams(paired, { hideResupplyOnRLNoMeeting = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide when the paired firing unit is low", params = buildParams(paired, { isPairedFiringUnitLowAmmo = true }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide when the paired firing unit is gone", params = buildParams(paired, { hasPairedFiringUnit = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide when the paired firing unit has no state", params = buildParams(paired, { pairedFiringUnitState = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide a unit that is not a resupply unit", params = buildParams(paired, { resupplyUnitState = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
      }, arrive(POSITION.RELOAD_POINT))
    end)

    describe("AHA", function()
      runRows({
        { name = "should begin the transload after a meeting", params = { hasMet = true }, steps = { STEP.BEGIN_TRANSLOAD } },
        { name = "should stop without a meeting", params = { hasMet = false }, steps = { STEP.STOP } },
      }, arrive(POSITION.AMMO_HOLDING_AREA))
    end)

    it("should return no steps for an unknown position type", function()
      assert.are.same({}, Rules.evaluateArrival(POSITION.MASK, { isAuto = true }))
    end)
  end)

  describe("evaluateFiringUnitTick", function()
    local defaults = {
      state = STATE.STATIC,
      isAuto = true,
      isLowAmmo = false,
      stowElapsedSec = nil,
      stowTimeSec = 600,
      reloadElapsedSec = 0,
      reloadTimeSec = 1800,
      hasMet = false,
      staysDeployed = false,
      hasResupplyUnitState = true,
      hasResupplyUnit = true,
    }

    local function tick(params)
      return Rules.evaluateFiringUnitTick(buildParams(defaults, params))
    end

    describe("STATIC", function()
      local sendToReloadPoint = {
        STEP.UNHIDE_RESUPPLY_UNIT,
        STEP.MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT,
        STEP.MOVE_TO_RELOAD_POINT,
        STEP.END_STOW,
      }
      runRows({
        { name = "should do nothing with enough ammo and no countdown", params = {}, steps = {} },
        { name = "should begin the stow countdown when low", params = { isLowAmmo = true }, steps = { STEP.BEGIN_STOW } },
        { name = "should wait while the countdown runs", params = { isLowAmmo = true, stowElapsedSec = 599 }, steps = {} },
        { name = "should move to HA with enough ammo once stowed", params = { stowElapsedSec = 600 }, steps = { STEP.MOVE_TO_HIDE_AREA, STEP.END_STOW } },
        { name = "should move with its resupply unit to RL when low once stowed", params = { isLowAmmo = true, stowElapsedSec = 600 }, steps = sendToReloadPoint },
        { name = "should warn and still move to RL when the resupply unit is gone", params = { isLowAmmo = true, stowElapsedSec = 600, hasResupplyUnit = false }, steps = { STEP.WARN_RESUPPLY_UNIT_NOT_FOUND, STEP.MOVE_TO_RELOAD_POINT, STEP.END_STOW } },
        { name = "should warn and still move to RL when the resupply unit has no state", params = { isLowAmmo = true, stowElapsedSec = 600, hasResupplyUnitState = false }, steps = { STEP.WARN_RESUPPLY_STATE_NOT_FOUND, STEP.MOVE_TO_RELOAD_POINT, STEP.END_STOW } },
        { name = "should do nothing in manual mode", params = { isAuto = false, isLowAmmo = true, stowElapsedSec = 600 }, steps = {} },
      }, tick)
    end)

    describe("RELOAD", function()
      local ready = { state = STATE.RELOAD, reloadElapsedSec = 1800, hasMet = true, isLowAmmo = true }
      runRows({
        { name = "should only keep the clock running before the reload time", params = buildParams(ready, { reloadElapsedSec = 1799 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish without a meeting", params = buildParams(ready, { hasMet = false }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish when no longer low", params = buildParams(ready, { isLowAmmo = false }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should finish, hide the resupply unit and move to HA", params = ready, steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.HIDE_RESUPPLY_UNIT, STEP.MOVE_TO_HIDE_AREA } },
        { name = "should move SAM back to FP", params = buildParams(ready, { staysDeployed = true }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.HIDE_RESUPPLY_UNIT, STEP.MOVE_TO_FIRING_POINT } },
        { name = "should only finish in manual mode", params = buildParams(ready, { isAuto = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD } },
      }, tick)
    end)

    runRows({
      { name = "should do nothing while repositioning", params = { state = STATE.REPOSITIONING, isLowAmmo = true, stowElapsedSec = 600 }, steps = {} },
      { name = "should do nothing while hiding", params = { state = STATE.HIDE, isLowAmmo = true }, steps = {} },
    }, tick)
  end)

  describe("evaluateResupplyUnitTick", function()
    local defaults = {
      state = STATE.STATIC,
      isAuto = true,
      weaponCount = 0,
      isInOperationalArea = true,
      reloadElapsedSec = 0,
      reloadTimeSec = 1800,
      hasMet = false,
      hasAmmoDepotState = true,
    }

    local function tick(params)
      return Rules.evaluateResupplyUnitTick(buildParams(defaults, params))
    end

    describe("STATIC", function()
      runRows({
        { name = "should move an empty unit to AHA", params = {}, steps = { STEP.MOVE_TO_AMMO_HOLDING_AREA } },
        { name = "should keep a unit that still carries missiles", params = { weaponCount = 4 }, steps = {} },
        { name = "should keep a unit outside its operational area", params = { isInOperationalArea = false }, steps = {} },
        { name = "should do nothing in manual mode", params = { isAuto = false }, steps = {} },
      }, tick)
    end)

    describe("RELOAD", function()
      local ready = { state = STATE.RELOAD, reloadElapsedSec = 1800, hasMet = true }
      runRows({
        { name = "should only keep the clock running before the reload time", params = buildParams(ready, { reloadElapsedSec = 1799 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish without a meeting", params = buildParams(ready, { hasMet = false }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish when it carries missiles", params = buildParams(ready, { weaponCount = 2 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should fail when the ammo depot has no state", params = buildParams(ready, { hasAmmoDepotState = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.FAIL_AMMO_DEPOT_STATE_NOT_FOUND } },
        { name = "should finish and recall to RL", params = ready, steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_TRANSLOAD, STEP.RECALL_TO_RELOAD_POINT } },
        { name = "should only finish in manual mode", params = buildParams(ready, { isAuto = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_TRANSLOAD } },
      }, tick)
    end)

    it("should do nothing while repositioning", function()
      assert.are.same({}, tick({ state = STATE.REPOSITIONING }))
    end)
  end)
end)
