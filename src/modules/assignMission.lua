Utils = require("src.utils.utils")
Logger = require("src.utils.logger")
GameApi = require("src.utils.gameApi")

AssignMission = {}

---@param baseUnit CMO__Unit The base unit with embarked units
---@param platformType string The type of platform to filter (e.g., 'Aircraft', 'Boat')
---@param platformDBID number The database ID of the platform to filter
---@return table<integer, CMO__Unit> A list of filtered embarked units
function AssignMission._filterEmbarkedPlatforms(baseUnit, platformType, platformDBID)
  local filteredPlatforms = {}
  if baseUnit == nil or #baseUnit.embarkedUnits[platformType] == 0 then return filteredPlatforms end

  ---@type string[]
  local platforms = baseUnit.embarkedUnits[platformType]
  for _, guid in ipairs(platforms) do
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

    if not unit then
      Logger.error("Failed to get unit '" .. guid .. "': " .. err)
      goto continue_filter -- 跳過當前單位
    end

    if unit.dbid == platformDBID then
      unit.manualSpeed = 'OFF'
      table.insert(filteredPlatforms, unit)
    end
    ::continue_filter::
  end
  return filteredPlatforms
end

---@param unit CMO__Unit The unit to check
---@param mission SBJ__MissionEntry The mission settings
---@return boolean True if the unit can be assigned to the mission, false otherwise
function AssignMission._canAssignUnitToMission(unit, mission)
  return not unit.mission and (mission.loadoutId == 0 or unit.loadoutdbid == mission.loadoutId)
end

---@param filteredPlatforms table<integer, CMO__Unit> A list of filtered embarked units
---@param mission SBJ__MissionEntry The mission to assign units to
function AssignMission._processMissionAssignments(filteredPlatforms, mission)
  local count = 0
  for _, unit in ipairs(filteredPlatforms) do
    if count >= mission.num then break end

    if AssignMission._canAssignUnitToMission(unit, mission) then
      local success, err = Utils.SafeCall("GameApi.ScenEdit_AssignUnitToMission", GameApi.ScenEdit_AssignUnitToMission,
        unit.guid, mission.name, false)

      if not success then
        Logger.error("Failed to assign unit '" .. unit.guid .. "' to mission '" .. mission.name .. "': " .. err)
        goto continue_assignment -- 跳過當前單位
      end

      count = count + 1
    end
    ::continue_assignment::
  end
end

---@param fromUnit string The unit guid with embarked units
---@param platformType string The type of platform to filter (e.g., 'Aircraft', 'Ship')
---@param platformDBID number The database ID of the platform to filter
---@param missions table<number, SBJ__MissionEntry> A list of missions to assign units to
function AssignMission.AssignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)
  local base, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, fromUnit)

  if not base then
    Logger.error("Failed to get base unit '" .. fromUnit .. "': " .. err)
    return -- 提前返回
  end

  local filteredPlatforms = AssignMission._filterEmbarkedPlatforms(base, platformType, platformDBID)

  for _, mission in ipairs(missions) do
    AssignMission._processMissionAssignments(filteredPlatforms, mission)
  end
end

---@param unitGuid string The GUID of the unit
---@param weaponDBID number The database ID of the weapon to filter by
---@return number The count of the specified weapon on the unit's loadout
function AssignMission._getWeaponCount(unitGuid, weaponDBID)
  local loadout, err = Utils.SafeCall("GameApi.ScenEdit_GetLoadout", GameApi.ScenEdit_GetLoadout, unitGuid)

  if not loadout then
    Logger.error("Failed to get loadout for unit '" .. unitGuid .. "': " .. err)
    return 0 -- 返回 0 表示沒有武器或獲取失敗
  end

  local weaponNum = 0
  if loadout.weapons and #loadout.weapons > 0 then
    for _, w in ipairs(loadout.weapons) do
      if w["wpn_dbid"] == weaponDBID then
        weaponNum = w["wpn_current"]
        break
      end
    end
  end
  return weaponNum
end

---@param unit CMO__Unit The unit to check
---@param weaponNum number The number of specified weapons on the unit
---@param unitDBID number|nil The database ID of the unit to filter by, or nil for any unit
---@return boolean True if the unit is eligible for the strike mission, false otherwise
function AssignMission._isUnitEligibleForStrikeMission(unit, weaponNum, unitDBID)
  return unit.readytime_v == 0 and unit.mission == nil and (weaponNum > 0 or unit.dbid == unitDBID)
end

---@param fromUnit string -- The unit guid with embarked units
---@param num number -- The number of units to assign to the mission
---@param weaponDBID number|0 -- The database ID of the weapon to filter by, or 0 for any weapon
---@param unitDBID number|nil -- The database ID of the unit to filter by, or nil for any unit
---@param missionName string -- The name of the mission to assign units to
---@param isEscort boolean -- Whether the mission is an escort mission
---@return table<integer, string>|nil -- A list of assigned units
function AssignMission.AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort)
  ---@type CMO__Unit
  local airbase, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, fromUnit)
  if not airbase then
    Logger.error("Failed to get airbase unit '" .. fromUnit .. "': " .. err)
    return nil -- 提前返回
  end

  if #airbase.embarkedUnits['Aircraft'] == 0 then return nil end

  ---@type CMO__Mission
  local m, err = Utils.SafeCall("GameApi.ScenEdit_GetMission", GameApi.ScenEdit_GetMission, airbase.side, missionName)
  if not m then
    Logger.error("Failed to get mission '" .. missionName .. "' for side '" .. airbase.side .. "': " .. err)
    return nil -- 提前返回
  end

  m.isactive = false
  ---@type table<integer, string>
  local temp = {}
  local count = 0

  ---@type string[]
  local platforms = airbase.embarkedUnits.Aircraft
  for _, guid in ipairs(platforms) do
    ---@type CMO__Unit
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)
    if not unit then
      Logger.error("Failed to get unit '" .. guid .. "': " .. err)
      goto continue_strike -- 跳過當前單位
    end

    local weaponNum = AssignMission._getWeaponCount(unit.guid, weaponDBID)
    if AssignMission._isUnitEligibleForStrikeMission(unit, weaponNum, unitDBID) and count < num then
      ---@type boolean
      local success, err = Utils.SafeCall("GameApi.ScenEdit_AssignUnitToMission", GameApi.ScenEdit_AssignUnitToMission,
        unit.guid, missionName, isEscort)

      if not success then
        Logger.error("Failed to assign unit '" .. unit.guid .. "' to mission '" .. missionName .. "': " .. err)
        goto continue_strike -- 跳過當前單位
      end

      count = count + 1
      table.insert(temp, unit.guid)
      if count >= num then break end
    end

    ::continue_strike::
  end
  if not m.isactive then m.isactive = true end
  return temp
end

return AssignMission
