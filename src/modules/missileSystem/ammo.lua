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

return Ammo
