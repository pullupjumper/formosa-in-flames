local GameApi = require("src.utils.gameApi")
local Ammo = require("src.modules.missileSystem.ammo")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

---Finds where battery units stand and which partner they can meet. Decides nothing: Rules does.
local Meeting = {}

---Find the RL zone of an operational area that a unit stands in
---@param unit CMO__Unit
---@param operationalArea SBJ__OperationalArea
---@return string[]|nil # Zone reference points, nil when the unit is in no RL zone
function Meeting.findReloadArea(unit, operationalArea)
  for _, pos in ipairs(operationalArea.RL) do
    if unit:inArea(pos.area) then
      return pos.area
    end
  end

  return nil
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

---Resolve the firing unit and resupply unit paired with a unit, both states and both CMO units
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit Firing or resupply unit; reused for its own end, the other end is looked up on its side
---@return SBJ__ReloadPair|nil # Nil when either state or either CMO unit is missing
function Meeting.resolveReloadPair(systemState, unit)
  local firingUnitState, resupplyUnitState = GroundStateStore.resolvePair(systemState, unit.name)
  if not firingUnitState or not resupplyUnitState then
    return nil
  end

  local firingUnit = resolveCmoUnit(firingUnitState, unit)
  local resupplyUnit = resolveCmoUnit(resupplyUnitState, unit)
  if not firingUnit or not resupplyUnit then
    return nil
  end

  local reload
  return {
    firingUnitState = firingUnitState,
    firingUnit = firingUnit,
    resupplyUnitState = resupplyUnitState,
    resupplyUnit = resupplyUnit,
    isTriggeredByFiringUnit = unit.name == firingUnitState.name,
    isFiringUnitLowAmmo = function()
      return Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
    end,
    isInSameReloadArea = function()
      local area = Meeting.findReloadArea(firingUnit, firingUnitState.operationalArea)
      return area ~= nil and resupplyUnit:inArea(area)
    end,
    buildReload = function()
      reload = reload or Ammo.buildReload(firingUnit, firingUnitState.weaponDBID, resupplyUnitState.weaponCountCurrent)
      return reload
    end,
  }
end

---Whether a resupply unit and its ammo depot stand in one ATP zone
---@param resupplyUnitState SBJ__ResupplyUnitState
---@param resupplyUnit CMO__Unit
---@return boolean # False also when the ammo depot is not in the game
function Meeting.isAtAmmoDepot(resupplyUnitState, resupplyUnit)
  local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitState.ammunition, resupplyUnit.side)
  if not ammoDepot then
    return false
  end

  for _, pos in ipairs(resupplyUnitState.operationalArea.ATP) do
    if resupplyUnit:inArea(pos.area) and ammoDepot:inArea(pos.area) then
      return true
    end
  end

  return false
end

return Meeting
