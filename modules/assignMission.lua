---@param fromUnit string The unit guid with embarked units
---@param platformType string The type of platform to filter (e.g., 'Aircraft', 'Ship')
---@param platformDBID number The database ID of the platform to filter
---@param missions table<number, {name: string, num: number, loadoutId: number}> A list of missions to assign units to
function AssignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)
  local base = ScenEdit_GetUnit({ guid = fromUnit })
  if base == nil then return end
  local platforms = base.embarkedUnits[platformType]
  local filteredPlatforms = {}

  for _, value in ipairs(platforms) do
    local unit = SE_GetUnit({ guid = value })
    if unit ~= nil and unit.dbid == platformDBID then
      unit.manualSpeed = 'OFF'
      table.insert(filteredPlatforms, unit)
    end
  end

  for _, mission in ipairs(missions) do
    local count = 0

    for idx, unit in ipairs(filteredPlatforms) do
      if count >= mission.num then break end

      if mission.loadoutId == 0 then
        if not unit.mission then
          ScenEdit_AssignUnitToMission(unit.guid, mission.name)
          count = count + 1
        end
      else
        if unit.loadoutdbid == mission.loadoutId and not unit.mission then
          ScenEdit_AssignUnitToMission(unit.guid, mission.name)
          count = count + 1
        end
      end
    end
  end
end

---@param fromUnit string The unit guid with embarked units
---@param num number The number of units to assign to the mission
---@param weaponDBID number | 0 The database ID of the weapon to filter by, or 0 for any weapon
---@param unitDBID number | nil The database ID of the unit to filter by, or nil for any unit
---@param missionName string The name of the mission to assign units to
---@param isEscort boolean Whether the mission is an escort mission
---@return table<number, {unit: string}>|nil A list of assigned units
function AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort)
  local airbase = ScenEdit_GetUnit({ guid = fromUnit })

  if airbase == nil then
    airbase = ScenEdit_GetUnit({ unitname = fromUnit })
  end

  if airbase == nil or airbase.embarkedUnits['Aircraft'] == nil then return end
  local m = ScenEdit_GetMission(airbase.side, missionName)
  if m == nil then return end
  m.isactive = false
  local temp = {}
  local count = 0

  for _, item in ipairs(airbase.embarkedUnits.Aircraft) do
    local unit = ScenEdit_GetUnit({ guid = item })
    if unit == nil then goto continue end

    local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
    local weaponNum = 0

    if weapons and #weapons > 0 then
      for _, w in ipairs(weapons) do
        if w["wpn_dbid"] == weaponDBID then weaponNum = w["wpn_current"] end
      end
    end

    if unit.readytime_v == 0 and unit.mission == nil and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
      -- if unit.readytime_v == 0 and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
      if isEscort then
        ScenEdit_AssignUnitToMission(unit.guid, missionName, true)
      else
        ScenEdit_AssignUnitToMission(unit.guid, missionName)
      end

      -- if course then unit.course = course end
      count = count + 1
      table.insert(temp, { unit = unit.guid })
      if count >= num then break end
    end

    ::continue::
  end
  if not m.isactive then m.isactive = true end
  return temp
end
