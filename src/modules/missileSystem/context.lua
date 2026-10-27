local Utils = require("src.utils.utils")

local Context = {}

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit
---@param systemState SBJ__MissileSystemState
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function Context.processSupplyAssetDestruction(unit, systemState)
  local ammoDepotState = systemState.ammunitions[unit.name]

  if ammoDepotState and unit.group == nil and ammoDepotState.weaponCountCurrent > 0 then
    local ammoBefore = ammoDepotState.weaponCountCurrent
    ammoDepotState.weaponCountCurrent = 0
    return true, {
      tag = "OK",
      system = systemState.name or "unknown",
      unitName = unit.name,
      contextName = ammoDepotState.name,
      role = "ammo_depot",
      ammoBefore = ammoBefore,
      ammoAfter = ammoDepotState.weaponCountCurrent,
      delta = ammoDepotState.weaponCountCurrent - ammoBefore
    }
  end

  if not unit.group then
    return false, nil
  end

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
function Context.ensureGroundState(missileSystemConfigMap, groundState)
  groundState.missileSystemTypes = groundState.missileSystemTypes or {}
  for system, _ in pairs(missileSystemConfigMap) do
    local systemState = groundState.missileSystemTypes[system] or {}
    systemState.name = system
    if systemState.enabled == nil then
      systemState.enabled = true
    end
    systemState.ammunitions = systemState.ammunitions or {}
    systemState.resupplyUnits = systemState.resupplyUnits or {}
    systemState.firingUnits = systemState.firingUnits or {}
    groundState.missileSystemTypes[system] = systemState
  end
end

---Initialize missile system runtime states from configuration
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
function Context.initMissileSystemContexts(missileSystemConfigMap, groundState)
  for system, systemConfig in pairs(missileSystemConfigMap) do
    local firingUnitMap = Utils.deepCopy(systemConfig.firingUnits)
    for _, descriptor in pairs(firingUnitMap) do
      local ctx = descriptor
      groundState.missileSystemTypes[system].firingUnits[ctx.name] = ctx
    end

    local resupplyUnitMap = Utils.deepCopy(systemConfig.resupplyUnits)
    for _, descriptor in pairs(resupplyUnitMap) do
      local ctx = descriptor
      groundState.missileSystemTypes[system].resupplyUnits[ctx.name] = ctx
    end

    local ammunitionMap = Utils.deepCopy(systemConfig.ammunitions)
    for _, descriptor in pairs(ammunitionMap) do
      local ctx = descriptor
      groundState.missileSystemTypes[system].ammunitions[ctx.name] = ctx
    end
  end
end

return Context
