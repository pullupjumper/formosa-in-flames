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
---@param weaponDBID number|number[]
---@return number[]
function Shared.normalizeWeaponDBIDs(weaponDBID)
  if type(weaponDBID) == "table" then
    return weaponDBID
  end
  return { weaponDBID }
end

---Check if a platform is a SAM system
---@param dbid number
---@return boolean # True if the platform is a SAM system
function Shared.isSAM(dbid)
  return Shared.SAM_DBIDS[dbid] == true
end

---Get the list of unit GUIDs from a unit or its group
---@param unit CMO__Unit
---@return string[] # Array of unit GUIDs
function Shared.getGroupUnits(unit)
  return unit.group and unit.group.unitlist or { unit.guid }
end

---Set unit movement and weapon control status
---@param unit CMO__Unit
---@param opts SBJ__SetUnitPropertiesOpts|nil
local function setUnitProperties(unit, opts)
  if not unit then return end
  local params = opts or {}

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
---@param firingUnit CMO__Unit
---@param propsBuilder fun(unit: CMO__Unit): SBJ__SetUnitPropertiesOpts
function Shared.setGroupUnitProperties(firingUnit, propsBuilder)
  local units = Shared.getGroupUnits(firingUnit)
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit then
      setUnitProperties(unit, propsBuilder(unit))
    end
  end
end

---Build auto/manual mode unit properties
---@param isAuto boolean
---@param wcs integer
---@return SBJ__SetUnitPropertiesOpts # Unit properties for the given mode
function Shared.buildModeProperties(isAuto, wcs)
  return {
    holdPosition = isAuto and true or false,
    throttle = isAuto and "Stop" or "OFF",
    speed = isAuto and 0 or "OFF",
    wcs = wcs,
  }
end

return Shared
