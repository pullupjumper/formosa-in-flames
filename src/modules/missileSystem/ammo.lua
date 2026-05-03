local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

local Ammo = {}

---Transfer ammunition from ammunition depot to resupply unit
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param ammoDepotCtx SBJ__AmmunitionContext Ammunition depot context
function Ammo.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
  if ammoDepotCtx.wpnCurrent > 0 and resupplyUnitCtx.wpnCurrent < resupplyUnitCtx.wpnDefault then
    local deficit = resupplyUnitCtx.wpnDefault - resupplyUnitCtx.wpnCurrent
    local ammoToTransfer = math.min(deficit, ammoDepotCtx.wpnCurrent)
    resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent + ammoToTransfer
    ammoDepotCtx.wpnCurrent = ammoDepotCtx.wpnCurrent - ammoToTransfer
  end

  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  resupplyUnitCtx.reloadStartTime = nil
end

---Reload ammunition for a single unit
---@param unit CMO__Unit|nil Unit object
---@param weaponDBID number|number[] Weapon database ID(s)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@return integer # Total ammunition consumed
function Ammo.reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  if not unit then return 0 end
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local totalLoaded = 0

  for _, dbid in ipairs(weaponDBIDs) do
    local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
    local required = wpnInfo.maxWeapons - wpnInfo.availableWeapons

    if required > 0 and resupplyUnitCtx.wpnCurrent > 0 then
      local ammoToLoad = math.min(required, resupplyUnitCtx.wpnCurrent)
      GameApi.ScenEdit_AddReloadsToUnit({ guid = unit.guid, side = unit.side, wpn_dbid = dbid, number = ammoToLoad })
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoToLoad
      totalLoaded = totalLoaded + ammoToLoad
    end
  end

  return totalLoaded
end

---Execute reload for firing unit
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param weaponDBID number|number[] Weapon database ID(s)
---@param sideName string Side name
---@return integer # Total ammunition loaded
function Ammo.reloadFiringUnit(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)
  if not firingUnit then return 0 end
  local units = Shared.getGroupUnits(firingUnit)

  local totalLoaded = 0
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    totalLoaded = totalLoaded + Ammo.reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  firingUnitCtx.reloadStartTime = nil
  return totalLoaded
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number|nil Percentage threshold
---@param weaponDBID number|number[]|nil Weapon database ID(s)
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
---@param current number Current ammunition count
---@param max number Maximum ammunition count
---@return integer # Percentage in 0-100 range, rounded to nearest integer
local function calcPercentage(current, max)
  if max == 0 then return 0 end
  return math.floor(current / max * 100 + 0.5)
end

---Sum ammunition across all firing units of a missile system by querying live game state
---@param firingUnits table<string, SBJ__FiringUnitContext> Firing unit contexts keyed by name
---@param sideName string Side name for ScenEdit_GetUnit lookup
---@return SBJ__AmmoSubtotal # Subtotal with current/max/percentage
local function sumFiringUnits(firingUnits, sideName)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for _, firingCtx in pairs(firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingCtx.name, sideName)
    if firingUnit then
      local weaponDBIDs = Shared.normalizeWeaponDBIDs(firingCtx.weaponDBID)
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

  subtotal.percentage = calcPercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Sum ammunition across context-tracked units (resupply trucks or ammo depots)
---@param contexts table<string, SBJ__ResupplyUnitContext|SBJ__AmmunitionContext> Contexts with wpnCurrent/wpnDefault
---@return SBJ__AmmoSubtotal # Subtotal with current/max/percentage
local function sumContextUnits(contexts)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for _, ctx in pairs(contexts) do
    subtotal.current = subtotal.current + ctx.wpnCurrent
    subtotal.max = subtotal.max + ctx.wpnDefault
  end

  subtotal.percentage = calcPercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Calculate ammunition inventory across firing units, resupply units, and ammo depots
---@param systemCtx SBJ__MissileSystemContext Missile system runtime context
---@param sideName string Side name used to resolve firing units in game state
---@return SBJ__AmmoInventoryReport # Inventory report with subtotals and percentages
function Ammo.getInventory(systemCtx, sideName)
  local firing = sumFiringUnits(systemCtx.firingUnits, sideName)
  local resupply = sumContextUnits(systemCtx.resupplyUnits)
  local ammo = sumContextUnits(systemCtx.ammunitions)

  local total = {
    current = firing.current + resupply.current + ammo.current,
    max = firing.max + resupply.max + ammo.max,
    percentage = 0,
  }
  total.percentage = calcPercentage(total.current, total.max)

  return {
    firing = firing,
    resupply = resupply,
    ammo = ammo,
    total = total,
  }
end

return Ammo
