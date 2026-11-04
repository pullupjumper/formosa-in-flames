---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
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
local Triggers = require("src.modules.missileSystem.triggers")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local StatusView = require("src.modules.missileSystem.statusView")
local ControlPanelLayout = require("src.modules.missileSystem.controlPanelLayout")
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
    local STATE = constants.MISSILE_SYSTEM_STATE

    ---@type luassert.spy
    local moveFromHideAreaStub

    before_each(function()
      moveFromHideAreaStub = trackStub(Concealment, "moveFromHideArea").returns(true)
    end)

    ---Send FU1 of an SRBM battery whose state and game unit are given
    ---@param firingUnitState table|nil
    ---@param firingUnit table|nil
    ---@return boolean inPosition
    ---@return boolean isMissing
    local function sendToFiringPoint(firingUnitState, firingUnit)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local groundState = { missileSystemTypes = { srbm = { firingUnits = { FU1 = firingUnitState } } } }
      return MissileSystem.sendToFiringPoint(groundState, "SRBM", "FU1")
    end

    -- Negative: a tracked unit that no longer exists in game is reported missing
    it("should report a missing unit without moving anything when the unit is gone", function()
      local moveStub = trackStub(Movement, "moveToFiringPoint")

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

    -- Positive: a unit with both state and game unit is not missing
    it("should report a present unit as not missing", function()
      local _, isMissing = sendToFiringPoint({ name = "FU1", state = STATE.STATIC }, { name = "FU1" })

      assert.is_false(isMissing)
    end)

    -- Positive: a hiding unit with ammo leaves its hide area and heads to FP
    it("should unload and move a hiding unit with enough ammo", function()
      local firingUnitState = { name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 }
      local firingUnit = { name = "FU1" }
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local moveStub = trackStub(Movement, "moveToFiringPoint").returns(true)

      local inPosition = sendToFiringPoint(firingUnitState, firingUnit)

      assert.is_false(inPosition)
      assert.stub(isLowAmmoStub).was.called_with(firingUnit, 40, 1)
      assert.stub(moveFromHideAreaStub).was.called_with(match.is_ref(firingUnitState), firingUnit)
      assert.stub(moveStub).was.called_with(match.is_ref(firingUnitState), firingUnit)
      assert.stub(errorStub).was_not.called()
      assert.are.equal(STATE.REPOSITIONING, firingUnitState.state)
    end)

    -- Positive: a unit already at its firing point reports in position without new commands
    it("should report in position for a STATIC unit without moving it", function()
      local firingUnitState = { name = "FU1", state = STATE.STATIC }
      local firingUnit = { name = "FU1" }
      local moveStub = trackStub(Movement, "moveToFiringPoint")

      local inPosition = sendToFiringPoint(firingUnitState, firingUnit)

      assert.is_true(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: low ammo keeps the unit hidden
    it("should keep a hiding unit with low ammo in place", function()
      local firingUnitState = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(true)
      local moveStub = trackStub(Movement, "moveToFiringPoint")

      local inPosition = sendToFiringPoint(firingUnitState, firingUnit)

      assert.is_false(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: logs when movement fails with structured fields
    it("should log an error when movement fails", function()
      local firingUnitState = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveToFiringPoint")
          .returns(false, { reason = "no_positions_available", position = "FP", area = "OPAREA-1" })

      sendToFiringPoint(firingUnitState, firingUnit)

      assert.stub(errorStub).was.called(1)
      assert.stub(errorStub).was.called_with(
        "[FAIL] module=missileSystem area=OPAREA-1 unit=FU1 action=move_to_firing_point position=FP" ..
        " reason=no_positions_available")
    end)

    -- Negative: a failed move leaves the unit HIDE instead of stuck REPOSITIONING
    it("should keep a hiding unit HIDE when movement fails", function()
      local firingUnitState = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveToFiringPoint").returns(false, { reason = "no_positions_available" })

      sendToFiringPoint(firingUnitState, firingUnit)

      assert.are.equal(STATE.HIDE, firingUnitState.state)
    end)

    -- Boundary: failure without error fields should not log (avoid "[FAIL] nil")
    it("should not log when movement fails without error fields", function()
      local firingUnitState = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveToFiringPoint").returns(false)

      sendToFiringPoint(firingUnitState, firingUnit)

      assert.stub(errorStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- evaluateReadiness
  -- ============================================================================

  describe("evaluateReadiness", function()
    local STATE = constants.MISSILE_SYSTEM_STATE

    ---@param firingUnitState table|nil
    ---@return SBJ__GroundState
    local function buildGroundState(firingUnitState)
      return { missileSystemTypes = { srbm = { firingUnits = { FU1 = firingUnitState } } } }
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

      local readiness = MissileSystem.evaluateReadiness(buildGroundState(nil), "SRBM", "FU1", getUnit)

      assert.are.equal("context_not_found", readiness)
      assert.spy(getUnit).was_not.called()
    end)

    -- Negative: a system the side does not field has no state for any unit
    it("should report context_not_found for a missile system the side does not field", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 })

      local readiness = MissileSystem.evaluateReadiness(groundState, "GLCM", "FU1", getUnit)

      assert.are.equal("context_not_found", readiness)
    end)

    -- Negative: a tracked unit that no longer exists in game
    it("should report unit_not_found when the tracked unit is gone from the game", function()
      local getUnit = trackGetUnit(nil)
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 })

      local readiness = MissileSystem.evaluateReadiness(groundState, "SRBM", "FU1", getUnit)

      assert.are.equal("unit_not_found", readiness)
      assert.spy(getUnit).was.called_with("FU1")
    end)

    -- Negative: only a hiding unit can be tasked, even with full ammo
    it("should report bad_state for a unit that is not hiding", function()
      local getUnit = trackGetUnit(buildUnit(6, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.STATIC, ammoThreshold = 40, weaponDBID = 1 })

      local readiness = MissileSystem.evaluateReadiness(groundState, "SRBM", "FU1", getUnit)

      assert.are.equal("bad_state", readiness)
    end)

    -- Negative: 2 of 6 missiles left is 33%, at or below the 40% threshold
    it("should report low_ammo for a hiding unit at or below its ammo threshold", function()
      local getUnit = trackGetUnit(buildUnit(2, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 })

      local readiness = MissileSystem.evaluateReadiness(groundState, "SRBM", "FU1", getUnit)

      assert.are.equal("low_ammo", readiness)
    end)

    -- Positive: a hiding unit with 3 of 6 missiles (50%) is above the 40% threshold
    it("should report available for a hiding unit above its ammo threshold", function()
      local getUnit = trackGetUnit(buildUnit(3, 6))
      local groundState = buildGroundState({ name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 })

      local readiness = MissileSystem.evaluateReadiness(groundState, "SRBM", "FU1", getUnit)

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
          policy = { isAuto = true, hideOnEnterHA = true, hideResupplyOnRLNoMeeting = true }
        }
      },
      blue = {
        ground = {
          missileSystemTypes = { id = "t-cfg" },
          policy = { isAuto = false, hideOnEnterHA = false, hideResupplyOnRLNoMeeting = false }
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
    it("should init contexts from the side's ground config when the side is enabled", function()
      local config, saveData = makeSides()
      saveData.blue.ground.enabled = true
      local contextStub = trackStub(GroundStateStore, "initMissileSystemStates")

      MissileSystem.initSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(contextStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground)
    end)

    -- Negative: a disabled side builds nothing
    it("should skip a side whose ground forces are disabled", function()
      local config, saveData = makeSides()
      local contextStub = trackStub(GroundStateStore, "initMissileSystemStates")

      MissileSystem.initSide(config, saveData, constants.SIDES.RED)

      assert.stub(contextStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- deploySide
  -- ============================================================================

  describe("deploySide", function()
    -- Positive: units and states are built from the side's ground config into the side's slice
    it("should add units and init contexts from the side's ground config", function()
      local config, saveData = makeSides()
      local addStub = trackStub(Deployment, "addMissileSystems")
      local contextStub = trackStub(GroundStateStore, "initMissileSystemStates")

      MissileSystem.deploySide(config, saveData, constants.SIDES.BLUE)

      assert.stub(addStub).was.called_with(config.blue.ground.missileSystemTypes, constants.SIDES.BLUE)
      assert.stub(contextStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground)
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
  -- buildDeploymentSystems
  -- ============================================================================

  describe("buildDeploymentSystems", function()
    -- Positive: rows come from the side's ground config and saved ground state
    it("should return the deployment systems built from the side's ground config and saved state", function()
      local config = makeSides()
      local rows = { srbm = { id = "row" } }
      local rowsStub = trackStub(ControlPanelLayout, "buildDeploymentSystems").returns(rows)

      local saveData = { blue = { ground = { missileSystemTypes = {} } } }

      local result = MissileSystem.buildDeploymentSystems(config, saveData, constants.SIDES.BLUE)

      assert.are.equal(rows, result)
      assert.stub(rowsStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground,
        constants.SIDES.BLUE)
    end)
  end)

  -- ============================================================================
  -- buildBatteryStatuses
  -- ============================================================================

  describe("buildBatteryStatuses", function()
    -- Positive: the side's slice and config are read at the current game time
    it("should build battery statuses from the side's slice and config at the current time", function()
      local config, saveData = makeSides()
      local rows = { { name = "FU-1" } }
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(4200)
      local rowsStub = trackStub(StatusView, "buildBatteryStatuses").returns(rows)

      local result = MissileSystem.buildBatteryStatuses(config, saveData, constants.SIDES.BLUE)

      assert.are.equal(rows, result)
      assert.stub(rowsStub).was.called_with(saveData.blue.ground, config.blue.ground.missileSystemTypes, 4200)
    end)
  end)

  -- ============================================================================
  -- processUnitEntersArea
  -- ============================================================================

  describe("processUnitEntersArea", function()
    -- Positive: side comes from the triggering unit, switches come from that side's policy
    it("should run a China unit against the China slice, contacts and policy", function()
      local config, saveData = makeSides()
      local unit = { name = "FU1", guid = "guid-fu1", side = constants.SIDES.RED }
      local event = { triggers = { { UnitEntersArea = { Description = "(China) Arrive in HA - 1 - AreaA" } } } }
      local firingUnitState = { name = "FU1" }
      saveData.red.ground = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true, firingUnits = { FU1 = firingUnitState }, resupplyUnits = {} }
        }
      }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local dropContactStub = trackStub(contact, "DropContact")
      local getContactsStub = trackStub(GameApi, "ScenEdit_GetContacts").returns({ contact })
      local hideStub = trackStub(Transitions, "hide")
      trackStub(Concealment, "hideUnit").returns(true)

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(getContactsStub).was.called_with(constants.SIDES.RED)
      assert.stub(dropContactStub).was.called(1)
      assert.stub(hideStub).was.called_with(firingUnitState, unit, true)
    end)

    -- Positive: a Taiwan unit gets the manual policy and the Taiwan slice
    it("should use the Taiwan slice and manual policy for a Taiwan unit", function()
      local config, saveData = makeSides()
      local unit = { name = "RS1", guid = "guid-rs1", side = constants.SIDES.BLUE }
      local event = { triggers = { { UnitEntersArea = { Description = "(Taiwan) Arrive in AHA - 1 - AreaA" } } } }

      local systemState = { enabled = true, firingUnits = {}, resupplyUnits = { RS1 = { name = "RS1" } } }
      saveData.blue.ground = { missileSystemTypes = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = systemState } }
      trackStub(GameApi, "ScenEdit_GetContacts").returns(nil)
      trackStub(Meeting, "hasMetAmmoDepot").returns(false, nil)
      local settleStub = trackStub(Transitions, "settle")

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(settleStub).was.called_with(systemState, unit, false)
    end)
  end)

  -- ============================================================================
  -- startStow
  -- ============================================================================

  describe("startStow", function()
    local STATE = constants.MISSILE_SYSTEM_STATE

    local function makeGroundState()
      return {
        missileSystemTypes = {
          srbm = {
            firingUnits = {
              ["FU-Static"] = { name = "FU-Static", state = STATE.STATIC },
              ["FU-Hide"] = { name = "FU-Hide", state = STATE.HIDE },
              ["FU-Stowing"] = { name = "FU-Stowing", state = STATE.STATIC, stowStartTime = 500 },
            }
          },
          sam = {
            firingUnits = {
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
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.startStow(groundState, "SRBM", firingUnits)

      assert.are.equal(9000, groundState.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.are.equal(9000, groundState.missileSystemTypes.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Boundary: a running countdown is preserved
    it("should keep an existing stowStartTime", function()
      local groundState = makeGroundState()
      local firingUnits = { { name = "FU-Stowing" } }

      MissileSystem.startStow(groundState, "srbm", firingUnits)

      assert.are.equal(500, groundState.missileSystemTypes.srbm.firingUnits["FU-Stowing"].stowStartTime)
    end)

    -- Boundary: onlyDeployed leaves units still in their hide area alone
    it("should skip non-deployed units when onlyDeployed is set", function()
      local groundState = makeGroundState()
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.startStow(groundState, "SRBM", firingUnits, { onlyDeployed = true })

      assert.are.equal(9000, groundState.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.is_nil(groundState.missileSystemTypes.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Negative: SAM never stows
    it("should not stamp SAM firing units", function()
      local groundState = makeGroundState()
      local firingUnits = { { name = "SAM-1" } }

      MissileSystem.startStow(groundState, "SAM", firingUnits)

      assert.is_nil(groundState.missileSystemTypes.sam.firingUnits["SAM-1"].stowStartTime)
    end)

    -- Negative: unknown units, unknown systems and missing inputs are ignored
    it("should ignore missing contexts and nil inputs", function()
      local groundState = makeGroundState()
      local ghostUnits = { { name = "Ghost" } }
      local staticUnits = { { name = "FU-Static" } }

      assert.has_no.Error(function()
        MissileSystem.startStow(groundState, "SRBM", ghostUnits)
        MissileSystem.startStow(groundState, "GLCM", staticUnits)
        MissileSystem.startStow(groundState, nil, staticUnits)
        MissileSystem.startStow(groundState, "SRBM", nil)
      end)
      assert.is_nil(groundState.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- processSupplyAssetDestruction
  -- ============================================================================

  describe("processSupplyAssetDestruction", function()
    -- Positive: finds the owning system on the unit's side and logs the ammunition delta
    it("should zero the depot of whichever system on the unit's side owns it and log the delta", function()
      local srbmState = {
        name = "srbm",
        resupplyUnits = {},
        ammunitions = {
          ["Ammo Depot Alpha"] = { name = "Ammo Depot Alpha", weaponCountCurrent = 100 }
        }
      }
      local saveData = {
        red = { ground = { missileSystemTypes = { srbm = { name = "srbm", resupplyUnits = {}, ammunitions = {} } } } },
        blue = {
          ground = {
            missileSystemTypes = {
              mlrs = { name = "mlrs", resupplyUnits = {}, ammunitions = {} },
              srbm = srbmState,
            },
          },
        },
      }
      local unit = { name = "Ammo Depot Alpha", side = constants.SIDES.BLUE }

      local processed = MissileSystem.processSupplyAssetDestruction(saveData, unit)

      assert.is_true(processed)
      assert.are.equal(0, srbmState.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_truthy(string.find(message, "system=srbm", 1, true))
      assert.is_truthy(string.find(message, "role=ammo_depot", 1, true))
      assert.is_truthy(string.find(message, "delta=-100", 1, true))
    end)

    -- Negative: a unit no system tracks is ignored without logging
    it("should return false and stay silent for an untracked unit", function()
      local saveData = { red = { ground = { missileSystemTypes = { srbm = { name = "srbm", resupplyUnits = {}, ammunitions = {} } } } } }
      local unit = { name = "Random Truck", side = constants.SIDES.RED }

      local processed = MissileSystem.processSupplyAssetDestruction(saveData, unit)

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
      local groundState = { missileSystemTypes = { srbm = srbmState } }

      local inventoryStub = trackStub(Ammo, "getInventory").returns({ total = { percentage = 80 } })

      local report = MissileSystem.getAmmoInventory(groundState, "srbm", "China")

      assert.are.equal(80, report.total.percentage)
      assert.stub(inventoryStub).was.called_with(srbmState, "China")
    end)

    -- Negative: absent system yields nil
    it("should return nil when the system is absent", function()
      local groundState = { missileSystemTypes = {} }
      assert.is_nil(MissileSystem.getAmmoInventory(groundState, "srbm", "China"))
    end)
  end)

  -- ============================================================================
  -- redeployFromControlPanel
  -- ============================================================================

  describe("redeployFromControlPanel", function()
    -- Positive: setup entries become layouts applied first, then zones, units and state are rebuilt in order
    it("should apply layouts from the setup entries, then rebuild triggers, units and contexts in order", function()
      local config, saveData = makeSides()
      local missileSystemConfigMap = config.blue.ground.missileSystemTypes
      local groundState = saveData.blue.ground
      local entries = { { unitname = "FU-1" } }
      local layouts = { { category = "srbm", unitname = "FU-1", operationalArea = { name = "#NEW" } } }
      local buildLayoutsStub = trackStub(ControlPanelLayout, "buildLayouts").returns(layouts)
      local newAreas = { { name = "#NEW" } }
      local oldAreas = { { name = "OPAREA-OLD" } }
      local calls = {}

      trackStub(Deployment, "updateLayouts").invokes(function()
        table.insert(calls, "updateLayouts")
        return newAreas, oldAreas
      end)
      local triggersStub = trackStub(Triggers, "initEventTriggers").invokes(function()
        table.insert(calls, "initEventTriggers")
      end)
      local addStub = trackStub(Deployment, "addMissileSystems").invokes(function()
        table.insert(calls, "addMissileSystems")
      end)
      local contextStub = trackStub(GroundStateStore, "initMissileSystemStates").invokes(function()
        table.insert(calls, "initMissileSystemStates")
      end)

      MissileSystem.redeployFromControlPanel(config, saveData, constants.SIDES.BLUE, entries)

      assert.stub(buildLayoutsStub).was.called_with(entries)
      assert.are.same({ "updateLayouts", "initEventTriggers", "addMissileSystems", "initMissileSystemStates" }, calls)
      assert.stub(triggersStub).was.called_with(newAreas, oldAreas, {
        constants.POSITION_TYPES.RELOAD_POINT,
        constants.POSITION_TYPES.FIRING_POINT,
        constants.POSITION_TYPES.HIDE_AREA,
        constants.POSITION_TYPES.AMMO_HOLDING_AREA
      }, "Taiwan")
      assert.stub(addStub).was.called_with(missileSystemConfigMap, "Taiwan", { ["FU-1"] = true })
      assert.stub(contextStub).was.called_with(missileSystemConfigMap, groundState)
    end)
  end)
end)
