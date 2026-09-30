local Utils = require("src.utils.utils")

local Context = {}

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function Context.processSupplyAssetDestruction(unit, systemCtx)
  local ammoDepotCtx = systemCtx.ammunitions[unit.name]

  if ammoDepotCtx and unit.group == nil and ammoDepotCtx.wpnCurrent > 0 then
    local ammoBefore = ammoDepotCtx.wpnCurrent
    ammoDepotCtx.wpnCurrent = 0
    return true, {
      tag = "OK",
      system = systemCtx.name or "unknown",
      unitName = unit.name,
      contextName = ammoDepotCtx.name,
      role = "ammo_depot",
      ammoBefore = ammoBefore,
      ammoAfter = ammoDepotCtx.wpnCurrent,
      delta = ammoDepotCtx.wpnCurrent - ammoBefore
    }
  end

  if not unit.group then
    return false, nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.group.name]

  if resupplyUnitCtx and resupplyUnitCtx.wpnCurrent > 0 then
    local ammoBefore = resupplyUnitCtx.wpnCurrent
    local ammoPerUnit = resupplyUnitCtx.wpnDefault / resupplyUnitCtx.unitCount

    if (resupplyUnitCtx.wpnCurrent - ammoPerUnit) < 0 then
      resupplyUnitCtx.wpnCurrent = 0
    else
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoPerUnit
    end
    return true, {
      tag = "OK",
      system = systemCtx.name or "unknown",
      unitName = unit.name,
      contextName = resupplyUnitCtx.name,
      role = "resupply_unit",
      ammoBefore = ammoBefore,
      ammoAfter = resupplyUnitCtx.wpnCurrent,
      delta = resupplyUnitCtx.wpnCurrent - ammoBefore
    }
  end

  return false, nil
end

---Fill the default per-system state for every system in config
---Existing fields are kept, so pre-seeded extras (e.g. Taiwan ascm.test) survive
---@param missileSystemTypeConfig SBJ__MissileSystemTypeConfig Ground force configuration
---@param groundCtx SBJ__GroundContext Ground force state to seed in place
function Context.ensureGroundState(missileSystemTypeConfig, groundCtx)
  groundCtx.missileSystemTypes = groundCtx.missileSystemTypes or {}
  for system, _ in pairs(missileSystemTypeConfig) do
    ---@type SBJ__MissileSystemContext
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
---@param missileSystemTypeConfig SBJ__MissileSystemTypeConfig Ground force configuration
---@param groundCtx SBJ__GroundContext Ground force runtime context
function Context.initMissileSystemContexts(missileSystemTypeConfig, groundCtx)
  for system, systemConfig in pairs(missileSystemTypeConfig) do
    ---@cast systemConfig SBJ__MissileSystemConfig
    local firingUnitMap = Utils.deepCopy(systemConfig.firingUnits)
    for _, descriptor in pairs(firingUnitMap) do
      ---@type SBJ__FiringUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundCtx.missileSystemTypes[system].firingUnits[ctx.name] = ctx
    end

    local resupplyUnitMap = Utils.deepCopy(systemConfig.resupplyUnits)
    for _, descriptor in pairs(resupplyUnitMap) do
      ---@type SBJ__ResupplyUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundCtx.missileSystemTypes[system].resupplyUnits[ctx.name] = ctx
    end

    local ammunitionMap = Utils.deepCopy(systemConfig.ammunitions)
    for _, descriptor in pairs(ammunitionMap) do
      ---@type SBJ__AmmunitionContext
      local ctx = descriptor
      groundCtx.missileSystemTypes[system].ammunitions[ctx.name] = ctx
    end
  end
end

return Context
