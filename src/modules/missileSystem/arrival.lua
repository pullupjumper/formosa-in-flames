local constants = require("src.core.constants")
local LogFormat = require("src.utils.logFormat")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Concealment = require("src.modules.missileSystem.concealment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local Rules = require("src.modules.missileSystem.rules")
local Shared = require("src.modules.missileSystem.shared")
local Transitions = require("src.modules.missileSystem.transitions")
local Triggers = require("src.modules.missileSystem.triggers")

---Reacts to a unit entering one of its battery's FP / HA / RL / ATP zones:
---observes the unit, asks Rules for the steps and carries them out.
local Arrival = {}

local STEP = Rules.STEP

---Extract position type token from UnitEntersArea trigger description
---@param event CMO__Event|nil
---@return string|nil # Position type token (FP/ATP/HA/RL)
local function resolvePositionType(event)
  if not event or not event.triggers then
    return nil
  end

  for _, trigger in ipairs(event.triggers) do
    local entersArea = trigger["UnitEntersArea"]
    if entersArea and entersArea.Description then
      local positionType = Triggers.parsePositionType(entersArea.Description)
      if positionType then
        return positionType
      end
    end
  end

  return nil
end

---Drop contact entries that point to the incoming unit
---@param unit CMO__Unit
---@param contacts CMO__Contact[]|nil
local function dropUnitContact(unit, contacts)
  if not contacts then
    return
  end

  for _, contact in ipairs(contacts) do
    if unit.guid == contact.actualunitid then
      contact:DropContact()
    end
  end
end

---Firing point steps keyed by Rules.STEP; each one acts on CMO, records the transition and returns its log row
---@type table<string, fun(ctx: SBJ__ArrivalContext, launcherState: SBJ__LauncherState): SBJ__LogResult|nil>
local FIRING_POINT_STEPS = {
  [STEP.ARRIVE_AT_FIRING_POINT] = function(ctx, launcherState)
    Transitions.arriveAtFiringPoint(launcherState, ctx.unit, ctx.moveCtx.isAuto)
    return { tag = "OK", fields = { unit = ctx.unit.name, action = "firing_ready", state = "STATIC", wcs = "FREE" } }
  end,
}

---Hide area steps keyed by Rules.STEP
---@type table<string, fun(ctx: SBJ__ArrivalContext, observation: SBJ__HideAreaObservation): SBJ__LogResult|nil>
local HIDE_AREA_STEPS = {
  [STEP.HIDE_LAUNCHER] = function(ctx, observation)
    local unit = ctx.unit
    Transitions.hide(observation.launcherState, unit, ctx.moveCtx.isAuto)
    local success, errorFields = Concealment.hideUnit(
      observation.launcherState, unit, observation.launcherDescriptor.weaponDBID
    )
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({ unit = unit.name, action = "concealment_failed", state = "HIDE" }, errorFields)
      }
    end

    return { tag = "OK", fields = { unit = unit.name, action = "concealed", state = "HIDE" } }
  end,
}

---Reload point steps keyed by Rules.STEP
---@type table<string, fun(ctx: SBJ__ArrivalContext, pair: SBJ__ReloadPair): SBJ__LogResult|nil>
local RELOAD_POINT_STEPS = {
  [STEP.BEGIN_RELOAD] = function(ctx, pair)
    local launcherState = pair.launcherState
    Transitions.beginReload(launcherState, pair.launcher, ctx.moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        unit = launcherState.name,
        action = "reload_started",
        triggerUnit = ctx.unit.name,
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, launcherState.reloadStartTime)
      }
    }
  end,

  -- Manual mode keeps a launcher drifting through RL during repositioning from being halted.
  [STEP.STOP_IN_MANUAL_MODE] = function(ctx)
    Transitions.settle(ctx.systemState, ctx.unit, false)
  end,

  [STEP.HIDE_UNMET_TRANSLOADER] = function(ctx, pair)
    local unit = ctx.unit
    local pairedLauncherName = pair.launcherState.name
    local success, errorFields = Concealment.hideUnit(pair.transloaderState, unit)
    if success == false then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = unit.name,
          action = "transloader_concealment_failed",
          pairedLauncher = pairedLauncherName
        }, errorFields)
      }
    end

    return {
      tag = "OK",
      fields = {
        unit = unit.name,
        action = "transloader_concealed",
        pairedLauncher = pairedLauncherName,
        ammoStatus = "sufficient"
      }
    }
  end,
}

---Ammunition transfer point steps keyed by Rules.STEP
---@type table<string, fun(ctx: SBJ__ArrivalContext, observation: SBJ__AmmunitionTransferPointObservation): SBJ__LogResult|nil>
local AMMUNITION_TRANSFER_POINT_STEPS = {
  [STEP.BEGIN_TRANSLOAD] = function(ctx, observation)
    local transloaderState = observation.transloaderState
    Transitions.beginReload(transloaderState, ctx.unit, ctx.moveCtx.isAuto)
    return {
      tag = "OK",
      fields = {
        unit = transloaderState.name,
        action = "transload_started",
        state = "RELOAD",
        startedAt = os.date(constants.DATE_FORMAT, transloaderState.reloadStartTime)
      }
    }
  end,

  [STEP.STOP] = function(ctx)
    Transitions.settle(ctx.systemState, ctx.unit, ctx.moveCtx.isAuto)
  end,
}

---Observe a unit entering its hide area
---@param ctx SBJ__ArrivalContext
---@return SBJ__HideAreaObservation|nil # Nil when the unit is not a launcher of this system
local function observeHideArea(ctx)
  local unit = ctx.unit
  local launcherState = ctx.systemState.launchers[unit.name]
  local launcherDescriptor = ctx.systemConfig.launchers[unit.name]
  if not launcherState or not launcherDescriptor then
    return nil
  end

  return {
    launcherState = launcherState,
    launcherDescriptor = launcherDescriptor,
    isLowAmmo = function()
      return Ammo.isLowAmmo(unit, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
    end,
  }
end

---Observe a unit entering its ammunition transfer point
---@param ctx SBJ__ArrivalContext
---@return SBJ__AmmunitionTransferPointObservation|nil # Nil when the unit is not a transloader of this system
local function observeAmmunitionTransferPoint(ctx)
  local unit = ctx.unit
  local transloaderState = ctx.systemState.transloaders[unit.name]
  local transloaderDescriptor = ctx.systemConfig.transloaders[unit.name]
  if not transloaderState or not transloaderDescriptor then
    return nil
  end

  return {
    transloaderState = transloaderState,
    isAtCanisterStock = function()
      return Meeting.isAtCanisterStock(transloaderDescriptor, transloaderState, unit)
    end,
  }
end

---How each position is observed, decided and carried out, keyed by the token extracted from the event trigger
---@type table<string, SBJ__ArrivalPosition>
local POSITIONS = {
  [constants.POSITION_TYPES.FIRING_POINT] = {
    observe = function(ctx) return ctx.systemState.launchers[ctx.unit.name] end,
    evaluate = Rules.evaluateFiringPointArrival,
    steps = FIRING_POINT_STEPS,
  },
  [constants.POSITION_TYPES.HIDE_AREA] = {
    observe = observeHideArea,
    evaluate = Rules.evaluateHideAreaArrival,
    steps = HIDE_AREA_STEPS,
  },
  [constants.POSITION_TYPES.RELOAD_POINT] = {
    observe = function(ctx) return Meeting.resolveReloadPair(ctx.systemConfig, ctx.systemState, ctx.unit) end,
    evaluate = Rules.evaluateReloadPointArrival,
    steps = RELOAD_POINT_STEPS,
  },
  [constants.POSITION_TYPES.AMMUNITION_TRANSFER_POINT] = {
    observe = observeAmmunitionTransferPoint,
    evaluate = Rules.evaluateAmmunitionTransferPointArrival,
    steps = AMMUNITION_TRANSFER_POINT_STEPS,
  },
}

---Handle missile system UnitEntersArea flow for FP/HA/RL/ATP positions
---@param params SBJ__MoveToPositionEventParams
function Arrival.processMoveToPositionEvent(params)
  local unit = params.unit
  local moveCtx = params.moveCtx
  local positionType = resolvePositionType(params.event)
  local position = positionType and POSITIONS[positionType]
  if not position then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, params.contacts)
  end

  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. unit.side, "Position event")

  GroundStateStore.forEachEnabledSystem(params.groundState, function(systemState, missileSystemType)
    ---@type SBJ__ArrivalContext
    local ctx = {
      systemConfig = params.missileSystemConfigMap[missileSystemType],
      systemState = systemState,
      unit = unit,
      moveCtx = moveCtx
    }
    local observation = position.observe(ctx)
    local steps = position.evaluate(moveCtx, observation)
    for _, row in ipairs(Shared.processSteps(steps, position.steps, ctx, observation)) do
      row.fields.system = missileSystemType
      report.add(row.tag, row.fields)
    end
  end)

  -- position is derived from the event trigger, so it describes the whole batch
  -- rather than any single row.
  report.emit({ mode = moveCtx.isAuto and "auto" or "manual", position = positionType })
end

return Arrival
