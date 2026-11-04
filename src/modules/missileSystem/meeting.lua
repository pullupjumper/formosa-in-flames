local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

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

---Resolve the CMO unit for a state, reusing the triggering unit when names match
---@param unitState SBJ__UnitBase
---@param triggeringUnit CMO__Unit
---@return CMO__Unit|nil # CMO unit or nil if lookup fails
local function resolveCmoUnit(unitState, triggeringUnit)
  if unitState.name == triggeringUnit.name then
    return triggeringUnit
  end
  return GameApi.ScenEdit_GetUnit(unitState.name, triggeringUnit.side)
end

---Check if firing unit and its paired resupply unit have met in a shared RL area
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param isAuto boolean
---@return boolean hasMet Whether the pair has met with reload required
---@return SBJ__FiringUnitState|nil firingUnitState Firing unit state targeted for reload
function Meeting.hasMetResupplyUnit(systemState, unit, isAuto)
  local firingUnitState, resupplyUnitState = GroundStateStore.resolvePair(systemState, unit.name)
  if not firingUnitState or not resupplyUnitState then
    return false, nil
  end

  local triggeringState = (unit.name == firingUnitState.name) and firingUnitState or resupplyUnitState
  if not isValidStateForMeeting(triggeringState.state, isAuto) then
    return false, nil
  end

  local firingUnit = resolveCmoUnit(firingUnitState, unit)
  local resupplyUnit = resolveCmoUnit(resupplyUnitState, unit)
  if not firingUnit or not resupplyUnit then
    return false, nil
  end

  if not Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
      or resupplyUnitState.weaponCountCurrent <= 0 then
    return false, nil
  end

  local area = Meeting.findUnitArea(firingUnit, firingUnitState.operationalArea)
  if not area or not resupplyUnit:inArea(area) then
    return false, nil
  end

  return true, firingUnitState
end

---Check if resupply unit has met with ammunition depot in a shared AHA
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit
---@param isAuto boolean
---@return boolean hasMet Whether units have met
---@return SBJ__ResupplyUnitState|nil resupplyUnitState The matched resupply unit state
function Meeting.hasMetAmmoDepot(systemState, unit, isAuto)
  local resupplyUnitState = systemState.resupplyUnits[unit.name]
  if not resupplyUnitState or not isValidStateForMeeting(resupplyUnitState.state, isAuto) then
    return false, nil
  end

  if resupplyUnitState.weaponCountCurrent ~= 0 then
    return false, nil
  end

  local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitState.ammunition, unit.side)
  if not ammoDepot then
    return false, nil
  end

  for _, pos in ipairs(resupplyUnitState.operationalArea.AHA) do
    if unit:inArea(pos.area) and ammoDepot:inArea(pos.area) then
      return true, resupplyUnitState
    end
  end

  return false, nil
end

return Meeting
