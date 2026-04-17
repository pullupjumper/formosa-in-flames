-- MissileSystem Init Unit Tests
---@diagnostic disable: undefined-field
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
local Utils = require("src.utils.utils")

describe("MissileSystem", function()
  local activeStubs

  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    table.insert(activeStubs, stub(Logger, "log"))
    table.insert(activeStubs, stub(Logger, "error"))
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
    -- Negative: logs and returns false when movement fails
    it("should log an error and return false when movement fails", function()
      trackStub(Movement, "moveToFiringPoint").returns(false, "boom")

      local result = MissileSystem.moveToFiringPoint({}, {})

      assert.is_false(result)
      assert.stub(Logger.error).was.called_with(constants.TAGS.MISSILE_SYSTEM .. ": [FAIL] boom")
    end)

    -- Positive: returns true when delegated movement succeeds
    it("should return true when delegated movement succeeds", function()
      trackStub(Movement, "moveToFiringPoint").returns(true)

      assert.is_true(MissileSystem.moveToFiringPoint({}, {}))
    end)
  end)

  -- ============================================================================
  -- checkMissileSystemState
  -- ============================================================================

  describe("checkMissileSystemState", function()
    -- Positive: logs aggregated reload cycle results from enabled systems
    it("should process enabled systems and log aggregated summary", function()
      local groundCtx = {}
      for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
        groundCtx[missileSystem] = { enabled = true }
      end

      trackStub(Cycle, "process").returns({
        { tag = "OK", unitName = "Firing Unit Alpha", action = "Missile reload finished" },
      })

      MissileSystem.checkMissileSystemState(groundCtx, true, "Taiwan")

      assert.stub(Cycle.process).was.called(Utils.getCount(constants.MISSILE_SYSTEM_TYPES))
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips disabled systems and does not log when no events occurred
    it("should skip disabled systems and not log when no results are returned", function()
      local groundCtx = {
        [constants.MISSILE_SYSTEM_TYPES.SRBM] = { enabled = true },
        [constants.MISSILE_SYSTEM_TYPES.MRBM] = { enabled = false },
        [constants.MISSILE_SYSTEM_TYPES.MLRS] = { enabled = true },
      }

      trackStub(Cycle, "process").returns({})

      MissileSystem.checkMissileSystemState(groundCtx, false, "Taiwan")

      assert.stub(Cycle.process).was.called(2)
      assert.stub(Logger.log).was_not.called()
    end)
  end)

  -- ============================================================================
  -- handleMoveToPositionEvent
  -- ============================================================================

  describe("handleMoveToPositionEvent", function()
    local function createGroundCtx(systemCtx)
      local groundCtx = {}
      for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
        groundCtx[missileSystem] = systemCtx
      end
      return groundCtx
    end

    it("should set WCS to free when entering FP while repositioning", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

      trackStub(Movement, "isRepositioning").returns(true)
      trackStub(Movement, "setWCSToFree")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "FP/AreaA" } } } },
        isAuto = true,
        contacts = nil
      })

      assert.stub(Movement.setWCSToFree).was.called_with(firingUnitCtx, unit, true)
    end)

    it("should drop contact and keep HA unchanged when manual mode is not repositioning", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "Taiwan" }
      local firingUnitCtx = { name = "FU1" }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = {}
      }

      trackStub(contact, "DropContact")
      trackStub(Movement, "isRepositioning").returns(false)
      trackStub(Movement, "setStateToHide")
      trackStub(Concealment, "hideUnit")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "HA/AreaA" } } } },
        isAuto = false,
        contacts = { contact },
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
        }
      })

      assert.stub(contact.DropContact).was.called(1)
      assert.stub(Movement.setStateToHide).was_not.called()
      assert.stub(Concealment.hideUnit).was_not.called()
    end)

    it("should force hide flow on HA when hideOnEnterHA is enabled", function()
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

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "HA/AreaA" } } } },
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false,
          firingUnitLookupSide = unit.side
        }
      })

      assert.stub(Movement.setStateToHide).was.called_with(firingUnitCtx, unit, true)
      assert.stub(Concealment.hideUnit).was.called_with(firingUnitCtx, unit)
    end)

    it("should hide resupply unit on RL no-meeting when ammo is sufficient", function()
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
      trackStub(Movement, "setStateToStatic")
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Concealment, "hideUnit")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "RL/AreaA" } } } },
        isAuto = true,
        contacts = nil,
        behavior = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true,
          firingUnitLookupSide = unit.side
        }
      })

      assert.stub(Movement.setStateToStatic).was.called_with(systemCtx, unit, true)
      assert.stub(GameApi.ScenEdit_GetUnit).was.called_with("FU1", unit.side)
      assert.stub(Concealment.hideUnit).was.called_with(resupplyUnitCtx, unit)
    end)

    -- Positive: RL meeting path starts reload directly
    it("should set reload start time on RL when meeting is confirmed", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local firingUnitCtx = { name = "FU1" }
      local matchedCtx = { name = "RS1" }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = firingUnitCtx },
        resupplyUnits = { RS1 = matchedCtx }
      }

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, matchedCtx)
      trackStub(Movement, "setReloadStartTime")
      trackStub(Movement, "setStateToStatic")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "RL/AreaA" } } } },
        isAuto = true,
        contacts = nil
      })

      assert.stub(Movement.setReloadStartTime).was.called_with(matchedCtx, unit, true)
      assert.stub(Movement.setStateToStatic).was_not.called()
    end)

    -- Positive: AHA meeting path starts reload
    it("should set reload start time on AHA when ammo depot meeting is confirmed", function()
      local unit = { name = "RS1", guid = "guid-rs1", side = "China" }
      local resupplyUnitCtx = { name = "RS1" }
      local systemCtx = {
        enabled = true,
        firingUnits = {},
        resupplyUnits = { [unit.name] = resupplyUnitCtx }
      }

      trackStub(Meeting, "hasMetAmmoDepot").returns(true, resupplyUnitCtx)
      trackStub(Movement, "setReloadStartTime")
      trackStub(Movement, "setStateToStatic")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "AHA/AreaA" } } } },
        isAuto = true,
        contacts = nil
      })

      assert.stub(Movement.setReloadStartTime).was.called_with(resupplyUnitCtx, unit, true)
      assert.stub(Movement.setStateToStatic).was_not.called()
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
      trackStub(Movement, "setReloadStartTime")
      trackStub(Movement, "setStateToStatic")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "AHA/AreaA" } } } },
        isAuto = true,
        contacts = nil
      })

      assert.stub(Movement.setReloadStartTime).was_not.called()
      assert.stub(Movement.setStateToStatic).was.called_with(systemCtx, unit, true)
    end)

    -- Boundary: no position token should short-circuit without side effects
    it("should return early when event description has no position type token", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

      trackStub(contact, "DropContact")
      trackStub(Movement, "setWCSToFree")
      trackStub(Movement, "setStateToHide")
      trackStub(Movement, "setReloadStartTime")
      trackStub(Movement, "setStateToStatic")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "MASK/AreaA" } } } },
        isAuto = true,
        contacts = { contact }
      })

      assert.stub(contact.DropContact).was_not.called()
      assert.stub(Movement.setWCSToFree).was_not.called()
      assert.stub(Movement.setStateToHide).was_not.called()
      assert.stub(Movement.setReloadStartTime).was_not.called()
      assert.stub(Movement.setStateToStatic).was_not.called()
    end)

    -- Boundary: behavior=nil should use default switches
    it("should not hide on RL no-meeting when behavior is nil", function()
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
      trackStub(GameApi, "ScenEdit_GetUnit").returns({ name = "FU1" })
      trackStub(Ammo, "isLowAmmo").returns(false)
      trackStub(Concealment, "hideUnit")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "RL/AreaA" } } } },
        isAuto = true,
        contacts = nil,
        behavior = nil
      })

      assert.stub(Movement.setStateToStatic).was.called_with(systemCtx, unit, true)
      assert.stub(GameApi.ScenEdit_GetUnit).was_not.called()
      assert.stub(Concealment.hideUnit).was_not.called()
    end)

    -- Boundary: disabled systems should be skipped
    it("should skip processing when missile systems are disabled", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local disabledCtx = {
        enabled = false,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

      trackStub(Movement, "isRepositioning").returns(true)
      trackStub(Movement, "setWCSToFree")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(disabledCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "FP/AreaA" } } } },
        isAuto = true,
        contacts = nil
      })

      assert.stub(Movement.isRepositioning).was_not.called()
      assert.stub(Movement.setWCSToFree).was_not.called()
    end)

    -- Boundary: FP path should not drop contacts
    it("should not drop contact when entering FP", function()
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemCtx = {
        enabled = true,
        firingUnits = { [unit.name] = { name = "FU1" } },
        resupplyUnits = {}
      }

      trackStub(contact, "DropContact")
      trackStub(Movement, "isRepositioning").returns(false)
      trackStub(Movement, "setWCSToFree")

      MissileSystem.handleMoveToPositionEvent({
        groundCtx = createGroundCtx(systemCtx),
        unit = unit,
        event = { triggers = { { UnitEntersArea = { Description = "FP/AreaA" } } } },
        isAuto = true,
        contacts = { contact }
      })

      assert.stub(contact.DropContact).was_not.called()
      assert.stub(Movement.setWCSToFree).was_not.called()
    end)
  end)
end)
