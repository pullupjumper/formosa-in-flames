-- MissileSystem Init Unit Tests
local stub = require("luassert.stub")
local match = require("luassert.match")
local MissileSystem = require("src.modules.missileSystem.init")
local Movement = require("src.modules.missileSystem.movement")
local Cycle = require("src.modules.missileSystem.cycle")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Ammo = require("src.modules.missileSystem.ammo")
local Deployment = require("src.modules.missileSystem.deployment")
local Triggers = require("src.modules.missileSystem.triggers")
local Context = require("src.modules.missileSystem.context")
local StatusView = require("src.modules.missileSystem.statusView")
local SetupLayout = require("src.modules.missileSystem.setupLayout")
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

    -- Positive: a hiding unit with ammo leaves its hide area and heads to FP
    it("should unload and move a hiding unit with enough ammo", function()
      local firingUnitCtx = { name = "FU1", state = STATE.HIDE, ammoThreshold = 40, weaponDBID = 1 }
      local firingUnit = { name = "FU1" }
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local moveStub = trackStub(Movement, "moveToFiringPoint").returns(true)

      local inPosition = MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(inPosition)
      assert.stub(isLowAmmoStub).was.called_with(firingUnit, 40, 1)
      assert.stub(moveFromHideAreaStub).was.called_with(firingUnitCtx, firingUnit)
      assert.stub(moveStub).was.called_with(firingUnitCtx, firingUnit)
      assert.stub(errorStub).was_not.called()
    end)

    -- Positive: a unit already at its firing point reports in position without new commands
    it("should report in position for a STATIC unit without moving it", function()
      local firingUnitCtx = { name = "FU1", state = STATE.STATIC }
      local firingUnit = { name = "FU1" }
      local moveStub = trackStub(Movement, "moveToFiringPoint")

      local inPosition = MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_true(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: a unit on its way is not commanded again
    it("should not command a REPOSITIONING unit", function()
      local firingUnitCtx = { name = "FU1", state = STATE.REPOSITIONING }
      local firingUnit = { name = "FU1" }
      local moveStub = trackStub(Movement, "moveToFiringPoint")

      local inPosition = MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(inPosition)
      assert.stub(moveStub).was_not.called()
    end)

    -- Negative: low ammo keeps the unit hidden
    it("should keep a hiding unit with low ammo in place", function()
      local firingUnitCtx = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(true)
      local moveStub = trackStub(Movement, "moveToFiringPoint")

      local inPosition = MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(inPosition)
      assert.stub(moveStub).was_not.called()
      assert.stub(moveFromHideAreaStub).was_not.called()
    end)

    -- Negative: logs when movement fails with structured fields
    it("should log an error when movement fails", function()
      local firingUnitCtx = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveToFiringPoint")
          .returns(false, { reason = "no_positions_available", position = "FP", area = "OPAREA-1" })

      MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(errorStub).was.called(1)
      assert.stub(errorStub).was.called_with(
        "[FAIL] module=missileSystem area=OPAREA-1 unit=FU1 action=move_to_firing_point position=FP" ..
        " reason=no_positions_available")
    end)

    -- Boundary: failure without error fields should not log (avoid "[FAIL] nil")
    it("should not log when movement fails without error fields", function()
      local firingUnitCtx = { name = "FU1", state = STATE.HIDE }
      local firingUnit = { name = "FU1" }

      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Movement, "moveToFiringPoint").returns(false)

      MissileSystem.sendToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(errorStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    -- Positive: each enabled system gets a run context with its own config and the shared isAuto, plus sideName
    it("should call Cycle.process with each system context and its config", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local mrbmCtx = { enabled = true, id = "mrbm" }
      local srbmConfig = { reloadTime = 300 }
      local mrbmConfig = { reloadTime = 600 }
      local groundCtx = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCtx,
        }
      }
      local missileSystemConfigMap = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmConfig,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmConfig,
      }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.process(groundCtx, missileSystemConfigMap, true, "Taiwan")

      assert.stub(cycleProcessStub).was.called(2)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, match.is_same({ systemConfig = srbmConfig, isAuto = true }),
        "Taiwan")
      assert.stub(cycleProcessStub).was.called_with(mrbmCtx, match.is_same({ systemConfig = mrbmConfig, isAuto = true }),
        "Taiwan")
    end)

    -- Positive: results from multiple systems are aggregated into one tagged log call
    it("should aggregate per-system results into a single tagged log entry", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local mrbmCtx = { enabled = true, id = "mrbm" }
      local mlrsCtx = { enabled = false, id = "mlrs" }
      local groundCtx = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCtx,
          [constants.MISSILE_SYSTEM_TYPES.MLRS] = mlrsCtx,
        }
      }
      local missileSystemConfigMap = {}

      local cycleProcessStub = trackStub(Cycle, "process").invokes(function(systemCtx)
        if systemCtx.id == "srbm" then
          return { { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } }
        elseif systemCtx.id == "mrbm" then
          return { { tag = "WARN", fields = { unit = "MRBM1", action = "low_ammo" } } }
        end
        return {}
      end)

      MissileSystem.process(groundCtx, missileSystemConfigMap, true, "Taiwan")

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
      local groundCtx = { missileSystemTypes = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true } } }
      local missileSystemConfigMap = {}
      trackStub(Cycle, "process").returns({ { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } })

      MissileSystem.process(groundCtx, missileSystemConfigMap, false, "Taiwan")

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "mode=manual", 1, true))
    end)

    -- Negative: failures are logged through Logger.error so they are not hidden by verbose settings
    it("should log reload cycle failures through Logger.error", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local groundCtx = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        }
      }
      local missileSystemConfigMap = {}

      trackStub(Cycle, "process").returns({
        {
          tag = "FAIL",
          fields = { unit = "SRBM1", action = "move_to_hide_area", reason = "no_ha_defined" }
        }
      })

      MissileSystem.process(groundCtx, missileSystemConfigMap, true, "Taiwan")

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_truthy(string.find(message, "[FAIL]", 1, true))
      assert.is_truthy(string.find(message, "reason=no_ha_defined", 1, true))
    end)

    -- Negative: skips disabled systems and does not log when no events occurred
    it("should skip disabled systems and not log when no results are returned", function()
      local srbmCtx = { enabled = true }
      local srbmConfig = { reloadTime = 300 }
      local groundCtx = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
          [constants.MISSILE_SYSTEM_TYPES.MRBM] = { enabled = false },
        }
      }
      local missileSystemConfigMap = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmConfig }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.process(groundCtx, missileSystemConfigMap, false, "Taiwan")

      assert.stub(cycleProcessStub).was.called(1)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, match.is_same({ systemConfig = srbmConfig, isAuto = false }),
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
    it("should pass the side's slice, config and policy mode to process", function()
      local config, saveData = makeSides()
      local processStub = trackStub(MissileSystem, "process")

      MissileSystem.processSide(config, saveData, constants.SIDES.RED)
      MissileSystem.processSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(processStub).was.called(2)
      assert.stub(processStub).was.called_with(saveData.red.ground, config.red.ground.missileSystemTypes, true,
        constants.SIDES.RED)
      assert.stub(processStub).was.called_with(saveData.blue.ground, config.blue.ground.missileSystemTypes, false,
        constants.SIDES.BLUE)
    end)
  end)

  -- ============================================================================
  -- initSide
  -- ============================================================================

  describe("initSide", function()
    -- Positive: an enabled side builds contexts from its own ground config into its own slice
    it("should init contexts from the side's ground config when the side is enabled", function()
      local config, saveData = makeSides()
      saveData.blue.ground.enabled = true
      local contextStub = trackStub(Context, "initMissileSystemContexts")

      MissileSystem.initSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(contextStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground)
    end)

    -- Negative: a disabled side builds nothing
    it("should skip a side whose ground forces are disabled", function()
      local config, saveData = makeSides()
      local contextStub = trackStub(Context, "initMissileSystemContexts")

      MissileSystem.initSide(config, saveData, constants.SIDES.RED)

      assert.stub(contextStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- deploySide
  -- ============================================================================

  describe("deploySide", function()
    -- Positive: units and contexts are built from the side's ground config into the side's slice
    it("should add units and init contexts from the side's ground config", function()
      local config, saveData = makeSides()
      local addStub = trackStub(Deployment, "addMissileSystems")
      local contextStub = trackStub(Context, "initMissileSystemContexts")

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
      local seedStub = trackStub(Context, "ensureGroundState")

      MissileSystem.ensureGroundState(config, saveData, constants.SIDES.BLUE)

      assert.stub(seedStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground)
    end)
  end)

  -- ============================================================================
  -- redeployFromSetup
  -- ============================================================================

  describe("redeployFromSetup", function()
    -- Positive: setup entries become layouts that redeploy the side's config and slice
    it("should redeploy the side with layouts built from the setup entries", function()
      local config, saveData = makeSides()
      local entries = { { unitname = "FU-1" } }
      local layouts = { { unitname = "FU-1" } }
      local buildLayoutsStub = trackStub(SetupLayout, "buildLayouts").returns(layouts)
      local redeployStub = trackStub(MissileSystem, "redeploy")

      MissileSystem.redeployFromSetup(config, saveData, constants.SIDES.BLUE, entries)

      assert.stub(buildLayoutsStub).was.called_with(entries)
      assert.stub(redeployStub).was.called_with(config.blue.ground.missileSystemTypes, saveData.blue.ground,
        constants.SIDES.BLUE, layouts)
    end)
  end)

  -- ============================================================================
  -- buildSetupMenuRows
  -- ============================================================================

  describe("buildSetupMenuRows", function()
    -- Positive: rows come from the side's ground config
    it("should return the setup rows built from the side's ground config", function()
      local config = makeSides()
      local rows = { srbm = { id = "row" } }
      local rowsStub = trackStub(SetupLayout, "buildSetupMenuRows").returns(rows)

      local result = MissileSystem.buildSetupMenuRows(config, constants.SIDES.BLUE)

      assert.are.equal(rows, result)
      assert.stub(rowsStub).was.called_with(config.blue.ground.missileSystemTypes, constants.SIDES.BLUE)
    end)
  end)

  -- ============================================================================
  -- buildBatteryStatusRows
  -- ============================================================================

  describe("buildBatteryStatusRows", function()
    -- Positive: the side's slice and config are read at the current game time
    it("should build status rows from the side's slice and config at the current time", function()
      local config, saveData = makeSides()
      local rows = { RS1 = {} }
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(4200)
      local rowsStub = trackStub(StatusView, "buildBatteryStatusRows").returns(rows)

      local result = MissileSystem.buildBatteryStatusRows(config, saveData, constants.SIDES.BLUE)

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
      local firingUnitCtx = { name = "FU1" }
      saveData.red.ground = {
        missileSystemTypes = {
          [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true, firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = {} }
        }
      }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local dropContactStub = trackStub(contact, "DropContact")
      local getContactsStub = trackStub(GameApi, "ScenEdit_GetContacts").returns({ contact })
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      trackStub(Concealment, "hideUnit").returns(true)

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(getContactsStub).was.called_with(constants.SIDES.RED)
      assert.stub(dropContactStub).was.called(1)
      assert.stub(setStateToHideStub).was.called_with(firingUnitCtx, unit, true)
    end)

    -- Positive: a Taiwan unit gets the manual policy and the Taiwan slice
    it("should use the Taiwan slice and manual policy for a Taiwan unit", function()
      local config, saveData = makeSides()
      local unit = { name = "RS1", guid = "guid-rs1", side = constants.SIDES.BLUE }
      local event = { triggers = { { UnitEntersArea = { Description = "(Taiwan) Arrive in AHA - 1 - AreaA" } } } }

      local systemCtx = { enabled = true, firingUnits = {}, resupplyUnits = { RS1 = { name = "RS1" } } }
      saveData.blue.ground = { missileSystemTypes = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = systemCtx } }
      trackStub(GameApi, "ScenEdit_GetContacts").returns(nil)
      trackStub(Meeting, "hasMetAmmoDepot").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, false)
    end)
  end)

  -- ============================================================================
  -- startStow
  -- ============================================================================

  describe("startStow", function()
    local STATE = constants.MISSILE_SYSTEM_STATE

    local function makeGroundCtx()
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
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.startStow(groundCtx, "SRBM", firingUnits)

      assert.are.equal(9000, groundCtx.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.are.equal(9000, groundCtx.missileSystemTypes.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Boundary: a running countdown is preserved
    it("should keep an existing stowStartTime", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Stowing" } }

      MissileSystem.startStow(groundCtx, "srbm", firingUnits)

      assert.are.equal(500, groundCtx.missileSystemTypes.srbm.firingUnits["FU-Stowing"].stowStartTime)
    end)

    -- Boundary: onlyDeployed leaves units still in their hide area alone
    it("should skip non-deployed units when onlyDeployed is set", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.startStow(groundCtx, "SRBM", firingUnits, { onlyDeployed = true })

      assert.are.equal(9000, groundCtx.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.is_nil(groundCtx.missileSystemTypes.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Negative: SAM never stows
    it("should not stamp SAM firing units", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "SAM-1" } }

      MissileSystem.startStow(groundCtx, "SAM", firingUnits)

      assert.is_nil(groundCtx.missileSystemTypes.sam.firingUnits["SAM-1"].stowStartTime)
    end)

    -- Negative: unknown units, unknown systems and missing inputs are ignored
    it("should ignore missing contexts and nil inputs", function()
      local groundCtx = makeGroundCtx()
      local ghostUnits = { { name = "Ghost" } }
      local staticUnits = { { name = "FU-Static" } }

      assert.has_no.Error(function()
        MissileSystem.startStow(groundCtx, "SRBM", ghostUnits)
        MissileSystem.startStow(groundCtx, "GLCM", staticUnits)
        MissileSystem.startStow(groundCtx, nil, staticUnits)
        MissileSystem.startStow(groundCtx, "SRBM", nil)
      end)
      assert.is_nil(groundCtx.missileSystemTypes.srbm.firingUnits["FU-Static"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- processSupplyAssetDestruction
  -- ============================================================================

  describe("processSupplyAssetDestruction", function()
    -- Positive: finds the owning system on the unit's side and logs the ammunition delta
    it("should zero the depot of whichever system on the unit's side owns it and log the delta", function()
      local srbmCtx = {
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
              srbm = srbmCtx,
            },
          },
        },
      }
      local unit = { name = "Ammo Depot Alpha", side = constants.SIDES.BLUE }

      local processed = MissileSystem.processSupplyAssetDestruction(saveData, unit)

      assert.is_true(processed)
      assert.are.equal(0, srbmCtx.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
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
  -- isLowAmmo
  -- ============================================================================

  describe("isLowAmmo", function()
    -- Positive: the unit's own threshold and weapon DBID drive the check
    it("should report low ammo using the firing unit's threshold and weapon", function()
      local firingUnitCtx = { name = "FU1", ammoThreshold = 40, weaponDBID = 7 }
      local firingUnit = { name = "FU1" }
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(true)

      local isLow = MissileSystem.isLowAmmo(firingUnitCtx, firingUnit)

      assert.is_true(isLow)
      assert.stub(isLowAmmoStub).was.called_with(firingUnit, 40, 7)
    end)
  end)

  -- ============================================================================
  -- getFiringUnitContext
  -- ============================================================================

  describe("getFiringUnitContext", function()
    local function makeGroundCtx()
      return { missileSystemTypes = { srbm = { firingUnits = { FU1 = { name = "FU1" } } } } }
    end

    -- Positive: the system name is matched in any case
    it("should resolve the context from an upper-case system name", function()
      local groundCtx = makeGroundCtx()

      local firingUnitCtx = MissileSystem.getFiringUnitContext(groundCtx, "SRBM", "FU1")

      assert.are.equal(groundCtx.missileSystemTypes.srbm.firingUnits.FU1, firingUnitCtx)
    end)

    -- Negative: an unknown unit resolves to nothing
    it("should return nil for an unknown firing unit", function()
      assert.is_nil(MissileSystem.getFiringUnitContext(makeGroundCtx(), "srbm", "Ghost"))
    end)

    -- Negative: an unknown system resolves to nothing
    it("should return nil for an unknown system", function()
      assert.is_nil(MissileSystem.getFiringUnitContext(makeGroundCtx(), "glcm", "FU1"))
    end)
  end)

  -- ============================================================================
  -- getAmmoInventory
  -- ============================================================================

  describe("getAmmoInventory", function()
    -- Positive: delegates with the system context picked from groundCtx
    it("should report inventory for the requested system", function()
      local srbmCtx = { name = "srbm" }
      local groundCtx = { missileSystemTypes = { srbm = srbmCtx } }

      local inventoryStub = trackStub(Ammo, "getInventory").returns({ total = { percentage = 80 } })

      local report = MissileSystem.getAmmoInventory(groundCtx, "srbm", "China")

      assert(report ~= nil)
      assert.are.equal(80, report.total.percentage)
      assert.stub(inventoryStub).was.called_with(srbmCtx, "China")
    end)

    -- Negative: absent system yields nil
    it("should return nil when the system is absent", function()
      local groundCtx = { missileSystemTypes = {} }
      assert.is_nil(MissileSystem.getAmmoInventory(groundCtx, "srbm", "China"))
    end)
  end)

  -- ============================================================================
  -- processUnitEntersArea: position handlers
  -- ============================================================================

  describe("processUnitEntersArea position handlers", function()
    local SYSTEM_KEY = constants.MISSILE_SYSTEM_TYPES.SRBM

    ---@type luassert.spy
    local getContactsStub

    before_each(function()
      getContactsStub = trackStub(GameApi, "ScenEdit_GetContacts")
    end)

    ---@param overrides? table Fields to override on the default firing unit
    local function makeUnit(overrides)
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      for k, v in pairs(overrides or {}) do
        unit[k] = v
      end
      return unit
    end

    ---@param overrides? table Fields to override on the default enabled, empty system context
    local function makeSystemCtx(overrides)
      local systemCtx = { enabled = true, firingUnits = {}, resupplyUnits = {} }
      for k, v in pairs(overrides or {}) do
        systemCtx[k] = v
      end
      return systemCtx
    end

    ---Move context the handlers receive when the policy overrides nothing
    ---@param overrides? table Fields to override on the default policy-derived context
    local function makeMoveCtx(overrides)
      local moveCtx = {
        isAuto = true,
        hideOnEnterHA = false,
        hideResupplyOnRLNoMeeting = false,
        firingUnitLookupSide =
        "China"
      }
      for k, v in pairs(overrides or {}) do
        moveCtx[k] = v
      end
      return moveCtx
    end

    local function groundCtxWith(systemCtx)
      return { missileSystemTypes = { [SYSTEM_KEY] = systemCtx } }
    end

    ---Fire UnitEntersArea for the unit's side, with that side's slice and policy built from params
    ---@param params {groundCtx: table, unit: table, event: table, contacts?: table, policy?: table}
    local function enterArea(params)
      local field = GameUtils.getCachedSideConfig(params.unit.side).field
      local policy = { isAuto = true, hideOnEnterHA = false, hideResupplyOnRLNoMeeting = false }
      local config = { [field] = { ground = { policy = policy } } }
      local saveData = { [field] = { ground = params.groundCtx } }
      for k, v in pairs(params.policy or {}) do
        policy[k] = v
      end
      getContactsStub.returns(params.contacts)

      MissileSystem.processUnitEntersArea(
        config,
        saveData,
        params.unit,
        params.event
      )
    end

    -- Real trigger descriptions look like "(Side) Arrive in TYPE - idx - areaName"
    local function enterEvent(positionType, areaName)
      local description = string.format("(China) Arrive in %s - 1 - %s",
        positionType, areaName or "AreaA")
      return { triggers = { { UnitEntersArea = { Description = description } } } }
    end

    local function enterEventRaw(description)
      return { triggers = { { UnitEntersArea = { Description = description } } } }
    end

    -- --- FP --------------------------------------------------------------

    -- Positive: FP + repositioning triggers setWCSToFree exactly once
    it("should set WCS to free exactly once when entering FP while repositioning", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Movement, "isRepositioning").returns(true)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(setWCSToFreeStub).was.called(1)
      assert.stub(setWCSToFreeStub).was.called_with(firingUnitCtx, unit, makeMoveCtx().isAuto)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_truthy(string.find(message, "action=firing_ready", 1, true))
      assert.is_truthy(string.find(message, "position=FP", 1, true))
    end)

    -- Negative: FP + not repositioning keeps WCS untouched
    it("should not set WCS to free when entering FP and not repositioning", function()
      local unit = makeUnit()
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = { name = "FU1" } } })

      trackStub(Movement, "isRepositioning").returns(false)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(setWCSToFreeStub).was_not.called()
      assert.stub(logStub).was_not.called()
      assert.stub(warnStub).was_not.called()
    end)

    -- Boundary: FP path must never drop contacts
    it("should not drop contacts when entering FP", function()
      local unit = makeUnit()
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = { name = "FU1" } } })

      local dropContactStub = trackStub(contact, "DropContact")
      trackStub(Movement, "isRepositioning").returns(false)

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
        contacts = { contact }
      })

      assert.stub(dropContactStub).was_not.called()
    end)

    -- --- HA --------------------------------------------------------------

    -- Negative: HA + no forced hide + not repositioning leaves state untouched
    it("should leave HA state untouched when not repositioning and hideOnEnterHA is off", function()
      local unit = makeUnit({ side = "Taiwan" })
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Movement, "isRepositioning").returns(false)
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          isAuto = false,
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(setStateToHideStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Boundary: HA path drops only matching contacts
    it("should drop only contacts whose actualunitid matches the incoming unit", function()
      local unit = makeUnit({ side = "Taiwan" })
      local firingUnitCtx = { name = "FU1" }
      local matchingContact = { actualunitid = unit.guid, DropContact = function() end }
      local otherContact = { actualunitid = "guid-other", DropContact = function() end }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      local matchingDropContactStub = trackStub(matchingContact, "DropContact")
      local otherDropContactStub = trackStub(otherContact, "DropContact")
      trackStub(Movement, "isRepositioning").returns(false)

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        contacts = { matchingContact, otherContact },
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(matchingDropContactStub).was.called(1)
      assert.stub(otherDropContactStub).was_not.called()
    end)

    -- Positive: HA + hideOnEnterHA enables both state change and concealment
    it("should force hide flow on HA when hideOnEnterHA is enabled", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Movement, "isRepositioning").returns(false)
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(setStateToHideStub).was.called(1)
      assert.stub(setStateToHideStub).was.called_with(firingUnitCtx, unit,
        makeMoveCtx({ hideOnEnterHA = true }).isAuto)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(firingUnitCtx, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=concealed", 1, true))
    end)

    -- Negative: HA hide failure is reported as a functional warning.
    -- WARN rows ride the info log: report routes only FAIL/ERROR to the error sink.
    it("should log warning when HA concealment fails", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Movement, "isRepositioning").returns(false)
      trackStub(Movement, "setStateToHide")
      trackStub(Concealment, "hideUnit")
          .returns(false, { reason = "no_buildings_in_mask", area = "OPAREA-1" })

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(warnStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "[WARN]", 1, true))
      assert.is_truthy(string.find(message, "action=concealment_failed", 1, true))
    end)

    -- Boundary: HA handler early-returns when unit is not a firing unit of the system
    it("should skip HA handling when unit is not a firing unit of the system", function()
      local unit = makeUnit({ name = "Unknown", guid = "guid-x" })
      local systemCtx = makeSystemCtx()

      local isRepositioningStub = trackStub(Movement, "isRepositioning").returns(true)
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(isRepositioningStub).was_not.called()
      assert.stub(setStateToHideStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- --- RL --------------------------------------------------------------

    -- Positive: RL + firing unit + meeting confirmed starts reload
    it("should set reload start time on RL when firing unit has met resupply unit", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx }, resupplyUnits = { RS1 = { name = "RS1" } } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, firingUnitCtx)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(setReloadStartTimeStub).was.called(1)
      assert.stub(setReloadStartTimeStub).was.called_with(firingUnitCtx, unit, makeMoveCtx().isAuto)
      assert.stub(setStateToStaticStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=reload_started", 1, true))
    end)

    -- Negative: a confirmed meeting whose firing unit cannot be found in game starts nothing
    it("should warn and not start reload when the met firing unit is not in the game", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = { RS1 = { name = "RS1" } } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, firingUnitCtx)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(setReloadStartTimeStub).was_not.called()
      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=reload_not_started", 1, true))
    end)

    -- Negative: RL + firing unit + meeting not detected falls back to no-meeting path.
    -- The policy mode is intentionally NOT forwarded: setStateToStatic always runs in manual mode
    -- so a firing unit that drifts through RL during repositioning does not halt mid-move.
    it("should fall back to no-meeting path on RL when firing unit exists but no meeting", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(setReloadStartTimeStub).was_not.called()
      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, false)
      assert.stub(logStub).was_not.called()
    end)

    -- Positive: RL no-meeting + hideResupplyOnRLNoMeeting + ammo sufficient hides resupply unit
    it("should hide resupply unit on RL no-meeting when firing unit ammo is sufficient", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = makeSystemCtx({ firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = { [unit.name] = resupplyUnitCtx } })
      local firingUnit = { name = "FU1" }

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, false)
      assert.stub(getUnitStub).was.called(1)
      assert.stub(getUnitStub).was.called_with("FU1", "China")
      assert.stub(isLowAmmoStub).was.called(1)
      assert.stub(isLowAmmoStub).was.called_with(firingUnit, 30, 123)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(resupplyUnitCtx, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=resupply_concealed", 1, true))
    end)

    -- Negative: RL no-meeting + low ammo must not hide the resupply unit
    it("should not hide resupply unit on RL no-meeting when firing unit ammo is low", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = makeSystemCtx({ firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")
      trackStub(GameApi, "ScenEdit_GetUnit").returns({ name = "FU1" })
      trackStub(Ammo, "isLowAmmo").returns(true)
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(hideUnitStub).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Boundary: ScenEdit_GetUnit returning nil short-circuits before ammo/hide checks
    it("should skip ammo and hide checks on RL no-meeting when ScenEdit_GetUnit returns nil", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = makeSystemCtx({ firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      trackStub(Movement, "setStateToStatic")
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(isLowAmmoStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- Boundary: firingUnitCtx lookup failure on RL no-meeting short-circuits before API call
    it("should skip hide flow on RL no-meeting when resupply unit references an unknown firing unit", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1", firingUnit = "MISSING" }
      local systemCtx = makeSystemCtx({ resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit")
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(getUnitStub).was_not.called()
      assert.stub(isLowAmmoStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- --- AHA -------------------------------------------------------------

    -- Positive: AHA + meeting confirmed starts reload
    it("should set reload start time on AHA when ammo depot meeting is confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1" }
      local systemCtx = makeSystemCtx({ resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetAmmoDepot").returns(true, resupplyUnitCtx)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("AHA"),
      })

      assert.stub(setReloadStartTimeStub).was.called(1)
      assert.stub(setReloadStartTimeStub).was.called_with(resupplyUnitCtx, unit, makeMoveCtx().isAuto)
      assert.stub(setStateToStaticStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=transload_started", 1, true))
    end)

    -- Negative: AHA fallback resets state when meeting fails
    it("should set state to static on AHA when ammo depot meeting is not confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1" }
      local systemCtx = makeSystemCtx({ resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetAmmoDepot").returns(false, nil)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("AHA"),
      })

      assert.stub(setReloadStartTimeStub).was_not.called()
      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, makeMoveCtx().isAuto)
      assert.stub(logStub).was_not.called()
    end)

    -- --- Boundaries -------------------------------------------------------

    -- Boundary: unrecognized position token short-circuits without side effects
    it("should return early when event description has no position type token", function()
      local unit = makeUnit()
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = { name = "FU1" } } })

      local dropContactStub = trackStub(contact, "DropContact")
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEventRaw("(China) Arrive in MASK - 1 - AreaA"),
        contacts = { contact }
      })

      assert.stub(dropContactStub).was_not.called()
      assert.stub(setWCSToFreeStub).was_not.called()
      assert.stub(setStateToHideStub).was_not.called()
      assert.stub(setReloadStartTimeStub).was_not.called()
      assert.stub(setStateToStaticStub).was_not.called()
    end)

    -- Boundary: descriptions outside the "Arrive in <TYPE> " format must not be matched
    it("should ignore descriptions that do not follow the 'Arrive in <TYPE>' format", function()
      local unit = makeUnit()
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = { name = "FU1" } } })

      trackStub(Movement, "isRepositioning").returns(true)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")

      local bogus = {
        "(China) Leaving HA - 1 - AreaA",     -- wrong verb
        "(China) Arrive in MASK - 1 - AreaA", -- unknown token
        "Random text with RL inside",         -- free-form, no 'Arrive in'
        "Arrive in HAPPY - 1 - AreaA",        -- 'HA' is not a standalone token
      }

      for _, description in ipairs(bogus) do
        enterArea({
          groundCtx = groundCtxWith(systemCtx),
          unit = unit,
          event = enterEventRaw(description),
        })
      end

      assert.stub(setWCSToFreeStub).was_not.called()
      assert.stub(setStateToHideStub).was_not.called()
      assert.stub(setStateToStaticStub).was_not.called()
      assert.stub(setReloadStartTimeStub).was_not.called()
    end)

    -- Boundary: real position type is preferred when areaName contains position-like substrings
    it("should match the real position type when areaName contains position-like substrings", function()
      local unit = makeUnit()
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = makeSystemCtx({ firingUnits = { [unit.name] = firingUnitCtx } })

      trackStub(Movement, "isRepositioning").returns(true)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")
      local setStateToHideStub = trackStub(Movement, "setStateToHide")

      -- areaName "HALLWAY-RL-FP" contains HA/RL/FP substrings; pos type must still be FP
      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP", "HALLWAY-RL-FP"),
      })

      assert.stub(setWCSToFreeStub).was.called(1)
      assert.stub(setWCSToFreeStub).was.called_with(firingUnitCtx, unit, makeMoveCtx().isAuto)
      assert.stub(setStateToHideStub).was_not.called()
    end)

    -- Boundary: with a paired firing unit that has ammo, the policy switch alone keeps the resupply unit out
    it("should not hide on RL no-meeting when hideResupplyOnRLNoMeeting is off", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = makeSystemCtx({ firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = { [unit.name] = resupplyUnitCtx } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit").returns({ name = "FU1" })
      trackStub(Ammo, "isLowAmmo").returns(false)
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        policy = { hideResupplyOnRLNoMeeting = false }
      })

      assert.stub(setStateToStaticStub).was.called(1)
      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, false)
      assert.stub(getUnitStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- Boundary: disabled systems must be skipped before any delegate is invoked
    it("should skip processing when the missile system is disabled", function()
      local unit = makeUnit()
      local disabledCtx = makeSystemCtx({ enabled = false, firingUnits = { [unit.name] = { name = "FU1" } } })

      local isRepositioningStub = trackStub(Movement, "isRepositioning").returns(true)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")

      enterArea({
        groundCtx = groundCtxWith(disabledCtx),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(isRepositioningStub).was_not.called()
      assert.stub(setWCSToFreeStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- redeploy
  -- ============================================================================

  describe("redeploy", function()
    -- Positive: layouts are applied first, then zones, units and state are rebuilt in order
    it("should apply layouts, then rebuild triggers, units and contexts in order", function()
      local missileSystemConfigMap = {}
      local groundCtx = {}
      local layouts = { { category = "srbm", unitname = "FU-1", operationalArea = { name = "#NEW" } } }
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
      local contextStub = trackStub(Context, "initMissileSystemContexts").invokes(function()
        table.insert(calls, "initMissileSystemContexts")
      end)

      MissileSystem.redeploy(missileSystemConfigMap, groundCtx, "Taiwan", layouts)

      assert.are.same({ "updateLayouts", "initEventTriggers", "addMissileSystems", "initMissileSystemContexts" }, calls)
      assert.stub(triggersStub).was.called_with(newAreas, oldAreas, {
        constants.POSITION_TYPES.RELOAD_POINT,
        constants.POSITION_TYPES.FIRING_POINT,
        constants.POSITION_TYPES.HIDE_AREA,
        constants.POSITION_TYPES.AMMO_HOLDING_AREA
      }, "Taiwan")
      assert.stub(addStub).was.called_with(missileSystemConfigMap, "Taiwan")
      assert.stub(contextStub).was.called_with(missileSystemConfigMap, groundCtx)
    end)
  end)
end)
