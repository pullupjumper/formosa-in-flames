local Utils = require("src.utils.utils")

local GroundStateStore = {}

---Find the firing unit, resupply unit and canister stock states paired with either end's unit name
---Any link can be missing when config names a partner that does not exist; it and everything past it is nil.
---@param systemState SBJ__MissileSystemState
---@param unitName string Firing or resupply unit name
---@return SBJ__FiringUnitState|nil firingUnitState Firing unit state of the pair
---@return SBJ__ResupplyUnitState|nil resupplyUnitState Resupply unit state of the pair
---@return SBJ__CanisterStockState|nil canisterStockState canister stock state of the resupply unit
function GroundStateStore.resolvePair(systemState, unitName)
  local firingUnitState = systemState.firingUnits[unitName]
  local resupplyUnitState
  if firingUnitState then
    resupplyUnitState = systemState.resupplyUnits[firingUnitState.resupplyUnit]
  else
    resupplyUnitState = systemState.resupplyUnits[unitName]
    firingUnitState = resupplyUnitState and systemState.firingUnits[resupplyUnitState.firingUnit]
  end

  local canisterStockState = resupplyUnitState and systemState.canisterStocks[resupplyUnitState.canisterStock]
  return firingUnitState, resupplyUnitState, canisterStockState
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

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit
---@param systemState SBJ__MissileSystemState
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function GroundStateStore.processSupplyAssetDestruction(unit, systemState)
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

  -- The destroyed unit is one vehicle; resupply state is keyed by its group's name
  local resupplyUnitState = systemState.resupplyUnits[unit.group.name]

  if resupplyUnitState and resupplyUnitState.weaponCountCurrent > 0 then
    local ammoBefore = resupplyUnitState.weaponCountCurrent
    local ammoPerUnit = resupplyUnitState.weaponCountDefault / resupplyUnitState.unitCount

    if (resupplyUnitState.weaponCountCurrent - ammoPerUnit) < 0 then
      resupplyUnitState.weaponCountCurrent = 0
    else
      resupplyUnitState.weaponCountCurrent = resupplyUnitState.weaponCountCurrent - ammoPerUnit
    end
    return true, {
      tag = "OK",
      system = systemState.name or "unknown",
      unitName = unit.name,
      contextName = resupplyUnitState.name,
      role = "resupply_unit",
      ammoBefore = ammoBefore,
      ammoAfter = resupplyUnitState.weaponCountCurrent,
      delta = resupplyUnitState.weaponCountCurrent - ammoBefore
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
    systemState.resupplyUnits = systemState.resupplyUnits or {}
    systemState.firingUnits = systemState.firingUnits or {}
    groundState.missileSystemTypes[system] = systemState
  end
end

---Set each battery's runtime state fresh from its config descriptors, at the battery's operational area
---Only the given batteries change; every other battery keeps its runtime state. Copies the area, so run it
---after PositionZones.rebuild has written the mask onto a new area.
---@param groundState SBJ__GroundState
---@param batteries SBJ__Battery[]
function GroundStateStore.setBatteryStates(groundState, batteries)
  for _, battery in ipairs(batteries) do
    local systemState = groundState.missileSystemTypes[battery.missileSystemType]
    local firingUnitState = Utils.deepCopy(battery.firing)
    local resupplyUnitState = Utils.deepCopy(battery.resupply)
    firingUnitState.operationalArea = Utils.deepCopy(battery.operationalArea)
    resupplyUnitState.operationalArea = Utils.deepCopy(battery.operationalArea)

    systemState.firingUnits[firingUnitState.name] = firingUnitState
    systemState.resupplyUnits[resupplyUnitState.name] = resupplyUnitState
    systemState.canisterStocks[battery.canisterStock.name] = Utils.deepCopy(battery.canisterStock)
  end
end

---Resolve where a battery is now: its saved state's area, or its config area before its first deploy
---A state area without a name is a copy of the config area made by a save from before areas had names.
---Returns the stored table; copy it before changing it.
---@param groundState SBJ__GroundState
---@param missileSystemType string
---@param firingUnitDescriptor SBJ__FiringUnitDescriptor Config descriptor, the fallback
---@return SBJ__OperationalArea
function GroundStateStore.resolveOperationalArea(groundState, missileSystemType, firingUnitDescriptor)
  local systemState = groundState.missileSystemTypes and groundState.missileSystemTypes[missileSystemType]
  local firingUnitState = systemState and systemState.firingUnits[firingUnitDescriptor.name]
  local stateArea = firingUnitState and firingUnitState.operationalArea
  return stateArea and stateArea.name and stateArea or firingUnitDescriptor.operationalArea
end

return GroundStateStore
