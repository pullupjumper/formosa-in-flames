---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem Init Unit Tests
local stub = require("luassert.stub")
local match = require("luassert.match")
local MissileSystem = require("src.modules.missileSystem.init")
local Movement = require("src.modules.missileSystem.movement")
local Cycle = require("src.modules.missileSystem.cycle")
local Transitions = require("src.modules.missileSystem.transitions")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Ammo = require("src.modules.missileSystem.ammo")
local Deployment = require("src.modules.missileSystem.deployment")
local PositionZones = require("src.modules.missileSystem.positionZones")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local PanelBattery = require("src.modules.missileSystem.panelBattery")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  ---@type luassert.spy
  local warnStub

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
    logStub = trackStub(Logger, "log")
    errorStub = trackStub(Logger, "error")
    warnStub = trackStub(Logger, "warn")
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- sendToFiringPoint
  -- ============================================================================

  describe("sendToFiringPoint", function()
    local STATE = constants.MISSILE_UNIT_POSTURE

    ---@type luassert.spy
    local moveFromHideAreaStub

    before_each(function()
      moveFromHideAreaStub = trackStub(Concealment, "moveFromHideArea").returns(true)
    end)

    ---Send FU1 of a China SRBM battery whose state, game unit and config descriptors are given
    ---@param launcherState table|nil
    ---@param launcher table|nil
    ---@param descriptorMap? table Config launchers; defaults to FU1 with a 40% threshold on weapon 1
    ---@return boolean inPosition
    ---@return boolean isMissing
    local function sendToFiringPoint(launcherState, launcher, descriptorMap)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(launcher)
      local launchers = descriptorMap or { FU1 = { name = "FU1", ammoThreshold = 40, weaponDBID = 1 } }
      local config = { red = { ground = { missileSystemTypes = { srbm = { launchers = launchers } } } } }
      local groundState = { missileSystemTypes = { srbm = { launchers = { FU1 = launcherState } } } }
      return MissileSystem.sendToFiringPoint(
        config, groundState, constants.SIDES.RED, { missileSystemType = "SRBM", launcherName = "FU1" }
      )
    end

    -- Negative: a tracked unit that no longer exists in game is reported missing
    it("should report a missing unit without moving anything when the unit is gone", function()
      local moveStub = trackStub(Movement, "moveTo")

      local inPosition, isMissing = sendToFiringPoint({ name = "FU1", state = STATE.HIDE }, nil)

      assert.is_false(inPosition)
      assert.is_true(isMissing)
      assert.stub(moveStub).was_not.called()
    end)

    -- Negative: a unit the missile system does not track is reported missing
    it("should report a missing unit when it has no runtime state", function()
      local inPosition, isMissing = sendToFiringPoint(nil, { name = "FU1" })

      assert.is_false(inPosition)
      assert.is_true(isMissing)
    end)

    -- Negative: a unit whose battery config dropped is reported missing, so the task lets it go
    it("should report a missing unit when it has no config descriptor", function()
      local moveStub = trackStub(Movement, "moveTo")

      local inPosition, isMissing = sendToFiringPoint({ name = "FU1", state = STATE.HIDE }, { name = "FU1" }, {})

      assert.is_false(inPosition)
      assert.is_true(isMissing)
      assert.stub(moveStub).was_not.called()
    end)

    -- Positive: a unit with both state and game unit is not missing
    it("should report a present unit as not missing", function()
      local _, isMissing = sendToFiringPoint({ name = "FU1", state = STATE.STATIC }, { name = "FU1" })

      assert.is_false(isMissing)
    end)

    -- Positive: a hiding unit with ammo leaves its hide area and heads to FP
    it("should unload and move a hiding unit with enough ammo", function()
      local launcherState = { name = "FU1", state = STATE.HIDE }
      local launcher = { name = "FU1" }
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local moveStub = trackStub(Movement, "moveTo").returns({ tag = "OK", fields = {} })

      local inPosition = sendToFiringPoint(launcherState, launcher)

      assert.is_false(inPosition)
      assert.stub(isLowAmmoStub).was.called_with(launcher, 40, 1)
      assert.stub(moveFromHideAreaStub).was.called_with(match.is_ref(launcherState), launcher)
      assert.stub(moveStub).was.called_with(match.is_ref(launcherState), launcher, Movement.ORDER.FIRING_POINT)
      assert.stub(errorStub).was_not.called()
      assert.are.equal(STATE.REPOSITIONING, launcherState.state)
    end)

    -- Positive: a unit already at its firing point reports in position without new commands
    it("should report in position for a STATIC unit without moving it", function()
      local launcherState = { name = "FU1", state = STATE.STATIC }
      local launcher = { name = "FU1" }
      local moveStub = trackStub(Movement, "moveTo")

      local inPosition = sendToFiringPoint(launcherState, launcher)

      assert.is_true(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: low ammo keeps the unit hidden
    it("should keep a hiding unit with low ammo in place", function()
      local launcherState = { name = "FU1", state = STATE.HIDE }
      local launcher = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(true)
      local moveStub = trackStub(Movement, "moveTo")

      local inPosition = sendToFiringPoint(launcherState, launcher)

      assert.is_false(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: logs when movement fails with structured fields
    it("should log an error when movement fails", function()
      local launcherState = { name = "FU1", state = STATE.HIDE }
      local launcher = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveTo").returns({ tag = "FAIL", fields = {
        unit = "FU1", action = "move_to_firing_point", reason = "no_positions_available", position = "FP", area = "OPAREA-1"
      } })

      sendToFiringPoint(launcherState, launcher)

      assert.stub(errorStub).was.called(1)
      assert.stub(errorStub).was.called_with(
        "[FAIL] module=missileSystem area=OPAREA-1 unit=FU1 action=move_to_firing_point position=FP" ..
        " reason=no_positions_available")
    end)

    -- Negative: a failed move leaves the unit HIDE instead of stuck REPOSITIONING
    it("should keep a hiding unit HIDE when movement fails", function()
      local launcherState = { name = "FU1", state = STATE.HIDE }
      local launcher = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveTo").returns({ tag = "FAIL", fields = { reason = "no_positions_available" } })

      sendToFiringPoint(launcherState, launcher)

      assert.are.equal(STATE.HIDE, launcherState.state)
    end)
  end)

  -- ============================================================================
  -- evaluateReadiness
  -- ============================================================================

  describe("evaluateReadiness", function()
    local STATE = constants.MISSILE_UNIT_POSTURE

    ---@param launcherState table|nil
    ---@return SBJ__GroundState
    local function buildGroundState(launcherState)
      return { missileSystemTypes = { srbm = { launchers = { FU1 = launcherState } } } }
    end

    ---China config whose SRBM FU1 is low on ammo at or below 40% of weapon 1
    local function buildConfig()
      return { red = { ground = { missileSystemTypes = {
        srbm = { launchers = { FU1 = { name = "FU1", ammoThreshold = 40, weaponDBID = 1 } } },
      } } } }
    end

    local function evaluateReadiness(groundState, missileSystemType, getUnit, config)
      return MissileSystem.evaluateReadiness(config or buildConfig(), groundState, constants.SIDES.RED, {
        missileSystemType = missileSystemType,
        launcherName = "FU1",
        getUnit = getUnit,
      })
    end

    ---@param current integer
    ---@param max integer
    ---@return table
    local function buildUnit(current, max)
      return {
        name = "FU1",
        guid = "guid-FU1",
        mounts = { { mount_dbid = 10, mount_weapons = { { wpn_dbid = 1, wpn_default = max, wpn_current = current, wpn_maxcap = max } } } }
      }
    end

    ---@param unit table|nil
    ---@return table getUnit spy
    local function trackGetUnit(unit)
      trackStub(GameApi, "ScenEdit_WeaponAllocation").returns(nil)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      return spy.new(function() return unit end)
    end

    -- Negative: a unit the missile system does not track is never looked up in game
    it("should report context_not_found without looking up the unit when it has no state", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))

      local readiness = evaluateReadiness(buildGroundState(nil), "SRBM", getUnit)

      assert.are.equal("context_not_found", readiness)
      assert.spy(getUnit).was_not.called()
    end)

    -- Negative: a system the side does not field has no state for any unit
    it("should report context_not_found for a missile system the side does not field", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE })

      local readiness = evaluateReadiness(groundState, "GLCM", getUnit)

      assert.are.equal("context_not_found", readiness)
    end)

    -- Negative: a unit whose battery config dropped is never looked up in game
    it("should report context_not_found without looking up the unit when it has no config descriptor", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))
      local config = buildConfig()
      config.red.ground.missileSystemTypes.srbm.launchers.FU1 = nil

      local readiness = evaluateReadiness(buildGroundState({ name = "FU1", state = STATE.HIDE }), "SRBM", getUnit, config)

      assert.are.equal("context_not_found", readiness)
      assert.spy(getUnit).was_not.called()
    end)

    -- Negative: a tracked unit that no longer exists in game
    it("should report unit_not_found when the tracked unit is gone from the game", function()
      local getUnit = trackGetUnit(nil)
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE })

      local readiness = evaluateReadiness(groundState, "SRBM", getUnit)

      assert.are.equal("unit_not_found", readiness)
      assert.spy(getUnit).was.called_with("FU1")
    end)

    -- Negative: only a hiding unit can be tasked, even with full ammo
    it("should report bad_state for a unit that is not hiding", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.STATIC })

      local readiness = evaluateReadiness(groundState, "SRBM", getUnit)

      assert.are.equal("bad_state", readiness)
    end)

    -- Negative: 2 of 6 missiles left is 33%, at or below the 40% threshold
    it("should report low_ammo for a hiding unit at or below its ammo threshold", function()
      local getUnit = trackGetUnit(buildUnit(2, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE })

      local readiness = evaluateReadiness(groundState, "SRBM", getUnit)

      assert.are.equal("low_ammo", readiness)
    end)

    -- Positive: a hiding unit with 3 of 6 missiles (50%) is above the 40% threshold
    it("should report available for a hiding unit above its ammo threshold", function()
      local getUnit = trackGetUnit(buildUnit(3, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE })

      local readiness = evaluateReadiness(groundState, "SRBM", getUnit)

      assert.are.equal("available", readiness)
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("processSide reload cycle", function()
    ---Run one reload cycle for Taiwan with the given ground slice, system config and policy mode
    ---@param groundState table
    ---@param missileSystemConfigMap table
    ---@param isAuto boolean
    local function processTaiwan(groundState, missileSystemConfigMap, isAuto)
      local config = { blue = { ground = { missileSystemTypes = missileSystemConfigMap, policy = { isAuto = isAuto } } } }
      local saveData = { blue = { ground = groundState } }
      MissileSystem.processSide(config, saveData, constants.SIDES.BLUE)
    end

    -- Positive: each enabled system gets a run context with its own config and the shared isAuto, plus sideName
    it("should call Cycle.process with each system context and its config", function()
      local srbmState = { enabled = true, id = "srbm" }
      local mrbmState = { enabled = true, id = "mrbm" }
      local srbmConfig = { reloadTime = 300 }
      local mrbmConfig = { reloadTime = 600 }
      local groundState = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmState,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmState,
        }
      }
      local missileSystemConfigMap = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmConfig,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmConfig,
      }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      processTaiwan(groundState, missileSystemConfigMap, true)

      assert.stub(cycleProcessStub).was.called(2)
      assert.stub(cycleProcessStub).was.called_with(srbmState, match.is_same({ systemConfig = srbmConfig, isAuto = true }),
        "Taiwan")
      assert.stub(cycleProcessStub).was.called_with(mrbmState, match.is_same({ systemConfig = mrbmConfig, isAuto = true }),
        "Taiwan")
    end)

    -- Positive: results from multiple systems are aggregated into one tagged log call
    it("should aggregate per-system results into a single tagged log entry", function()
      local srbmState = { enabled = true, id = "srbm" }
      local mrbmState = { enabled = true, id = "mrbm" }
      local mlrsState = { enabled = false, id = "mlrs" }
      local groundState = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmState,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmState,
          [constants.MISSILE_SYSTEM_TYPES.MLRS] = mlrsState,
        }
      }
      local missileSystemConfigMap = {}

      local cycleProcessStub = trackStub(Cycle, "process").invokes(function(systemState)
        if systemState.id == "srbm" then
          return { { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } }
        elseif systemState.id == "mrbm" then
          return { { tag = "WARN", fields = { unit = "MRBM1", action = "low_ammo" } } }
        end
        return {}
      end)

      processTaiwan(groundState, missileSystemConfigMap, true)

      assert.stub(cycleProcessStub).was.called(2) -- MLRS disabled is skipped
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_truthy(string.find(message, "total=2", 1, true))
      assert.is_truthy(string.find(message, "[OK]", 1, true))
      assert.is_truthy(string.find(message, constants.MISSILE_SYSTEM_TYPES.SRBM, 1, true))
      assert.is_truthy(string.find(message, "reload_done", 1, true))
      assert.is_truthy(string.find(message, "SRBM1", 1, true))
      assert.is_truthy(string.find(message, "[WARN]", 1, true))
      assert.is_truthy(string.find(message, constants.MISSILE_SYSTEM_TYPES.MRBM, 1, true))
      assert.is_truthy(string.find(message, "low_ammo", 1, true))
      assert.is_truthy(string.find(message, "MRBM1", 1, true))
    end)

    -- Positive: the log names the run mode so auto and manual sides can be told apart
    it("should report the run mode in the log", function()
      local groundState = { missileSystemTypes = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true } } }
      local missileSystemConfigMap = {}
      trackStub(Cycle, "process").returns({ { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } })

      processTaiwan(groundState, missileSystemConfigMap, false)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "mode=manual", 1, true))
    end)

    -- Negative: failures are logged through Logger.error so they are not hidden by verbose settings
    it("should log reload cycle failures through Logger.error", function()
      local srbmState = { enabled = true, id = "srbm" }
      local groundState = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmState,
        }
      }
      local missileSystemConfigMap = {}

      trackStub(Cycle, "process").returns({
        {
          tag = "FAIL",
          fields = { unit = "SRBM1", action = "move_to_hide_area", reason = "no_ha_defined" }
        }
      })

      processTaiwan(groundState, missileSystemConfigMap, true)

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_truthy(string.find(message, "[FAIL]", 1, true))
      assert.is_truthy(string.find(message, "reason=no_ha_defined", 1, true))
    end)

    -- Negative: skips disabled systems and does not log when no events occurred
    it("should skip disabled systems and not log when no results are returned", function()
      local srbmState = { enabled = true }
      local srbmConfig = { reloadTime = 300 }
      local groundState = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmState,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = { enabled = false },
        }
      }
      local missileSystemConfigMap = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmConfig }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      processTaiwan(groundState, missileSystemConfigMap, false)

      assert.stub(cycleProcessStub).was.called(1)
      assert.stub(cycleProcessStub).was.called_with(srbmState, match.is_same({ systemConfig = srbmConfig, isAuto = false }),
        "Taiwan")
      assert.stub(logStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Shared builders for side-aware entries
  -- ============================================================================

  ---Minimal config/saveData pair whose China and Taiwan sides differ only by policy
  ---@return table config, table saveData
  local function makeSides()
    local config = {
      red = {
        ground = {
          missileSystemTypes = { id = "c-cfg" },
          policy = { isAuto = true, hideOnEnterHA = true, hideTransloaderOnRLNoMeeting = true }
        }
      },
      blue = {
        ground = {
          missileSystemTypes = { id = "t-cfg" },
          policy = { isAuto = false, hideOnEnterHA = false, hideTransloaderOnRLNoMeeting = false }
        }
      }
    }
    local saveData = { red = { ground = { id = "c-ctx" } }, blue = { ground = { id = "t-ctx" } } }
    return config, saveData
  end

  -- ============================================================================
  -- processSide
  -- ============================================================================

  describe("processSide", function()
    -- Positive: each side runs with its own ground slice, ground config and isAuto from policy
    it("should run each side's cycle on its own slice, config and policy mode", function()
      local config, saveData = makeSides()
      local redState = { enabled = true }
      local blueState = { enabled = true }
      local redConfig = { reloadTime = 300 }
      local blueConfig = { reloadTime = 600 }
      config.red.ground.missileSystemTypes = { srbm = redConfig }
      config.blue.ground.missileSystemTypes = { srbm = blueConfig }
      saveData.red.ground.missileSystemTypes = { srbm = redState }
      saveData.blue.ground.missileSystemTypes = { srbm = blueState }
      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.processSide(config, saveData, constants.SIDES.RED)
      MissileSystem.processSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(cycleProcessStub).was.called(2)
      assert.stub(cycleProcessStub).was.called_with(redState, match.is_same({ systemConfig = redConfig, isAuto = true }),
        constants.SIDES.RED)
      assert.stub(cycleProcessStub).was.called_with(blueState, match.is_same({ systemConfig = blueConfig, isAuto = false }),
        constants.SIDES.BLUE)
    end)
  end)

  -- ============================================================================
  -- initSide
  -- ============================================================================

  describe("initSide", function()
    -- Positive: an enabled side builds states from its own ground config into its own slice
    it("should set battery states from the side's ground config when the side is enabled", function()
      local config, saveData = makeSides()
      saveData.blue.ground.enabled = true
      local batteries = { { id = "battery" } }
      local resolveStub = trackStub(Deployment, "resolveBatteries").returns(batteries)
      local stateStub = trackStub(GroundStateStore, "resetBatteryStates")

      MissileSystem.initSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(resolveStub).was.called_with(config.blue.ground.missileSystemTypes)
      assert.stub(stateStub).was.called_with(saveData.blue.ground, batteries)
    end)

    -- Negative: a disabled side builds nothing
    it("should skip a side whose ground forces are disabled", function()
      local config, saveData = makeSides()
      local stateStub = trackStub(GroundStateStore, "resetBatteryStates")

      MissileSystem.initSide(config, saveData, constants.SIDES.RED)

      assert.stub(stateStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- deploySide
  -- ============================================================================

  describe("deploySide", function()
    -- Positive: units and states are built from the side's ground config into the side's slice
    it("should deploy every battery and set its state from the side's ground config", function()
      local config, saveData = makeSides()
      local batteries = { { id = "battery" } }
      local resolveStub = trackStub(Deployment, "resolveBatteries").returns(batteries)
      local deployStub = trackStub(Deployment, "deployBatteries")
      local stateStub = trackStub(GroundStateStore, "resetBatteryStates")

      MissileSystem.deploySide(config, saveData, constants.SIDES.BLUE)

      assert.stub(resolveStub).was.called_with(config.blue.ground.missileSystemTypes)
      assert.stub(deployStub).was.called_with(constants.SIDES.BLUE, batteries)
      assert.stub(stateStub).was.called_with(saveData.blue.ground, batteries)
    end)
  end)

  -- ============================================================================
  -- ensureGroundState
  -- ============================================================================

  describe("ensureGroundState", function()
    -- Positive: the side's own config seeds the side's own slice
    it("should seed the side's slice from the side's ground config", function()
      local config, saveData = makeSides()
      local seedStub = trackStub(GroundStateStore, "ensureGroundState")

      MissileSystem.ensureGroundState(config, saveData, constants.SIDES.BLUE)

      assert.stub(seedStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground)
    end)
  end)

  -- ============================================================================
  -- buildPanelBatteries
  -- ============================================================================

  describe("buildPanelBatteries", function()
    -- Positive: batteries come from the side's ground config and saved state at the current game time
    it("should build the batteries from the side's ground config and saved state at the current time", function()
      local config, saveData = makeSides()
      local batteries = { { name = "FU-1" } }
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(4200)
      local batteriesStub = trackStub(PanelBattery, "buildPanelBatteries").returns(batteries)

      local result = MissileSystem.buildPanelBatteries(config, saveData, constants.SIDES.BLUE)

      assert.are.equal(batteries, result)
      assert.stub(batteriesStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground,
        constants.SIDES.BLUE, 4200)
    end)
  end)

  -- ============================================================================
  -- processArrival
  -- ============================================================================

  describe("processArrival", function()
    -- Positive: side comes from the triggering unit, switches come from that side's policy
    it("should run a China unit against the China slice, contacts and policy", function()
      local config, saveData = makeSides()
      local unit = { name = "FU1", guid = "guid-fu1", side = constants.SIDES.RED }
      local event = { triggers = { { UnitEntersArea = { Description = "(China) Arrive in HA - 1 - AreaA" } } } }
      local launcherState = { name = "FU1" }
      config.red.ground.missileSystemTypes = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = { launchers = { FU1 = { name = "FU1", weaponDBID = 1, ammoThreshold = 40 } } }
      }
      saveData.red.ground = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true, launchers = { FU1 = launcherState }, transloaders = {} }
        }
      }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local dropContactStub = trackStub(contact, "DropContact")
      local getContactsStub = trackStub(GameApi, "ScenEdit_GetContacts").returns({ contact })
      local hideStub = trackStub(Transitions, "hide")
      trackStub(Concealment, "hideUnit").returns(true)

      MissileSystem.processArrival(config, saveData, unit, event)

      assert.stub(getContactsStub).was.called_with(constants.SIDES.RED)
      assert.stub(dropContactStub).was.called(1)
      assert.stub(hideStub).was.called_with(launcherState, unit, true)
    end)

    -- Positive: a Taiwan unit gets the manual policy and the Taiwan slice
    it("should use the Taiwan slice and manual policy for a Taiwan unit", function()
      local config, saveData = makeSides()
      local unit = { name = "RS1", guid = "guid-rs1", side = constants.SIDES.BLUE }
      local event = { triggers = { { UnitEntersArea = { Description = "(Taiwan) Arrive in ATP - 1 - AreaA" } } } }

      local systemState = { enabled = true, launchers = {}, transloaders = { RS1 = { name = "RS1" } } }
      config.blue.ground.missileSystemTypes = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = { transloaders = { RS1 = { name = "RS1", canisterStock = "CS1" } } }
      }
      saveData.blue.ground = { missileSystemTypes = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = systemState } }
      trackStub(GameApi, "ScenEdit_GetContacts").returns(nil)
      trackStub(Meeting, "isAtCanisterStock").returns(false)
      local settleStub = trackStub(Transitions, "settle")

      MissileSystem.processArrival(config, saveData, unit, event)

      assert.stub(settleStub).was.called_with(systemState, unit, false)
    end)
  end)

  -- ============================================================================
  -- completeFireTask / abortFireTask
  -- ============================================================================

  describe("completeFireTask / abortFireTask", function()
    local STATE = constants.MISSILE_UNIT_POSTURE

    local function makeGroundState()
      return {
        missileSystemTypes = {
          srbm = {
            launchers = {
              ["FU-Static"] = { name = "FU-Static", state = STATE.STATIC },
              ["FU-Hide"] = { name = "FU-Hide", state = STATE.HIDE },
              ["FU-Stowing"] = { name = "FU-Stowing", state = STATE.STATIC, stowStartTime = 500 },
            }
          },
          sam = {
            launchers = {
              ["SAM-1"] = { name = "SAM-1", state = STATE.STATIC },
            }
          }
        }
      }
    end

    before_each(function()
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(9000)
    end)

    -- Positive: upper-case system name resolves and every unit without a countdown is stamped
    it("should stamp stowStartTime on every listed unit regardless of state", function()
      local groundState = makeGroundState()
      local launcherNames = { "FU-Static", "FU-Hide" }

      MissileSystem.completeFireTask(groundState, "SRBM", launcherNames)

      assert.are.equal(9000, groundState.missileSystemTypes.srbm.launchers["FU-Static"].stowStartTime)
      assert.are.equal(9000, groundState.missileSystemTypes.srbm.launchers["FU-Hide"].stowStartTime)
    end)

    -- Boundary: a running countdown is preserved
    it("should keep an existing stowStartTime", function()
      local groundState = makeGroundState()
      local launcherNames = { "FU-Stowing" }

      MissileSystem.completeFireTask(groundState, "srbm", launcherNames)

      assert.are.equal(500, groundState.missileSystemTypes.srbm.launchers["FU-Stowing"].stowStartTime)
    end)

    -- Boundary: an aborted task leaves units still in their hide area alone
    it("should skip non-deployed units when the task is aborted", function()
      local groundState = makeGroundState()
      local launcherNames = { "FU-Static", "FU-Hide" }

      MissileSystem.abortFireTask(groundState, "SRBM", launcherNames)

      assert.are.equal(9000, groundState.missileSystemTypes.srbm.launchers["FU-Static"].stowStartTime)
      assert.is_nil(groundState.missileSystemTypes.srbm.launchers["FU-Hide"].stowStartTime)
    end)

    -- Negative: SAM stays on station when its task ends
    it("should not stamp SAM launchers", function()
      local groundState = makeGroundState()
      local launcherNames = { "SAM-1" }

      MissileSystem.completeFireTask(groundState, "SAM", launcherNames)
      MissileSystem.abortFireTask(groundState, "SAM", launcherNames)

      assert.is_nil(groundState.missileSystemTypes.sam.launchers["SAM-1"].stowStartTime)
    end)

    -- Negative: unknown units, unknown systems and missing inputs are ignored
    it("should ignore missing contexts and nil inputs", function()
      local groundState = makeGroundState()
      local ghostUnits = { { name = "Ghost" } }
      local staticUnits = { { name = "FU-Static" } }

      assert.has_no.Error(function()
        MissileSystem.completeFireTask(groundState, "SRBM", ghostUnits)
        MissileSystem.completeFireTask(groundState, "GLCM", staticUnits)
        MissileSystem.completeFireTask(groundState, nil, staticUnits)
        MissileSystem.completeFireTask(groundState, "SRBM", nil)
      end)
      assert.is_nil(groundState.missileSystemTypes.srbm.launchers["FU-Static"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- processSupplyAssetDestruction
  -- ============================================================================

  describe("processSupplyAssetDestruction", function()
    -- Positive: finds the owning system on the unit's side and logs the ammunition delta
    it("should zero the canister stock of whichever system on the unit's side owns it and log the delta", function()
      local srbmState = {
        name = "srbm",
        transloaders = {},
        canisterStocks = {
          ["Canister Stock Alpha"] = { name = "Canister Stock Alpha", weaponCountCurrent = 100 }
        }
      }
      local saveData = {
        red = { ground = { missileSystemTypes = { srbm = { name = "srbm", transloaders = {}, canisterStocks = {} } } } },
        blue = {
          ground = {
            missileSystemTypes = {
              mlrs = { name = "mlrs", transloaders = {}, canisterStocks = {} },
              srbm = srbmState,
            },
          },
        },
      }
      local unit = { name = "Canister Stock Alpha", side = constants.SIDES.BLUE }
      local config = { blue = { ground = { missileSystemTypes = { mlrs = { transloaders = {} }, srbm = { transloaders = {} } } } } }

      local processed = MissileSystem.processSupplyAssetDestruction(config, saveData, unit)

      assert.is_true(processed)
      assert.are.equal(0, srbmState.canisterStocks["Canister Stock Alpha"].weaponCountCurrent)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_truthy(string.find(message, "system=srbm", 1, true))
      assert.is_truthy(string.find(message, "role=canister_stock", 1, true))
      assert.is_truthy(string.find(message, "delta=-100", 1, true))
    end)

    -- Negative: a unit no system tracks is ignored without logging
    it("should return false and stay silent for an untracked unit", function()
      local saveData = { red = { ground = { missileSystemTypes = { srbm = { name = "srbm", transloaders = {}, canisterStocks = {} } } } } }
      local unit = { name = "Random Truck", side = constants.SIDES.RED }
      local config = { red = { ground = { missileSystemTypes = { srbm = { transloaders = {} } } } } }

      local processed = MissileSystem.processSupplyAssetDestruction(config, saveData, unit)

      assert.is_false(processed)
      assert.stub(logStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- getAmmoInventory
  -- ============================================================================

  describe("getAmmoInventory", function()
    -- Positive: delegates with the system state picked from groundState
    it("should report inventory for the requested system", function()
      local srbmState = { name = "srbm" }
      local srbmConfig = { reloadTime = 60 }
      local groundState = { missileSystemTypes = { srbm = srbmState } }
      local config = { red = { ground = { missileSystemTypes = { srbm = srbmConfig } } } }

      local inventoryStub = trackStub(Ammo, "getInventory").returns({ total = { percentage = 80 } })

      local report = MissileSystem.getAmmoInventory(config, groundState, "srbm", constants.SIDES.RED)

      assert.are.equal(80, report.total.percentage)
      assert.stub(inventoryStub).was.called_with(match.is_ref(srbmConfig), match.is_ref(srbmState), constants.SIDES.RED)
    end)

    -- Negative: absent system yields nil
    it("should return nil when the system is absent", function()
      local groundState = { missileSystemTypes = {} }
      local config = { red = { ground = { missileSystemTypes = {} } } }
      assert.is_nil(MissileSystem.getAmmoInventory(config, groundState, "srbm", constants.SIDES.RED))
    end)
  end)

  -- ============================================================================
  -- listSigintEmitters
  -- ============================================================================

  describe("listSigintEmitters", function()
    -- Positive: message comes from config, area from state, systems in the order asked
    it("should list each tracked launcher with its config message and saved area", function()
      local srbmArea, glcmArea = { name = "#SRBM" }, { name = "#GLCM" }
      local config = { blue = { ground = { missileSystemTypes = {
        srbm = { launchers = { FU1 = { name = "FU1", msg = "SRBM radio" } } },
        glcm = { launchers = { FU2 = { name = "FU2", msg = "GLCM radio" } } },
      } } } }
      local saveData = { blue = { ground = { missileSystemTypes = {
        srbm = { launchers = { FU1 = { name = "FU1", msg = "old copy", operationalArea = srbmArea } } },
        glcm = { launchers = { FU2 = { name = "FU2", operationalArea = glcmArea } } },
      } } } }

      local emitters = MissileSystem.listSigintEmitters(config, saveData, constants.SIDES.BLUE, { "glcm", "srbm" })

      assert.are.same({
        { name = "FU2", msg = "GLCM radio", operationalArea = glcmArea },
        { name = "FU1", msg = "SRBM radio", operationalArea = srbmArea },
      }, emitters)
    end)

    -- Negative: a launcher whose battery config dropped is not listed
    it("should leave out a launcher with no config descriptor", function()
      local config = { blue = { ground = { missileSystemTypes = { srbm = { launchers = {} } } } } }
      local saveData = { blue = { ground = { missileSystemTypes = {
        srbm = { launchers = { FU1 = { name = "FU1", operationalArea = {} } } },
      } } } }

      assert.are.same({}, MissileSystem.listSigintEmitters(config, saveData, constants.SIDES.BLUE, { "srbm" }))
    end)
  end)

  -- ============================================================================
  -- redeployFromControlPanel
  -- ============================================================================

  describe("redeployFromControlPanel", function()
    ---Let deployment run against an empty map: no old units, every add succeeds
    local function stubUnitSpawning()
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      trackStub(GameUtils, "resolveUnitType").returns("Coy")
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)
      trackStub(GameApi, "ScenEdit_ClearAllMagazines")
    end

    ---One battery whose config area is OPAREA-CONFIG, already moved to OPAREA-SAVED in saved state
    local function makeMovedBattery()
      local configArea = { name = "OPAREA-CONFIG", HA = { { course = { { latitude = 1, longitude = 1 } } } },
        RL = { { course = { { latitude = 2, longitude = 2 } } } }, ATP = { { course = { { latitude = 3, longitude = 3 } } } } }
      local config = {
        blue = { ground = { missileSystemTypes = { srbm = {
          launchers = { ["FU-A"] = { name = "FU-A", dbid = 1, weaponDBID = 2, transloader = "RU-A", operationalArea = configArea } },
          transloaders = { ["RU-A"] = { name = "RU-A", unitCount = 1, canisterStock = "AMMO-A", launcher = "FU-A",
            operationalArea = configArea } },
          canisterStocks = { ["AMMO-A"] = { name = "AMMO-A" } }
        } } } }
      }
      local saveData = { blue = { ground = {} } }
      local configMap = config.blue.ground.missileSystemTypes
      GroundStateStore.ensureGroundState(configMap, saveData.blue.ground)
      local systemState = saveData.blue.ground.missileSystemTypes.srbm
      systemState.launchers["FU-A"] = { name = "FU-A", operationalArea = { name = "OPAREA-SAVED" } }
      systemState.transloaders["RU-A"] = { name = "RU-A", operationalArea = { name = "OPAREA-SAVED" } }
      systemState.canisterStocks["AMMO-A"] = { name = "AMMO-A" }
      return config, saveData
    end

    -- Positive: after a save/load the battery sits at its saved area, so that area's zones are the ones removed
    it("should remove the zones of the battery's saved area, not its config area", function()
      local config, saveData = makeMovedBattery()
      local newArea = { name = "OPAREA-NEW", HA = { { course = { { latitude = 4, longitude = 4 } } } },
        RL = { { course = { { latitude = 5, longitude = 5 } } } }, ATP = { { course = { { latitude = 6, longitude = 6 } } } } }
      trackStub(PanelBattery, "buildOperationalArea").returns(newArea)
      local triggersStub = trackStub(PositionZones, "rebuild")
      stubUnitSpawning()

      MissileSystem.redeployFromControlPanel(config, saveData, constants.SIDES.BLUE,
        { { missileSystemType = "srbm", name = "FU-A", placement = {} } })

      local newAreas, removedAreas = triggersStub.calls[1].vals[1], triggersStub.calls[1].vals[2]
      assert.are.same({ "OPAREA-NEW" }, { newAreas[1].name })
      assert.are.same({ "OPAREA-SAVED" }, { removedAreas[1].name })
    end)

    -- Negative: config is the template for the next deploySide and must never take the player's placement
    it("should leave the side's config unchanged", function()
      local config, saveData = makeMovedBattery()
      local srbmConfig = config.blue.ground.missileSystemTypes.srbm
      local launcherDescriptor = srbmConfig.launchers["FU-A"]
      local transloaderDescriptor = srbmConfig.transloaders["RU-A"]
      local canisterStockDescriptor = srbmConfig.canisterStocks["AMMO-A"]
      local configArea = launcherDescriptor.operationalArea
      trackStub(PanelBattery, "buildOperationalArea").returns({ name = "OPAREA-NEW" })
      trackStub(PositionZones, "rebuild")
      stubUnitSpawning()

      MissileSystem.redeployFromControlPanel(config, saveData, constants.SIDES.BLUE,
        { { missileSystemType = "srbm", name = "FU-A", placement = {} } })

      assert.are.equal(launcherDescriptor, srbmConfig.launchers["FU-A"])
      assert.are.equal(transloaderDescriptor, srbmConfig.transloaders["RU-A"])
      assert.are.equal(canisterStockDescriptor, srbmConfig.canisterStocks["AMMO-A"])
      assert.are.equal(configArea, launcherDescriptor.operationalArea)
      assert.are.equal("OPAREA-CONFIG", configArea.name)
      assert.are.equal("OPAREA-NEW", saveData.blue.ground.missileSystemTypes.srbm.launchers["FU-A"].operationalArea.name)
    end)

    -- Positive: zones go first so their mask lands on the new area before state copies it
    it("should rebuild triggers, then units, then state, for the batteries the redeployments name", function()
      local config, saveData = makeMovedBattery()
      local redeployments = {
        { missileSystemType = "srbm", name = "FU-A", placement = {} },
        { missileSystemType = "srbm", name = "Ghost", placement = {} }
      }
      local newArea = { name = "#NEW" }
      local buildAreaStub = trackStub(PanelBattery, "buildOperationalArea").returns(newArea)
      local calls = {}
      local triggersStub = trackStub(PositionZones, "rebuild").invokes(function()
        table.insert(calls, "rebuild")
      end)
      local deployStub = trackStub(Deployment, "deployBatteries").invokes(function()
        table.insert(calls, "deployBatteries")
      end)
      local stateStub = trackStub(GroundStateStore, "resetBatteryStates").invokes(function()
        table.insert(calls, "resetBatteryStates")
      end)

      MissileSystem.redeployFromControlPanel(config, saveData, constants.SIDES.BLUE, redeployments)

      assert.stub(buildAreaStub).was.called_with(redeployments[1].placement)
      assert.are.same({ "rebuild", "deployBatteries", "resetBatteryStates" }, calls)
      assert.stub(triggersStub).was.called_with({ newArea }, match._, {
        constants.POSITION_TYPES.RELOAD_POINT,
        constants.POSITION_TYPES.FIRING_POINT,
        constants.POSITION_TYPES.HIDE_AREA,
        constants.POSITION_TYPES.AMMUNITION_TRANSFER_POINT
      }, "Taiwan")
      local batteries = deployStub.calls[1].vals[2]
      assert.are.equal(1, #batteries)
      assert.are.equal("FU-A", batteries[1].launcher.name)
      assert.are.same(newArea, batteries[1].operationalArea)
      assert.stub(deployStub).was.called_with("Taiwan", batteries)
      assert.stub(stateStub).was.called_with(saveData.blue.ground, batteries)
    end)

    -- Positive: only the redeployed battery is reset; another battery keeps its runtime state and ammo
    it("should reset only the redeployed battery and keep the other batteries' state", function()
      local function makeBattery(suffix)
        return { name = "FU-" .. suffix, state = constants.MISSILE_UNIT_POSTURE.HIDE, transloader = "RU-" .. suffix,
            operationalArea = { name = "OPAREA-" .. suffix } },
          { name = "RU-" .. suffix, weaponCountCurrent = 8, unitCount = 1, canisterStock = "AMMO-" .. suffix,
            operationalArea = { name = "OPAREA-" .. suffix } },
          { name = "AMMO-" .. suffix, weaponCountCurrent = 40 }
      end
      local launcherA, transloaderA, ammoA = makeBattery("A")
      local launcherB, transloaderB, ammoB = makeBattery("B")
      local config = {
        blue = { ground = { missileSystemTypes = { srbm = {
          launchers = { ["FU-A"] = launcherA, ["FU-B"] = launcherB },
          transloaders = { ["RU-A"] = transloaderA, ["RU-B"] = transloaderB },
          canisterStocks = { ["AMMO-A"] = ammoA, ["AMMO-B"] = ammoB }
        } } } }
      }
      local saveData = { blue = { ground = {} } }
      local configMap = config.blue.ground.missileSystemTypes
      GroundStateStore.ensureGroundState(configMap, saveData.blue.ground)
      GroundStateStore.resetBatteryStates(saveData.blue.ground, Deployment.resolveBatteries(configMap))

      local systemState = saveData.blue.ground.missileSystemTypes.srbm
      systemState.launchers["FU-A"].weaponCountCurrent = 1
      systemState.launchers["FU-B"].state = constants.MISSILE_UNIT_POSTURE.RELOAD
      systemState.launchers["FU-B"].reloadStartTime = 123
      systemState.transloaders["RU-B"].weaponCountCurrent = 2
      systemState.canisterStocks["AMMO-B"].weaponCountCurrent = 5

      local newArea = { name = "#NEW" }
      trackStub(PanelBattery, "buildOperationalArea").returns(newArea)
      trackStub(PositionZones, "rebuild")
      stubUnitSpawning()
      local redeployments = { { missileSystemType = "srbm", name = "FU-A", placement = {} } }

      MissileSystem.redeployFromControlPanel(config, saveData, constants.SIDES.BLUE, redeployments)

      assert.are.same(newArea, systemState.launchers["FU-A"].operationalArea)
      assert.is_nil(systemState.launchers["FU-A"].weaponCountCurrent)
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.RELOAD, systemState.launchers["FU-B"].state)
      assert.are.equal(123, systemState.launchers["FU-B"].reloadStartTime)
      assert.are.equal(2, systemState.transloaders["RU-B"].weaponCountCurrent)
      assert.are.equal(5, systemState.canisterStocks["AMMO-B"].weaponCountCurrent)
    end)
  end)
end)
