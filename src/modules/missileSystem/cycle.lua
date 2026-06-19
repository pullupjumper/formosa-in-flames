local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")

local Cycle = {}

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
local function triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  if not isAuto or firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return
  end

  local isLowAmmo = Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)

  -- A unit only needs to redeploy if it was just fired (FSP) or its ammo dropped low
  if not firingUnitCtx.stowStartTime and not isLowAmmo then
    return
  end

  -- Begin the stow countdown the first cycle we detect a redeploy trigger
  if not firingUnitCtx.stowStartTime then
    firingUnitCtx.stowStartTime = GameApi.ScenEdit_CurrentTime()
    return
  end

  -- Wait until the stow window has fully elapsed before moving
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.stowStartTime
  if elapsedTime < systemCtx.stowTime then
    return
  end

  -- Stow complete: sufficient ammo -> hide area; low -> reload point
  if not isLowAmmo then
    Movement.moveToHideArea(firingUnitCtx, firingUnit)
    firingUnitCtx.stowStartTime = nil
    return
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)

  if resupplyUnit then
    Concealment.moveFromHideArea(resupplyUnitCtx, resupplyUnit)
    Movement.moveToReloadPoint(resupplyUnitCtx, resupplyUnit, resupplyUnitCtx.operationalArea.SHRL)
  end

  Movement.moveToReloadPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.stowStartTime = nil
end

---Complete firing unit reload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if reload was completed
local function completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto)
  if firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return nil
  end

  if firingUnitCtx.reloadStartTime == nil then
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetResupplyUnit(systemCtx, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(
    firingUnitCtx, systemCtx, hasMet, firingUnit, firingUnitCtx.weaponDBID)

  if not isReadyToReload then
    return nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)
  Ammo.reloadFiringUnit(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, firingUnit.side)

  if isAuto then
    if resupplyUnit and resupplyUnitCtx.wpnCurrent > 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
      Concealment.hideUnit(resupplyUnitCtx, resupplyUnit)
    end

    if systemCtx.name == constants.MISSILE_SYSTEM_TYPES.SAM then
      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
    else
      Movement.moveToHideArea(firingUnitCtx, firingUnit)
    end
  end

  return { tag = "OK", unitName = firingUnitCtx.name, action = "Missile reload finished" }
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if action was taken
local function handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
  triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  return completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto)
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  if not isAuto or resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return
  end

  if resupplyUnitCtx.wpnCurrent == 0 and Meeting.findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
    Movement.moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  end
end

---Complete resupply unit transload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if transload was completed
local function completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return nil
  end

  if resupplyUnitCtx.reloadStartTime == nil then
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = Meeting.hasMetAmmoDepot(systemCtx, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, hasMet)

  if not isReadyToReload then
    return nil
  end

  local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]
  Ammo.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

  if isAuto then
    Movement.moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  end

  return { tag = "OK", unitName = resupplyUnitCtx.name, action = "Ammo transload finished" }
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if action was taken
local function handleResupplyUnitReloadCycle(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  return completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
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
      local result = handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
      if result then table.insert(results, result) end
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
      local result = handleResupplyUnitReloadCycle(msContext, resupplyUnitCtx, resupplyUnit, isAuto)
      if result then table.insert(results, result) end
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
