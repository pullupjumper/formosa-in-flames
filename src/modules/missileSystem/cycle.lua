local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")

local Cycle = {}

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

  table.insert(results, { tag = "FAIL", fields = LogFormat.merge({ unit = params.unit, action = params.action }, errorDetail) })
end

---Check if firing unit reload conditions are met
---@param firingUnitState SBJ__FiringUnitState
---@param systemConfig SBJ__MissileSystemConfig
---@param hasMet boolean
---@param firingUnit CMO__Unit
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitState, systemConfig, hasMet, firingUnit)
  if firingUnitState.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitState.reloadStartTime
  return elapsedTime >= systemConfig.reloadTime and hasMet and
      Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param systemConfig SBJ__MissileSystemConfig
---@param hasMet boolean
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitState, systemConfig, hasMet)
  if resupplyUnitState.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitState.reloadStartTime
  return elapsedTime >= systemConfig.reloadTime and resupplyUnitState.weaponCountCurrent == 0 and hasMet
end

---Trigger reload movement when firing unit is static and low on ammo (auto mode only)
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function startReloadMovement(systemState, runCtx, firingUnitState, firingUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if not isAuto or firingUnitState.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  local isLowAmmo = Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)

  -- A unit only needs to redeploy if it was just fired (FSP) or its ammo dropped low
  if not firingUnitState.stowStartTime and not isLowAmmo then
    return results
  end

  -- Begin the stow countdown the first cycle we detect a redeploy trigger
  if not firingUnitState.stowStartTime then
    firingUnitState.stowStartTime = GameApi.ScenEdit_CurrentTime()
    table.insert(results, {
      tag = "OK",
      fields = {
        unit = firingUnitState.name,
        action = "stow_countdown_started",
        startedAt = firingUnitState.stowStartTime
      }
    })
    return results
  end

  -- Wait until the stow window has fully elapsed before moving
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitState.stowStartTime
  if elapsedTime < systemConfig.stowTime then
    return results
  end

  -- Stow complete: sufficient ammo -> hide area; low -> reload point
  if not isLowAmmo then
    local success, errorFields = Movement.moveToHideArea(firingUnitState, firingUnit)
    addCommandResult(results, { unit = firingUnitState.name, action = "move_to_hide_area" }, success, errorFields)
    firingUnitState.stowStartTime = nil
    return results
  end

  local resupplyUnitState = systemState.resupplyUnits[firingUnitState.resupplyUnit]
  if resupplyUnitState then
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitState.name, firingUnit.side)

    if resupplyUnit then
      local unloadSuccess, unloadFields = Concealment.moveFromHideArea(resupplyUnitState, resupplyUnit)
      if not unloadSuccess then
        table.insert(results, {
          tag = "WARN",
          fields = LogFormat.merge({
            unit = resupplyUnitState.name,
            action = "unload_from_hide_area"
          }, unloadFields)
        })
      end

      local success, errorFields = Movement.moveToReloadPoint(
        resupplyUnitState,
        resupplyUnit,
        resupplyUnitState.operationalArea.SHRL
      )
      addCommandResult(results, { unit = resupplyUnitState.name, action = "move_resupply_to_reload_point" }, success, errorFields)
    else
      table.insert(results, {
        tag = "WARN",
        fields = {
          unit = resupplyUnitState.name,
          action = "move_resupply_to_reload_point",
          reason = "unit_not_found"
        }
      })
    end
  else
    table.insert(results, {
      tag = "WARN",
      fields = {
        unit = firingUnitState.resupplyUnit or "unknown",
        action = "move_resupply_to_reload_point",
        reason = "context_not_found"
      }
    })
  end

  local success, errorFields = Movement.moveToReloadPoint(firingUnitState, firingUnit)
  addCommandResult(results, { unit = firingUnitState.name, action = "move_firing_unit_to_reload_point" }, success, errorFields)
  firingUnitState.stowStartTime = nil
  return results
end

---Complete firing unit reload when conditions are met
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function completeFiringUnitReload(systemState, runCtx, firingUnitState, firingUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if firingUnitState.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if firingUnitState.reloadStartTime == nil then
    firingUnitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetResupplyUnit(systemState, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(firingUnitState, systemConfig, hasMet, firingUnit)

  if not isReadyToReload then
    return results
  end

  local resupplyUnitState = systemState.resupplyUnits[firingUnitState.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitState.name, firingUnit.side)
  local loaded = Ammo.reloadFiringUnit(firingUnitState, resupplyUnitState, firingUnitState.weaponDBID, firingUnit.side)
  table.insert(results, {
    tag = "OK",
    fields = {
      unit = firingUnitState.name,
      action = "missile_reload_finished",
      loaded = loaded
    }
  })

  if isAuto then
    if resupplyUnit and resupplyUnitState.weaponCountCurrent > 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitState.operationalArea) then
      local hideSuccess, hideFields = Concealment.hideUnit(resupplyUnitState, resupplyUnit)
      if not hideSuccess then
        table.insert(results, {
          tag = "WARN",
          fields = LogFormat.merge({
            unit = resupplyUnitState.name,
            action = "hide_resupply_unit"
          }, hideFields)
        })
      end
    end

    local success, errorFields
    if systemState.name == constants.MISSILE_SYSTEM_TYPES.SAM then
      success, errorFields = Movement.moveToFiringPoint(firingUnitState, firingUnit)
      addCommandResult(results, { unit = firingUnitState.name, action = "move_to_firing_point" }, success, errorFields)
    else
      success, errorFields = Movement.moveToHideArea(firingUnitState, firingUnit)
      addCommandResult(results, { unit = firingUnitState.name, action = "move_to_hide_area" }, success, errorFields)
    end
  end

  return results
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnitReloadCycle(systemState, runCtx, firingUnitState, firingUnit)
  local results = startReloadMovement(systemState, runCtx, firingUnitState, firingUnit)
  Utils.addAll(results, completeFiringUnitReload(systemState, runCtx, firingUnitState, firingUnit))
  return results
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@param runCtx SBJ__CycleRunContext
---@return SBJ__LogResult[] results Collected structured results
local function startResupplyMovement(resupplyUnitState, resupplyUnit, runCtx)
  local results = {}

  if not runCtx.isAuto or resupplyUnitState.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  if resupplyUnitState.weaponCountCurrent == 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitState.operationalArea) then
    local success, errorFields = Movement.moveToAmmoHoldingArea(resupplyUnitState, resupplyUnit)
    addCommandResult(results, { unit = resupplyUnitState.name, action = "move_to_ammo_holding_area" }, success, errorFields)
  end

  return results
end

---Complete resupply unit transload when conditions are met
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function completeResupplyUnitTransload(systemState, runCtx, resupplyUnitState, resupplyUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if resupplyUnitState.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if resupplyUnitState.reloadStartTime == nil then
    resupplyUnitState.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetAmmoDepot(systemState, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitState, systemConfig, hasMet)

  if not isReadyToReload then
    return results
  end

  local ammoDepotState = systemState.ammunitions[resupplyUnitState.ammunition]
  if not ammoDepotState then
    table.insert(results, {
      tag = "FAIL",
      fields = {
        unit = resupplyUnitState.name,
        action = "ammo_transload_finished",
        reason = "ammo_context_not_found"
      }
    })
    return results
  end

  local beforeResupply = resupplyUnitState.weaponCountCurrent
  local beforeDepot = ammoDepotState.weaponCountCurrent
  Ammo.transferAmmunition(resupplyUnitState, ammoDepotState)
  local transferred = resupplyUnitState.weaponCountCurrent - beforeResupply
  table.insert(results, {
    tag = "OK",
    fields = {
      unit = resupplyUnitState.name,
      action = "ammo_transload_finished",
      transferred = transferred,
      depotBefore = beforeDepot,
      depotAfter = ammoDepotState.weaponCountCurrent
    }
  })

  if isAuto then
    local success, errorFields = Movement.moveResupplyUnitToReloadPoint(resupplyUnitState, resupplyUnit)
    addCommandResult(results, { unit = resupplyUnitState.name, action = "move_resupply_to_reload_point" }, success, errorFields)
  end

  return results
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemState SBJ__MissileSystemState
---@param runCtx SBJ__CycleRunContext
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnitReloadCycle(systemState, runCtx, resupplyUnitState, resupplyUnit)
  local results = startResupplyMovement(resupplyUnitState, resupplyUnit, runCtx)
  Utils.addAll(results, completeResupplyUnitTransload(systemState, runCtx, resupplyUnitState, resupplyUnit))
  return results
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
      Utils.addAll(results, processFiringUnitReloadCycle(systemState, runCtx, firingUnitState, firingUnit))
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
      Utils.addAll(results, processResupplyUnitReloadCycle(systemState, runCtx, resupplyUnitState, resupplyUnit))
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
