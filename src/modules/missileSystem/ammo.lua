local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")

local Ammo = {}

---Transfer canisters from the canister stock to its transloader, up to the transloader's capacity
---@param transloaderState SBJ__TransloaderState
---@param canisterStockState SBJ__CanisterStockState
---@param capacity number Missiles a full transloader carries
function Ammo.transferCanisters(transloaderState, canisterStockState, capacity)
  if canisterStockState.weaponCountCurrent > 0 and transloaderState.weaponCountCurrent < capacity then
    local deficit = capacity - transloaderState.weaponCountCurrent
    local canistersToTransfer = math.min(deficit, canisterStockState.weaponCountCurrent)
    transloaderState.weaponCountCurrent = transloaderState.weaponCountCurrent + canistersToTransfer
    canisterStockState.weaponCountCurrent = canisterStockState.weaponCountCurrent - canistersToTransfer
  end
end

---Build the reloads a launcher's group needs, filling each unit and weapon in order until the stock runs out
---Reads CMO only, so the plan can be decided on before any reload is written.
---@param launcher CMO__Unit
---@param weaponDBID number|number[]
---@param stock integer Missiles the transloader carries
---@return SBJ__ReloadPlan
function Ammo.buildReload(launcher, weaponDBID, stock)
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local plan = { entries = {}, count = 0 }

  for _, guid in ipairs(Shared.getGroupUnits(launcher)) do
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

---Load a reload plan into the launcher's group and take the missiles from the transloader
---@param transloaderState SBJ__TransloaderState
---@param plan SBJ__ReloadPlan From Ammo.buildReload with this transloader's stock
---@return integer # Total ammunition loaded
function Ammo.reloadLauncher(transloaderState, plan)
  for _, entry in ipairs(plan.entries) do
    GameApi.ScenEdit_AddReloadsToUnit({ guid = entry.guid, side = entry.side, wpn_dbid = entry.weaponDBID, number = entry.number })
  end

  transloaderState.weaponCountCurrent = transloaderState.weaponCountCurrent - plan.count
  return plan.count
end

---Sum loaded and maximum weapons across every unit of a launcher's group
---@param launcher CMO__Unit
---@param weaponDBID number|number[]
---@return integer current Weapons loaded
---@return integer max Weapon capacity
local function tallyWeapons(launcher, weaponDBID)
  local weaponDBIDs = Shared.normalizeWeaponDBIDs(weaponDBID)
  local current, max = 0, 0

  for _, guid in ipairs(Shared.getGroupUnits(launcher)) do
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
---@param launcher CMO__Unit
---@param percentage number|nil
---@param weaponDBID number|number[]|nil
---@return boolean # Whether it is low ammunition
function Ammo.isLowAmmo(launcher, percentage, weaponDBID)
  if not percentage or not weaponDBID then
    return false
  end

  local totalCurrent, totalMax = tallyWeapons(launcher, weaponDBID)
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

---Sum ammunition across all launchers of a missile system by querying live game state
---@param launcherMap table<string, SBJ__LauncherState>
---@param descriptorMap table<string, SBJ__LauncherDescriptor>
---@param sideName string
---@return SBJ__AmmoSubtotalEntry # Subtotal with current/max/percentage
local function countLaunchers(launcherMap, descriptorMap, sideName)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for name in pairs(launcherMap) do
    local descriptor = descriptorMap[name]
    local launcher = descriptor and GameApi.ScenEdit_GetUnit(name, sideName)
    if launcher then
      local current, max = tallyWeapons(launcher, descriptor.weaponDBID)
      subtotal.current = subtotal.current + current
      subtotal.max = subtotal.max + max
    end
  end

  subtotal.percentage = calculatePercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Sum ammunition across state-tracked units (transloaders or canister stocks)
---@param stateMap table<string, SBJ__TransloaderState|SBJ__CanisterStockState>
---@param descriptorMap table<string, SBJ__TransloaderDescriptor|SBJ__CanisterStockDescriptor>
---@return SBJ__AmmoSubtotalEntry # Subtotal with current/max/percentage
local function countStateUnits(stateMap, descriptorMap)
  local subtotal = { current = 0, max = 0, percentage = 0 }

  for name, unitState in pairs(stateMap) do
    local descriptor = descriptorMap[name]
    if descriptor then
      subtotal.current = subtotal.current + unitState.weaponCountCurrent
      subtotal.max = subtotal.max + descriptor.weaponCountDefault
    end
  end

  subtotal.percentage = calculatePercentage(subtotal.current, subtotal.max)
  return subtotal
end

---Calculate ammunition inventory across launchers, transloaders, and canister stocks
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@param sideName string
---@return SBJ__AmmoInventoryResult # Inventory report with subtotals and percentages
function Ammo.getInventory(systemConfig, systemState, sideName)
  local launcher = countLaunchers(systemState.launchers, systemConfig.launchers, sideName)
  local transloader = countStateUnits(systemState.transloaders, systemConfig.transloaders)
  local canisterStock = countStateUnits(systemState.canisterStocks, systemConfig.canisterStocks)

  local total = {
    current = launcher.current + transloader.current + canisterStock.current,
    max = launcher.max + transloader.max + canisterStock.max,
    percentage = 0,
  }
  total.percentage = calculatePercentage(total.current, total.max)

  return {
    launcher = launcher,
    transloader = transloader,
    canisterStock = canisterStock,
    total = total,
  }
end

return Ammo
