local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local Rules = require("src.modules.missileSystem.rules")
local Shared = require("src.modules.missileSystem.shared")
local Transitions = require("src.modules.missileSystem.transitions")

---Runs the reload cycle: observes each unit, asks Rules for the steps and carries them out.
local Cycle = {}

local STEP = Rules.STEP
local ORDER = Movement.ORDER

---Step that sends the firing unit on a move order
---@param order SBJ__MoveOrder
---@return fun(tick: SBJ__FiringUnitTick): SBJ__LogResult
local function departFiringUnit(order)
  return function(tick)
    return Transitions.depart(tick.firingUnitState, tick.firingUnit, order)
  end
end

---Firing unit steps keyed by Rules.STEP; each one acts on CMO, records the transition and returns its log row
---@type table<string, fun(tick: SBJ__FiringUnitTick, pair: SBJ__ReloadPair): SBJ__LogResult|nil>
local FIRING_UNIT_STEPS = {
  [STEP.BEGIN_STOW] = function(tick)
    local firingUnitState = tick.firingUnitState
    Transitions.beginStow(firingUnitState)
    return {
      tag = "OK",
      fields = {
        unit = firingUnitState.name,
        action = "stow_countdown_started",
        startedAt = firingUnitState.stowStartTime
      }
    }
  end,

  [STEP.END_STOW] = function(tick)
    Transitions.endStow(tick.firingUnitState)
  end,

  [STEP.MOVE_TO_HIDE_AREA] = departFiringUnit(ORDER.HIDE_AREA),

  [STEP.UNHIDE_RESUPPLY_UNIT] = function(_, pair)
    local success, errorFields = Concealment.moveFromHideArea(pair.resupplyUnitState, pair.resupplyUnit)
    if not success then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = pair.resupplyUnitState.name,
          action = "unload_from_hide_area"
        }, errorFields)
      }
    end
  end,

  [STEP.MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT] = function(_, pair)
    return Transitions.depart(pair.resupplyUnitState, pair.resupplyUnit, ORDER.RESUPPLY_VIA_SHRL)
  end,

  [STEP.WARN_RESUPPLY_UNIT_NOT_FOUND] = function(tick)
    return {
      tag = "WARN",
      fields = {
        unit = tick.firingUnitState.resupplyUnit,
        action = ORDER.RESUPPLY_VIA_SHRL.action,
        reason = "unit_not_found"
      }
    }
  end,

  [STEP.WARN_RESUPPLY_STATE_NOT_FOUND] = function(tick)
    return {
      tag = "WARN",
      fields = {
        unit = tick.firingUnitState.resupplyUnit or "unknown",
        action = ORDER.RESUPPLY_VIA_SHRL.action,
        reason = "context_not_found"
      }
    }
  end,

  [STEP.MOVE_TO_RELOAD_POINT] = departFiringUnit(ORDER.RELOAD_POINT),

  [STEP.ENSURE_RELOAD_CLOCK] = function(tick)
    Transitions.ensureReloadClock(tick.firingUnitState)
  end,

  [STEP.COMPLETE_RELOAD] = function(tick, pair)
    local loaded = Ammo.reloadFiringUnit(pair.resupplyUnitState, pair.buildReload())
    Transitions.finishReload(tick.firingUnitState)
    return {
      tag = "OK",
      fields = {
        unit = tick.firingUnitState.name,
        action = "missile_reload_finished",
        loaded = loaded
      }
    }
  end,

  [STEP.HIDE_RESUPPLY_UNIT_AFTER_RELOAD] = function(_, pair)
    local success, errorFields = Concealment.hideUnit(pair.resupplyUnitState, pair.resupplyUnit)
    if not success then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = pair.resupplyUnitState.name,
          action = "hide_resupply_unit"
        }, errorFields)
      }
    end
  end,

  [STEP.MOVE_TO_FIRING_POINT] = departFiringUnit(ORDER.FIRING_POINT),
}

---Resupply unit steps keyed by Rules.STEP
---@type table<string, fun(tick: SBJ__ResupplyUnitTick, canisterStockState: SBJ__CanisterStockState): SBJ__LogResult|nil>
local RESUPPLY_UNIT_STEPS = {
  [STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT] = function(tick)
    return Transitions.depart(tick.resupplyUnitState, tick.resupplyUnit, ORDER.AMMUNITION_TRANSFER_POINT)
  end,

  [STEP.ENSURE_RELOAD_CLOCK] = function(tick)
    Transitions.ensureReloadClock(tick.resupplyUnitState)
  end,

  [STEP.FAIL_CANISTER_STOCK_STATE_NOT_FOUND] = function(tick)
    return {
      tag = "FAIL",
      fields = {
        unit = tick.resupplyUnitState.name,
        action = "ammo_transload_finished",
        reason = "ammo_context_not_found"
      }
    }
  end,

  [STEP.COMPLETE_TRANSLOAD] = function(tick, canisterStockState)
    local resupplyUnitState = tick.resupplyUnitState
    local beforeResupply = resupplyUnitState.weaponCountCurrent
    local beforeCanisterStock = canisterStockState.weaponCountCurrent
    Ammo.transferCanisters(resupplyUnitState, canisterStockState)
    Transitions.finishReload(resupplyUnitState)
    return {
      tag = "OK",
      fields = {
        unit = resupplyUnitState.name,
        action = "ammo_transload_finished",
        transferred = resupplyUnitState.weaponCountCurrent - beforeResupply,
        canisterStockBefore = beforeCanisterStock,
        canisterStockAfter = canisterStockState.weaponCountCurrent
      }
    }
  end,

  [STEP.RECALL_TO_RELOAD_POINT] = function(tick)
    return Transitions.depart(tick.resupplyUnitState, tick.resupplyUnit, ORDER.RESUPPLY_RECALL)
  end,
}

---Run one reload cycle step for a firing unit
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnit(systemState, runCtx, firingUnitState, firingUnit)
  ---@type SBJ__FiringUnitTick
  local tick = {
    firingUnitState = firingUnitState,
    firingUnit = firingUnit,
    isAuto = runCtx.isAuto,
    now = GameApi.ScenEdit_CurrentTime(),
    stowTimeSec = runCtx.systemConfig.stowTime,
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    staysDeployed = Rules.staysDeployed(systemState.name),
    hasResupplyUnitState = systemState.resupplyUnits[firingUnitState.resupplyUnit] ~= nil,
    isLowAmmo = function()
      return Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
    end,
  }
  local pair = Meeting.resolveReloadPair(systemState, firingUnit)

  return Shared.processSteps(Rules.evaluateFiringUnitTick(tick, pair), FIRING_UNIT_STEPS, tick, pair)
end

---Run one reload cycle step for a resupply unit
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnit(systemState, runCtx, resupplyUnitState, resupplyUnit)
  ---@type SBJ__ResupplyUnitTick
  local tick = {
    resupplyUnitState = resupplyUnitState,
    resupplyUnit = resupplyUnit,
    isAuto = runCtx.isAuto,
    now = GameApi.ScenEdit_CurrentTime(),
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    isInReloadArea = function()
      return Meeting.findReloadArea(resupplyUnit, resupplyUnitState.operationalArea) ~= nil
    end,
    isAtCanisterStock = function()
      return Meeting.isAtCanisterStock(resupplyUnitState, resupplyUnit)
    end,
  }
  local _, _, canisterStockState = GroundStateStore.resolvePair(systemState, resupplyUnitState.name)

  return Shared.processSteps(Rules.evaluateResupplyUnitTick(tick, canisterStockState), RESUPPLY_UNIT_STEPS, tick,
    canisterStockState)
end

---Process missile-system reload cycles and return structured results
---Firing units go first: their steps change the resupply unit states the resupply loop then reads.
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param sideName string
---@return SBJ__LogResult[] results Collected structured results
function Cycle.process(systemState, runCtx, sideName)
  local results = {}
  for _, firingUnitState in pairs(systemState.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitState.name, sideName)
    if firingUnit then
      Utils.addAll(results, processFiringUnit(systemState, runCtx, firingUnitState, firingUnit))
    end
  end

  for _, resupplyUnitState in pairs(systemState.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitState.name, sideName)
    if resupplyUnit then
      Utils.addAll(results, processResupplyUnit(systemState, runCtx, resupplyUnitState, resupplyUnit))
    end
  end

  return results
end

return Cycle
