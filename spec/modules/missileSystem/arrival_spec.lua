---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Arrival Unit Tests
local stub = require("luassert.stub")
local Arrival = require("src.modules.missileSystem.arrival")
local Transitions = require("src.modules.missileSystem.transitions")
local Triggers = require("src.modules.missileSystem.triggers")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local Ammo = require("src.modules.missileSystem.ammo")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Arrival", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
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
    warnStub = trackStub(Logger, "warn")
    trackStub(Logger, "error")
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  describe("processMoveToPositionEvent", function()
    local SYSTEM_KEY = constants.MISSILE_SYSTEM_TYPES.SRBM

    ---@param overrides? table Fields to override on the default firing unit
    local function makeUnit(overrides)
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      for k, v in pairs(overrides or {}) do
        unit[k] = v
      end
      return unit
    end

    ---@param overrides? table Fields to override on the default enabled, empty system state
    local function makeSystemState(overrides)
      local systemState = { enabled = true, firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      for k, v in pairs(overrides or {}) do
        systemState[k] = v
      end
      return systemState
    end

    ---Move state the handlers receive when the policy overrides nothing
    ---@param overrides? table Fields to override on the default policy-derived state
    local function makeMoveCtx(overrides)
      local moveCtx = {
        isAuto = true,
        hideOnEnterHA = false,
        hideResupplyOnRLNoMeeting = false,
        firingUnitLookupSide = "China"
      }
      for k, v in pairs(overrides or {}) do
        moveCtx[k] = v
      end
      return moveCtx
    end

    local function groundStateWith(systemState)
      return { missileSystemTypes = { [SYSTEM_KEY] = systemState } }
    end

    ---Fire UnitEntersArea against the given slice, with move switches built from params.policy
    ---@param params {groundState: table, unit: table, event: table, contacts?: table, policy?: table}
    local function enterArea(params)
      Arrival.processMoveToPositionEvent({
        groundState = params.groundState,
        unit = params.unit,
        event = params.event,
        contacts = params.contacts,
        moveCtx = makeMoveCtx(params.policy)
      })
    end

    local function enterEvent(positionType, areaName)
      local description = Triggers.formatTriggerName("China", positionType, 1, areaName or "AreaA")
      return { triggers = { { UnitEntersArea = { Description = description } } } }
    end

    local function enterEventRaw(description)
      return { triggers = { { UnitEntersArea = { Description = description } } } }
    end

    -- --- FP --------------------------------------------------------------

    -- Positive: FP + repositioning triggers arriveAtFiringPoint exactly once
    it("should set WCS to free exactly once when entering FP while repositioning", function()
      local unit = makeUnit()
      local firingUnitState = { name = "FU1", state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(arriveAtFiringPointStub).was.called(1)
      assert.stub(arriveAtFiringPointStub).was.called_with(firingUnitState, unit, makeMoveCtx().isAuto)
      assert.stub(logStub).was.called(1)

      local tag = logStub.calls[1].vals[1]
      local message = logStub.calls[1].vals[2]
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, tag)
      assert.is_truthy(string.find(message, "action=firing_ready", 1, true))
      assert.is_truthy(string.find(message, "position=FP", 1, true))
    end)

    -- Boundary: FP path must never drop contacts
    it("should not drop contacts when entering FP", function()
      local unit = makeUnit()
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = { name = "FU1" } } })

      local dropContactStub = trackStub(contact, "DropContact")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("FP"),
        contacts = { contact }
      })

      assert.stub(dropContactStub).was_not.called()
    end)

    -- --- HA --------------------------------------------------------------

    -- Boundary: HA path drops only matching contacts
    it("should drop only contacts whose actualunitid matches the incoming unit", function()
      local unit = makeUnit({ side = "Taiwan" })
      local firingUnitState = { name = "FU1" }
      local matchingContact = { actualunitid = unit.guid, DropContact = function() end }
      local otherContact = { actualunitid = "guid-other", DropContact = function() end }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      local matchingDropContactStub = trackStub(matchingContact, "DropContact")
      local otherDropContactStub = trackStub(otherContact, "DropContact")

      enterArea({
        groundState = groundStateWith(systemState),
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
      local firingUnitState = { name = "FU1" }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      local hideStub = trackStub(Transitions, "hide")
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideResupplyOnRLNoMeeting = false
        }
      })

      assert.stub(hideStub).was.called(1)
      assert.stub(hideStub).was.called_with(firingUnitState, unit,
        makeMoveCtx({ hideOnEnterHA = true }).isAuto)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(firingUnitState, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=concealed", 1, true))
    end)

    -- Negative: HA hide failure is reported as a functional warning.
    -- WARN rows ride the info log: report routes only FAIL/ERROR to the error sink.
    it("should log warning when HA concealment fails", function()
      local unit = makeUnit()
      local firingUnitState = { name = "FU1" }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      trackStub(Transitions, "hide")
      trackStub(Concealment, "hideUnit")
          .returns(false, { reason = "no_buildings_in_mask", area = "OPAREA-1" })

      enterArea({
        groundState = groundStateWith(systemState),
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

    -- --- RL --------------------------------------------------------------

    -- Positive: RL + firing unit + meeting confirmed starts reload
    it("should set reload start time on RL when firing unit has met resupply unit", function()
      local unit = makeUnit()
      local firingUnitState = { name = "FU1" }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState }, resupplyUnits = { RS1 = { name = "RS1" } } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, firingUnitState)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(beginReloadStub).was.called(1)
      assert.stub(beginReloadStub).was.called_with(firingUnitState, unit, makeMoveCtx().isAuto)
      assert.stub(settleStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=reload_started", 1, true))
    end)

    -- Negative: a confirmed meeting whose firing unit cannot be found in game starts nothing
    it("should warn and not start reload when the met firing unit is not in the game", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local firingUnitState = { name = "FU1" }
      local systemState = makeSystemState({ firingUnits = { FU1 = firingUnitState }, resupplyUnits = { RS1 = { name = "RS1" } } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(true, firingUnitState)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local beginReloadStub = trackStub(Transitions, "beginReload")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(beginReloadStub).was_not.called()
      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=reload_not_started", 1, true))
    end)

    -- Negative: RL + firing unit + meeting not detected falls back to no-meeting path.
    -- The policy mode is intentionally NOT forwarded: settle always runs in manual mode
    -- so a firing unit that drifts through RL during repositioning does not halt mid-move.
    it("should fall back to no-meeting path on RL when firing unit exists but no meeting", function()
      local unit = makeUnit()
      local firingUnitState = { name = "FU1" }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(beginReloadStub).was_not.called()
      assert.stub(settleStub).was.called(1)
      assert.stub(settleStub).was.called_with(systemState, unit, false)
      assert.stub(logStub).was_not.called()
    end)

    -- Positive: RL no-meeting + hideResupplyOnRLNoMeeting + ammo sufficient hides resupply unit
    it("should hide resupply unit on RL no-meeting when firing unit ammo is sufficient", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1", firingUnit = "FU1" }
      local firingUnitState = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemState = makeSystemState({ firingUnits = { FU1 = firingUnitState }, resupplyUnits = { [unit.name] = resupplyUnitState } })
      local firingUnit = { name = "FU1" }

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local settleStub = trackStub(Transitions, "settle")
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(settleStub).was.called(1)
      assert.stub(settleStub).was.called_with(systemState, unit, false)
      assert.stub(getUnitStub).was.called(1)
      assert.stub(getUnitStub).was.called_with("FU1", "China")
      assert.stub(isLowAmmoStub).was.called(1)
      assert.stub(isLowAmmoStub).was.called_with(firingUnit, 30, 123)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(resupplyUnitState, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=resupply_concealed", 1, true))
    end)

    -- Negative: RL no-meeting + low ammo must not hide the resupply unit
    it("should not hide resupply unit on RL no-meeting when firing unit ammo is low", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1", firingUnit = "FU1" }
      local firingUnitState = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemState = makeSystemState({ firingUnits = { FU1 = firingUnitState }, resupplyUnits = { [unit.name] = resupplyUnitState } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local settleStub = trackStub(Transitions, "settle")
      trackStub(GameApi, "ScenEdit_GetUnit").returns({ name = "FU1" })
      trackStub(Ammo, "isLowAmmo").returns(true)
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(settleStub).was.called(1)
      assert.stub(hideUnitStub).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Boundary: ScenEdit_GetUnit returning nil short-circuits before ammo/hide checks
    it("should skip ammo and hide checks on RL no-meeting when ScenEdit_GetUnit returns nil", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1", firingUnit = "FU1" }
      local firingUnitState = { name = "FU1", ammoThreshold = 30, weaponDBID = 123 }
      local systemState = makeSystemState({ firingUnits = { FU1 = firingUnitState }, resupplyUnits = { [unit.name] = resupplyUnitState } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      trackStub(Transitions, "settle")
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo").returns(false)
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
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

    -- Boundary: firingUnitState lookup failure on RL no-meeting short-circuits before API call
    it("should skip hide flow on RL no-meeting when resupply unit references an unknown firing unit", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1", firingUnit = "MISSING" }
      local systemState = makeSystemState({ resupplyUnits = { [unit.name] = resupplyUnitState } })

      trackStub(Meeting, "hasMetResupplyUnit").returns(false, nil)
      local settleStub = trackStub(Transitions, "settle")
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit")
      local isLowAmmoStub = trackStub(Ammo, "isLowAmmo")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideResupplyOnRLNoMeeting = true
        }
      })

      assert.stub(settleStub).was.called(1)
      assert.stub(getUnitStub).was_not.called()
      assert.stub(isLowAmmoStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- --- AHA -------------------------------------------------------------

    -- Positive: AHA + meeting confirmed starts reload
    it("should set reload start time on AHA when ammo depot meeting is confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1" }
      local systemState = makeSystemState({ resupplyUnits = { [unit.name] = resupplyUnitState } })

      trackStub(Meeting, "hasMetAmmoDepot").returns(true, resupplyUnitState)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("AHA"),
      })

      assert.stub(beginReloadStub).was.called(1)
      assert.stub(beginReloadStub).was.called_with(resupplyUnitState, unit, makeMoveCtx().isAuto)
      assert.stub(settleStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=transload_started", 1, true))
    end)

    -- Negative: AHA fallback resets state when meeting fails
    it("should set state to static on AHA when ammo depot meeting is not confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local resupplyUnitState = { name = "RS1" }
      local systemState = makeSystemState({ resupplyUnits = { [unit.name] = resupplyUnitState } })

      trackStub(Meeting, "hasMetAmmoDepot").returns(false, nil)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("AHA"),
      })

      assert.stub(beginReloadStub).was_not.called()
      assert.stub(settleStub).was.called(1)
      assert.stub(settleStub).was.called_with(systemState, unit, makeMoveCtx().isAuto)
      assert.stub(logStub).was_not.called()
    end)

    -- --- Boundaries -------------------------------------------------------

    -- Boundary: unrecognized position token short-circuits without side effects
    it("should return early when event description has no position type token", function()
      local unit = makeUnit()
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = { name = "FU1" } } })

      local dropContactStub = trackStub(contact, "DropContact")
      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")
      local hideStub = trackStub(Transitions, "hide")
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEventRaw("(China) Arrive in MASK - 1 - AreaA"),
        contacts = { contact }
      })

      assert.stub(dropContactStub).was_not.called()
      assert.stub(arriveAtFiringPointStub).was_not.called()
      assert.stub(hideStub).was_not.called()
      assert.stub(beginReloadStub).was_not.called()
      assert.stub(settleStub).was_not.called()
    end)

    -- Boundary: descriptions outside the "Arrive in <TYPE> " format must not be matched
    it("should ignore descriptions that do not follow the 'Arrive in <TYPE>' format", function()
      local unit = makeUnit()
      local systemState = makeSystemState({ firingUnits = { [unit.name] = { name = "FU1", state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING } } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")
      local hideStub = trackStub(Transitions, "hide")
      local settleStub = trackStub(Transitions, "settle")
      local beginReloadStub = trackStub(Transitions, "beginReload")

      local bogus = {
        "(China) Leaving HA - 1 - AreaA",     -- wrong verb
        "(China) Arrive in MASK - 1 - AreaA", -- unknown token
        "Random text with RL inside",         -- free-form, no 'Arrive in'
        "Arrive in HAPPY - 1 - AreaA",        -- 'HA' is not a standalone token
      }

      for _, description in ipairs(bogus) do
        enterArea({
          groundState = groundStateWith(systemState),
          unit = unit,
          event = enterEventRaw(description),
        })
      end

      assert.stub(arriveAtFiringPointStub).was_not.called()
      assert.stub(hideStub).was_not.called()
      assert.stub(settleStub).was_not.called()
      assert.stub(beginReloadStub).was_not.called()
    end)

    -- Boundary: real position type is preferred when areaName contains position-like substrings
    it("should match the real position type when areaName contains position-like substrings", function()
      local unit = makeUnit()
      local firingUnitState = { name = "FU1", state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING }
      local systemState = makeSystemState({ firingUnits = { [unit.name] = firingUnitState } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")
      local hideStub = trackStub(Transitions, "hide")

      -- areaName "HALLWAY-RL-FP" contains HA/RL/FP substrings; pos type must still be FP
      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("FP", "HALLWAY-RL-FP"),
      })

      assert.stub(arriveAtFiringPointStub).was.called(1)
      assert.stub(arriveAtFiringPointStub).was.called_with(firingUnitState, unit, makeMoveCtx().isAuto)
      assert.stub(hideStub).was_not.called()
    end)

    -- Boundary: disabled systems must be skipped before any delegate is invoked
    it("should skip processing when the missile system is disabled", function()
      local unit = makeUnit()
      local disabledState = makeSystemState({ enabled = false, firingUnits = { [unit.name] = { name = "FU1" } } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")

      enterArea({
        groundState = groundStateWith(disabledState),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(arriveAtFiringPointStub).was_not.called()
    end)
  end)
end)
