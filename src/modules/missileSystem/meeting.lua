local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")

local Meeting = {}

---Find the area where the unit is located within RL areas
---@param unit CMO__Unit
---@param operationalArea SBJ__OperationalArea
---@return string[]|nil # Area reference points or nil
function Meeting.findUnitArea(unit, operationalArea)
  for _, pos in ipairs(operationalArea.RL) do
    if unit:inArea(pos.area) then
      return pos.area
    end
  end

  return nil
end

---Check if a unit state is valid for meeting in the given mode
---@param state integer
---@param isAuto boolean
---@return boolean # Whether the state allows meeting
local function isValidStateForMeeting(state, isAuto)
  if not isAuto then
    return true
  end
  return state == constants.MISSILE_SYSTEM_STATE.REPOSITIONING or state == constants.MISSILE_SYSTEM_STATE.RELOAD
end

---Resolve the firing/resupply context pair from either end's unit name
---@param systemCtx SBJ__MissileSystemContext
---@param unitName string
---@return SBJ__FiringUnitContext|nil firingUnitCtx Firing unit context of the pair
---@return SBJ__ResupplyUnitContext|nil resupplyUnitCtx Resupply unit context of the pair
local function resolvePair(systemCtx, unitName)
  local firingUnitCtx = systemCtx.firingUnits[unitName]
  if firingUnitCtx then
    return firingUnitCtx, systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unitName]
  if resupplyUnitCtx then
    local partner = resupplyUnitCtx.firingUnit
    if type(partner) == "table" then
      partner = partner[1]
    end
    return systemCtx.firingUnits[partner], resupplyUnitCtx
  end

  return nil, nil
end

---Resolve the CMO unit for a context, reusing the triggering unit when names match
---@param unitCtx SBJ__UnitBase
---@param triggeringUnit CMO__Unit
---@return CMO__Unit|nil # CMO unit or nil if lookup fails
local function resolveCmoUnit(unitCtx, triggeringUnit)
  if unitCtx.name == triggeringUnit.name then
    return triggeringUnit
  end
  return GameApi.ScenEdit_GetUnit(unitCtx.name, triggeringUnit.side)
end

---Check if firing unit and its paired resupply unit have met in a shared RL area
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param isAuto boolean
---@return boolean hasMet Whether the pair has met with reload required
---@return SBJ__FiringUnitContext|nil firingUnitCtx Firing unit context targeted for reload
function Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)
  local firingUnitCtx, resupplyUnitCtx = resolvePair(systemCtx, unit.name)
  if not firingUnitCtx or not resupplyUnitCtx then
    return false, nil
  end

  local triggeringCtx = (unit.name == firingUnitCtx.name) and firingUnitCtx or resupplyUnitCtx
  if not isValidStateForMeeting(triggeringCtx.state, isAuto) then
    return false, nil
  end

  local firingUnit = resolveCmoUnit(firingUnitCtx, unit)
  local resupplyUnit = resolveCmoUnit(resupplyUnitCtx, unit)
  if not firingUnit or not resupplyUnit then
    return false, nil
  end

  if not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
      or resupplyUnitCtx.weaponCountCurrent <= 0 then
    return false, nil
  end

  local area = Meeting.findUnitArea(firingUnit, firingUnitCtx.operationalArea)
  if not area or not resupplyUnit:inArea(area) then
    return false, nil
  end

  return true, firingUnitCtx
end

---Check if resupply unit has met with ammunition depot in a shared AHA
---@param systemCtx SBJ__MissileSystemContext
---@param unit CMO__Unit
---@param isAuto boolean
---@return boolean hasMet Whether units have met
---@return SBJ__ResupplyUnitContext|nil resupplyUnitCtx The matched resupply unit context
function Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]
  if not resupplyUnitCtx or not isValidStateForMeeting(resupplyUnitCtx.state, isAuto) then
    return false, nil
  end

  if resupplyUnitCtx.weaponCountCurrent ~= 0 then
    return false, nil
  end

  local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)
  if not ammoDepot then
    return false, nil
  end

  for _, pos in ipairs(resupplyUnitCtx.operationalArea.AHA) do
    if unit:inArea(pos.area) and ammoDepot:inArea(pos.area) then
      return true, resupplyUnitCtx
    end
  end

  return false, nil
end

return Meeting
