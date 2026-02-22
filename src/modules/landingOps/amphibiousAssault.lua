local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local AmphibiousAssault = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local AMPHIB_ASSAULT_TAG = "amphibiousAssault"

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
---@return string tag Result tag (OK/FAIL)
---@return string msg Description
local function setMissionStartTime(mission, currentTime)
  local startTime = os.date("%Y-%m-%d %H:%M:%S", (currentTime + mission.startTime))
  local m = GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, mission.name)

  if not m then
    return "FAIL", string.format("Mission not found: %s", mission.name)
  end

  m.starttime = startTime
  return "OK", string.format("%s → %s", mission.name, startTime)
end

---Set start times for all missions in a single zone
---Iterates transport helicopter, boat, and attack helicopter missions
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param currentTime number Current scenario time in seconds
---@return boolean success True if all missions were set
---@return string[] logEntries Collected log entries
local function setZoneMissionStartTimes(zone, currentTime)
  local logEntries = {}

  for _, category in ipairs(MISSION_CATEGORIES) do
    for _, mission in ipairs(zone[category].missions) do
      local tag, msg = setMissionStartTime(mission, currentTime)
      table.insert(logEntries, string.format("  [%s] %s", tag, msg))
      if tag == "FAIL" then
        return false, logEntries
      end
    end
  end

  return true, logEntries
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
---@return string tag Result tag (OK/FAIL)
---@return string msg Description
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
    return "FAIL", string.format("AddUnit failed: %s", acvType.name)
  end

  local doctrine = GameApi.ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = "no" })

  if not doctrine then
    return "FAIL", string.format("SetDoctrine failed: %s", acvType.name)
  end

  addedUnit.throttle = "Full"
  addedUnit.course = destination
  return "OK", string.format("%s spawned at (%.4f, %.4f)", acvType.name, location.latitude, location.longitude)
end

-- ============================================================================
-- Course Setting
-- ============================================================================

---Set course for an LST to approach the beach
---@param unit CMO__Unit LST ship unit
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@return string tag Result tag (OK/SKIP/FAIL)
---@return string msg Description
local function setCourseForLST(unit, zone)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    bearing = zone.lstSettings.course.bearing,
    distance = zone.lstSettings.course.distance
  })

  if not destination then
    return "FAIL", string.format("Destination calc failed: %s", unit.name)
  end

  if isLST(unit) then
    unit.course = { destination }
    unit.manualSpeed = zone.lstSettings.speed
    return "OK",
        string.format("%s → bearing %d, speed %d", unit.name, zone.lstSettings.course.bearing, zone.lstSettings.speed)
  end

  return "SKIP", string.format("%s is non-LST (auxiliary)", unit.name)
end

---Set course for a Surface Action Group
---@param descriptor table SAG descriptor with groupName and destination
---@return string tag Result tag (OK/FAIL)
---@return string msg Description
local function setCourseForSAG(descriptor)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.groupName)

  if not unit then
    return "FAIL", string.format("SAG unit not found: %s", descriptor.groupName)
  end

  unit.course = descriptor.to.amphibiousVehicleStagingArea
  return "OK", string.format("SAG %s → staging area", descriptor.groupName)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Set start times for all amphibious assault missions across all operational zones
---Configures transport helicopters, landing craft, attack helicopters and records start timestamp
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data to record mission start time
---@return boolean # True if all mission start times were successfully set
function AmphibiousAssault.setLandingMissionStartTime(amphibOpsConfig, saveData)
  local currentTime = GameApi.ScenEdit_CurrentTime()

  if not currentTime then
    return false
  end

  saveData.c.amphibOps.airlandingMissionStartTime = currentTime
  local operationalZones = amphibOpsConfig.operationalZones
  local allLogEntries = {}

  for _, zone in ipairs(operationalZones) do
    local success, logEntries = setZoneMissionStartTimes(zone, currentTime)
    for _, entry in ipairs(logEntries) do
      table.insert(allLogEntries, entry)
    end
    if not success then
      Logger.log(AMPHIB_ASSAULT_TAG, string.format(
        "Set landing mission start times: failed\n%s",
        table.concat(allLogEntries, "\n")
      ))
      return false
    end
  end

  if #allLogEntries > 0 then
    Logger.log(AMPHIB_ASSAULT_TAG, string.format(
      "Set landing mission start times: %d missions configured\n%s",
      #allLogEntries, table.concat(allLogEntries, "\n")
    ))
  end

  return true
end

---Set course for LSTs to approach beach and move SAGs to staging areas
---LSTs in anchorage are directed to landing zones; RORO ships and barges remain in anchorage
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all LST courses were successfully set
function AmphibiousAssault.setCoursesForLSTs(amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones
  local logEntries = {}

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit then
      for _, zone in ipairs(operationalZones) do
        if unit.type == "Ship" and unit:inArea(zone.lstAnchorageArea) then
          local tag, msg = setCourseForLST(unit, zone)
          table.insert(logEntries, string.format("  [%s] %s", tag, msg))
          if tag == "FAIL" then
            return false
          end
        end
      end
    end
  end

  for _, descriptor in pairs(amphibOpsConfig.sag) do
    local tag, msg = setCourseForSAG(descriptor)
    table.insert(logEntries, string.format("  [%s] %s", tag, msg))
    if tag == "FAIL" then
      return false
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_ASSAULT_TAG, string.format(
      "Set courses for LSTs: %d entries\n%s",
      #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Count enemy ground force contacts in the air landing zone
---Only counts contacts of type FACILITY_MOBILE to assess landing zone threat level
---@param contacts CMO__Contact[] Contact list from the side
---@param area CMO__ReferencePoint[] Reference points defining the air landing zone
---@return integer # Number of enemy ground units in the area
function AmphibiousAssault.countContactsInArea(contacts, area)
  return countGroundContacts(contacts, area)
end

---Launch Air Cushion Vehicles (ACVs) from an amphibious assault ship
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
  local logEntries = {}
  local index = 0
  local count = 0

  for _, allocation in ipairs(allocations) do
    for _ = 1, allocation.count do
      index = index + 1
      local tag, msg = spawnSingleACV(allocation.acvType, ACVlocations[index], destination)
      table.insert(logEntries, string.format("  [%s] %s", tag, msg))
      if tag == "FAIL" then
        Logger.log(AMPHIB_ASSAULT_TAG, string.format(
          "Launch ACV from %s: failed at #%d\n%s",
          ship.name, index, table.concat(logEntries, "\n")
        ))
        return
      end
      count = count + 1
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_ASSAULT_TAG, string.format(
      "Launch ACV from %s: %d vehicles deployed\n%s",
      ship.name, count, table.concat(logEntries, "\n")
    ))
  end

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
