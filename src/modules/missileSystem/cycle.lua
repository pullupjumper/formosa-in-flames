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
---@return fun(tickCtx: SBJ__LauncherTickContext): SBJ__LogResult
local function departLauncher(order)
  return function(tickCtx)
    return Transitions.startMove(tickCtx.launcherState, tickCtx.launcher, order)
  end
end

---Launcher steps keyed by Rules.STEP; each one acts on CMO, records the transition and returns its log row
---@type table<string, fun(tickCtx: SBJ__LauncherTickContext, pair: SBJ__ReloadPair): SBJ__LogResult|nil>
local LAUNCHER_STEPS = {
  [STEP.START_STOW] = function(tickCtx)
    local launcherState = tickCtx.launcherState
    Transitions.startStow(launcherState)
    return {
      tag = "OK",
      fields = {
        unit = launcherState.name,
        action = "stow_countdown_started",
        startedAt = launcherState.stowStartTime
      }
    }
  end,

  [STEP.COMPLETE_STOW] = function(tickCtx)
    Transitions.completeStow(tickCtx.launcherState)
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
    return Transitions.startMove(pair.transloaderState, pair.transloader, ORDER.TRANSLOADER_VIA_SHRL)
  end,

  [STEP.WARN_TRANSLOADER_NOT_FOUND] = function(tickCtx)
    return {
      tag = "WARN",
      fields = {
        unit = tickCtx.launcherDescriptor.transloader,
        action = ORDER.TRANSLOADER_VIA_SHRL.action,
        reason = "unit_not_found"
      }
    }
  end,

  [STEP.WARN_TRANSLOADER_STATE_NOT_FOUND] = function(tickCtx)
    return {
      tag = "WARN",
      fields = {
        unit = tickCtx.launcherDescriptor.transloader,
        action = ORDER.TRANSLOADER_VIA_SHRL.action,
        reason = "transloader_state_not_found"
      }
    }
  end,

  [STEP.MOVE_TO_RELOAD_POINT] = departLauncher(ORDER.RELOAD_POINT),

  [STEP.ENSURE_RELOAD_CLOCK] = function(tickCtx)
    Transitions.ensureReloadClock(tickCtx.launcherState)
  end,

  [STEP.COMPLETE_RELOAD] = function(tickCtx, pair)
    local loaded = Ammo.reloadLauncher(pair.transloaderState, pair.buildReload())
    Transitions.completeReload(tickCtx.launcherState)
    return {
      tag = "OK",
      fields = {
        unit = tickCtx.launcherState.name,
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
---@type table<string, fun(tickCtx: SBJ__TransloaderTickContext, canisterStockState: SBJ__CanisterStockState): SBJ__LogResult|nil>
local TRANSLOADER_STEPS = {
  [STEP.MOVE_TO_AMMUNITION_TRANSFER_POINT] = function(tickCtx)
    return Transitions.startMove(tickCtx.transloaderState, tickCtx.transloader, ORDER.AMMUNITION_TRANSFER_POINT)
  end,

  [STEP.ENSURE_RELOAD_CLOCK] = function(tickCtx)
    Transitions.ensureReloadClock(tickCtx.transloaderState)
  end,

  [STEP.FAIL_CANISTER_STOCK_STATE_NOT_FOUND] = function(tickCtx)
    return {
      tag = "FAIL",
      fields = {
        unit = tickCtx.transloaderState.name,
        action = "ammo_transload_finished",
        reason = "canister_stock_state_not_found"
      }
    }
  end,

  [STEP.COMPLETE_TRANSLOAD] = function(tickCtx, canisterStockState)
    local transloaderState = tickCtx.transloaderState
    local weaponCountBefore = transloaderState.weaponCountCurrent
    local beforeCanisterStock = canisterStockState.weaponCountCurrent
    Ammo.transferCanisters(transloaderState, canisterStockState, tickCtx.transloaderDescriptor.weaponCountDefault)
    Transitions.completeReload(transloaderState)
    return {
      tag = "OK",
      fields = {
        unit = transloaderState.name,
        action = "ammo_transload_finished",
        transferred = transloaderState.weaponCountCurrent - weaponCountBefore,
        canisterStockBefore = beforeCanisterStock,
        canisterStockAfter = canisterStockState.weaponCountCurrent
      }
    }
  end,

  [STEP.RECALL_TO_RELOAD_POINT] = function(tickCtx)
    return Transitions.startMove(tickCtx.transloaderState, tickCtx.transloader, ORDER.TRANSLOADER_RECALL)
  end,
}

---Run one reload cycle step for a launcher
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param launcherState SBJ__LauncherState Its config descriptor must exist
---@param launcher CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processLauncher(systemState, runCtx, launcherState, launcher)
  local launcherDescriptor = runCtx.systemConfig.launchers[launcherState.name]
  ---@type SBJ__LauncherTickContext
  local tickCtx = {
    launcherState = launcherState,
    launcherDescriptor = launcherDescriptor,
    launcher = launcher,
    isAuto = runCtx.isAuto,
    currentTime = GameApi.ScenEdit_CurrentTime(),
    stowTimeSec = runCtx.systemConfig.stowTime,
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    shouldStayDeployed = Rules.shouldStayDeployed(systemState.name),
    hasTransloaderState = systemState.transloaders[launcherDescriptor.transloader] ~= nil,
    isLowAmmo = function()
      return Ammo.isLowAmmo(launcher, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
    end,
  }
  local pair = Meeting.resolveReloadPair(runCtx.systemConfig, systemState, launcher)

  return Shared.executeSteps(Rules.evaluateLauncherTick(tickCtx, pair), LAUNCHER_STEPS, tickCtx, pair)
end

---Run one reload cycle step for a transloader
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param transloaderState SBJ__TransloaderState Its config descriptor must exist
---@param transloader CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processTransloader(systemState, runCtx, transloaderState, transloader)
  local transloaderDescriptor = runCtx.systemConfig.transloaders[transloaderState.name]
  ---@type SBJ__TransloaderTickContext
  local tickCtx = {
    transloaderState = transloaderState,
    transloaderDescriptor = transloaderDescriptor,
    transloader = transloader,
    isAuto = runCtx.isAuto,
    currentTime = GameApi.ScenEdit_CurrentTime(),
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    isInReloadArea = function()
      return Meeting.findReloadArea(transloader, transloaderState.operationalArea) ~= nil
    end,
    isInSameAmmunitionTransferPoint = function()
      return Meeting.isInSameAmmunitionTransferPoint(transloaderDescriptor, transloaderState, transloader)
    end,
  }
  local canisterStockState = systemState.canisterStocks[transloaderDescriptor.canisterStock]

  return Shared.executeSteps(Rules.evaluateTransloaderTick(tickCtx, canisterStockState), TRANSLOADER_STEPS, tickCtx,
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
      Utils.addAll(results, processLauncher(systemState, runCtx, launcherState, launcher))
    end
  end

  for name, transloaderState in pairs(systemState.transloaders) do
    local descriptor = runCtx.systemConfig.transloaders[name]
    local transloader = descriptor and GameApi.ScenEdit_GetUnit(name, sideName)
    if not descriptor then
      table.insert(results, buildDescriptorNotFound(name))
    elseif transloader then
      Utils.addAll(results, processTransloader(systemState, runCtx, transloaderState, transloader))
    end
  end

  return results
end

return Cycle
