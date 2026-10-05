local Utils = require("src.utils.utils")

local Context = {}

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit
---@param systemCtx SBJ__MissileSystemContext
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function Context.processSupplyAssetDestruction(unit, systemCtx)
  local ammoDepotCtx = systemCtx.ammunitions[unit.name]

  if ammoDepotCtx and unit.group == nil and ammoDepotCtx.weaponCountCurrent > 0 then
    local ammoBefore = ammoDepotCtx.weaponCountCurrent
    ammoDepotCtx.weaponCountCurrent = 0
    return true, {
      tag = "OK",
      system = systemCtx.name or "unknown",
      unitName = unit.name,
      contextName = ammoDepotCtx.name,
      role = "ammo_depot",
      ammoBefore = ammoBefore,
      ammoAfter = ammoDepotCtx.weaponCountCurrent,
      delta = ammoDepotCtx.weaponCountCurrent - ammoBefore
    }
  end

  if not unit.group then
    return false, nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.group.name]

  if resupplyUnitCtx and resupplyUnitCtx.weaponCountCurrent > 0 then
    local ammoBefore = resupplyUnitCtx.weaponCountCurrent
    local ammoPerUnit = resupplyUnitCtx.weaponCountDefault / resupplyUnitCtx.unitCount

    if (resupplyUnitCtx.weaponCountCurrent - ammoPerUnit) < 0 then
      resupplyUnitCtx.weaponCountCurrent = 0
    else
      resupplyUnitCtx.weaponCountCurrent = resupplyUnitCtx.weaponCountCurrent - ammoPerUnit
    end
    return true, {
      tag = "OK",
      system = systemCtx.name or "unknown",
      unitName = unit.name,
      contextName = resupplyUnitCtx.name,
      role = "resupply_unit",
      ammoBefore = ammoBefore,
      ammoAfter = resupplyUnitCtx.weaponCountCurrent,
      delta = resupplyUnitCtx.weaponCountCurrent - ammoBefore
    }
  end

  return false, nil
end

---Fill the default per-system state for every system in config
---Existing fields are kept, so pre-seeded extras (e.g. Taiwan ascm.test) survive
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundCtx SBJ__GroundContext
function Context.ensureGroundState(missileSystemConfigMap, groundCtx)
  groundCtx.missileSystemTypes = groundCtx.missileSystemTypes or {}
  for system, _ in pairs(missileSystemConfigMap) do
    local systemCtx = groundCtx.missileSystemTypes[system] or {}
    systemCtx.name = system
    if systemCtx.enabled == nil then
      systemCtx.enabled = true
    end
    systemCtx.ammunitions = systemCtx.ammunitions or {}
    systemCtx.resupplyUnits = systemCtx.resupplyUnits or {}
    systemCtx.firingUnits = systemCtx.firingUnits or {}
    groundCtx.missileSystemTypes[system] = systemCtx
  end
end

---Initialize missile system runtime contexts from configuration
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundCtx SBJ__GroundContext
function Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)
  for system, systemConfig in pairs(missileSystemConfigMap) do
    local firingUnitMap = Utils.deepCopy(systemConfig.firingUnits)
    for _, descriptor in pairs(firingUnitMap) do
      local ctx = descriptor
      groundCtx.missileSystemTypes[system].firingUnits[ctx.name] = ctx
    end

    local resupplyUnitMap = Utils.deepCopy(systemConfig.resupplyUnits)
    for _, descriptor in pairs(resupplyUnitMap) do
      local ctx = descriptor
      groundCtx.missileSystemTypes[system].resupplyUnits[ctx.name] = ctx
    end

    local ammunitionMap = Utils.deepCopy(systemConfig.ammunitions)
    for _, descriptor in pairs(ammunitionMap) do
      local ctx = descriptor
      groundCtx.missileSystemTypes[system].ammunitions[ctx.name] = ctx
    end
  end
end

return Context
