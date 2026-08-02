-- MissileSystem Init Unit Tests
local stub = require("luassert.stub")
local MissileSystem = require("src.modules.missileSystem.init")
local Movement = require("src.modules.missileSystem.movement")
local Cycle = require("src.modules.missileSystem.cycle")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Ammo = require("src.modules.missileSystem.ammo")
local GameApi = require("src.utils.gameApi")
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
  -- moveToFiringPoint
  -- ============================================================================

  describe("moveToFiringPoint", function()
    -- Negative: logs and returns false when movement fails with structured fields
    it("should forward arguments, log an error and return false when movement fails", function()
      local firingUnitCtx = { name = "FU1" }
      local firingUnit = { name = "FU1" }
      local moveToFiringPointStub = trackStub(Movement, "moveToFiringPoint")
          .returns(false, { reason = "no_positions_available", position = "FP", area = "OPAREA-1" })

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
      assert.stub(moveToFiringPointStub).was.called(1)
      assert.stub(moveToFiringPointStub).was.called_with(firingUnitCtx, firingUnit)
      assert.stub(errorStub).was.called(1)
      assert.stub(errorStub).was.called_with(
        "[FAIL] module=missileSystem area=OPAREA-1 unit=FU1 action=move_to_firing_point position=FP" ..
        " reason=no_positions_available")
    end)

    -- Positive: forwards arguments and returns true without logging
    it("should forward arguments and return true when delegated movement succeeds", function()
      local firingUnitCtx = { name = "FU1" }
      local firingUnit = { name = "FU1" }
      local moveToFiringPointStub = trackStub(Movement, "moveToFiringPoint").returns(true)

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_true(result)
      assert.stub(moveToFiringPointStub).was.called(1)
      assert.stub(moveToFiringPointStub).was.called_with(firingUnitCtx, firingUnit)
      assert.stub(errorStub).was_not.called()
    end)

    -- Boundary: failure without error fields should not log (avoid "[FAIL] nil")
    it("should not log when movement fails without an error message", function()
      trackStub(Movement, "moveToFiringPoint").returns(false)
      local firingUnitCtx = { name = "FU1" }
      local firingUnit = { name = "FU1" }

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
      assert.stub(errorStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- checkMissileSystemState
  -- ============================================================================

  describe("checkMissileSystemState", function()
    -- Positive: each enabled system receives the same (isAuto, sideName) pair
    it("should call Cycle.process with the correct arguments for each enabled system", function()
      local srbmCtx = { enabled = true, id = "srbm" }
      local mrbmCtx = { enabled = true, id = "mrbm" }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = mrbmCtx,
      }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.checkMissileSystemState(groundCtx, true, "Taiwan")

      assert.stub(cycleProcessStub).was.called(2)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, true, "Taiwan")
      assert.stub(cycleProcessStub).was.called_with(mrbmCtx, true, "Taiwan")
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

      local cycleProcessStub = trackStub(Cycle, "process").invokes(function(systemCtx)
        if systemCtx.id == "srbm" then
          return { { tag = "OK", fields = { unit = "SRBM1", action = "reload_done" } } }
        elseif systemCtx.id == "mrbm" then
          return { { tag = "WARN", fields = { unit = "MRBM1", action = "low_ammo" } } }
        end
        return {}
      end)

      MissileSystem.checkMissileSystemState(groundCtx, true, "Taiwan")

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

      trackStub(Cycle, "process").returns({
        {
          tag = "FAIL",
          fields = { unit = "SRBM1", action = "move_to_hide_area", reason = "no_ha_defined" }
        }
      })

      MissileSystem.checkMissileSystemState(groundCtx, true, "Taiwan")

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "[FAIL]", 1, true))
      assert.is_not_nil(string.find(message, "reason=no_ha_defined", 1, true))
    end)

    -- Negative: skips disabled systems and does not log when no events occurred
    it("should skip disabled systems and not log when no results are returned", function()
      local srbmCtx = { enabled = true }
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = srbmCtx,
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = { enabled = false },
      }

      local cycleProcessStub = trackStub(Cycle, "process").returns({})

      MissileSystem.checkMissileSystemState(groundCtx, false, "Taiwan")

      assert.stub(cycleProcessStub).was.called(1)
      assert.stub(cycleProcessStub).was.called_with(srbmCtx, false, "Taiwan")
      assert.stub(logStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- handleSupplyAssetDestruction
  -- ============================================================================

  describe("handleSupplyAssetDestruction", function()
    -- Positive: logs ammunition delta when a tracked ammo depot is destroyed
    it("should log ammunition delta when supply asset destruction is processed", function()
      local systemCtx = {
        name = "srbm",
        resupplyUnits = {},
        ammunitions = {
          ["Ammo Depot Alpha"] = {
            name = "Ammo Depot Alpha",
            wpnCurrent = 100
          }
        }
      }
      local unit = { name = "Ammo Depot Alpha" }

      local result, detail = MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)

      assert.is_true(result)
      assert.are.equal("ammo_depot", detail.role)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_not_nil(string.find(message, "system=srbm", 1, true))
      assert.is_not_nil(string.find(message, "role=ammo_depot", 1, true))
      assert.is_not_nil(string.find(message, "delta=-100", 1, true))
    end)
  end)

  -- ============================================================================
  -- handleMoveToPositionEvent
  -- ============================================================================

  describe("handleMoveToPositionEvent", function()
    local SYSTEM_KEY = constants.MISSILE_SYSTEM_TYPES.SRBM

    local function groundCtxWith(systemCtx)
      return { [SYSTEM_KEY] = systemCtx }
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP"),
        isAuto = true,
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        isAuto = false,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        isAuto = true,
        contacts = { matchingContact, otherContact },
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("HA"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true,
          firingUnitLookupSide = "China"
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true,
          firingUnitLookupSide = "China"
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true,
          firingUnitLookupSide = "China"
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true,
          firingUnitLookupSide = "China"
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("AHA"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("AHA"),
        isAuto = true,
        contacts = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEventRaw("(China) Arrive in MASK - 1 - AreaA"),
        isAuto = true,
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
        MissileSystem.handleMoveToPositionEvent({
          groundCtx = groundCtxWith(systemCtx),
          unit = unit,
          event = enterEventRaw(description),
          isAuto = true,
          contacts = nil
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
      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("FP", "HALLWAY-RL-FP"),
        isAuto = true,
        contacts = nil
      })

      assert.stub(setWCSToFreeStub).was.called(1)
      assert.stub(setWCSToFreeStub).was.called_with(firingUnitCtx, unit, true)
      assert.stub(setStateToHideStub).was_not.called()
    end)

    -- Boundary: behavior=nil defaults to no-hide on RL no-meeting
    it("should not hide on RL no-meeting when behavior is nil (defaults applied)", function()
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(systemCtx),
        unit = unit,
        event = enterEvent("RL"),
        isAuto = true,
        contacts = nil,
        behavior = nil
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = groundCtxWith(disabledCtx),
        unit = unit,
        event = enterEvent("FP"),
        isAuto = true,
        contacts = nil
      })

      assert.stub(isRepositioningStub).was_not.called()
      assert.stub(setWCSToFreeStub).was_not.called()
    end)
  end)
end)
