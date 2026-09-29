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
---@param results SBJ__LogResult[] Result list to append to
---@param params {unit: string, action: string} Unit name and snake_case action token
---@param success boolean Whether the command succeeded
---@param errorFields table<string, any>|nil Log fields describing the failure
local function addCommandResult(results, params, success, errorFields)
  if success then
    table.insert(results, { tag = "OK", fields = { unit = params.unit, action = params.action } })
    return
  end

  table.insert(results, { tag = "FAIL", fields = LogFormat.merge({ unit = params.unit, action = params.action }, errorFields) })
end

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param systemConfig SBJ__MissileSystemConfig Missile system configuration (reload/stow timers)
---@param hasMet boolean Whether firing unit has met with resupply unit
---@param firingUnit CMO__Unit Firing unit group
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, systemConfig, hasMet, firingUnit)
  if firingUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime
  return elapsedTime >= systemConfig.reloadTime and hasMet and
      Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param systemConfig SBJ__MissileSystemConfig Missile system configuration (reload/stow timers)
---@param hasMet boolean Whether resupply unit has met with ammunition depot
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, systemConfig, hasMet)
  if resupplyUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime
  return elapsedTime >= systemConfig.reloadTime and resupplyUnitCtx.wpnCurrent == 0 and hasMet
end

---Trigger reload movement when firing unit is static and low on ammo (auto mode only)
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return SBJ__LogResult[] results Collected structured results
local function startReloadMovement(systemCtx, runCtx, firingUnitCtx, firingUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if not isAuto or firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  local isLowAmmo = Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)

  -- A unit only needs to redeploy if it was just fired (FSP) or its ammo dropped low
  if not firingUnitCtx.stowStartTime and not isLowAmmo then
    return results
  end

  -- Begin the stow countdown the first cycle we detect a redeploy trigger
  if not firingUnitCtx.stowStartTime then
    firingUnitCtx.stowStartTime = GameApi.ScenEdit_CurrentTime()
    table.insert(results, {
      tag = "OK",
      fields = {
        unit = firingUnitCtx.name,
        action = "stow_countdown_started",
        startedAt = firingUnitCtx.stowStartTime
      }
    })
    return results
  end

  -- Wait until the stow window has fully elapsed before moving
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.stowStartTime
  if elapsedTime < systemConfig.stowTime then
    return results
  end

  -- Stow complete: sufficient ammo -> hide area; low -> reload point
  if not isLowAmmo then
    local success, errorFields = Movement.moveToHideArea(firingUnitCtx, firingUnit)
    addCommandResult(results, { unit = firingUnitCtx.name, action = "move_to_hide_area" }, success, errorFields)
    firingUnitCtx.stowStartTime = nil
    return results
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  if resupplyUnitCtx then
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)

    if resupplyUnit then
      local unloadSuccess, unloadFields = Concealment.moveFromHideArea(resupplyUnitCtx, resupplyUnit)
      if not unloadSuccess then
        table.insert(results, {
          tag = "WARN",
          fields = LogFormat.merge({
            unit = resupplyUnitCtx.name,
            action = "unload_from_hide_area"
          }, unloadFields)
        })
      end

      local success, errorFields = Movement.moveToReloadPoint(
        resupplyUnitCtx,
        resupplyUnit,
        resupplyUnitCtx.operationalArea.SHRL
      )
      addCommandResult(results, { unit = resupplyUnitCtx.name, action = "move_resupply_to_reload_point" }, success, errorFields)
    else
      table.insert(results, {
        tag = "WARN",
        fields = {
          unit = resupplyUnitCtx.name,
          action = "move_resupply_to_reload_point",
          reason = "unit_not_found"
        }
      })
    end
  else
    table.insert(results, {
      tag = "WARN",
      fields = {
        unit = firingUnitCtx.resupplyUnit or "unknown",
        action = "move_resupply_to_reload_point",
        reason = "context_not_found"
      }
    })
  end

  local success, errorFields = Movement.moveToReloadPoint(firingUnitCtx, firingUnit)
  addCommandResult(results, { unit = firingUnitCtx.name, action = "move_firing_unit_to_reload_point" }, success, errorFields)
  firingUnitCtx.stowStartTime = nil
  return results
end

---Complete firing unit reload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return SBJ__LogResult[] results Collected structured results
local function completeFiringUnitReload(systemCtx, runCtx, firingUnitCtx, firingUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if firingUnitCtx.reloadStartTime == nil then
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetResupplyUnit(systemCtx, firingUnit, runCtx)
  local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, systemConfig, hasMet, firingUnit)

  if not isReadyToReload then
    return results
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)
  local loaded = Ammo.reloadFiringUnit(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, firingUnit.side)
  table.insert(results, {
    tag = "OK",
    fields = {
      unit = firingUnitCtx.name,
      action = "missile_reload_finished",
      loaded = loaded
    }
  })

  if isAuto then
    if resupplyUnit and resupplyUnitCtx.wpnCurrent > 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
      local hideSuccess, hideFields = Concealment.hideUnit(resupplyUnitCtx, resupplyUnit)
      if not hideSuccess then
        table.insert(results, {
          tag = "WARN",
          fields = LogFormat.merge({
            unit = resupplyUnitCtx.name,
            action = "hide_resupply_unit"
          }, hideFields)
        })
      end
    end

    local success, errorFields
    if systemCtx.name == constants.MISSILE_SYSTEM_TYPES.SAM then
      success, errorFields = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
      addCommandResult(results, { unit = firingUnitCtx.name, action = "move_to_firing_point" }, success, errorFields)
    else
      success, errorFields = Movement.moveToHideArea(firingUnitCtx, firingUnit)
      addCommandResult(results, { unit = firingUnitCtx.name, action = "move_to_hide_area" }, success, errorFields)
    end
  end

  return results
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnitReloadCycle(systemCtx, runCtx, firingUnitCtx, firingUnit)
  local results = startReloadMovement(systemCtx, runCtx, firingUnitCtx, firingUnit)
  Utils.addAll(results, completeFiringUnitReload(systemCtx, runCtx, firingUnitCtx, firingUnit))
  return results
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@return SBJ__LogResult[] results Collected structured results
local function startResupplyMovement(resupplyUnitCtx, resupplyUnit, runCtx)
  local results = {}

  if not runCtx.isAuto or resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  if resupplyUnitCtx.wpnCurrent == 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
    local success, errorFields = Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
    addCommandResult(results, { unit = resupplyUnitCtx.name, action = "move_to_ammo_holding_area" }, success, errorFields)
  end

  return results
end

---Complete resupply unit transload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return SBJ__LogResult[] results Collected structured results
local function completeResupplyUnitTransload(systemCtx, runCtx, resupplyUnitCtx, resupplyUnit)
  local systemConfig, isAuto = runCtx.systemConfig, runCtx.isAuto
  local results = {}

  if resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if resupplyUnitCtx.reloadStartTime == nil then
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetAmmoDepot(systemCtx, resupplyUnit, runCtx)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemConfig, hasMet)

  if not isReadyToReload then
    return results
  end

  local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]
  if not ammoDepotCtx then
    table.insert(results, {
      tag = "FAIL",
      fields = {
        unit = resupplyUnitCtx.name,
        action = "ammo_transload_finished",
        reason = "ammo_context_not_found"
      }
    })
    return results
  end

  local beforeResupply = resupplyUnitCtx.wpnCurrent
  local beforeDepot = ammoDepotCtx.wpnCurrent
  Ammo.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
  local transferred = resupplyUnitCtx.wpnCurrent - beforeResupply
  table.insert(results, {
    tag = "OK",
    fields = {
      unit = resupplyUnitCtx.name,
      action = "ammo_transload_finished",
      transferred = transferred,
      depotBefore = beforeDepot,
      depotAfter = ammoDepotCtx.wpnCurrent
    }
  })

  if isAuto then
    local success, errorFields = Movement.moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
    addCommandResult(results, { unit = resupplyUnitCtx.name, action = "move_resupply_to_reload_point" }, success, errorFields)
  end

  return results
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnitReloadCycle(systemCtx, runCtx, resupplyUnitCtx, resupplyUnit)
  local results = startResupplyMovement(resupplyUnitCtx, resupplyUnit, runCtx)
  Utils.addAll(results, completeResupplyUnitTransload(systemCtx, runCtx, resupplyUnitCtx, resupplyUnit))
  return results
end

---Process all firing units and collect structured results
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnits(systemCtx, runCtx, sideName)
  local results = {}
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      Utils.addAll(results, processFiringUnitReloadCycle(systemCtx, runCtx, firingUnitCtx, firingUnit))
    end
  end
  return results
end

---Process all resupply units and collect structured results
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnits(systemCtx, runCtx, sideName)
  local results = {}
  for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      Utils.addAll(results, processResupplyUnitReloadCycle(systemCtx, runCtx, resupplyUnitCtx, resupplyUnit))
    end
  end
  return results
end

---Process missile-system reload cycles and return structured results
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param runCtx SBJ__CycleRunContext Per-run settings shared by every unit in this cycle
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
function Cycle.process(systemCtx, runCtx, sideName)
  local results = processFiringUnits(systemCtx, runCtx, sideName)
  Utils.addAll(results, processResupplyUnits(systemCtx, runCtx, sideName))
  return results
end

return Cycle
