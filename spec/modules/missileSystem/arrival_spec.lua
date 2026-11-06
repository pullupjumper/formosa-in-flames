---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Arrival Unit Tests
local stub = require("luassert.stub")
local Arrival = require("src.modules.missileSystem.arrival")
local Transitions = require("src.modules.missileSystem.transitions")
local Triggers = require("src.modules.missileSystem.triggers")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
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

  describe("process", function()
    local SYSTEM_KEY = constants.MISSILE_SYSTEM_TYPES.SRBM
    local SYSTEM_CONFIG = {
      launchers = { FU1 = { name = "FU1", transloader = "RS1", weaponDBID = 1234, ammoThreshold = 60 } },
      transloaders = { RS1 = { name = "RS1", launcher = "FU1", canisterStock = "CS1", weaponCountDefault = 8 } },
      canisterStocks = { CS1 = { name = "CS1", weaponCountDefault = 40 } },
    }

    ---@param overrides? table Fields to override on the default launcher
    local function makeUnit(overrides)
      local unit = { name = "FU1", guid = "guid-fu1", side = "China" }
      for k, v in pairs(overrides or {}) do
        unit[k] = v
      end
      return unit
    end

    ---@param overrides? table Fields to override on the default enabled, empty system state
    local function makeSystemState(overrides)
      local systemState = { enabled = true, launchers = {}, transloaders = {}, canisterStocks = {} }
      for k, v in pairs(overrides or {}) do
        systemState[k] = v
      end
      return systemState
    end

    ---Move state the handlers receive when the policy overrides nothing
    ---@param overrides? table Fields to override on the default policy-derived state
    local function buildRunCtx(overrides)
      local runCtx = {
        isAuto = true,
        hideOnEnterHA = false,
        hideTransloaderOnRLNoMeeting = false
      }
      for k, v in pairs(overrides or {}) do
        runCtx[k] = v
      end
      return runCtx
    end

    local function groundStateWith(systemState)
      return { missileSystemTypes = { [SYSTEM_KEY] = systemState } }
    end

    ---Fire UnitEntersArea against the given slice, with move switches built from params.policy
    ---@param params {groundState: table, unit: table, event: table, contacts?: table, policy?: table}
    local function enterArea(params)
      Arrival.process({
        missileSystemConfigMap = { [SYSTEM_KEY] = SYSTEM_CONFIG },
        groundState = params.groundState,
        unit = params.unit,
        event = params.event,
        contacts = params.contacts,
        runCtx = buildRunCtx(params.policy)
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
      local launcherState = { name = "FU1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING }
      local systemState = makeSystemState({ launchers = { [unit.name] = launcherState } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("FP"),
      })

      assert.stub(arriveAtFiringPointStub).was.called(1)
      assert.stub(arriveAtFiringPointStub).was.called_with(launcherState, unit, buildRunCtx().isAuto)
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
      local systemState = makeSystemState({ launchers = { [unit.name] = { name = "FU1" } } })

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
      local launcherState = { name = "FU1" }
      local matchingContact = { actualunitid = unit.guid, DropContact = function() end }
      local otherContact = { actualunitid = "guid-other", DropContact = function() end }
      local systemState = makeSystemState({ launchers = { [unit.name] = launcherState } })

      local matchingDropContactStub = trackStub(matchingContact, "DropContact")
      local otherDropContactStub = trackStub(otherContact, "DropContact")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("HA"),
        contacts = { matchingContact, otherContact },
        policy = {
          hideOnEnterHA = false,
          hideTransloaderOnRLNoMeeting = false
        }
      })

      assert.stub(matchingDropContactStub).was.called(1)
      assert.stub(otherDropContactStub).was_not.called()
    end)

    -- Positive: HA + hideOnEnterHA enables both state change and concealment
    it("should force hide flow on HA when hideOnEnterHA is enabled", function()
      local unit = makeUnit()
      local launcherState = { name = "FU1" }
      local systemState = makeSystemState({ launchers = { [unit.name] = launcherState } })

      local hideStub = trackStub(Transitions, "hide")
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideTransloaderOnRLNoMeeting = false
        }
      })

      assert.stub(hideStub).was.called(1)
      assert.stub(hideStub).was.called_with(launcherState, unit,
        buildRunCtx({ hideOnEnterHA = true }).isAuto)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(launcherState, unit, 1234)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=concealed", 1, true))
    end)

    -- Negative: HA hide failure is reported as a functional warning.
    -- WARN rows ride the info log: report routes only FAIL/ERROR to the error sink.
    it("should log warning when HA concealment fails", function()
      local unit = makeUnit()
      local launcherState = { name = "FU1" }
      local systemState = makeSystemState({ launchers = { [unit.name] = launcherState } })

      trackStub(Transitions, "hide")
      trackStub(Concealment, "hideUnit")
          .returns(false, { reason = "no_buildings_in_mask", area = "OPAREA-1" })

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("HA"),
        policy = {
          hideOnEnterHA = true,
          hideTransloaderOnRLNoMeeting = false
        }
      })

      assert.stub(warnStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "[WARN]", 1, true))
      assert.is_truthy(string.find(message, "action=concealment_failed", 1, true))
    end)

    -- Negative: a unit whose battery config dropped is not hidden
    it("should leave a unit with no config descriptor alone on HA", function()
      local unit = makeUnit({ name = "FU-GONE" })
      local systemState = makeSystemState({ launchers = { [unit.name] = { name = "FU-GONE" } } })
      local hideStub = trackStub(Transitions, "hide")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({ groundState = groundStateWith(systemState), unit = unit, event = enterEvent("HA"), policy = { hideOnEnterHA = true } })

      assert.stub(hideStub).was_not.called()
      assert.stub(hideUnitStub).was_not.called()
    end)

    -- --- RL --------------------------------------------------------------

    ---Pair Meeting.resolveReloadPair hands to the RL rule: FU1 (the arriving unit by default) with RS1
    ---@param overrides? table Fields to override on the default pair, which has met
    local function buildPair(overrides)
      local pair = {
        launcherState = { name = "FU1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING },
        launcher = makeUnit(),
        transloaderState = { name = "RS1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING, weaponCountCurrent = 8 },
        transloader = makeUnit({ name = "RS1", guid = "guid-rs1" }),
        isTriggeredByLauncher = true,
        isLauncherLowAmmo = function() return true end,
        isInSameReloadArea = function() return true end,
      }
      for k, v in pairs(overrides or {}) do
        pair[k] = v
      end
      return pair
    end

    -- Positive: RL + launcher + meeting confirmed starts reload
    it("should set reload start time on RL when launcher has met transloader", function()
      local pair = buildPair()
      local unit = pair.launcher
      local systemState = makeSystemState()

      local resolvePairStub = trackStub(Meeting, "resolveReloadPair").returns(pair)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
      })

      assert.stub(resolvePairStub).was.called_with(SYSTEM_CONFIG, systemState, unit)
      assert.stub(beginReloadStub).was.called(1)
      assert.stub(beginReloadStub).was.called_with(pair.launcherState, unit, buildRunCtx().isAuto)
      assert.stub(settleStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=reload_started", 1, true))
      assert.is_truthy(string.find(message, "system=" .. SYSTEM_KEY, 1, true))
    end)

    -- Negative: a unit without a complete pair stops in manual mode and hides nothing
    it("should stop in manual mode on RL when the unit has no complete pair", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(nil)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
        policy = { hideTransloaderOnRLNoMeeting = true },
      })

      assert.stub(beginReloadStub).was_not.called()
      assert.stub(settleStub).was.called_with(systemState, unit, false)
      assert.stub(hideUnitStub).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Negative: RL + launcher + meeting not detected falls back to no-meeting path.
    -- The policy mode is intentionally NOT forwarded: settle always runs in manual mode
    -- so a launcher that drifts through RL during repositioning does not halt mid-move.
    it("should fall back to no-meeting path on RL when launcher exists but no meeting", function()
      local pair = buildPair({ isInSameReloadArea = function() return false end })
      local unit = pair.launcher
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(pair)
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

    -- Negative: in auto mode a unit that is not on its way does not meet
    it("should not begin a reload on RL in auto mode when the arriving unit is not repositioning", function()
      local pair = buildPair()
      pair.launcherState.state = constants.MISSILE_UNIT_POSTURE.HIDE
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(pair)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      trackStub(Transitions, "settle")

      enterArea({ groundState = groundStateWith(systemState), unit = pair.launcher, event = enterEvent("RL") })

      assert.stub(beginReloadStub).was_not.called()
    end)

    -- Positive: RL no-meeting + hideTransloaderOnRLNoMeeting + ammo sufficient hides transloader
    it("should hide transloader on RL no-meeting when launcher ammo is sufficient", function()
      local pair = buildPair({ isTriggeredByLauncher = false, isLauncherLowAmmo = function() return false end })
      local unit = pair.transloader
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(pair)
      local settleStub = trackStub(Transitions, "settle")
      local hideUnitStub = trackStub(Concealment, "hideUnit").returns(true)

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideTransloaderOnRLNoMeeting = true
        }
      })

      assert.stub(settleStub).was.called(1)
      assert.stub(settleStub).was.called_with(systemState, unit, false)
      assert.stub(hideUnitStub).was.called(1)
      assert.stub(hideUnitStub).was.called_with(pair.transloaderState, unit)
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=transloader_concealed", 1, true))
      assert.is_truthy(string.find(message, "pairedLauncher=FU1", 1, true))
    end)

    -- Negative: RL no-meeting + low ammo must not hide the transloader
    it("should not hide transloader on RL no-meeting when launcher ammo is low", function()
      local pair = buildPair({ isTriggeredByLauncher = false, isInSameReloadArea = function() return false end })
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(pair)
      local settleStub = trackStub(Transitions, "settle")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = pair.transloader,
        event = enterEvent("RL"),
        policy = {
          hideOnEnterHA = false,
          hideTransloaderOnRLNoMeeting = true
        }
      })

      assert.stub(settleStub).was.called(1)
      assert.stub(hideUnitStub).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Negative: a launcher arriving alone never hides its transloader
    it("should not hide on RL no-meeting when the arriving unit is the launcher", function()
      local pair = buildPair({ isLauncherLowAmmo = function() return false end })
      local systemState = makeSystemState()

      trackStub(Meeting, "resolveReloadPair").returns(pair)
      trackStub(Transitions, "settle")
      local hideUnitStub = trackStub(Concealment, "hideUnit")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = pair.launcher,
        event = enterEvent("RL"),
        policy = { hideTransloaderOnRLNoMeeting = true },
      })

      assert.stub(hideUnitStub).was_not.called()
    end)

    -- --- ATP -------------------------------------------------------------

    -- Positive: ATP + meeting confirmed starts reload
    it("should set reload start time on ATP when canister stock meeting is confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local transloaderState = { name = "RS1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING, weaponCountCurrent = 0 }
      local systemState = makeSystemState({ transloaders = { [unit.name] = transloaderState } })

      local isAtCanisterStockStub = trackStub(Meeting, "isAtCanisterStock").returns(true)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("ATP"),
      })

      assert.stub(isAtCanisterStockStub).was.called_with(SYSTEM_CONFIG.transloaders.RS1, transloaderState, unit)
      assert.stub(beginReloadStub).was.called(1)
      assert.stub(beginReloadStub).was.called_with(transloaderState, unit, buildRunCtx().isAuto)
      assert.stub(settleStub).was_not.called()
      assert.stub(logStub).was.called(1)

      local message = logStub.calls[1].vals[2]
      assert.is_truthy(string.find(message, "action=transload_started", 1, true))
    end)

    -- Negative: ATP fallback resets state when meeting fails
    it("should set state to static on ATP when canister stock meeting is not confirmed", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local transloaderState = { name = "RS1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING, weaponCountCurrent = 0 }
      local systemState = makeSystemState({ transloaders = { [unit.name] = transloaderState } })

      trackStub(Meeting, "isAtCanisterStock").returns(false)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      local settleStub = trackStub(Transitions, "settle")

      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("ATP"),
      })

      assert.stub(beginReloadStub).was_not.called()
      assert.stub(settleStub).was.called(1)
      assert.stub(settleStub).was.called_with(systemState, unit, buildRunCtx().isAuto)
      assert.stub(logStub).was_not.called()
    end)

    -- Negative: a transloader that still carries missiles does not meet its canister stock
    it("should not begin a transload on ATP when the transloader still carries missiles", function()
      local unit = makeUnit({ name = "RS1", guid = "guid-rs1" })
      local transloaderState = { name = "RS1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING, weaponCountCurrent = 3 }
      local systemState = makeSystemState({ transloaders = { [unit.name] = transloaderState } })

      local isAtCanisterStockStub = trackStub(Meeting, "isAtCanisterStock").returns(true)
      local beginReloadStub = trackStub(Transitions, "beginReload")
      trackStub(Transitions, "settle")

      enterArea({ groundState = groundStateWith(systemState), unit = unit, event = enterEvent("ATP") })

      assert.stub(beginReloadStub).was_not.called()
      assert.stub(isAtCanisterStockStub).was_not.called()
    end)

    -- --- Boundaries -------------------------------------------------------

    -- Boundary: unrecognized position token short-circuits without side effects
    it("should return early when event description has no position type token", function()
      local unit = makeUnit()
      local contact = { actualunitid = unit.guid, DropContact = function() end }
      local systemState = makeSystemState({ launchers = { [unit.name] = { name = "FU1" } } })

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
      local systemState = makeSystemState({ launchers = { [unit.name] = { name = "FU1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING } } })

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
      local launcherState = { name = "FU1", state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING }
      local systemState = makeSystemState({ launchers = { [unit.name] = launcherState } })

      local arriveAtFiringPointStub = trackStub(Transitions, "arriveAtFiringPoint")
      local hideStub = trackStub(Transitions, "hide")

      -- areaName "HALLWAY-RL-FP" contains HA/RL/FP substrings; pos type must still be FP
      enterArea({
        groundState = groundStateWith(systemState),
        unit = unit,
        event = enterEvent("FP", "HALLWAY-RL-FP"),
      })

      assert.stub(arriveAtFiringPointStub).was.called(1)
      assert.stub(arriveAtFiringPointStub).was.called_with(launcherState, unit, buildRunCtx().isAuto)
      assert.stub(hideStub).was_not.called()
    end)

    -- Boundary: disabled systems must be skipped before any delegate is invoked
    it("should skip processing when the missile system is disabled", function()
      local unit = makeUnit()
      local disabledState = makeSystemState({ enabled = false, launchers = { [unit.name] = { name = "FU1" } } })

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
