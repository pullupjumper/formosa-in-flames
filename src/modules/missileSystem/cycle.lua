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
---@param success boolean Whether the command succeeded
---@param errorFields table<string, any>|nil Log fields describing the failure
---@param unitName string Unit name
---@param action string Snake_case action token
local function appendCommandResult(results, success, errorFields, unitName, action)
  if success then
    table.insert(results, { tag = "OK", fields = { unit = unitName, action = action } })
    return
  end

  table.insert(results, { tag = "FAIL", fields = LogFormat.merge({ unit = unitName, action = action }, errorFields) })
end

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param hasMet boolean Whether firing unit has met with resupply unit
---@param firingUnit CMO__Unit Firing unit group
---@param weaponDBID number|number[] Weapon database ID(s)
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, hasMet, firingUnit, weaponDBID)
  if firingUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and hasMet and
      Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param hasMet boolean Whether resupply unit has met with ammunition depot
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, hasMet)
  if resupplyUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and resupplyUnitCtx.wpnCurrent == 0 and hasMet
end

---Trigger reload movement when firing unit is static and low on ammo (auto mode only)
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
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
  if elapsedTime < systemCtx.stowTime then
    return results
  end

  -- Stow complete: sufficient ammo -> hide area; low -> reload point
  if not isLowAmmo then
    local success, errorFields = Movement.moveToHideArea(firingUnitCtx, firingUnit)
    appendCommandResult(results, success, errorFields, firingUnitCtx.name, "move_to_hide_area")
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
      appendCommandResult(results, success, errorFields, resupplyUnitCtx.name, "move_resupply_to_reload_point")
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
  appendCommandResult(results, success, errorFields, firingUnitCtx.name, "move_firing_unit_to_reload_point")
  firingUnitCtx.stowStartTime = nil
  return results
end

---Complete firing unit reload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto)
  local results = {}

  if firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if firingUnitCtx.reloadStartTime == nil then
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetResupplyUnit(systemCtx, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, hasMet, firingUnit,
    firingUnitCtx.weaponDBID)

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
      appendCommandResult(results, success, errorFields, firingUnitCtx.name, "move_to_firing_point")
    else
      success, errorFields = Movement.moveToHideArea(firingUnitCtx, firingUnit)
      appendCommandResult(results, success, errorFields, firingUnitCtx.name, "move_to_hide_area")
    end
  end

  return results
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
  local results = triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  Utils.insertList(results, completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto))
  return results
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  local results = {}

  if not isAuto or resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  if resupplyUnitCtx.wpnCurrent == 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
    local success, errorFields = Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
    appendCommandResult(results, success, errorFields, resupplyUnitCtx.name, "move_to_ammo_holding_area")
  end

  return results
end

---Complete resupply unit transload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  local results = {}

  if resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return results
  end

  if resupplyUnitCtx.reloadStartTime == nil then
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetAmmoDepot(systemCtx, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, hasMet)

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
    appendCommandResult(results, success, errorFields, resupplyUnitCtx.name, "move_resupply_to_reload_point")
  end

  return results
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__LogResult[] results Collected structured results
local function handleResupplyUnitReloadCycle(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  local results = triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  Utils.insertList(results, completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto))
  return results
end

---Process all firing units and collect structured results
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
local function processFiringUnits(systemCtx, isAuto, sideName)
  local results = {}
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      Utils.insertList(results, handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto))
    end
  end
  return results
end

---Process all resupply units and collect structured results
---@param msContext SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
local function processResupplyUnits(msContext, isAuto, sideName)
  local results = {}
  for _, resupplyUnitCtx in pairs(msContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      Utils.insertList(results, handleResupplyUnitReloadCycle(msContext, resupplyUnitCtx, resupplyUnit, isAuto))
    end
  end
  return results
end

---Process missile-system reload cycles and return structured results
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__LogResult[] results Collected structured results
function Cycle.process(systemCtx, isAuto, sideName)
  local results = processFiringUnits(systemCtx, isAuto, sideName)
  Utils.insertList(results, processResupplyUnits(systemCtx, isAuto, sideName))
  return results
end

return Cycle
