local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")

--- Amphibious Assault
---
--- Core amphibious assault operations including LST beaching, ACV launches,
--- mission timing, and landing zone assessment
local AmphibiousAssault = {}

---Set start time for a single landing mission
---Calculates start time relative to current time and updates the mission
---@param mission SBJ__LandingMissionDescriptor Mission descriptor with delay offset
---@return boolean # True if mission start time was successfully set
local function setMissionStartTime(mission)
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

---Set start times for all amphibious assault missions across all operational zones
---Configures transport helicopters, landing craft, and attack helicopters
---Records the mission start timestamp in saveData for phase tracking
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data to record mission start time
---@return boolean # True if all mission start times were successfully set
function AmphibiousAssault.setLandingMissionStartTime(amphibOpsConfig, saveData)
  local currentTime = GameApi.ScenEdit_CurrentTime()

  if not currentTime then
    return false
  end

  saveData.c.PHIBOP.airlandingMissionStartTime = currentTime
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      if not setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.boat.missions) do
      if not setMissionStartTime(mission) then
        return false
      end
    end

    for _, mission in ipairs(zone.attackHelicopter.missions) do
      if not setMissionStartTime(mission) then
        return false
      end
    end
  end

  return true
end

---Check if unit is a Landing Ship Tank (excludes auxiliary vessels)
---Used to filter out RORO ships and barges from LST-specific operations
---@param unit CMO__Unit Ship unit to check
---@return boolean # True if unit is an LST (not RORO or Barge)
local function isLST(unit)
  if unit.name ~= 'RORO' and unit.name ~= 'Barge' then
    return true
  end
  return false
end

---Set course for Landing Ship Tanks to approach the beach
---LSTs in anchorage areas are directed toward their landing zones
---Surface Action Groups are moved to amphibious vehicle staging areas for support
---RORO ships and barges remain in anchorage and do not beach
---@param config SBJ__Config Global configuration (unused but kept for consistency)
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all LST courses were successfully set
function AmphibiousAssault.setCoursesForLSTs(config, amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, item in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(item.guid)

    if unit then
      for _, zone in ipairs(operationalZones) do
        if unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
          local destination = GameApi.World_GetPointFromBearing({
            latitude = unit.latitude,
            longitude = unit.longitude,
            bearing = zone.LSTSettings.course.bearing,
            distance = zone.LSTSettings.course.distance
          })

          if not destination then
            return false
          end

          if isLST(unit) then
            unit.course = { destination }
            unit.manualSpeed = zone.LSTSettings.speed
          end
        end
      end
    end
  end

  for _, group in pairs(amphibOpsConfig.sag) do
    local unit = GameApi.ScenEdit_GetUnit(group.groupName)

    if not unit then
      return false
    end

    unit.course = group.to.amphibiousVehicleStagingArea
  end

  return true
end

---Count enemy ground force contacts in the air landing zone
---Used to assess landing zone threat level before committing air assault forces
---Only counts contacts of type 8 (ground units)
---@param contacts CMO__Contact Contact list from the side
---@param area CMO__ReferencePoint[] Reference points defining the air landing zone
---@return integer # Number of enemy ground units in the area
function AmphibiousAssault.countContactsInArea(contacts, area)
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == 8 then
      table.insert(filteredContacts, contact)
    end
  end

  return #filteredContacts
end

---Launch Air Cushion Vehicles (ACVs) from an amphibious assault ship
---Deletes cargo from ship inventory and spawns ZTD-05 and ZBD-05 amphibious vehicles
---Vehicles are positioned in formation and directed toward the landing zone
---Prioritizes ZBD-05 (IFV) over ZTD-05 (light tank) when cargo is available
---@param params SBJ__ACVDeploymentParams Deployment configuration (ship, bearing, distance, destination)
---@return number|nil # Number of ACVs successfully launched, or nil on failure
function AmphibiousAssault.launchACV(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end

  local destination = params.destination
  local ACVlocations = GameUtils.generateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance
  })

  local zbd = AmphibiousLogistics.deleteCargo(ship, { type = 2, num = params.num, dbid = 241 })
  local ztd = AmphibiousLogistics.deleteCargo(ship, { type = 2, num = params.num - zbd, dbid = 240 })
  local index = 0
  local count = 0

  if ztd > 0 then
    for i = 1, ztd, 1 do
      local addedUnit = GameApi.ScenEdit_AddUnit({
        side = 'China',
        type = 'Vehicle',
        name = 'ZTD-05',
        dbid = 240,
        latitude = ACVlocations[i].latitude,
        longitude = ACVlocations[i].longitude,
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

---Check if a ship is a ferry or Landing Ship Tank (LST)
---Used to identify ships capable of launching ACVs or beaching operations
---Includes Type 071 (LPD), Type 072 (LST variants), Type 073A (LSM), and ferries
---@param config SBJ__Config Global configuration for platform DBIDs
---@param ship CMO__Unit Ship unit to check
---@return boolean # True if ship is a ferry or LST
function AmphibiousAssault.isFerryOrLST(config, ship)
  return (ship.dbid == config.platform.TYPE_071 or
    ship.dbid == config.platform.TYPE_072III or
    ship.dbid == config.platform.TYPE_072A or
    ship.dbid == config.platform.TYPE_073A or
    ship.name == 'Ferry')
end

---Get the operational zone for a ship based on its location
---Matches ship position against ACV deployment areas to determine assigned landing zone
---Used to retrieve zone-specific configuration for ACV launches
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param ship CMO__Unit Ship unit to locate
---@return SBJ__OperationZoneDescriptor|nil # Operation zone descriptor, or nil if ship not in any zone
function AmphibiousAssault.getShipZone(amphibOpsConfig, ship)
  for _, zone in ipairs(amphibOpsConfig.operationalZones) do
    if ship:inArea(zone.ACV.area) then
      return zone
    end
  end

  return nil
end

return AmphibiousAssault
