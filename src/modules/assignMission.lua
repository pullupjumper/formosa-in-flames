local GameApi = require("src.utils.gameApi")

local AssignMission = {}

---Filter embarked platforms by type and database ID
---@param baseUnit CMO__Unit The base unit with embarked units
---@param platformType string The type of platform to filter (e.g., 'Aircraft', 'Boat')
---@param platformDBID number The database ID of the platform to filter
---@return table<integer, CMO__Unit> # A list of filtered embarked units
local function filterEmbarkedPlatforms(baseUnit, platformType, platformDBID)
  local filteredPlatforms = {}
  if baseUnit == nil or #baseUnit.embarkedUnits[platformType] == 0 then return filteredPlatforms end

  ---@type string[]
  local platforms = baseUnit.embarkedUnits[platformType]
  for _, guid in ipairs(platforms) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and unit.dbid == platformDBID then
      unit.manualSpeed = "OFF"
      table.insert(filteredPlatforms, unit)
    end
  end
  return filteredPlatforms
end

---Check if a unit can be assigned to a mission
---@param unit CMO__Unit The unit to check
---@param mission SBJ__MissionDeploymentDescriptor The mission settings
---@return boolean # True if the unit can be assigned to the mission, false otherwise
local function canAssignUnitToMission(unit, mission)
  return not unit.mission and (mission.loadoutId == 0 or unit.loadoutdbid == mission.loadoutId)
end

---Process mission assignments for filtered platforms
---@param filteredPlatforms table<integer, CMO__Unit> A list of filtered embarked units
---@param mission SBJ__MissionDeploymentDescriptor The mission to assign units to
local function processMissionAssignments(filteredPlatforms, mission)
  local count = 0
  for _, unit in ipairs(filteredPlatforms) do
    if count >= mission.num then break end

    if canAssignUnitToMission(unit, mission) then
      local success = GameApi.ScenEdit_AssignUnitToMission(unit.guid, mission.name, false)

      if success then
        count = count + 1
      end
    end
  end
end

---Assign embarked units to missions
---@param fromUnit string The unit guid with embarked units
---@param platformType string The type of platform to filter (e.g., 'Aircraft', 'Ship')
---@param platformDBID number The database ID of the platform to filter
---@param missions table<number, SBJ__MissionDeploymentDescriptor> A list of missions to assign units to
function AssignMission.assignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)
  local base = GameApi.ScenEdit_GetUnit(fromUnit)

  if not base then
    return -- Early return
  end

  local filteredPlatforms = filterEmbarkedPlatforms(base, platformType, platformDBID)

  for _, mission in ipairs(missions) do
    processMissionAssignments(filteredPlatforms, mission)
  end
end

---Get weapon count for a specific weapon type on a unit
---@param unitGuid string The GUID of the unit
---@param weaponDBID number The database ID of the weapon to filter by
---@return number # The count of the specified weapon on the unit's loadout
local function getWeaponCount(unitGuid, weaponDBID)
  local loadout = GameApi.ScenEdit_GetLoadout(unitGuid)

  if not loadout then
    return 0 -- Return 0 indicates no weapons or retrieval failed
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

---Check if unit is eligible for strike mission
---@param unit CMO__Unit The unit to check
---@param weaponNum number The number of specified weapons on the unit
---@param unitDBID number|nil The database ID of the unit to filter by, or nil for any unit
---@return boolean # True if the unit is eligible for the strike mission, false otherwise
local function isUnitEligibleForStrikeMission(unit, weaponNum, unitDBID)
  return unit.readytime_v == 0 and unit.mission == nil and (weaponNum > 0 or unit.dbid == unitDBID)
end

---Assign embarked units to strike mission
---@param fromUnit string The unit guid with embarked units
---@param num number The number of units to assign to the mission
---@param weaponDBID number|0 The database ID of the weapon to filter by, or 0 for any weapon
---@param unitDBID number|nil The database ID of the unit to filter by, or nil for any unit
---@param missionName string The name of the mission to assign units to
---@param isEscort boolean Whether the mission is an escort mission
---@return table<integer, string>|nil # A list of assigned units
function AssignMission.assignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort)
  ---@type CMO__Unit
  local airbase = GameApi.ScenEdit_GetUnit(fromUnit)
  if not airbase then
    return nil -- Early return
  end

  if #airbase.embarkedUnits["Aircraft"] == 0 then return nil end

  ---@type CMO__Mission
  local m = GameApi.ScenEdit_GetMission(airbase.side, missionName)
  if not m then
    return nil -- Early return
  end

  m.isactive = false
  ---@type table<integer, string>
  local temp = {}
  local count = 0

  ---@type string[]
  local platforms = airbase.embarkedUnits.Aircraft
  for _, guid in ipairs(platforms) do
    ---@type CMO__Unit
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit then
      local weaponNum = getWeaponCount(unit.guid, weaponDBID)
      if isUnitEligibleForStrikeMission(unit, weaponNum, unitDBID) and count < num then
        ---@type boolean
        local success = GameApi.ScenEdit_AssignUnitToMission(unit.guid, missionName, isEscort)

        if success then
          count = count + 1
          table.insert(temp, unit.guid)
          if count >= num then break end
        end
      end
    end
  end
  if not m.isactive then m.isactive = true end
  return temp
end

return AssignMission
