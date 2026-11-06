local Utils = require("src.utils.utils")

local GroundStateStore = {}

---Find the launcher, transloader and canister stock states paired with either end's unit name
---The pairing comes from config links. Each state is nil when it is not tracked; all are nil when config
---has no launcher or transloader of that name.
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@param unitName string Launcher or transloader name
---@return SBJ__LauncherState|nil launcherState Launcher state of the pair
---@return SBJ__TransloaderState|nil transloaderState Transloader state of the pair
---@return SBJ__CanisterStockState|nil canisterStockState canister stock state of the transloader
function GroundStateStore.resolvePair(systemConfig, systemState, unitName)
  local transloaderName = unitName
  local launcherDescriptor = systemConfig.launchers[unitName]
  if launcherDescriptor then
    transloaderName = launcherDescriptor.transloader
  end

  local transloaderDescriptor = systemConfig.transloaders[transloaderName]
  if not transloaderDescriptor then
    return nil, nil, nil
  end

  return systemState.launchers[transloaderDescriptor.launcher],
      systemState.transloaders[transloaderDescriptor.name],
      systemState.canisterStocks[transloaderDescriptor.canisterStock]
end

---Call back once for every enabled missile system
---@param groundState SBJ__GroundState
---@param callback fun(systemState: SBJ__MissileSystemState, missileSystemType: string)
function GroundStateStore.forEachEnabledSystem(groundState, callback)
  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    if systemState.enabled then
      callback(systemState, missileSystemType)
    end
  end
end

---Handle logic when transloader is destroyed
---@param unit CMO__Unit
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function GroundStateStore.processSupplyAssetDestruction(unit, systemConfig, systemState)
  local canisterStockState = systemState.canisterStocks[unit.name]

  if canisterStockState and unit.group == nil and canisterStockState.weaponCountCurrent > 0 then
    local ammoBefore = canisterStockState.weaponCountCurrent
    canisterStockState.weaponCountCurrent = 0
    return true, {
      tag = "OK",
      system = systemState.name or "unknown",
      unitName = unit.name,
      contextName = canisterStockState.name,
      role = "canister_stock",
      ammoBefore = ammoBefore,
      ammoAfter = canisterStockState.weaponCountCurrent,
      delta = canisterStockState.weaponCountCurrent - ammoBefore
    }
  end

  if not unit.group then
    return false, nil
  end

  -- The destroyed unit is one vehicle; transloader state is keyed by its group's name
  local transloaderState = systemState.transloaders[unit.group.name]
  local transloaderDescriptor = systemConfig.transloaders[unit.group.name]

  if transloaderState and transloaderDescriptor and transloaderState.weaponCountCurrent > 0 then
    local ammoBefore = transloaderState.weaponCountCurrent
    local ammoPerUnit = transloaderDescriptor.weaponCountDefault / transloaderDescriptor.unitCount

    if (transloaderState.weaponCountCurrent - ammoPerUnit) < 0 then
      transloaderState.weaponCountCurrent = 0
    else
      transloaderState.weaponCountCurrent = transloaderState.weaponCountCurrent - ammoPerUnit
    end
    return true, {
      tag = "OK",
      system = systemState.name or "unknown",
      unitName = unit.name,
      contextName = transloaderState.name,
      role = "transloader",
      ammoBefore = ammoBefore,
      ammoAfter = transloaderState.weaponCountCurrent,
      delta = transloaderState.weaponCountCurrent - ammoBefore
    }
  end

  return false, nil
end

---Fill the default per-system state for every system in config
---Existing fields are kept, so pre-seeded extras (e.g. Taiwan ascm.test) survive
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
function GroundStateStore.ensureGroundState(missileSystemConfigMap, groundState)
  groundState.missileSystemTypes = groundState.missileSystemTypes or {}
  for system, _ in pairs(missileSystemConfigMap) do
    local systemState = groundState.missileSystemTypes[system] or {}
    systemState.name = system
    if systemState.enabled == nil then
      systemState.enabled = true
    end
    systemState.canisterStocks = systemState.canisterStocks or {}
    systemState.transloaders = systemState.transloaders or {}
    systemState.launchers = systemState.launchers or {}
    groundState.missileSystemTypes[system] = systemState
  end
end

---Set each battery's runtime state fresh from its config descriptors' starting values, at the battery's operational area
---Only the given batteries change; every other battery keeps its runtime state. Copies the area, so run it
---after PositionZones.rebuild has written the mask onto a new area.
---@param groundState SBJ__GroundState
---@param batteries SBJ__Battery[]
function GroundStateStore.resetBatteryStates(groundState, batteries)
  for _, battery in ipairs(batteries) do
    local systemState = groundState.missileSystemTypes[battery.missileSystemType]
    local launcher, transloader, canisterStock = battery.launcher, battery.transloader, battery.canisterStock

    systemState.launchers[launcher.name] = {
      name = launcher.name,
      state = launcher.state,
      operationalArea = Utils.deepCopy(battery.operationalArea),
    }
    systemState.transloaders[transloader.name] = {
      name = transloader.name,
      state = transloader.state,
      operationalArea = Utils.deepCopy(battery.operationalArea),
      weaponCountCurrent = transloader.weaponCountCurrent,
    }
    systemState.canisterStocks[canisterStock.name] = {
      name = canisterStock.name,
      weaponCountCurrent = canisterStock.weaponCountCurrent,
    }
  end
end

---Resolve where a battery is now: its saved state's area, or its config area before its first deploy
---A state area without a name is a copy of the config area made by a save from before areas had names.
---Returns the stored table; copy it before changing it.
---@param groundState SBJ__GroundState
---@param missileSystemType string
---@param launcherDescriptor SBJ__LauncherDescriptor Config descriptor, the fallback
---@return SBJ__OperationalArea
function GroundStateStore.resolveOperationalArea(groundState, missileSystemType, launcherDescriptor)
  local systemState = groundState.missileSystemTypes and groundState.missileSystemTypes[missileSystemType]
  local launcherState = systemState and systemState.launchers[launcherDescriptor.name]
  local stateArea = launcherState and launcherState.operationalArea
  return stateArea and stateArea.name and stateArea or launcherDescriptor.operationalArea
end

return GroundStateStore
