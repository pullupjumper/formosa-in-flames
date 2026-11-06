---@diagnostic disable: missing-fields, param-type-mismatch
-- MissileSystem Rules Unit Tests
-- Each row: observations in, ordered steps out. Rules never calls CMO, so no stubs are needed.
local Rules = require("src.modules.missileSystem.rules")
local constants = require("src.core.constants")

local STATE = constants.MISSILE_UNIT_POSTURE
local POSITION = constants.POSITION_TYPES
local READINESS = constants.MISSILE_SYSTEM_READINESS
local STEP = Rules.STEP

---Observation function that answers, or fails the test when the rule must not read it
---@param value boolean|nil nil means the rule must not call it
---@return fun(): boolean
local function answer(value)
  return function()
    assert.is_not_nil(value)
    return value --[[@as boolean]]
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
    it("should return false when launcherState is nil", function()
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

  describe("isDeployed", function()
    local rows = {
      { state = STATE.HIDE, expected = false },
      { state = STATE.RELOAD, expected = false },
      { state = STATE.STATIC, expected = true },
      { state = STATE.REPOSITIONING, expected = true },
    }

    for _, row in ipairs(rows) do
      it("should return " .. tostring(row.expected) .. " for state " .. row.state, function()
        assert.are.equal(row.expected, Rules.isDeployed({ state = row.state }))
      end)
    end
  end)

  describe("evaluateReadiness", function()
    it("should report NOT_HIDDEN for a unit that is not hiding", function()
      assert.are.equal(READINESS.NOT_HIDDEN, Rules.evaluateReadiness({ state = STATE.STATIC }, answer(nil)))
    end)

    it("should report LOW_AMMO for a hiding unit with low ammo", function()
      assert.are.equal(READINESS.LOW_AMMO, Rules.evaluateReadiness({ state = STATE.HIDE }, answer(true)))
    end)

    it("should report READY for a hiding unit with enough ammo", function()
      assert.are.equal(READINESS.READY, Rules.evaluateReadiness({ state = STATE.HIDE }, answer(false)))
    end)
  end)

  describe("evaluateSendToFiringPoint", function()
    runRows({
      { name = "should unhide and move a hiding unit with enough ammo", params = { state = STATE.HIDE, isLowAmmo = false }, steps = { STEP.UNHIDE, STEP.MOVE_TO_FIRING_POINT } },
      { name = "should keep a hiding unit with low ammo", params = { state = STATE.HIDE, isLowAmmo = true }, steps = {} },
      { name = "should leave a STATIC unit alone", params = { state = STATE.STATIC }, steps = {} },
      { name = "should leave a REPOSITIONING unit alone", params = { state = STATE.REPOSITIONING }, steps = {} },
    }, function(params)
      return Rules.evaluateSendToFiringPoint({ state = params.state }, answer(params.isLowAmmo))
    end)
  end)

  ---Pair with a met launcher FU1 and transloader RS1; overrides are plain values, wrapped into observation functions
  ---@param overrides table|nil launcherState, transloaderState, stock, isTriggeredByLauncher, isLow, isInSameArea, reloadCount
  ---@return SBJ__ReloadPair
  local function buildPair(overrides)
    local o = buildParams({
      launcherState = STATE.REPOSITIONING,
      transloaderState = STATE.REPOSITIONING,
      stock = 8,
      isTriggeredByLauncher = true,
      isLow = true,
      isInSameArea = true,
      reloadCount = 6,
    }, overrides)
    return {
      launcherState = { name = "FU1", state = o.launcherState },
      transloaderState = { name = "RS1", state = o.transloaderState, weaponCountCurrent = o.stock },
      isTriggeredByLauncher = o.isTriggeredByLauncher,
      isLauncherLowAmmo = answer(o.isLow),
      isInSameReloadArea = answer(o.isInSameArea),
      buildReload = function() return { entries = {}, count = o.reloadCount } end,
    }
  end

  describe("arrival", function()
    local runCtx = { isAuto = true, hideOnEnterHA = true, hideTransloaderOnRLNoMeeting = true }

    describe("FP", function()
      runRows({
        { name = "should arrive when repositioning in auto mode", params = { launcherState = { state = STATE.REPOSITIONING } }, steps = { STEP.ARRIVE_AT_FIRING_POINT } },
        { name = "should do nothing when static in auto mode", params = { launcherState = { state = STATE.STATIC } }, steps = {} },
        { name = "should arrive in manual mode whatever the state", params = { isAuto = false, launcherState = { state = STATE.STATIC } }, steps = { STEP.ARRIVE_AT_FIRING_POINT } },
        { name = "should do nothing for a unit that is not a launcher", params = {}, steps = {} },
      }, function(params)
        return Rules.evaluateFiringPointArrival(buildParams(runCtx, { isAuto = params.isAuto ~= false }), params.launcherState)
      end)
    end)

    describe("HA", function()
      runRows({
        { name = "should hide a launcher with enough ammo when the policy hides on HA", params = { isLow = false }, steps = { STEP.HIDE_LAUNCHER } },
        { name = "should not hide a low-ammo launcher", params = { isLow = true }, steps = {} },
        { name = "should not hide or read ammo when the policy is off", params = { hideOnEnterHA = false }, steps = {} },
        { name = "should do nothing for a unit that is not a launcher", params = { isLauncher = false }, steps = {} },
      }, function(params)
        local observation = params.isLauncher ~= false
            and { launcherState = { state = STATE.REPOSITIONING }, isLowAmmo = answer(params.isLow) } or nil
        return Rules.evaluateHideAreaArrival(buildParams(runCtx, { hideOnEnterHA = params.hideOnEnterHA ~= false }), observation)
      end)
    end)

    describe("RL", function()
      local alone = { isTriggeredByLauncher = false, isLow = false }
      runRows({
        { name = "should begin the reload after a meeting", params = {}, steps = { STEP.BEGIN_RELOAD } },
        { name = "should begin the reload when the transloader arrives to meet", params = { isTriggeredByLauncher = false }, steps = { STEP.BEGIN_RELOAD } },
        { name = "should begin the reload in manual mode whatever the state", params = { isAuto = false, launcherState = STATE.HIDE }, steps = { STEP.BEGIN_RELOAD } },
        { name = "should stop in manual mode when the pair is incomplete", params = { noPair = true }, steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not meet in auto mode when the arriving unit is not on its way", params = { launcherState = STATE.STATIC, isLow = false }, steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not meet when the launcher has enough ammo", params = { isLow = false }, steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not meet when the transloader is empty", params = { stock = 0 }, steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not meet when they stand in different zones", params = { isInSameArea = false }, steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should stop in manual mode and hide the transloader when its launcher has ammo", params = alone, steps = { STEP.STOP_IN_MANUAL_MODE, STEP.HIDE_UNMET_TRANSLOADER } },
        { name = "should not hide when the policy is off", params = buildParams(alone, { hideTransloaderOnRLNoMeeting = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide when the paired launcher is low", params = buildParams(alone, { isLow = true, isInSameArea = false }), steps = { STEP.STOP_IN_MANUAL_MODE } },
        { name = "should not hide a transloader when the launcher arrives", params = buildParams(alone, { isTriggeredByLauncher = true }), steps = { STEP.STOP_IN_MANUAL_MODE } },
      }, function(params)
        local ctx = buildParams(runCtx, {
          isAuto = params.isAuto ~= false,
          hideTransloaderOnRLNoMeeting = params.hideTransloaderOnRLNoMeeting ~= false,
        })
        return Rules.evaluateReloadPointArrival(ctx, not params.noPair and buildPair(params) or nil)
      end)
    end)

    describe("ATP", function()
      runRows({
        { name = "should begin the transload after meeting its canister stock", params = { isAtCanisterStock = true }, steps = { STEP.BEGIN_TRANSLOAD } },
        { name = "should stop when not at its canister stock", params = { isAtCanisterStock = false }, steps = { STEP.STOP } },
        { name = "should stop when it still carries missiles", params = { stock = 2 }, steps = { STEP.STOP } },
        { name = "should stop in auto mode when not on its way", params = { state = STATE.STATIC }, steps = { STEP.STOP } },
        { name = "should stop for a unit that is not a transloader", params = { isTransloader = false }, steps = { STEP.STOP } },
      }, function(params)
        local o = buildParams({ state = STATE.REPOSITIONING, stock = 0, isTransloader = true }, params)
        local observation = o.isTransloader and {
          transloaderState = { state = o.state, weaponCountCurrent = o.stock },
          isAtCanisterStock = answer(o.isAtCanisterStock),
        } or nil
        return Rules.evaluateAmmunitionTransferPointArrival(runCtx, observation)
      end)
    end)
  end)

  describe("evaluateLauncherTick", function()
    ---Launcher tick, plus its pair unless params.pair is false
    ---@param params table state, isAuto, isLow, stowStartTime, reloadStartTime, staysDeployed, hasTransloaderState, pair (overrides or false)
    local function tick(params)
      local o = buildParams({
        state = STATE.STATIC,
        isAuto = true,
        now = 10000,
        staysDeployed = false,
        hasTransloaderState = true,
      }, params)
      local pair = params.pair ~= false and buildPair(buildParams({ launcherState = o.state }, params.pair)) or nil
      return Rules.evaluateLauncherTick({
        launcherState = { state = o.state, stowStartTime = o.stowStartTime, reloadStartTime = o.reloadStartTime },
        isAuto = o.isAuto,
        now = o.now,
        stowTimeSec = 600,
        reloadTimeSec = 1800,
        staysDeployed = o.staysDeployed,
        hasTransloaderState = o.hasTransloaderState,
        isLowAmmo = answer(o.isLow),
      }, pair)
    end

    describe("STATIC", function()
      local sendToReloadPoint = {
        STEP.UNHIDE_TRANSLOADER,
        STEP.MOVE_TRANSLOADER_TO_RELOAD_POINT,
        STEP.MOVE_TO_RELOAD_POINT,
        STEP.END_STOW,
      }
      local stowed = 10000 - 600
      runRows({
        { name = "should do nothing with enough ammo and no countdown", params = { isLow = false }, steps = {} },
        { name = "should begin the stow countdown when low", params = { isLow = true }, steps = { STEP.BEGIN_STOW } },
        { name = "should wait without reading ammo while the countdown runs", params = { stowStartTime = stowed + 1 }, steps = {} },
        { name = "should move to HA with enough ammo once stowed", params = { isLow = false, stowStartTime = stowed }, steps = { STEP.MOVE_TO_HIDE_AREA, STEP.END_STOW } },
        { name = "should move with its transloader to RL when low once stowed", params = { isLow = true, stowStartTime = stowed }, steps = sendToReloadPoint },
        { name = "should warn and still move to RL when the transloader is gone", params = { isLow = true, stowStartTime = stowed, pair = false }, steps = { STEP.WARN_TRANSLOADER_NOT_FOUND, STEP.MOVE_TO_RELOAD_POINT, STEP.END_STOW } },
        { name = "should warn and still move to RL when the transloader has no state", params = { isLow = true, stowStartTime = stowed, pair = false, hasTransloaderState = false }, steps = { STEP.WARN_RESUPPLY_STATE_NOT_FOUND, STEP.MOVE_TO_RELOAD_POINT, STEP.END_STOW } },
        { name = "should begin the stow countdown for SAM when low", params = { isLow = true, staysDeployed = true }, steps = { STEP.BEGIN_STOW } },
        { name = "should wait out the stow time for SAM before RL", params = { isLow = true, staysDeployed = true, stowStartTime = stowed + 1 }, steps = {} },
        { name = "should move SAM with its transloader to RL when low once stowed", params = { isLow = true, staysDeployed = true, stowStartTime = stowed }, steps = sendToReloadPoint },
        { name = "should do nothing in manual mode", params = { isAuto = false, stowStartTime = stowed }, steps = {} },
      }, tick)
    end)

    describe("RELOAD", function()
      local ready = { state = STATE.RELOAD, reloadStartTime = 10000 - 1800 }
      runRows({
        { name = "should only keep the clock running before the reload time", params = buildParams(ready, { reloadStartTime = 10000 - 1799 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should only keep the clock running when the clock has not started", params = { state = STATE.RELOAD }, steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish without its transloader", params = buildParams(ready, { pair = false }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish without a meeting", params = buildParams(ready, { pair = { isInSameArea = false } }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish when no longer low", params = buildParams(ready, { pair = { isLow = false } }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should finish, hide the transloader and move to HA", params = ready, steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.HIDE_TRANSLOADER_AFTER_RELOAD, STEP.MOVE_TO_HIDE_AREA } },
        { name = "should not hide a transloader the reload empties exactly", params = buildParams(ready, { pair = { stock = 6, reloadCount = 6 } }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.MOVE_TO_HIDE_AREA } },
        { name = "should hide a transloader one missile left after the reload", params = buildParams(ready, { pair = { stock = 7, reloadCount = 6 } }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.HIDE_TRANSLOADER_AFTER_RELOAD, STEP.MOVE_TO_HIDE_AREA } },
        { name = "should move SAM back to FP", params = buildParams(ready, { staysDeployed = true }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD, STEP.HIDE_TRANSLOADER_AFTER_RELOAD, STEP.MOVE_TO_FIRING_POINT } },
        { name = "should only finish in manual mode", params = buildParams(ready, { isAuto = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_RELOAD } },
      }, tick)
    end)

    runRows({
      { name = "should do nothing while repositioning", params = { state = STATE.REPOSITIONING, stowStartTime = 0 }, steps = {} },
      { name = "should do nothing while hiding", params = { state = STATE.HIDE }, steps = {} },
    }, tick)
  end)

  describe("evaluateTransloaderTick", function()
    ---Transloader tick with its canister stock state unless params.hasCanisterStockState is false
    ---@param params table state, isAuto, stock, reloadStartTime, isInReloadArea, isAtCanisterStock, hasCanisterStockState
    local function tick(params)
      local o = buildParams({ state = STATE.STATIC, isAuto = true, stock = 0, hasCanisterStockState = true }, params)
      return Rules.evaluateTransloaderTick({
        transloaderState = { state = o.state, weaponCountCurrent = o.stock, reloadStartTime = o.reloadStartTime },
        isAuto = o.isAuto,
        now = 10000,
        reloadTimeSec = 1800,
        isInReloadArea = answer(o.isInReloadArea),
        isAtCanisterStock = answer(o.isAtCanisterStock),
      }, o.hasCanisterStockState and { name = "AD1" } or nil)
    end

    describe("STATIC", function()
      runRows({
        { name = "should move an empty unit in an RL zone to ATP", params = { isInReloadArea = true }, steps = { STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT } },
        { name = "should keep a unit that still carries missiles", params = { stock = 4 }, steps = {} },
        { name = "should keep a unit outside its RL zones", params = { isInReloadArea = false }, steps = {} },
        { name = "should do nothing in manual mode", params = { isAuto = false }, steps = {} },
      }, tick)
    end)

    describe("RELOAD", function()
      local ready = { state = STATE.RELOAD, reloadStartTime = 10000 - 1800, isAtCanisterStock = true }
      runRows({
        { name = "should only keep the clock running before the reload time", params = buildParams(ready, { reloadStartTime = 10000 - 1799 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish without a meeting", params = buildParams(ready, { isAtCanisterStock = false }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should not finish when it carries missiles", params = buildParams(ready, { stock = 2 }), steps = { STEP.ENSURE_RELOAD_CLOCK } },
        { name = "should fail when the canister stock has no state", params = buildParams(ready, { hasCanisterStockState = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.FAIL_CANISTER_STOCK_STATE_NOT_FOUND } },
        { name = "should finish and recall to RL", params = ready, steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_TRANSLOAD, STEP.RECALL_TO_RELOAD_POINT } },
        { name = "should only finish in manual mode", params = buildParams(ready, { isAuto = false }), steps = { STEP.ENSURE_RELOAD_CLOCK, STEP.COMPLETE_TRANSLOAD } },
      }, tick)
    end)

    it("should do nothing while repositioning", function()
      assert.are.same({}, tick({ state = STATE.REPOSITIONING }))
    end)
  end)
end)
