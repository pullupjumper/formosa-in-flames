local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")

local Shared = {}

---@type table<number, true>
Shared.SAM_DBIDS = {
  [constants.PLATFORMS.PAC3] = true,
  [constants.PLATFORMS.SKY_GUARD] = true,
  [constants.PLATFORMS.TC2] = true,
  [constants.PLATFORMS.CUSTOMED_TK3] = true,
  [constants.PLATFORMS.CUSTOMED_SAM] = true,
  [constants.PLATFORMS.S300] = true,
  [constants.PLATFORMS.S400] = true,
  [constants.PLATFORMS.HQ12] = true,
  [constants.PLATFORMS.HQ22] = true,
}

---Normalize weaponDBID to always be an array
---@param weaponDBID number|number[] Weapon DBID or array of weapon DBIDs
---@return number[]
function Shared.normalizeWeaponDBIDs(weaponDBID)
  if type(weaponDBID) == "table" then
    return weaponDBID
  end
  return { weaponDBID }
end

---Check if a platform is a SAM system
---@param dbid number Platform database ID
---@return boolean # True if the platform is a SAM system
function Shared.isSAM(dbid)
  return Shared.SAM_DBIDS[dbid] == true
end

---Get the list of unit GUIDs from a unit or its group
---@param unit CMO__Unit Unit or group leader
---@return string[] # Array of unit GUIDs
function Shared.getGroupUnits(unit)
  return unit.group and unit.group.unitlist or { unit.guid }
end

---Set unit movement and weapon control status using table parameters
---@param params SBJ__SetUnitPropertiesParams Unit properties configuration table
function Shared.setUnitProperties(params)
  local unit = params.unit
  if not unit then return end

  local unitSetParams = {
    guid = unit.guid,
    manualthrottle = params.throttle or "Stop",
    manualSpeed = params.speed or 0,
    holdposition = params.holdPosition == nil and true or params.holdPosition
  }

  if params.course then
    unitSetParams.course = params.course
  end

  GameApi.ScenEdit_SetUnit(unitSetParams)

  if params.wcs then
    local doctrine = { weapon_control_status_land = params.wcs }

    if Shared.isSAM(unit.dbid) then
      doctrine = { weapon_control_status_air = params.wcs }
    end

    GameApi.ScenEdit_SetDoctrine({ side = unit.side, guid = unit.guid }, doctrine)
  end

  if params.formation then
    unit.formation = params.formation
  end
end

---Apply properties to all units in a group
---@param firingUnit CMO__Unit Unit or group leader
---@param propsBuilder fun(unit: CMO__Unit): SBJ__SetUnitPropertiesParams Property builder function
function Shared.applyToGroupUnits(firingUnit, propsBuilder)
  local units = Shared.getGroupUnits(firingUnit)
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit then
      Shared.setUnitProperties(propsBuilder(unit))
    end
  end
end

---Build auto/manual mode unit properties
---@param unit CMO__Unit Target unit
---@param isAuto boolean Whether in automatic mode
---@param wcs integer Weapon control status
---@return SBJ__SetUnitPropertiesParams # Unit properties for the given mode
function Shared.buildModeProperties(unit, isAuto, wcs)
  return {
    unit = unit,
    holdPosition = isAuto and true or false,
    throttle = isAuto and "Stop" or "OFF",
    speed = isAuto and 0 or "OFF",
    wcs = wcs,
  }
end

return Shared
