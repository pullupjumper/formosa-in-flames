local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = {}

---@param mission SBJ__LandingMission
---@return boolean
function AmphibiousAssault._setMissionStartTime(mission)
  local currentTime = GameApi.ScenEdit_CurrentTime()
  if not currentTime then
    return false
  end

  local startTime = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + mission.startTime))

  local m = GameApi.ScenEdit_GetMission("China", mission.name)
  if not m then
    return false
  end

  m.starttime = startTime
  return true
end

---comment
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@return boolean
function AmphibiousAssault.SetLandingMissionStartTime(CONFIG, saveData)
  local currentTime = GameApi.ScenEdit_CurrentTime()

  if not currentTime then
    return false
  end

  saveData.c.PHIBOP.airlandingMissionStartTime = currentTime
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      if not AmphibiousAssault._setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.boat.missions) do
      if not AmphibiousAssault._setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.attackHelicopter.missions) do
      if not AmphibiousAssault._setMissionStartTime(mission) then
        return false
      end
    end
  end

  return true
end

---comment
---@param unit CMO__Unit
---@return boolean
function AmphibiousAssault._isLST(unit)
  if unit.name ~= 'RORO' and unit.name ~= 'Barge' then
    return true
  end
  return false
end

---comment
---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit[]
---@return boolean
function AmphibiousAssault.SetCoursesForLSTs(CONFIG, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, item in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(item.guid)

    if unit then
      for _, zone in ipairs(operationalZones) do
        if unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
          local destination = GameApi.World_GetPointFromBearing({
            LATITUDE = unit.latitude,
            LONGITUDE = unit.longitude,
            BEARING = zone.LSTSettings.course.bearing,
            DISTANCE = zone.LSTSettings.course.distance
          })

          if not destination then
            return false
          end

          if AmphibiousAssault._isLST(unit) then
            unit.course = { destination }
            unit.manualSpeed = zone.LSTSettings.speed
          end
        end
      end
    end
  end

  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    local unit = GameApi.ScenEdit_GetUnit(group.groupName)

    if not unit then
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
function AmphibiousAssault.CountContactsInArea(contacts, area)
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == 8 then
      table.insert(filteredContacts, contact)
    end
  end

  return #filteredContacts
end

---@param params SBJ__ACVLocation_Params
---@return number|nil
function AmphibiousAssault.LaunchACV(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end

  local destination = params.destination
  local ACVlocations = GameUtils.GenerateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance
  })

  local zbd = AmphibiousLogistics.DeleteCargo(ship, { type = 2, num = params.num, dbid = 241 })
  local ztd = AmphibiousLogistics.DeleteCargo(ship, { type = 2, num = params.num - zbd, dbid = 240 })
  local index = 0
  local count = 0

  if ztd > 0 then
    for i = 1, ztd, 1 do
      local addedUnit = GameApi.ScenEdit_AddUnit({
        side = 'China',
        type = 'Vehicle',
        name = 'ZTD-05',
        dbid = 240,
        LATITUDE = ACVlocations[i].latitude,
        LONGITUDE = ACVlocations[i].longitude,
      })

      if not addedUnit then
        return
      end

      local doctrine = GameApi.ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })

      if not doctrine then
        return
      end

      addedUnit.throttle = 'Full'
      addedUnit.course = destination
      index = i
      count = count + 1
    end
  end

  if zbd > 0 then
    for i = index + 1, index + zbd, 1 do
      local addedUnit = GameApi.ScenEdit_AddUnit({
        side = 'China',
        type = 'Vehicle',
        name = 'ZBD-05',
        dbid = 241,
        LATITUDE = ACVlocations[i].latitude,
        LONGITUDE = ACVlocations[i].longitude,
      })

      if not addedUnit then
        return
      end

      local doctrine = GameApi.ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })

      if not doctrine then
        return
      end

      addedUnit.throttle = 'Full'
      addedUnit.course = destination
      count = count + 1
    end
  end

  return count
end

---comment
---@param CONFIG SBJ__CONFIG
---@param ship CMO__Unit
---@return boolean
function AmphibiousAssault.IsFerryOrLST(CONFIG, ship)
  return (ship.dbid == CONFIG.platformDBID7
    or ship.dbid == CONFIG.platformDBID8
    or ship.dbid == CONFIG.platformDBID9
    or ship.dbid == CONFIG.platformDBID10
    or ship.name == 'Ferry')
end

---comment
---@param CONFIG SBJ__CONFIG
---@param ship CMO__Unit
---@return SBJ__OperationalZone|nil
function AmphibiousAssault.GetShipZone(CONFIG, ship)
  for _, zone in ipairs(CONFIG.c.PHIBOP.operationalZones) do
    if ship:inArea(zone.ACV.area) then
      return zone
    end
  end

  return nil
end

return AmphibiousAssault
