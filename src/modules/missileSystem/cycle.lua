local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Rules = require("src.modules.missileSystem.rules")
local Shared = require("src.modules.missileSystem.shared")
local Transitions = require("src.modules.missileSystem.transitions")

---Runs the reload cycle: observes each unit, asks Rules for the steps and carries them out.
local Cycle = {}

local STEP = Rules.STEP
local ORDER = Movement.ORDER

---Step that sends the launcher on a move order
---@param order SBJ__MoveOrder
---@return fun(tick: SBJ__LauncherTick): SBJ__LogResult
local function departLauncher(order)
  return function(tick)
    return Transitions.depart(tick.launcherState, tick.launcher, order)
  end
end

---Launcher steps keyed by Rules.STEP; each one acts on CMO, records the transition and returns its log row
---@type table<string, fun(tick: SBJ__LauncherTick, pair: SBJ__ReloadPair): SBJ__LogResult|nil>
local LAUNCHER_STEPS = {
  [STEP.BEGIN_STOW] = function(tick)
    local launcherState = tick.launcherState
    Transitions.beginStow(launcherState)
    return {
      tag = "OK",
      fields = {
        unit = launcherState.name,
        action = "stow_countdown_started",
        startedAt = launcherState.stowStartTime
      }
    }
  end,

  [STEP.END_STOW] = function(tick)
    Transitions.endStow(tick.launcherState)
  end,

  [STEP.MOVE_TO_HIDE_AREA] = departLauncher(ORDER.HIDE_AREA),

  [STEP.UNHIDE_TRANSLOADER] = function(_, pair)
    local success, errorFields = Concealment.moveFromHideArea(pair.transloaderState, pair.transloader)
    if not success then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = pair.transloaderState.name,
          action = "unload_from_hide_area"
        }, errorFields)
      }
    end
  end,

  [STEP.MOVE_TRANSLOADER_TO_RELOAD_POINT] = function(_, pair)
    return Transitions.depart(pair.transloaderState, pair.transloader, ORDER.RESUPPLY_VIA_SHRL)
  end,

  [STEP.WARN_TRANSLOADER_NOT_FOUND] = function(tick)
    return {
      tag = "WARN",
      fields = {
        unit = tick.launcherDescriptor.transloader,
        action = ORDER.RESUPPLY_VIA_SHRL.action,
        reason = "unit_not_found"
      }
    }
  end,

  [STEP.WARN_RESUPPLY_STATE_NOT_FOUND] = function(tick)
    return {
      tag = "WARN",
      fields = {
        unit = tick.launcherDescriptor.transloader,
        action = ORDER.RESUPPLY_VIA_SHRL.action,
        reason = "context_not_found"
      }
    }
  end,

  [STEP.MOVE_TO_RELOAD_POINT] = departLauncher(ORDER.RELOAD_POINT),

  [STEP.ENSURE_RELOAD_CLOCK] = function(tick)
    Transitions.ensureReloadClock(tick.launcherState)
  end,

  [STEP.COMPLETE_RELOAD] = function(tick, pair)
    local loaded = Ammo.reloadLauncher(pair.transloaderState, pair.buildReload())
    Transitions.finishReload(tick.launcherState)
    return {
      tag = "OK",
      fields = {
        unit = tick.launcherState.name,
        action = "missile_reload_finished",
        loaded = loaded
      }
    }
  end,

  [STEP.HIDE_TRANSLOADER_AFTER_RELOAD] = function(_, pair)
    local success, errorFields = Concealment.hideUnit(pair.transloaderState, pair.transloader)
    if not success then
      return {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = pair.transloaderState.name,
          action = "hide_transloader"
        }, errorFields)
      }
    end
  end,

  [STEP.MOVE_TO_FIRING_POINT] = departLauncher(ORDER.FIRING_POINT),
}

---Transloader steps keyed by Rules.STEP
---@type table<string, fun(tick: SBJ__TransloaderTick, canisterStockState: SBJ__CanisterStockState): SBJ__LogResult|nil>
local TRANSLOADER_STEPS = {
  [STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT] = function(tick)
    return Transitions.depart(tick.transloaderState, tick.transloader, ORDER.AMMUNITION_TRANSFER_POINT)
  end,

  [STEP.ENSURE_RELOAD_CLOCK] = function(tick)
    Transitions.ensureReloadClock(tick.transloaderState)
  end,

  [STEP.FAIL_CANISTER_STOCK_STATE_NOT_FOUND] = function(tick)
    return {
      tag = "FAIL",
      fields = {
        unit = tick.transloaderState.name,
        action = "ammo_transload_finished",
        reason = "canister_stock_state_not_found"
      }
    }
  end,

  [STEP.COMPLETE_TRANSLOAD] = function(tick, canisterStockState)
    local transloaderState = tick.transloaderState
    local beforeResupply = transloaderState.weaponCountCurrent
    local beforeCanisterStock = canisterStockState.weaponCountCurrent
    Ammo.transferCanisters(transloaderState, canisterStockState, tick.transloaderDescriptor.weaponCountDefault)
    Transitions.finishReload(transloaderState)
    return {
      tag = "OK",
      fields = {
        unit = transloaderState.name,
        action = "ammo_transload_finished",
        transferred = transloaderState.weaponCountCurrent - beforeResupply,
        canisterStockBefore = beforeCanisterStock,
        canisterStockAfter = canisterStockState.weaponCountCurrent
      }
    }
  end,

  [STEP.RECALL_TO_RELOAD_POINT] = function(tick)
    return Transitions.depart(tick.transloaderState, tick.transloader, ORDER.RESUPPLY_RECALL)
  end,
}

---Run one reload cycle step for a launcher
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param launcherState SBJ__LauncherState
---@param launcherDescriptor SBJ__LauncherDescriptor
---@param launcher CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processLauncher(systemState, runCtx, launcherState, launcherDescriptor, launcher)
  ---@type SBJ__LauncherTick
  local tick = {
    launcherState = launcherState,
    launcherDescriptor = launcherDescriptor,
    launcher = launcher,
    isAuto = runCtx.isAuto,
    now = GameApi.ScenEdit_CurrentTime(),
    stowTimeSec = runCtx.systemConfig.stowTime,
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    staysDeployed = Rules.staysDeployed(systemState.name),
    hasTransloaderState = systemState.transloaders[launcherDescriptor.transloader] ~= nil,
    isLowAmmo = function()
      return Ammo.isLowAmmo(launcher, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
    end,
  }
  local pair = Meeting.resolveReloadPair(runCtx.systemConfig, systemState, launcher)

  return Shared.processSteps(Rules.evaluateLauncherTick(tick, pair), LAUNCHER_STEPS, tick, pair)
end

---Run one reload cycle step for a transloader
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param transloaderState SBJ__TransloaderState
---@param transloaderDescriptor SBJ__TransloaderDescriptor
---@param transloader CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processTransloader(systemState, runCtx, transloaderState, transloaderDescriptor, transloader)
  ---@type SBJ__TransloaderTick
  local tick = {
    transloaderState = transloaderState,
    transloaderDescriptor = transloaderDescriptor,
    transloader = transloader,
    isAuto = runCtx.isAuto,
    now = GameApi.ScenEdit_CurrentTime(),
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    isInReloadArea = function()
      return Meeting.findReloadArea(transloader, transloaderState.operationalArea) ~= nil
    end,
    isAtCanisterStock = function()
      return Meeting.isAtCanisterStock(transloaderDescriptor, transloaderState, transloader)
    end,
  }
  local canisterStockState = systemState.canisterStocks[transloaderDescriptor.canisterStock]

  return Shared.processSteps(Rules.evaluateTransloaderTick(tick, canisterStockState), TRANSLOADER_STEPS, tick,
    canisterStockState)
end

---Log row for a unit whose state has no config descriptor, e.g. config dropped its battery after a save
---@param unitName string
---@return SBJ__LogResult
local function buildDescriptorNotFound(unitName)
  return { tag = "WARN", fields = { unit = unitName, action = "reload_cycle", reason = "descriptor_not_found" } }
end

---Process missile-system reload cycles and return structured results
---Launchers go first: their steps change the transloader states the transloader loop then reads.
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param sideName string
---@return SBJ__LogResult[] results Collected structured results
function Cycle.process(systemState, runCtx, sideName)
  local results = {}
  for name, launcherState in pairs(systemState.launchers) do
    local descriptor = runCtx.systemConfig.launchers[name]
    local launcher = descriptor and GameApi.ScenEdit_GetUnit(name, sideName)
    if not descriptor then
      table.insert(results, buildDescriptorNotFound(name))
    elseif launcher then
      Utils.addAll(results, processLauncher(systemState, runCtx, launcherState, descriptor, launcher))
    end
  end

  for name, transloaderState in pairs(systemState.transloaders) do
    local descriptor = runCtx.systemConfig.transloaders[name]
    local transloader = descriptor and GameApi.ScenEdit_GetUnit(name, sideName)
    if not descriptor then
      table.insert(results, buildDescriptorNotFound(name))
    elseif transloader then
      Utils.addAll(results, processTransloader(systemState, runCtx, transloaderState, descriptor, transloader))
    end
  end

  return results
end

return Cycle
