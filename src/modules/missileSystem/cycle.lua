local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local Rules = require("src.modules.missileSystem.rules")
local Transitions = require("src.modules.missileSystem.transitions")

---Runs the reload cycle: observes each unit, asks Rules for the steps and carries them out.
local Cycle = {}

local STEP = Rules.STEP

---Append a movement command result
---Rows carry only unit-level fields; the caller adds the owning system name.
---The failing helper supplies its own reason, so no generic one is invented here.
---@param results SBJ__LogResult[]
---@param params {unit: string, action: string}
---@param success boolean
---@param errorDetail table<string, any>|nil
local function addCommandResult(results, params, success, errorDetail)
  if success then
    table.insert(results, { tag = "OK", fields = { unit = params.unit, action = params.action } })
    return
  end

  table.insert(results,
    { tag = "FAIL", fields = LogFormat.merge({ unit = params.unit, action = params.action }, errorDetail) })
end

---Seconds since a clock started, or 0 when it has not started yet
---@param startTime number|nil
---@param currentTime number
---@return number
local function calculateElapsedSec(startTime, currentTime)
  return startTime and currentTime - startTime or 0
end

---Firing unit steps keyed by Rules.STEP; each one acts on CMO, records the transition and adds its log rows
---@type table<string, fun(stepCtx: SBJ__FiringUnitStepContext)>
local FIRING_UNIT_STEPS = {
  [STEP.BEGIN_STOW] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState
    Transitions.beginStow(firingUnitState)
    table.insert(stepCtx.results, {
      tag = "OK",
      fields = {
        unit = firingUnitState.name,
        action = "stow_countdown_started",
        startedAt = firingUnitState.stowStartTime
      }
    })
  end,

  [STEP.END_STOW] = function(stepCtx)
    Transitions.endStow(stepCtx.firingUnitState)
  end,

  [STEP.MOVE_TO_HIDE_AREA] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState
    local success, errorFields = Transitions.depart(firingUnitState,
      Movement.moveToHideArea(firingUnitState, stepCtx.firingUnit))
    addCommandResult(stepCtx.results, { unit = firingUnitState.name, action = "move_to_hide_area" }, success, errorFields)
  end,

  [STEP.UNHIDE_RESUPPLY_UNIT] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]
    local success, errorFields = Concealment.moveFromHideArea(resupplyUnitState, stepCtx.resupplyUnit)
    if not success then
      table.insert(stepCtx.results, {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = resupplyUnitState.name,
          action = "unload_from_hide_area"
        }, errorFields)
      })
    end
  end,

  [STEP.MOVE_RESUPPLY_UNIT_TO_RELOAD_POINT] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]
    local success, errorFields = Transitions.depart(resupplyUnitState, Movement.moveToReloadPoint(
      resupplyUnitState,
      stepCtx.resupplyUnit,
      resupplyUnitState.operationalArea.SHRL
    ))
    addCommandResult(stepCtx.results, { unit = resupplyUnitState.name, action = "move_resupply_to_reload_point" },
      success, errorFields)
  end,

  [STEP.WARN_RESUPPLY_UNIT_NOT_FOUND] = function(stepCtx)
    table.insert(stepCtx.results, {
      tag = "WARN",
      fields = {
        unit = (stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]).name,
        action = "move_resupply_to_reload_point",
        reason = "unit_not_found"
      }
    })
  end,

  [STEP.WARN_RESUPPLY_STATE_NOT_FOUND] = function(stepCtx)
    table.insert(stepCtx.results, {
      tag = "WARN",
      fields = {
        unit = stepCtx.firingUnitState.resupplyUnit or "unknown",
        action = "move_resupply_to_reload_point",
        reason = "context_not_found"
      }
    })
  end,

  [STEP.MOVE_TO_RELOAD_POINT] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState
    local success, errorFields = Transitions.depart(firingUnitState,
      Movement.moveToReloadPoint(firingUnitState, stepCtx.firingUnit))
    addCommandResult(stepCtx.results, { unit = firingUnitState.name, action = "move_firing_unit_to_reload_point" },
      success, errorFields)
  end,

  [STEP.ENSURE_RELOAD_CLOCK] = function(stepCtx)
    Transitions.ensureReloadClock(stepCtx.firingUnitState)
  end,

  [STEP.COMPLETE_RELOAD] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState
    local resupplyUnitState = stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]
    local loaded = Ammo.reloadFiringUnit(firingUnitState, resupplyUnitState, firingUnitState.weaponDBID,
      stepCtx.firingUnit.side)
    Transitions.finishReload(firingUnitState)
    table.insert(stepCtx.results, {
      tag = "OK",
      fields = {
        unit = firingUnitState.name,
        action = "missile_reload_finished",
        loaded = loaded
      }
    })
  end,

  -- The resupply unit's remaining missiles are known only after the reload, so the stock check stays here.
  [STEP.HIDE_RESUPPLY_UNIT] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState --[[@as SBJ__ResupplyUnitState]]
    local resupplyUnit = stepCtx.resupplyUnit
    if not resupplyUnit or resupplyUnitState.weaponCountCurrent <= 0
        or not Meeting.findUnitArea(resupplyUnit, resupplyUnitState.operationalArea) then
      return
    end

    local success, errorFields = Concealment.hideUnit(resupplyUnitState, resupplyUnit)
    if not success then
      table.insert(stepCtx.results, {
        tag = "WARN",
        fields = LogFormat.merge({
          unit = resupplyUnitState.name,
          action = "hide_resupply_unit"
        }, errorFields)
      })
    end
  end,

  [STEP.MOVE_TO_FIRING_POINT] = function(stepCtx)
    local firingUnitState = stepCtx.firingUnitState
    local success, errorFields = Transitions.depart(firingUnitState,
      Movement.moveToFiringPoint(firingUnitState, stepCtx.firingUnit))
    addCommandResult(stepCtx.results, { unit = firingUnitState.name, action = "move_to_firing_point" }, success,
      errorFields)
  end,
}

---Resupply unit steps keyed by Rules.STEP
---@type table<string, fun(stepCtx: SBJ__ResupplyUnitStepContext)>
local RESUPPLY_UNIT_STEPS = {
  [STEP.MOVE_TO_AMMO_HOLDING_AREA] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState
    local success, errorFields = Transitions.depart(resupplyUnitState,
      Movement.moveToAmmoHoldingArea(resupplyUnitState, stepCtx.resupplyUnit))
    addCommandResult(stepCtx.results, { unit = resupplyUnitState.name, action = "move_to_ammo_holding_area" }, success,
      errorFields)
  end,

  [STEP.ENSURE_RELOAD_CLOCK] = function(stepCtx)
    Transitions.ensureReloadClock(stepCtx.resupplyUnitState)
  end,

  [STEP.FAIL_AMMO_DEPOT_STATE_NOT_FOUND] = function(stepCtx)
    table.insert(stepCtx.results, {
      tag = "FAIL",
      fields = {
        unit = stepCtx.resupplyUnitState.name,
        action = "ammo_transload_finished",
        reason = "ammo_context_not_found"
      }
    })
  end,

  [STEP.COMPLETE_TRANSLOAD] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState
    local _, _, ammoDepotState = GroundStateStore.resolvePair(stepCtx.systemState, resupplyUnitState.name)
    ---@cast ammoDepotState SBJ__AmmunitionState
    local beforeResupply = resupplyUnitState.weaponCountCurrent
    local beforeDepot = ammoDepotState.weaponCountCurrent
    Ammo.transferAmmunition(resupplyUnitState, ammoDepotState)
    Transitions.finishReload(resupplyUnitState)
    table.insert(stepCtx.results, {
      tag = "OK",
      fields = {
        unit = resupplyUnitState.name,
        action = "ammo_transload_finished",
        transferred = resupplyUnitState.weaponCountCurrent - beforeResupply,
        depotBefore = beforeDepot,
        depotAfter = ammoDepotState.weaponCountCurrent
      }
    })
  end,

  [STEP.RECALL_TO_RELOAD_POINT] = function(stepCtx)
    local resupplyUnitState = stepCtx.resupplyUnitState
    local success, errorFields = Transitions.depart(resupplyUnitState,
      Movement.moveResupplyUnitToReloadPoint(resupplyUnitState, stepCtx.resupplyUnit))
    addCommandResult(stepCtx.results, { unit = resupplyUnitState.name, action = "move_resupply_to_reload_point" },
      success, errorFields)
  end,
}

---Run steps in order against their handlers
---@param steps string[]
---@generic T: SBJ__FiringUnitStepContext|SBJ__ResupplyUnitStepContext
---@param handlers table<string, fun(stepCtx: T)>
---@param stepCtx T
---@return SBJ__LogResult[] results Collected structured results
local function runSteps(steps, handlers, stepCtx)
  for _, step in ipairs(steps) do
    handlers[step](stepCtx)
  end
  return stepCtx.results
end

---Run one reload cycle step for a firing unit
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnit(systemState, runCtx, firingUnitState, firingUnit)
  local _, resupplyUnitState = GroundStateStore.resolvePair(systemState, firingUnitState.name)
  local resupplyUnit = resupplyUnitState and GameApi.ScenEdit_GetUnit(resupplyUnitState.name, firingUnit.side)
  local currentTime = GameApi.ScenEdit_CurrentTime()

  local steps = Rules.evaluateFiringUnitTick({
    state = firingUnitState.state,
    isAuto = runCtx.isAuto,
    isLowAmmo = Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID),
    stowElapsedSec = firingUnitState.stowStartTime and currentTime - firingUnitState.stowStartTime,
    stowTimeSec = runCtx.systemConfig.stowTime,
    reloadElapsedSec = calculateElapsedSec(firingUnitState.reloadStartTime, currentTime),
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    hasMet = (Meeting.hasMetResupplyUnit(systemState, firingUnit, runCtx.isAuto)),
    staysDeployed = Rules.staysDeployed(systemState.name),
    hasResupplyUnitState = resupplyUnitState ~= nil,
    hasResupplyUnit = resupplyUnit ~= nil,
  })

  return runSteps(steps, FIRING_UNIT_STEPS, {
    systemState = systemState,
    firingUnitState = firingUnitState,
    firingUnit = firingUnit,
    resupplyUnitState = resupplyUnitState,
    resupplyUnit = resupplyUnit,
    results = {}
  })
end

---Run one reload cycle step for a resupply unit
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnit(systemState, runCtx, resupplyUnitState, resupplyUnit)
  local _, _, ammoDepotState = GroundStateStore.resolvePair(systemState, resupplyUnitState.name)
  local steps = Rules.evaluateResupplyUnitTick({
    state = resupplyUnitState.state,
    isAuto = runCtx.isAuto,
    weaponCount = resupplyUnitState.weaponCountCurrent,
    isInOperationalArea = Meeting.findUnitArea(resupplyUnit, resupplyUnitState.operationalArea) ~= nil,
    reloadElapsedSec = calculateElapsedSec(resupplyUnitState.reloadStartTime, GameApi.ScenEdit_CurrentTime()),
    reloadTimeSec = runCtx.systemConfig.reloadTime,
    hasMet = (Meeting.hasMetAmmoDepot(systemState, resupplyUnit, runCtx.isAuto)),
    hasAmmoDepotState = ammoDepotState ~= nil,
  })

  return runSteps(steps, RESUPPLY_UNIT_STEPS, {
    systemState = systemState,
    resupplyUnitState = resupplyUnitState,
    resupplyUnit = resupplyUnit,
    results = {}
  })
end

---Process all firing units and collect structured results
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param sideName string
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnits(systemState, runCtx, sideName)
  local results = {}
  for _, firingUnitState in pairs(systemState.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitState.name, sideName)

    if firingUnit then
      Utils.addAll(results, processFiringUnit(systemState, runCtx, firingUnitState, firingUnit))
    end
  end
  return results
end

---Process all resupply units and collect structured results
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param sideName string
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnits(systemState, runCtx, sideName)
  local results = {}
  for _, resupplyUnitState in pairs(systemState.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitState.name, sideName)

    if resupplyUnit then
      Utils.addAll(results, processResupplyUnit(systemState, runCtx, resupplyUnitState, resupplyUnit))
    end
  end
  return results
end

---Process missile-system reload cycles and return structured results
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param sideName string
---@return SBJ__LogResult[] results Collected structured results
function Cycle.process(systemState, runCtx, sideName)
  local results = processFiringUnits(systemState, runCtx, sideName)
  Utils.addAll(results, processResupplyUnits(systemState, runCtx, sideName))
  return results
end

return Cycle
