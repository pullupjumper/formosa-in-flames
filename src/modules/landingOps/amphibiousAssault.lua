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

---@type {name: string, dbid: number, key: string}[]
local ACV_TYPES = {
  { name = "ZBD-05", dbid = constants.PLATFORMS.ZBD05, key = "zbd05" },
  { name = "ZTD-05", dbid = constants.PLATFORMS.ZTD05, key = "ztd05" },
}

---Unit types counted in each operational zone once landed
---@type {name: string, dbid: number}[]
local LANDED_UNIT_TYPES = {
  { name = "ZBD-05",        dbid = constants.PLATFORMS.ZBD05 },
  { name = "ZTD-05",        dbid = constants.PLATFORMS.ZTD05 },
  { name = "PLL-05",        dbid = constants.PLATFORMS.PLL05 },
  { name = "PLZ-96",        dbid = constants.PLATFORMS.PLZ96 },
  { name = "PGZ-09",        dbid = constants.PLATFORMS.PGZ09 },
  { name = "PGZ-95",        dbid = constants.PLATFORMS.PGZ95 },
  { name = "SA-15",         dbid = constants.PLATFORMS.SA15 },
  { name = "AirborneCorps", dbid = constants.PLATFORMS.MC },
  { name = "HMMWV",         dbid = constants.PLATFORMS.HMMWV },
  { name = "ZBD-03",        dbid = constants.PLATFORMS.ZBD03 },
}

-- ============================================================================
-- Validation and Filtering
-- ============================================================================

---Check if unit is a Landing Ship Tank (excludes auxiliary vessels and Type 529 sweepers)
---@param unit CMO__Unit
---@return boolean # True if unit is an LST (not RORO, Barge or Type 529)
local function isLST(unit)
  return not NON_LST_NAMES[unit.name] and unit.dbid ~= constants.PLATFORMS.TYPE_082
end

-- ============================================================================
-- Mission Configuration
-- ============================================================================

---Set start time for a single landing mission
---Calculates start time relative to current time and updates the mission
---@param mission SBJ__LandingMissionDescriptor
---@param currentTime number
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setMissionStartTime(mission, currentTime)
  local startTime = os.date(constants.DATE_FORMAT, (currentTime + mission.startTime))
  local cmoMission = GameApi.ScenEdit_GetMission(constants.SIDES.RED, mission.name)

  if not cmoMission then
    return { tag = "FAIL", fields = { mission = mission.name, reason = "mission_not_found" } }
  end

  cmoMission.starttime = startTime .. constants.TIME_FORMATS
  return { tag = "OK", fields = { mission = mission.name, startTime = startTime } }
end

---Set start times for the missions of the given categories in a single zone
---@param zone SBJ__OperationalZoneDescriptor
---@param currentTime number
---@param categories string[] Keys of `zone.air` holding missions (e.g. "transportHelicopter", "attackHelicopter")
---@return boolean success True if all missions were set
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setZoneMissionStartTimes(zone, currentTime, categories)
  local results = {}

  for _, category in ipairs(categories) do
    for _, mission in ipairs(zone.air[category].missions) do
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

---Count cargo items of one DBID aboard a ship
---@param ship CMO__Unit
---@param dbid number
---@return integer
local function countCargo(ship, dbid)
  local cargos = ship.cargo and ship.cargo[1] and ship.cargo[1].cargo or {}
  local count = 0
  for _, element in ipairs(cargos) do
    if element.dbid == dbid then
      count = count + 1
    end
  end
  return count
end

---Delete cargo by priority from ship for ACV deployment
---Iterates ACV_TYPES in order, giving each type at most its own quota
---@param ship CMO__Unit
---@param totalNum number
---@param quota table<string, integer> Remaining quota per ACV type key
---@return {acvType: {name: string, dbid: number, key: string}, count: number}[] # Allocation array
local function removeCargoByPriority(ship, totalNum, quota)
  local allocations = {}
  local remaining = totalNum

  for _, acvType in ipairs(ACV_TYPES) do
    if remaining <= 0 then break end
    local num = math.min(remaining, quota[acvType.key] or 0)
    local deleted = AmphibiousLogistics.removeCargo(ship, { type = 2, num = num, dbid = acvType.dbid })
    if deleted > 0 then
      table.insert(allocations, { acvType = acvType, count = deleted })
      remaining = remaining - deleted
    end
  end

  return allocations
end

---Spawn a single ACV unit at the specified location
---@param acvType {name: string, dbid: number, key: string}
---@param location CMO__Location
---@param routeACV fun(unit: CMO__Unit, acvKey: string): CMO__Location[]
---@return SBJ__LogResult # Deferred log result describing the outcome
local function createSingleACV(acvType, location, routeACV)
  local addedUnit = GameApi.ScenEdit_AddUnit({
    side = constants.SIDES.RED,
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
  addedUnit.course = routeACV(addedUnit, acvType.key)
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
---@param allocations {acvType: {name: string, dbid: number, key: string}, count: number}[]
---@param locations CMO__Location[]
---@param routeACV fun(unit: CMO__Unit, acvKey: string): CMO__Location[]
---@return integer|nil count ACVs launched, nil when a spawn failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function createAllocatedACVs(allocations, locations, routeACV)
  local results = {}
  local index = 0

  for _, allocation in ipairs(allocations) do
    for _ = 1, allocation.count do
      index = index + 1
      local result = createSingleACV(allocation.acvType, locations[index], routeACV)
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
---@param unit CMO__Unit
---@param zone SBJ__OperationalZoneDescriptor
---@return SBJ__LogResult # Deferred log result describing the outcome
local function setCourseForLST(unit, zone)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    bearing = zone.heading,
    distance = zone.landing.lstSettings.distance
  })

  if not destination then
    return { tag = "FAIL", fields = { ship = unit.name, reason = "destination_calc_failed" } }
  end

  if not isLST(unit) then
    return { tag = "SKIP", fields = { ship = unit.name, reason = "non_lst_auxiliary" } }
  end

  unit.course = { destination }
  unit.manualSpeed = zone.landing.lstSettings.speed
  return {
    tag = "OK",
    fields = { ship = unit.name, bearing = zone.heading, speed = zone.landing.lstSettings.speed }
  }
end

---Set course for a Surface Action Group
---@param descriptor SBJ__SAGDescriptor
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
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean success True when no LST failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setZoneLSTCourses(zone, units)
  local results = {}

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == "Ship" and unit:inArea(zone.anchorage.lstArea) then
      local result = setCourseForLST(unit, zone)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return false, results
      end
    end
  end

  return true, results
end

---Set courses for every SAG in a zone, stopping at the first failure
---@param sags SBJ__SAGDescriptor[]
---@return boolean success True when no SAG failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function setZoneSAGCourses(sags)
  local results = {}

  for _, descriptor in ipairs(sags) do
    local result = setCourseForSAG(descriptor)
    table.insert(results, result)

    if result.tag == "FAIL" then
      return false, results
    end
  end

  return true, results
end

-- ============================================================================
-- Public API
-- ============================================================================

---Set start times for amphibious assault missions in a single operational zone and record the start timestamp
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param categories string[] Keys of `zone.air` holding missions to start (e.g. "transportHelicopter", "attackHelicopter")
---@return boolean # True if all mission start times were successfully set
function AmphibiousAssault.setLandingMissionStartTime(zone, zoneState, categories)
  local currentTime = GameApi.ScenEdit_CurrentTime()
  zoneState.airlandingMissionStartTime = currentTime
  local success, results = setZoneMissionStartTimes(zone, currentTime, categories)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Set landing mission start times")
  report.addAll(results)
  report.emit()

  return success
end

---Set course for LSTs to approach beach and move SAGs to staging areas
---LSTs in anchorage are directed to landing zones; RORO ships and barges remain in anchorage
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean # True if all LST courses were successfully set
function AmphibiousAssault.setCoursesForLSTs(zone, units)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Set courses for LSTs")

  local success, results = setZoneLSTCourses(zone, units)
  report.addAll(results)

  if success then
    local sagResults
    success, sagResults = setZoneSAGCourses(zone.sags)
    report.addAll(sagResults)
  end

  report.emit()

  return success
end

---Count enemy ground force contacts in the air landing zone
---Only counts contacts of type FACILITY_MOBILE to assess landing zone threat level
---@param contacts CMO__Contact[]
---@param area CMO__ReferencePoint[]
---@return integer # Number of enemy ground units in the area
function AmphibiousAssault.countContactsInArea(contacts, area)
  local count = 0
  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      count = count + 1
    end
  end
  return count
end

---Count landed China units by type in each operational zone's CAS area
---@param zones SBJ__OperationalZoneDescriptor[]
---@return table<string, table<string, number>> # Unit counts keyed by zone name, then by unit type label
function AmphibiousAssault.countUnitsInEachArea(zones)
  local unitsFromRed = GameApi.VP_GetSide({ side = constants.SIDES.RED }).units
  local result = {}

  for _, zone in ipairs(zones) do
    local item = {}
    for _, unitType in ipairs(LANDED_UNIT_TYPES) do
      item[unitType.name] = 0
    end

    for _, u in ipairs(unitsFromRed) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if unit and unit:inArea(zone.air.casArea) then
        for _, unitType in ipairs(LANDED_UNIT_TYPES) do
          if unit.dbid == unitType.dbid then
            item[unitType.name] = item[unitType.name] + 1
          end
        end
      end
    end

    result[zone.name] = item
  end

  return result
end

---Launch Amphibious Combat Vehicles (ACVs) from an amphibious ship
---Spawns ZBD-05 and ZTD-05 amphibious vehicles abreast of the ship, within the per-type quota
---@param params SBJ__ACVDeploymentParams
---@return SBJ__LaunchACVResult|nil # nil when the ship is missing or destroyed
function AmphibiousAssault.launchACV(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end

  local hasCargo, hasQuotaForCargo = false, false
  for _, acvType in ipairs(ACV_TYPES) do
    if countCargo(ship, acvType.dbid) > 0 then
      hasCargo = true
      hasQuotaForCargo = hasQuotaForCargo or (params.quota[acvType.key] or 0) > 0
    end
  end

  if not hasCargo then
    return { count = 0, isEmpty = true, isPaused = false }
  end
  if not hasQuotaForCargo then
    return { count = 0, isEmpty = false, isPaused = true }
  end

  local acvLocations = GameUtils.buildLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance
  })

  local allocations = removeCargoByPriority(ship, params.num, params.quota)
  local count, results = createAllocatedACVs(allocations, acvLocations, params.routeACV)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_ASSAULT, "ship=" .. (ship.name or ship.guid), "Launch ACV")
  report.addAll(results)
  report.emit()

  return { count = count, isEmpty = false, isPaused = false }
end

---Check if a ship is a ferry or Landing Ship Tank (LST)
---Includes Type 071/072/073 and ferries capable of launching ACVs or beaching
---@param ship CMO__Unit
---@return boolean # True if ship is a ferry or LST
function AmphibiousAssault.isFerryOrLST(ship)
  return FERRY_OR_LST_DBIDS[ship.dbid] == true or ship.name == FERRY_NAME
end

---Get the operational zone for a ship based on its location
---Matches ship position against ACV deployment areas to retrieve zone-specific configuration
---@param zones SBJ__OperationalZoneDescriptor[]
---@param ship CMO__Unit
---@return SBJ__OperationalZoneDescriptor|nil # Operation zone descriptor, or nil if ship not in any zone
function AmphibiousAssault.getShipZone(zones, ship)
  for _, zone in ipairs(zones) do
    if ship:inArea(zone.landing.acv.area) then
      return zone
    end
  end

  return nil
end

return AmphibiousAssault
