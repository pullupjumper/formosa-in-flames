local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
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
end

---Build the reloads a firing unit's group needs, filling each unit and weapon in order until the stock runs out
---Reads CMO only, so the plan can be decided on before any reload is written.
---@param firingUnit CMO__Unit
---@param weaponDBID number|number[]
---@param stock integer Missiles the resupply unit carries
---@return SBJ__ReloadPlan
function Ammo.buildReload(firingUnit, weaponDBID, stock)
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local plan = { entries = {}, count = 0 }

  for _, guid in ipairs(Shared.getGroupUnits(firingUnit)) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      for _, dbid in ipairs(weaponDBIDs) do
        local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
        local required = wpnInfo.maxWeapons - wpnInfo.availableWeapons
        local remaining = stock - plan.count

        if required > 0 and remaining > 0 then
          local number = math.min(required, remaining)
          table.insert(plan.entries, { guid = unit.guid, side = unit.side, weaponDBID = dbid, number = number })
          plan.count = plan.count + number
        end
      end
    end
  end

  return plan
end

---Load a reload plan into the firing unit's group and take the missiles from the resupply unit
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param plan SBJ__ReloadPlan From Ammo.buildReload with this resupply unit's stock
---@return integer # Total ammunition loaded
function Ammo.reloadFiringUnit(resupplyUnitState, plan)
  for _, entry in ipairs(plan.entries) do
    GameApi.ScenEdit_AddReloadsToUnit({ guid = entry.guid, side = entry.side, wpn_dbid = entry.weaponDBID, number = entry.number })
  end

  resupplyUnitState.weaponCountCurrent = resupplyUnitState.weaponCountCurrent - plan.count
  return plan.count
end

---Sum loaded and maximum weapons across every unit of a firing unit's group
---@param firingUnit CMO__Unit
---@param weaponDBID number|number[]
---@return integer current Weapons loaded
---@return integer max Weapon capacity
local function tallyWeapons(firingUnit, weaponDBID)
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local current, max = 0, 0

  for _, guid in ipairs(Shared.getGroupUnits(firingUnit)) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      for _, dbid in ipairs(weaponDBIDs) do
        local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
        current = current + wpnInfo.availableWeapons
        max = max + wpnInfo.maxWeapons
      end
    end
  end

  return current, max
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

  local totalCurrent, totalMax = tallyWeapons(firingUnit, weaponDBID)
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
      local current, max = tallyWeapons(firingUnit, firingState.weaponDBID)
      subtotal.current = subtotal.current + current
      subtotal.max = subtotal.max + max
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
