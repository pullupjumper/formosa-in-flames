GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall

---@param mission {name: string, startTime: number}
---@return boolean
function _setMissionStartTime(mission)
  local currentTime, err = SafeCall("GameApi.ScenEdit_CurrentTime", GameApi.ScenEdit_CurrentTime)
  if not currentTime then
    Logger.error("Error in ScenEdit_CurrentTime: " .. err)
    return false
  end

  local startTime = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + mission.startTime))

  local m, err = SafeCall("GameApi.ScenEdit_GetMission", GameApi.ScenEdit_GetMission, "China", mission.name)
  if not m then
    Logger.error("Error in ScenEdit_GetMission: " .. err)
    return false
  end

  m.starttime = startTime
  return true
end

---comment
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@return boolean
function SetLandingMissionStartTime(CONFIG, saveData)
  local currentTime = SafeCall("GameApi.ScenEdit_CurrentTime", GameApi.ScenEdit_CurrentTime)

  if not currentTime then
    Logger.error("Error in ScenEdit_CurrentTime")
    return false
  end

  saveData.c.PHIBOP.airlandingMissionStartTime = currentTime
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      if not _setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.boat.missions) do
      if not _setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.attackHelicopter.missions) do
      if not _setMissionStartTime(mission) then
        return false
      end
    end
  end

  return true
end

---comment
---@param unit CMO__Unit
---@return boolean
function _isLST(unit)
  if unit.name ~= 'RORO' and unit.name ~= 'Barge' then
    return true
  end
  return false
end

---comment
---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit[]
---@return boolean
function SetCoursesForLSTs(CONFIG, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, item in ipairs(units) do
    -- local unit = SE_GetUnit({ guid = item.guid })
    local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, item.guid)

    if not unit then
      Logger.error("Failed to get unit '" .. item.name .. "': " .. err)
      return false
    end

    for _, zone in ipairs(operationalZones) do
      if unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
        local destination, err = SafeCall("GameApi.World_GetPointFromBearing", GameApi.World_GetPointFromBearing, {
          LATITUDE = unit.latitude,
          LONGITUDE = unit.longitude,
          BEARING = zone.LSTSettings.course.bearing,
          DISTANCE = zone.LSTSettings.course.distance
        })

        if not destination then
          Logger.error("Failed to get destination point: " .. err)
          return false
        end

        if _isLST(unit) then
          unit.course = { destination }
          unit.manualSpeed = zone.LSTSettings.speed
        end
      end
    end
  end

  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, group.groupName)

    if not unit then
      Logger.error("Failed to get unit '" .. group.groupName .. "': " .. err)
      return false
    end

    unit.course = group.to.amphibiousVehicleStagingArea
  end

  return true
end

---comment
---@param contacts CMO__Contact
---@param area CMO__ReferencePoint[]
---@return integer
function CountContactsInArea(contacts, area)
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == 8 then
      table.insert(filteredContacts, contact)
    end
  end

  return #filteredContacts
end

return {
  _setMissionStartTime = _setMissionStartTime,
  _isLST = _isLST,
  SetCoursesForLSTs = SetCoursesForLSTs,
  CountContactsInArea = CountContactsInArea,
  SetLandingMissionStartTime = SetLandingMissionStartTime
}
