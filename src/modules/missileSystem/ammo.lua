local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

local Ammo = {}

---Transfer ammunition from ammunition depot to resupply unit
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param ammoDepotState SBJ__AmmunitionState
function Ammo.transferAmmunition(resupplyUnitState, ammoDepotState)
  if ammoDepotState.weaponCountCurrent > 0 and resupplyUnitState.weaponCountCurrent < resupplyUnitState.weaponCountDefault then
    local deficit = resupplyUnitState.weaponCountDefault - resupplyUnitState.weaponCountCurrent
    local ammoToTransfer = math.min(deficit, ammoDepotState.weaponCountCurrent)
    resupplyUnitState.weaponCountCurrent = resupplyUnitState.weaponCountCurrent + ammoToTransfer
    ammoDepotState.weaponCountCurrent = ammoDepotState.weaponCountCurrent - ammoToTransfer
  end

  resupplyUnitState.state = constants.MISSILE_SYSTEM_STATE.STATIC
  resupplyUnitState.reloadStartTime = nil
end

---Reload ammunition for a single unit
---@param unit CMO__Unit|nil
---@param weaponDBID number|number[]
---@param resupplyUnitState SBJ__ResupplyUnitState
---@return integer # Total ammunition consumed
local function reloadUnit(unit, weaponDBID, resupplyUnitState)
  if not unit then return 0 end
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local totalLoaded = 0

  for _, dbid in ipairs(weaponDBIDs) do
    local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
    local required = wpnInfo.maxWeapons - wpnInfo.availableWeapons

    if required > 0 and resupplyUnitState.weaponCountCurrent > 0 then
      local ammoToLoad = math.min(required, resupplyUnitState.weaponCountCurrent)
      GameApi.ScenEdit_AddReloadsToUnit({ guid = unit.guid, side = unit.side, wpn_dbid = dbid, number = ammoToLoad })
      resupplyUnitState.weaponCountCurrent = resupplyUnitState.weaponCountCurrent - ammoToLoad
      totalLoaded = totalLoaded + ammoToLoad
    end
  end

  return totalLoaded
end

---Execute reload for firing unit
---@param firingUnitState SBJ__FiringUnitState
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param weaponDBID number|number[]
---@param sideName string
---@return integer # Total ammunition loaded
function Ammo.reloadFiringUnit(firingUnitState, resupplyUnitState, weaponDBID, sideName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitState.name, sideName)
  if not firingUnit then return 0 end
  local units = Shared.getGroupUnits(firingUnit)

  local totalLoaded = 0
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    totalLoaded = totalLoaded + reloadUnit(unit, weaponDBID, resupplyUnitState)
  end

  firingUnitState.state = constants.MISSILE_SYSTEM_STATE.STATIC
  firingUnitState.reloadStartTime = nil
  return totalLoaded
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit
---@param percentage number|nil
---@param weaponDBID number|number[]|nil
---@return boolean # Whether it is low ammunition
function Ammo.isLowAmmo(firingUnit, percentage, weaponDBID)
  if not percentage or not weaponDBID then
    return false
  end

  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local totalCurrent = 0
  local totalMax = 0

  local units = Shared.getGroupUnits(firingUnit)
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      for _, dbid in ipairs(weaponDBIDs) do
        local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
        totalCurrent = totalCurrent + wpnInfo.availableWeapons
        totalMax = totalMax + wpnInfo.maxWeapons
      end
    end
  end

  if totalMax == 0 then return false end
  return (totalCurrent / totalMax * 100) <= percentage
end

---Compute usage percentage rounded to integer; returns 0 when max is 0 to avoid divide-by-zero
---@param current number
---@param max number
---@return integer # Percentage in 0-100 range, rounded to nearest integer
local function calculatePercentage(current, max)
  if max == 0 then return 0 end
  return math.floor(current / max * 100 + 0.5)
end

---Sum ammunition across all firing units of a missile system by querying live game state
---@param firingUnitMap table<string, SBJ__FiringUnitState>
---@param sideName string
---@return SBJ__AmmoSubtotalEntry # Subtotal with current/max/percentage
local function countFiringUnits(firingUnitMap, sideName)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for _, firingState in pairs(firingUnitMap) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingState.name, sideName)
    if firingUnit then
      local weaponDBIDs = Shared.normalizeWeaponDBIDs(firingState.weaponDBID)
      local units = Shared.getGroupUnits(firingUnit)
      for _, guid in ipairs(units) do
        local unit = GameApi.ScenEdit_GetUnit(guid)
        if unit then
          for _, dbid in ipairs(weaponDBIDs) do
            local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
            subtotal.current = subtotal.current + wpnInfo.availableWeapons
            subtotal.max = subtotal.max + wpnInfo.maxWeapons
          end
        end
      end
    end
  end

  subtotal.percentage = calculatePercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Sum ammunition across state-tracked units (resupply trucks or ammo depots)
---@param stateMap table<string, SBJ__ResupplyUnitState|SBJ__AmmunitionState>
---@return SBJ__AmmoSubtotalEntry # Subtotal with current/max/percentage
local function countStateUnits(stateMap)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for _, ctx in pairs(stateMap) do
    subtotal.current = subtotal.current + ctx.weaponCountCurrent
    subtotal.max = subtotal.max + ctx.weaponCountDefault
  end

  subtotal.percentage = calculatePercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Calculate ammunition inventory across firing units, resupply units, and ammo depots
---@param systemState SBJ__MissileSystemState
---@param sideName string
---@return SBJ__AmmoInventoryResult # Inventory report with subtotals and percentages
function Ammo.getInventory(systemState, sideName)
  local firing = countFiringUnits(systemState.firingUnits, sideName)
  local resupply = countStateUnits(systemState.resupplyUnits)
  local ammo = countStateUnits(systemState.ammunitions)

  local total = {
    current = firing.current + resupply.current + ammo.current,
    max = firing.max + resupply.max + ammo.max,
    percentage = 0,
  }
  total.percentage = calculatePercentage(total.current, total.max)

  return {
    firing = firing,
    resupply = resupply,
    ammo = ammo,
    total = total,
  }
end

return Ammo
