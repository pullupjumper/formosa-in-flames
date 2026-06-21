local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")

local Cycle = {}

---Format free-text detail for log output
---@param value any Value to format
---@return string # Quoted detail field
local function detailField(value)
  if value == nil then
    return "detail=\"unknown\""
  end

  return string.format("detail=%q", tostring(value))
end

---Build a structured reload cycle result
---@param tag string Result tag
---@param unitName string Unit name
---@param action string Action description
---@param reason? string Optional reason for non-OK outcomes
---@param detail? string Optional key=value detail fields
---@return SBJ__ReloadCycleResult # Structured result
local function buildResult(tag, unitName, action, reason, detail)
  return {
    tag = tag,
    unitName = unitName,
    action = action,
    reason = reason,
    detail = detail
  }
end

---Append all source results into destination result list
---@param destination SBJ__ReloadCycleResult[] Destination result list
---@param source SBJ__ReloadCycleResult[]|nil Source result list
local function appendResults(destination, source)
  if not source then return end

  for _, result in ipairs(source) do
    table.insert(destination, result)
  end
end

---Append a movement command result
---@param results SBJ__ReloadCycleResult[] Result list to append to
---@param success boolean Whether the command succeeded
---@param errorMsg string|nil Error message when command failed
---@param unitName string Unit name
---@param action string Action description
local function appendCommandResult(results, success, errorMsg, unitName, action)
  if success then
    table.insert(results, buildResult("OK", unitName, action))
    return
  end

  table.insert(results, buildResult(
    "FAIL",
    unitName,
    action,
    "command_failed",
    errorMsg and detailField(errorMsg) or nil
  ))
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
---@return SBJ__ReloadCycleResult[] results Collected structured results
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
    table.insert(results, buildResult(
      "OK", firingUnitCtx.name, "Stow countdown started",
      nil, string.format("startedAt=%d", firingUnitCtx.stowStartTime)
    ))
    return results
  end

  -- Wait until the stow window has fully elapsed before moving
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.stowStartTime
  if elapsedTime < systemCtx.stowTime then
    return results
  end

  -- Stow complete: sufficient ammo -> hide area; low -> reload point
  if not isLowAmmo then
    local success, errorMsg = Movement.moveToHideArea(firingUnitCtx, firingUnit)
    appendCommandResult(results, success, errorMsg, firingUnitCtx.name, "Move to hide area")
    firingUnitCtx.stowStartTime = nil
    return results
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  if resupplyUnitCtx then
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)

    if resupplyUnit then
      local unloadSuccess, unloadMsg = Concealment.moveFromHideArea(resupplyUnitCtx, resupplyUnit)
      if not unloadSuccess then
        table.insert(results, buildResult(
          "WARN",
          resupplyUnitCtx.name,
          "Unload from hide area",
          "unload_failed",
          unloadMsg and detailField(unloadMsg) or nil
        ))
      end

      local success, errorMsg = Movement.moveToReloadPoint(
        resupplyUnitCtx,
        resupplyUnit,
        resupplyUnitCtx.operationalArea.SHRL
      )
      appendCommandResult(results, success, errorMsg, resupplyUnitCtx.name, "Move resupply to reload point")
    else
      table.insert(results, buildResult(
        "WARN", resupplyUnitCtx.name, "Move resupply to reload point", "unit_not_found"
      ))
    end
  else
    table.insert(results, buildResult(
      "WARN", firingUnitCtx.resupplyUnit or "unknown", "Move resupply to reload point", "context_not_found"
    ))
  end

  local success, errorMsg = Movement.moveToReloadPoint(firingUnitCtx, firingUnit)
  appendCommandResult(results, success, errorMsg, firingUnitCtx.name, "Move firing unit to reload point")
  firingUnitCtx.stowStartTime = nil
  return results
end

---Complete firing unit reload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult[] results Collected structured results
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
  table.insert(results, buildResult(
    "OK",
    firingUnitCtx.name,
    "Missile reload finished",
    nil,
    string.format("loaded=%d", loaded)
  ))

  if isAuto then
    if resupplyUnit and resupplyUnitCtx.wpnCurrent > 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
      local hideSuccess, hideMsg = Concealment.hideUnit(resupplyUnitCtx, resupplyUnit)
      if not hideSuccess then
        table.insert(results, buildResult(
          "WARN",
          resupplyUnitCtx.name,
          "Hide resupply unit",
          "hide_failed",
          hideMsg and detailField(hideMsg) or nil
        ))
      end
    end

    local success, errorMsg
    if systemCtx.name == constants.MISSILE_SYSTEM_TYPES.SAM then
      success, errorMsg = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
      appendCommandResult(results, success, errorMsg, firingUnitCtx.name, "Move to firing point")
    else
      success, errorMsg = Movement.moveToHideArea(firingUnitCtx, firingUnit)
      appendCommandResult(results, success, errorMsg, firingUnitCtx.name, "Move to hide area")
    end
  end

  return results
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
  local results = triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  appendResults(results, completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto))
  return results
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  local results = {}

  if not isAuto or resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return results
  end

  if resupplyUnitCtx.wpnCurrent == 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
    local success, errorMsg = Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
    appendCommandResult(results, success, errorMsg, resupplyUnitCtx.name, "Move to ammo holding area")
  end

  return results
end

---Complete resupply unit transload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult[] results Collected structured results
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
    table.insert(results, buildResult(
      "FAIL", resupplyUnitCtx.name, "Ammo transload finished", "ammo_context_not_found"
    ))
    return results
  end

  local beforeResupply = resupplyUnitCtx.wpnCurrent
  local beforeDepot = ammoDepotCtx.wpnCurrent
  Ammo.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
  local transferred = resupplyUnitCtx.wpnCurrent - beforeResupply
  table.insert(results, buildResult(
    "OK", resupplyUnitCtx.name, "Ammo transload finished", nil,
    string.format("transferred=%d depotBefore=%d depotAfter=%d", transferred, beforeDepot, ammoDepotCtx.wpnCurrent)
  ))

  if isAuto then
    local success, errorMsg = Movement.moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
    appendCommandResult(results, success, errorMsg, resupplyUnitCtx.name, "Move resupply to reload point")
  end

  return results
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function handleResupplyUnitReloadCycle(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  local results = triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  appendResults(results, completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto))
  return results
end

---Process all firing units and collect structured results
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function processFiringUnits(systemCtx, isAuto, sideName)
  local results = {}
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      appendResults(results, handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto))
    end
  end
  return results
end

---Process all resupply units and collect structured results
---@param msContext SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function processResupplyUnits(msContext, isAuto, sideName)
  local results = {}
  for _, resupplyUnitCtx in pairs(msContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      appendResults(results, handleResupplyUnitReloadCycle(msContext, resupplyUnitCtx, resupplyUnit, isAuto))
    end
  end
  return results
end

---Process missile-system reload cycles and return structured results
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__ReloadCycleResult[] results Collected structured results
function Cycle.process(systemCtx, isAuto, sideName)
  local firingResults = processFiringUnits(systemCtx, isAuto, sideName)
  local resupplyResults = processResupplyUnits(systemCtx, isAuto, sideName)

  local allResults = {}
  for _, r in ipairs(firingResults) do table.insert(allResults, r) end
  for _, r in ipairs(resupplyResults) do table.insert(allResults, r) end
  return allResults
end

return Cycle
