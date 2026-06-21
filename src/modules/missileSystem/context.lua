local Utils = require("src.utils.utils")

local Context = {}

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function Context.handleSupplyAssetDestruction(unit, systemCtx)
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

---Initialize missile system runtime contexts from configuration
---@param groundForceCfg SBJ__GroundForceConfig Ground force configuration
---@param groundForceCtx SBJ__GroundForceContext Ground force runtime context
function Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)
  for system, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local firingUnits = Utils.deepCopy(systemCfg.firingUnits)
    for _, descriptor in pairs(firingUnits) do
      ---@type SBJ__FiringUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundForceCtx[system].firingUnits[ctx.name] = ctx
    end

    local resupplyUnits = Utils.deepCopy(systemCfg.resupplyUnits)
    for _, descriptor in pairs(resupplyUnits) do
      ---@type SBJ__ResupplyUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundForceCtx[system].resupplyUnits[ctx.name] = ctx
    end

    local ammunitions = Utils.deepCopy(systemCfg.ammunitions)
    for _, descriptor in pairs(ammunitions) do
      ---@type SBJ__AmmunitionContext
      local ctx = descriptor
      groundForceCtx[system].ammunitions[ctx.name] = ctx
    end
  end
end

return Context
