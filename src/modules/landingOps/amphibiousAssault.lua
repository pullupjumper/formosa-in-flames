local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")

local AmphibiousAssault = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================


---@type table<number, boolean>
local FERRY_OR_LST_DBIDS = {
  [constants.PLATFORMS.TYPE_071]    = true,
  [constants.PLATFORMS.TYPE_072III] = true,
  [constants.PLATFORMS.TYPE_072A]   = true,
  [constants.PLATFORMS.TYPE_073A]   = true,
}
local FERRY_NAME = "Ferry"

---@type table<string, boolean>
local NON_LST_NAMES = {
  RORO  = true,
  Barge = true,
}

---@type {name: string, dbid: number}[]
local ACV_TYPES = {
  { name = "ZBD-05", dbid = constants.PLATFORMS.ZBD05 },
  { name = "ZTD-05", dbid = constants.PLATFORMS.ZTD05 },
}

---@type string[]
local MISSION_CATEGORIES = { "transportHelicopter", "boat", "attackHelicopter" }

-- ============================================================================
-- Validation and Filtering
-- ============================================================================

---Check if unit is a Landing Ship Tank (excludes auxiliary vessels)
---@param unit CMO__Unit Ship unit to check
---@return boolean # True if unit is an LST (not RORO or Barge)
local function isLST(unit)
  return not NON_LST_NAMES[unit.name]
end

---Count enemy ground force contacts in the specified area
---Only counts contacts of type FACILITY_MOBILE to assess landing zone threat level
---@param contacts CMO__Contact[] Contact list from the side
---@param area CMO__ReferencePoint[] Reference points defining the area
---@return integer # Number of enemy ground units in the area
local function countGroundContacts(contacts, area)
  local count = 0
  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      count = count + 1
    end
  end
  return count
end

-- ============================================================================
-- Mission Configuration
-- ============================================================================

---Set start time for a single landing mission
---Calculates start time relative to current time and updates the mission
---@param mission SBJ__LandingMissionDescriptor Mission descriptor with delay offset
---@param currentTime number Current scenario time in seconds
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setMissionStartTime(mission, currentTime)
  local startTime = os.date(constants.DATE_FORMAT, (currentTime + mission.startTime))
  local m = GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, mission.name)

  if not m then
    return { tag = "FAIL", fields = { mission = mission.name, reason = "mission_not_found" } }
  end

  m.starttime = startTime .. constants.TIME_FORMATS
  return { tag = "OK", fields = { mission = mission.name, startTime = startTime } }
end

---Set start times for all missions in a single zone
---Iterates transport helicopter, boat, and attack helicopter missions
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param currentTime number Current scenario time in seconds
---@return boolean success True if all missions were set
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setZoneMissionStartTimes(zone, currentTime)
  local results = {}

  for _, category in ipairs(MISSION_CATEGORIES) do
    for _, mission in ipairs(zone[category].missions) do
      local result = setMissionStartTime(mission, currentTime)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return false, results
      end
    end
  end

  return true, results
end

-- ============================================================================
-- ACV Spawning
-- ============================================================================

---Delete cargo by priority from ship for ACV deployment
---Iterates ACV_TYPES in order, allocating remaining slots to each type
---@param ship CMO__Unit Ship to delete cargo from
---@param totalNum number Total number of ACVs to deploy
---@return {acvType: {name: string, dbid: number}, count: number}[] # Allocation array
local function deleteCargoByPriority(ship, totalNum)
  local allocations = {}
  local remaining = totalNum

  for _, acvType in ipairs(ACV_TYPES) do
    if remaining <= 0 then break end
    local deleted = AmphibiousLogistics.deleteCargo(ship, { type = 2, num = remaining, dbid = acvType.dbid })
    if deleted > 0 then
      table.insert(allocations, { acvType = acvType, count = deleted })
      remaining = remaining - deleted
    end
  end

  return allocations
end

---Spawn a single ACV unit at the specified location
---@param acvType {name: string, dbid: number} ACV type descriptor
---@param location CMO__Location Spawn coordinates
---@param destination CMO__Location[] Course destination waypoints
---@return SBJ__LogResult # Deferred log result describing the outcome
local function spawnSingleACV(acvType, location, destination)
  local addedUnit = GameApi.ScenEdit_AddUnit({
    side = constants.SIDES.ENEMY,
    type = "Vehicle",
    name = acvType.name,
    dbid = acvType.dbid,
    latitude = location.latitude,
    longitude = location.longitude,
  })

  if not addedUnit then
    return { tag = "FAIL", fields = { unit = acvType.name, reason = "add_unit_failed" } }
  end

  local doctrine = GameApi.ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = "no" })

  if not doctrine then
    return { tag = "FAIL", fields = { unit = acvType.name, reason = "set_doctrine_failed" } }
  end

  addedUnit.throttle = "Full"
  addedUnit.course = destination
  return {
    tag = "OK",
    fields = {
      unit = acvType.name,
      lat = string.format("%.4f", location.latitude),
      lon = string.format("%.4f", location.longitude)
    }
  }
end

---Spawn every allocated ACV, stopping at the first failure
---@param allocations {acvType: {name: string, dbid: number}, count: number}[] ACV allocations by type
---@param locations CMO__Location[] Spawn coordinates in launch order
---@param destination CMO__Location[] Course destination waypoints
---@return integer|nil count ACVs launched, nil when a spawn failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function spawnAllocatedACVs(allocations, locations, destination)
  local results = {}
  local index = 0

  for _, allocation in ipairs(allocations) do
    for _ = 1, allocation.count do
      index = index + 1
      local result = spawnSingleACV(allocation.acvType, locations[index], destination)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return nil, results
      end
    end
  end

  return index, results
end

-- ============================================================================
-- Course Setting
-- ============================================================================

---Set course for an LST to approach the beach
---@param unit CMO__Unit LST ship unit
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setCourseForLST(unit, zone)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    bearing = zone.lstSettings.course.bearing,
    distance = zone.lstSettings.course.distance
  })

  if not destination then
    return { tag = "FAIL", fields = { ship = unit.name, reason = "destination_calc_failed" } }
  end

  if not isLST(unit) then
    return { tag = "SKIP", fields = { ship = unit.name, reason = "non_lst_auxiliary" } }
  end

  unit.course = { destination }
  unit.manualSpeed = zone.lstSettings.speed
  return {
    tag = "OK",
    fields = { ship = unit.name, bearing = zone.lstSettings.course.bearing, speed = zone.lstSettings.speed }
  }
end

---Set course for a Surface Action Group
---@param descriptor SBJ__SAGDescriptor SAG descriptor with groupName and destination
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setCourseForSAG(descriptor)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.groupName)

  if not unit then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "sag_unit_not_found" } }
  end

  unit.course = descriptor.to.amphibiousVehicleStagingArea
  return { tag = "OK", fields = { sag = descriptor.groupName, dest = "amphibious_vehicle_staging_area" } }
end

---Set courses for every LST anchored in a zone, stopping at the first failure
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean success True when no LST failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setZoneLSTCourses(zone, units)
  local results = {}

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == "Ship" and unit:inArea(zone.lstAnchorageArea) then
      local result = setCourseForLST(unit, zone)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return false, results
      end
    end
  end

  return true, results
end

---Set courses for every SAG in an operation, stopping at the first failure
---@param operation SBJ__AmphibiousOperationDescriptor Operation descriptor with sagNames
---@param sagLookup table<string, SBJ__SAGDescriptor> SAG descriptor lookup table
---@return boolean success True when no SAG failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setOperationSAGCourses(operation, sagLookup)
  local results = {}

  for _, sagName in ipairs(operation.sagNames) do
    local descriptor = sagLookup[sagName]

    if descriptor then
      local result = setCourseForSAG(descriptor)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return false, results
      end
    end
  end

  return true, results
end

-- ============================================================================
-- Public API
-- ============================================================================

---Set start times for amphibious assault missions in a single operational zone
---Configures transport helicopters, landing craft, attack helicopters and records start timestamp
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param zoneState SBJ__ZoneState Per-zone state to record mission start time
---@return boolean # True if all mission start times were successfully set
function AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)
  local currentTime = GameApi.ScenEdit_CurrentTime()
  zoneState.airlandingMissionStartTime = currentTime
  local success, results = setZoneMissionStartTimes(zone, currentTime)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Set landing mission start times")
  report.addAll(results)
  report.emit()

  return success
end

---Set course for LSTs to approach beach and move SAGs to staging areas
---LSTs in anchorage are directed to landing zones; RORO ships and barges remain in anchorage
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@param operation SBJ__AmphibiousOperationDescriptor Operation descriptor with sagNames
---@param sagLookup table<string, SBJ__SAGDescriptor> SAG descriptor lookup table
---@return boolean # True if all LST courses were successfully set
function AmphibiousAssault.setCoursesForLSTs(zone, units, operation, sagLookup)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Set courses for LSTs")

  local success, results = setZoneLSTCourses(zone, units)
  report.addAll(results)

  if success then
    local sagResults
    success, sagResults = setOperationSAGCourses(operation, sagLookup)
    report.addAll(sagResults)
  end

  report.emit()

  return success
end

---Count enemy ground force contacts in the air landing zone
---Only counts contacts of type FACILITY_MOBILE to assess landing zone threat level
---@param contacts CMO__Contact[] Contact list from the side
---@param area CMO__ReferencePoint[] Reference points defining the air landing zone
---@return integer # Number of enemy ground units in the area
function AmphibiousAssault.countContactsInArea(contacts, area)
  return countGroundContacts(contacts, area)
end

---Launch Amphibious Combat Vehicles (ACVs) from an amphibious ship
---Spawns ZBD-05 and ZTD-05 amphibious vehicles in formation toward landing zone
---@param params SBJ__ACVDeploymentParams Deployment configuration (ship, bearing, distance, destination)
---@return integer|nil # Number of ACVs successfully launched, or nil on failure
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

  local allocations = deleteCargoByPriority(ship, params.num)
  local count, results = spawnAllocatedACVs(allocations, ACVlocations, destination)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_ASSAULT, "ship=" .. (ship.name or ship.guid), "Launch ACV")
  report.addAll(results)
  report.emit()

  return count
end

---Check if a ship is a ferry or Landing Ship Tank (LST)
---Includes Type 071/072/073 and ferries capable of launching ACVs or beaching
---@param ship CMO__Unit Ship unit to check
---@return boolean # True if ship is a ferry or LST
function AmphibiousAssault.isFerryOrLST(ship)
  return FERRY_OR_LST_DBIDS[ship.dbid] == true or ship.name == FERRY_NAME
end

---Get the operational zone for a ship based on its location
---Matches ship position against ACV deployment areas to retrieve zone-specific configuration
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param ship CMO__Unit Ship unit to locate
---@return SBJ__OperationalZoneDescriptor|nil # Operation zone descriptor, or nil if ship not in any zone
function AmphibiousAssault.getShipZone(amphibOpsConfig, ship)
  for _, zone in ipairs(amphibOpsConfig.operationalZones) do
    if ship:inArea(zone.acv.area) then
      return zone
    end
  end

  return nil
end

return AmphibiousAssault
