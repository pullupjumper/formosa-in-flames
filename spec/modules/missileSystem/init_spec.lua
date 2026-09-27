-- MissileSystem Init Unit Tests
local stub = require("luassert.stub")
local MissileSystem = require("src.modules.missileSystem.init")
local Movement = require("src.modules.missileSystem.movement")
local Cycle = require("src.modules.missileSystem.cycle")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Ammo = require("src.modules.missileSystem.ammo")
local Deployment = require("src.modules.missileSystem.deployment")
local Triggers = require("src.modules.missileSystem.triggers")
local Context = require("src.modules.missileSystem.context")
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
    -- Positive: each enabled system receives its own config plus the shared (isAuto, sideName) pair
    it("should call Cycle.process with each system context and its config", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local mrbmCtx = { enabled = true, id = "mrbm" }
      local srbmCfg = { reloadTime = 300 }
      local mrbmCfg = { reloadTime = 600 }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCtx,
      }
      local groundCfg = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCfg,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCfg,
      }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.process(groundCtx, groundCfg, true, "Taiwan")

      assert.stub(cycleProcessStub).was.called(2)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, srbmCfg, true, "Taiwan")
      assert.stub(cycleProcessStub).was.called_with(mrbmCtx, mrbmCfg, true, "Taiwan")
    end)

    -- Positive: results from multiple systems are aggregated into one tagged log call
    it("should aggregate per-system results into a single tagged log entry", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local mrbmCtx = { enabled = true, id = "mrbm" }
      local mlrsCtx = { enabled = false, id = "mlrs" }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MLRS] = mlrsCtx,
      }
      local groundCfg = {}

      local cycleProcessStub = trackStub(Cycle, "process").invokes(function(systemCtx)
        if systemCtx.id == "srbm" then
          return { { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } }
        elseif systemCtx.id == "mrbm" then
          return { { tag = "WARN", fields = { unit = "MRBM1", action = "low_ammo" } } }
        end
        return {}
      end)

      MissileSystem.process(groundCtx, groundCfg, true, "Taiwan")

      assert.stub(cycleProcessStub).was.called(2) -- MLRS disabled is skipped
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_not_nil(string.find(message, "total=2", 1, true))
      assert.is_not_nil(string.find(message, "[OK]", 1, true))
      assert.is_not_nil(string.find(message, constants.MISSILE_SYSTEM_TYPES.SRBM, 1, true))
      assert.is_not_nil(string.find(message, "reload_done", 1, true))
      assert.is_not_nil(string.find(message, "SRBM1", 1, true))
      assert.is_not_nil(string.find(message, "[WARN]", 1, true))
      assert.is_not_nil(string.find(message, constants.MISSILE_SYSTEM_TYPES.MRBM, 1, true))
      assert.is_not_nil(string.find(message, "low_ammo", 1, true))
      assert.is_not_nil(string.find(message, "MRBM1", 1, true))
    end)

    -- Negative: failures are logged through Logger.error so they are not hidden by verbose settings
    it("should log reload cycle failures through Logger.error", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
      }
      local groundCfg = {}

      trackStub(Cycle, "process").returns({
        {
          tag = "FAIL",
          fields = { unit = "SRBM1", action = "move_to_hide_area", reason = "no_ha_defined" }
        }
      })

      MissileSystem.process(groundCtx, groundCfg, true, "Taiwan")

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "[FAIL]", 1, true))
      assert.is_not_nil(string.find(message, "reason=no_ha_defined", 1, true))
    end)

    -- Negative: skips disabled systems and does not log when no events occurred
    it("should skip disabled systems and not log when no results are returned", function()
      local srbmCtx = { enabled = true }
      local srbmCfg = { reloadTime = 300 }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = { enabled = false },
      }
      local groundCfg = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCfg }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.process(groundCtx, groundCfg, false, "Taiwan")

      assert.stub(cycleProcessStub).was.called(1)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, srbmCfg, false, "Taiwan")
      assert.stub(logStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- side-aware entries
  -- ============================================================================

  ---Minimal config/saveData pair whose China and Taiwan sides differ only by policy
  ---@return table config, table saveData
  local function makeSides()
    local config = {
      c = {
        ground = { id = "c-cfg" },
        missileSystemPolicy = { isAuto = true, hideOnEnterHA = true, hideResupplyOnRLNoMeeting = true }
      },
      t = {
        ground = { id = "t-cfg" },
        missileSystemPolicy = { isAuto = false, hideOnEnterHA = false, hideResupplyOnRLNoMeeting = false }
      }
    }
    local saveData = { c = { ground = { id = "c-ctx" } }, t = { ground = { id = "t-ctx" } } }
    return config, saveData
  end

  describe("processSide", function()
    -- Positive: each side runs with its own ground slice, ground config and isAuto from policy
    it("should pass the side's slice, config and policy mode to process", function()
      local config, saveData = makeSides()
      local processStub = trackStub(MissileSystem, "process")

      MissileSystem.processSide(config, saveData, constants.SIDES.ENEMY)
      MissileSystem.processSide(config, saveData, constants.SIDES.PLAYER)

      assert.stub(processStub).was.called(2)
      assert.stub(processStub).was.called_with(saveData.c.ground, config.c.ground, true, constants.SIDES.ENEMY)
      assert.stub(processStub).was.called_with(saveData.t.ground, config.t.ground, false, constants.SIDES.PLAYER)
    end)
  end)

  describe("deploySide", function()
    -- Positive: units and contexts are built from the side's ground config into the side's slice
    it("should add units and init contexts from the side's ground config", function()
      local config, saveData = makeSides()
      local addStub = trackStub(Deployment, "addMissileSystems")
      local contextStub = trackStub(Context, "initMissileSystemContexts")

      MissileSystem.deploySide(config, saveData, constants.SIDES.PLAYER)

      assert.stub(addStub).was.called_with(config.t.ground, constants.SIDES.PLAYER)
      assert.stub(contextStub).was.called_with(config.t.ground, saveData.t.ground)
    end)
  end)

  describe("processUnitEntersArea", function()
    -- Positive: side comes from the triggering unit, switches come from that side's policy
    it("should run a China unit against the China slice, contacts and policy", function()
      local config, saveData = makeSides()
      local unit = { name = "FU1", guid = "guid-fu1", side = constants.SIDES.ENEMY }
      local event = { triggers = { { UnitEntersArea = { Description = "(China) Arrive in HA - 1 - AreaA" } } } }
      local firingUnitCtx = { name = "FU1" }
      saveData.c.ground = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true, firingUnits = { FU1 = firingUnitCtx }, resupplyUnits = {} }
      }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local dropContactStub = trackStub(contact, "DropContact")
      local getContactsStub = trackStub(GameApi, "ScenEdit_GetContacts").returns({ contact })
      local setStateToHideStub = trackStub(Movement, "setStateToHide")
      trackStub(Concealment, "hideUnit").returns(true)

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(getContactsStub).was.called_with(constants.SIDES.ENEMY)
      assert.stub(dropContactStub).was.called(1)
      assert.stub(setStateToHideStub).was.called_with(firingUnitCtx, unit, true)
    end)

    -- Positive: a Taiwan unit gets the manual policy and the Taiwan slice
    it("should use the Taiwan slice and manual policy for a Taiwan unit", function()
      local config, saveData = makeSides()
      local unit = { name = "RS1", guid = "guid-rs1", side = constants.SIDES.PLAYER }
      local event = { triggers = { { UnitEntersArea = { Description = "(Taiwan) Arrive in AHA - 1 - AreaA" } } } }

      local systemCtx = { enabled = true, firingUnits = {}, resupplyUnits = { RS1 = { name = "RS1" } } }
      saveData.t.ground = { [constants.MISSILE_SYSTEM_TYPES.SRBM] = systemCtx }
      trackStub(GameApi, "ScenEdit_GetContacts").returns(nil)
      trackStub(Meeting, "hasMetAmmoDepot").returns(false, nil)
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      MissileSystem.processUnitEntersArea(config, saveData, unit, event)

      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, false)
    end)
  end)

  -- ============================================================================
  -- markForStow
  -- ============================================================================

  describe("markForStow", function()
    local STATE = constants.MISSILE_SYSTEM_STATE

    local function makeGroundCtx()
      return {
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
    end

    before_each(function()
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(9000)
    end)

    -- Positive: upper-case system name resolves and every unit without a countdown is stamped
    it("should stamp stowStartTime on every listed unit regardless of state", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.markForStow(groundCtx, "SRBM", firingUnits)

      assert.are.equal(9000, groundCtx.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.are.equal(9000, groundCtx.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Boundary: a running countdown is preserved
    it("should keep an existing stowStartTime", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Stowing" } }

      MissileSystem.markForStow(groundCtx, "srbm", firingUnits)

      assert.are.equal(500, groundCtx.srbm.firingUnits["FU-Stowing"].stowStartTime)
    end)

    -- Boundary: onlyDeployed leaves units still in their hide area alone
    it("should skip non-deployed units when onlyDeployed is set", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "FU-Static" }, { name = "FU-Hide" } }

      MissileSystem.markForStow(groundCtx, "SRBM", firingUnits,
        { onlyDeployed = true })

      assert.are.equal(9000, groundCtx.srbm.firingUnits["FU-Static"].stowStartTime)
      assert.is_nil(groundCtx.srbm.firingUnits["FU-Hide"].stowStartTime)
    end)

    -- Negative: SAM never stows
    it("should not stamp SAM firing units", function()
      local groundCtx = makeGroundCtx()
      local firingUnits = { { name = "SAM-1" } }

      MissileSystem.markForStow(groundCtx, "SAM", firingUnits)

      assert.is_nil(groundCtx.sam.firingUnits["SAM-1"].stowStartTime)
    end)

    -- Negative: unknown units, unknown systems and missing inputs are ignored
    it("should ignore missing contexts and nil inputs", function()
      local groundCtx = makeGroundCtx()
      local firingUnits1 = { { name = "Ghost" } }
      local firingUnits2 = { { name = "FU-Static" } }


      assert.has_no.Error(function()
        MissileSystem.markForStow(groundCtx, "SRBM", firingUnits1)
        MissileSystem.markForStow(groundCtx, "GLCM", firingUnits2)
        MissileSystem.markForStow(groundCtx, nil, firingUnits2)
        MissileSystem.markForStow(groundCtx, "SRBM", nil)
      end)
      assert.is_nil(groundCtx.srbm.firingUnits["FU-Static"].stowStartTime)
    end)
  end)

  -- ============================================================================
  -- processSupplyAssetDestruction
  -- ============================================================================

  describe("processSupplyAssetDestruction", function()
    -- Positive: finds the owning system and logs the ammunition delta
    it("should zero the depot of whichever system owns it and log the delta", function()
      local srbmCtx = {
        name = "srbm",
        resupplyUnits = {},
        ammunitions = {
          ["Ammo Depot Alpha"] = { name = "Ammo Depot Alpha", wpnCurrent = 100 }
        }
      }
      local groundCtx = {
        mlrs = { name = "mlrs", resupplyUnits = {}, ammunitions = {} },
        srbm = srbmCtx,
      }
      local unit = { name = "Ammo Depot Alpha" }

      local processed = MissileSystem.processSupplyAssetDestruction(unit, groundCtx)

      assert.is_true(processed)
      assert.are.equal(0, srbmCtx.ammunitions["Ammo Depot Alpha"].wpnCurrent)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_not_nil(string.find(message, "system=srbm", 1, true))
      assert.is_not_nil(string.find(message, "role=ammo_depot", 1, true))
      assert.is_not_nil(string.find(message, "delta=-100", 1, true))
    end)

    -- Negative: a unit no system tracks is ignored without logging
    it("should return false and stay silent for an untracked unit", function()
      local groundCtx = { srbm = { name = "srbm", resupplyUnits = {}, ammunitions = {} } }
      local unit = { name = "Random Truck" }

      local processed = MissileSystem.processSupplyAssetDestruction(unit, groundCtx)

      assert.is_false(processed)
      assert.stub(logStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- getAmmoInventory
  -- ============================================================================

  describe("getAmmoInventory", function()
    -- Positive: delegates with the system context picked from groundCtx
    it("should report inventory for the requested system", function()
      local srbmCtx = { name = "srbm" }
      local groundCtx = { srbm = srbmCtx }

      local inventoryStub = trackStub(Ammo, "getInventory").returns({ total = { percentage = 80 } })

      local report = MissileSystem.getAmmoInventory(groundCtx, "srbm", "China")

      assert(report ~= nil)
      assert.are.equal(80, report.total.percentage)
      assert.stub(inventoryStub).was.called_with(srbmCtx, "China")
    end)

    -- Negative: absent system yields nil
    it("should return nil when the system is absent", function()
      local groundCtx = {}
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

    local function groundCtxWith(systemCtx)
      return { [SYSTEM_KEY] = systemCtx }
    end

    ---Fire UnitEntersArea for the unit's side, with that side's slice and policy built from params
    ---@param params {groundCtx: table, unit: table, event: table, contacts?: table, policy?: table}
    local function enterArea(params)
      local field = GameUtils.getCachedSideConfig(params.unit.side).field
      local policy = { isAuto = true, hideOnEnterHA = false, hideResupplyOnRLNoMeeting = false }
      local config = { [field] = { missileSystemPolicy = policy } }
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
    -- (see src/modules/missileSystem/triggers.lua:255).
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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

      trackStub(Movement, "isRepositioning").returns(true)
      local setWCSToFreeStub = trackStub(Movement, "setWCSToFree")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(setWCSToFreeStub).was.called(1)
      assert.stub(setWCSToFreeStub).was.called_with(firingUnitCtx, unit, true)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_not_nil(string.find(message, "action=firing_ready", 1, true))
      assert.is_not_nil(string.find(message, "position=FP", 1, true))
      assert.is_not_nil(string.find(message, "state=STATIC", 1, true))
    end)

    -- Negative: FP + not repositioning keeps WCS untouched
    it("should not set WCS to free when entering FP and not repositioning", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "Taiwan" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "Taiwan" }
      local firingUnitCtx = { name = "FU1" }
      local matchingContact = { actualunitid = unit.guid, DropContact = function() end }
      local otherContact = { actualunitid = "guid-other", DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      assert.stub(setStateToHideStub).was.called_with(firingUnitCtx, unit, true)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(firingUnitCtx, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_not_nil(string.find(message, "action=concealed", 1, true))
      assert.is_not_nil(string.find(message, "position=HA", 1, true))
      assert.is_not_nil(string.find(message, "state=HIDE", 1, true))
    end)

    -- Negative: HA hide failure is reported as a functional warning.
    -- WARN rows ride the info log: report routes only FAIL/ERROR to the error sink.
    it("should log warning when HA concealment fails", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      assert.is_not_nil(string.find(message, "[WARN]", 1, true))
      assert.is_not_nil(string.find(message, "action=concealment_failed", 1, true))
      assert.is_not_nil(string.find(message, "reason=no_buildings_in_mask", 1, true))
      assert.is_not_nil(string.find(message, "area=OPAREA-1", 1, true))
    end)

    -- Boundary: HA handler early-returns when unit is not a firing unit of the system
    it("should skip HA handling when unit is not a firing unit of the system", function()
      local unit = { name = "Unknown", guid = "guid-x", side = "China" }
      local systemCtx = {
        enabled = true,
        firingUnits = {},
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = { RS1 = { name = "RS1" } }
      }

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, firingUnitCtx)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(setReloadStartTimeStub).was.called(1)
      assert.stub(setReloadStartTimeStub).was.called_with(firingUnitCtx, unit, true)
      assert.stub(setStateToStaticStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_not_nil(string.find(message, "action=reload_started", 1, true))
      assert.is_not_nil(string.find(message, "position=RL", 1, true))
      assert.is_not_nil(string.find(message, "triggerUnit=FU1", 1, true))
    end)

    -- Negative: RL + firing unit + meeting not detected falls back to no-meeting path.
    -- isAuto is intentionally NOT forwarded: setStateToStatic is always called with false
    -- so a firing unit that drifts through RL during repositioning does not halt mid-move.
    it("should fall back to no-meeting path on RL when firing unit exists but no meeting", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = {
        enabled = true,
        firingUnits = { FU1 = firingUnitCtx },
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }
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
      assert.is_not_nil(string.find(message, "action=resupply_concealed", 1, true))
      assert.is_not_nil(string.find(message, "position=RL", 1, true))
      assert.is_not_nil(string.find(message, "pairedFiringUnit=FU1", 1, true))
    end)

    -- Negative: RL no-meeting + low ammo must not hide the resupply unit
    it("should not hide resupply unit on RL no-meeting when firing unit ammo is low", function()
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = {
        enabled = true,
        firingUnits = { FU1 = firingUnitCtx },
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

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
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = {
        enabled = true,
        firingUnits = { FU1 = firingUnitCtx },
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

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
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1", firingUnit = "MISSING" }
      local systemCtx = {
        enabled = true,
        firingUnits = {},
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

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
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1" }
      local systemCtx = {
        enabled = true,
        firingUnits = {},
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

      trackStub(Meeting, "hasMetAmmoDepot").returns(true, resupplyUnitCtx)
      local setReloadStartTimeStub = trackStub(Movement, "setReloadStartTime")
      local setStateToStaticStub = trackStub(Movement, "setStateToStatic")

      enterArea({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("AHA"),
      })

      assert.stub(setReloadStartTimeStub).was.called(1)
      assert.stub(setReloadStartTimeStub).was.called_with(resupplyUnitCtx, unit, true)
      assert.stub(setStateToStaticStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_not_nil(string.find(message, "action=transload_started", 1, true))
      assert.is_not_nil(string.find(message, "position=AHA", 1, true))
      assert.is_not_nil(string.find(message, "state=RELOAD", 1, true))
    end)

    -- Negative: AHA fallback resets state when meeting fails
    it("should set state to static on AHA when ammo depot meeting is not confirmed", function()
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1" }
      local systemCtx = {
        enabled = true,
        firingUnits = {},
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

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
      assert.stub(setStateToStaticStub).was.called_with(systemCtx, unit, true)
      assert.stub(logStub).was_not.called()
    end)

    -- --- Boundaries -------------------------------------------------------

    -- Boundary: unrecognized position token short-circuits without side effects
    it("should return early when event description has no position type token", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

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
      assert.stub(setWCSToFreeStub).was.called_with(firingUnitCtx, unit, true)
      assert.stub(setStateToHideStub).was_not.called()
    end)

    -- Boundary: with a paired firing unit that has ammo, the policy switch alone keeps the resupply unit out
    it("should not hide on RL no-meeting when hideResupplyOnRLNoMeeting is off", function()
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1", firingUnit = "FU1" }
      local firingUnitCtx = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemCtx = {
        enabled = true,
        firingUnits = { FU1 = firingUnitCtx },
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

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
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local disabledCtx = {
        enabled = false,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

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
      local groundForceCfg = {}
      local groundForceCtx = {}
      local layouts = { { category = "srbm", unitname = "FU-1", operationalArea = { name = "#NEW" } } }
      local newAreas = { { name = "#NEW" } }
      local oldAreas = { { name = "OPAREA-OLD" } }
      local calls = {}

      trackStub(Deployment, "applyLayouts").invokes(function()
        table.insert(calls, "applyLayouts")
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

      MissileSystem.redeploy(groundForceCfg, groundForceCtx, layouts, "Taiwan")

      assert.are.same({ "applyLayouts", "initEventTriggers", "addMissileSystems", "initMissileSystemContexts" }, calls)
      assert.stub(triggersStub).was.called_with(newAreas, oldAreas, {
        constants.POSITION_TYPES.RELOAD_POINT,
        constants.POSITION_TYPES.FIRING_POINT,
        constants.POSITION_TYPES.HIDE_AREA,
        constants.POSITION_TYPES.AMMO_HOLDING_AREA
      }, "Taiwan")
      assert.stub(addStub).was.called_with(groundForceCfg, "Taiwan")
      assert.stub(contextStub).was.called_with(groundForceCfg, groundForceCtx)
    end)
  end)
end)
