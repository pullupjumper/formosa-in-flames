local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")

local Meeting = {}

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param operationalArea SBJ__OperationalArea Position information table
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
---@param state integer Unit state
---@param isAuto boolean Whether in automatic mode
---@return boolean # Whether the state allows meeting
function Meeting.isValidStateForMeeting(state, isAuto)
  if not isAuto then
    return true
  end
  return state == constants.MISSILE_SYSTEM_STATE.REPOSITIONING or state == constants.MISSILE_SYSTEM_STATE.RELOAD
end

---Check if reload is required between a target and its counterpart
---@param targetCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Target unit context
---@param counterpartCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Counterpart unit context
---@param unit CMO__Unit Target unit for ammo check
---@param counterpart CMO__Unit Counterpart unit for ammo check
---@return boolean # Whether reload is required
function Meeting.isReloadRequired(targetCtx, counterpartCtx, unit, counterpart)
  local isFiringUnitCtx = targetCtx.weaponDBID ~= nil

  if isFiringUnitCtx then
    return Ammo.isLowAmmo(unit, targetCtx.ammoThreshold, targetCtx.weaponDBID) and counterpartCtx.wpnCurrent > 0
  end

  return Ammo.isLowAmmo(counterpart, counterpartCtx.ammoThreshold, counterpartCtx.weaponDBID) and
      targetCtx.wpnCurrent > 0
end

---Check if a unit has met with any counterpart in the same reload area
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context to check
---@param unitName string Unit name to match against unitCtx.name
---@param counterpartList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Counterpart units to check
---@param unit CMO__Unit Unit object for area checking
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil matchedUnitCtx The unit context that was matched
function Meeting.checkMeetingInArea(unitCtx, unitName, counterpartList, unit, isAuto)
  if unitCtx.name ~= unitName or not Meeting.isValidStateForMeeting(unitCtx.state, isAuto) then
    return false, nil
  end

  local area = Meeting.findUnitArea(unit, unitCtx.operationalArea)
  if not area then return false, nil end

  for _, counterpartCtx in pairs(counterpartList) do
    local counterpart = GameApi.ScenEdit_GetUnit(counterpartCtx.name, unit.side)
    if counterpart and counterpart:inArea(area)
        and Meeting.isReloadRequired(unitCtx, counterpartCtx, unit, counterpart) then
      return true, unitCtx
    end
  end

  return false, nil
end

---Search for a meeting match between a unit list and counterpart list
---@param unitList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Units to iterate
---@param unitName string Unit name to match
---@param counterpartList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Counterpart units
---@param unit CMO__Unit Unit object for area checking
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil matchedUnitCtx The matched context
function Meeting.findMeetingMatch(unitList, unitName, counterpartList, unit, isAuto)
  for _, unitCtx in pairs(unitList) do
    local hasMet, matchedCtx = Meeting.checkMeetingInArea(unitCtx, unitName, counterpartList, unit, isAuto)
    if hasMet then return true, matchedCtx end
  end
  return false, nil
end

---Check if firing unit has met with resupply units
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context
function Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)
  local isResupplyUnit = systemCtx.resupplyUnits[unit.name] ~= nil
  local isFiringUnit = systemCtx.firingUnits[unit.name] ~= nil

  if not isFiringUnit and not isResupplyUnit then
    return false, nil
  end

  if isResupplyUnit then
    return Meeting.findMeetingMatch(systemCtx.resupplyUnits, unit.name, systemCtx.firingUnits, unit, isAuto)
  end

  return Meeting.findMeetingMatch(systemCtx.firingUnits, unit.name, systemCtx.resupplyUnits, unit, isAuto)
end

---Check if resupply unit has met with ammunition depot
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__ResupplyUnitContext|nil resupplyUnit The matched resupply unit context
function Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
  if not systemCtx.resupplyUnits[unit.name] then
    return false, nil
  end

  for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
    if resupplyUnitCtx.name == unit.name and Meeting.isValidStateForMeeting(resupplyUnitCtx.state, isAuto) then
      local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)

      for _, pos in ipairs(resupplyUnitCtx.operationalArea.AHA) do
        local isInSameArea = unit:inArea(pos.area) and (ammoDepot and ammoDepot:inArea(pos.area)) and
            resupplyUnitCtx.wpnCurrent == 0
        if isInSameArea then return true, resupplyUnitCtx end
      end
    end
  end

  return false, nil
end

return Meeting
