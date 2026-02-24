local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local SecondWaveUnloading = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local SECOND_WAVE_TAG = "secondWaveUnloading"

local SHIP_NAMES = {
  BARGE = "Barge",
  RORO = "RORO",
}

---@type table<number, string>
local CARGO_TYPE_MAP = {
  [2] = "Ground unit",
}

local DEFAULT_CARGO_TYPE = "Facility"

-- ============================================================================
-- Course Calculation
-- ============================================================================

---Calculate course for barge to reach offload area
---Projects barge position onto LST approach bearing line using spherical geometry
---@param zone SBJ__OperationalZoneDescriptor Operation zone with offload area and LST settings
---@param unit CMO__Unit Barge unit to calculate course for
---@return CMO__Waypoint[]|nil # Destination waypoint, or nil on error
local function createCourseForBarge(zone, unit)
  local points = GameApi.ScenEdit_GetReferencePoints({ side = constants.SIDES.ENEMY, area = zone.offloadArea })

  if not points then
    return nil
  end

  local centerPoint = Utils.calculateSphericalCenter(points)

  if not centerPoint then
    return nil
  end

  local d1 = GameApi.Tool_Range({ latitude = unit.latitude, longitude = unit.longitude }, centerPoint)

  if not d1 then
    return nil
  end

  local b1 = GameApi.Tool_Bearing({ latitude = unit.latitude, longitude = unit.longitude }, centerPoint)

  if not b1 then
    return nil
  end

  local b2 = math.abs(zone.lstSettings.course.bearing - b1)
  local d2 = d1 * math.cos(b2 * 2 * math.pi / 360)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    distance = d2,
    bearing = zone.lstSettings.course.bearing
  })

  if not destination then
    return nil
  end

  return destination
end

---Calculate course for RORO ship to follow barge to beach
---Returns two-waypoint course: first at LST approach distance, second at barge destination
---@param zone SBJ__OperationalZoneDescriptor Operation zone with LST settings
---@param unit CMO__Unit RORO ship unit to calculate course for
---@param bargeDest CMO__Waypoint[] Barge's destination waypoint
---@return CMO__Waypoint[]|nil # Two-waypoint course (approach, then barge position), or nil on error
local function createCourseForRORO(zone, unit, bargeDest)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    distance = zone.lstSettings.course.distance,
    bearing = zone.lstSettings.course.bearing
  })

  if not destination then
    return nil
  end

  return { destination, bargeDest }
end

-- ============================================================================
-- Unit Classification and Processing
-- ============================================================================

---Process a barge unit for second wave unloading
---Creates course, sets speed, and registers barge in saveData
---@param unit CMO__Unit Barge unit to process
---@param zone SBJ__OperationalZoneDescriptor Operation zone descriptor
---@param saveData SBJ__SaveData Save data to track barge
---@return string tag Result tag (OK/SKIP)
---@return string msg Description
---@return CMO__Waypoint[]|nil dest Barge destination for RORO pairing
local function processBarge(unit, zone, saveData)
  local destination = createCourseForBarge(zone, unit)

  if not destination then
    return "SKIP", string.format("Course calculation failed: %s", unit.guid)
  end

  unit.course = { destination }
  unit.manualSpeed = zone.lstSettings.speed
  saveData.c.amphibOps.barges[unit.guid] = { guid = unit.guid, roros = {} }
  return "OK", string.format("%s → course set", unit.guid), destination
end

---Pair a RORO ship with a barge for logistics chain
---Registers RORO under barge's roros list and sets RORO course
---@param roroEntry { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor } RORO entry
---@param bargeEntry { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor, dest: CMO__Waypoint[] } Barge entry
---@param saveData SBJ__SaveData Save data to track RORO-barge relationship
---@return string tag Result tag (OK/SKIP)
---@return string msg Description
local function pairROROWithBarge(roroEntry, bargeEntry, saveData)
  table.insert(saveData.c.amphibOps.barges[bargeEntry.unit.guid].roros, roroEntry.unit.guid)
  local course = createCourseForRORO(roroEntry.zone, roroEntry.unit, bargeEntry.dest)

  if not course then
    return "SKIP", string.format("RORO course failed: %s", roroEntry.unit.guid)
  end

  roroEntry.unit.course = course
  roroEntry.unit.manualSpeed = roroEntry.zone.lstSettings.speed
  return "OK", string.format("RORO %s → paired with %s", roroEntry.unit.guid, bargeEntry.unit.guid)
end

-- ============================================================================
-- Vehicle Offloading
-- ============================================================================

---Extract cargo items from ship up to specified count
---@param ship CMO__Unit Ship to extract cargo from
---@param num number Maximum number of items to extract
---@return { guid: string, dbid: number, name: string, type: number }[] # Extracted cargo items
local function extractCargoItems(ship, num)
  local cargoItems = {}
  local count = 0

  for _, item in ipairs(ship.cargo[1].cargo) do
    table.insert(cargoItems, { guid = item.guid, dbid = item.dbid, name = item.name, type = item.Type })
    count = count + 1

    if count == num then
      break
    end
  end

  return cargoItems
end

---Spawn a single offloaded vehicle at the specified location
---@param ship CMO__Unit Ship to delete cargo from
---@param item { guid: string, dbid: number, name: string, type: number } Cargo item to spawn
---@param location CMO__Location Spawn coordinates
---@return string tag Result tag (OK/FAIL)
---@return string msg Description
local function spawnOffloadedVehicle(ship, item, location)
  ship:deleteUnitCargo(item.guid)
  local unitType = CARGO_TYPE_MAP[item.type] or DEFAULT_CARGO_TYPE

  local vehicle = GameApi.ScenEdit_AddUnit({
    side      = constants.SIDES.ENEMY,
    type      = unitType,
    latitude  = location.latitude,
    longitude = location.longitude,
    dbid      = item.dbid,
    unitname  = item.name,
  })

  if not vehicle then
    return "FAIL", string.format("AddUnit failed: %s", item.name)
  end

  return "OK", string.format("%s spawned as %s", item.name, unitType)
end

-- ============================================================================
-- Public API: Queries
-- ============================================================================

---Check if a barge's logistics bridge has been destroyed
---Returns true if bridge GUID exists but unit is destroyed
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if bridge was created but is now destroyed
function SecondWaveUnloading.isBridgeDestroyed(saveData, ship)
  if saveData.c.amphibOps.barges[ship.guid] and saveData.c.amphibOps.barges[ship.guid].bridgeGUID then
    local bridge = GameApi.ScenEdit_GetUnit(saveData.c.amphibOps.barges[ship.guid].bridgeGUID)

    if not bridge then
      return true
    end

    return false
  end

  return true
end

---Check if a barge has an extended logistics bridge
---Bridge is created when barge reaches offload position for vehicle transfer operations
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if barge has an active bridge GUID
function SecondWaveUnloading.hasExtendedBridge(saveData, ship)
  return saveData.c.amphibOps.barges[ship.guid].bridgeGUID ~= nil
end

---Get the operational zone for a barge-RORO pair
---Checks if both units are in same ACV area and within 1nm of each other
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param barge CMO__Unit Barge ship
---@param roro CMO__Unit RORO ship
---@return SBJ__OperationalZoneDescriptor|nil # Operation zone descriptor, or nil if units not properly positioned
function SecondWaveUnloading.getBargeROROZone(amphibOpsConfig, barge, roro)
  for _, zone in ipairs(amphibOpsConfig.operationalZones) do
    local distance = GameApi.Tool_Range(roro.guid, barge.guid)

    if distance and roro:inArea(zone.acv.area) and barge:inArea(zone.acv.area) and distance < 1 then
      return zone
    end
  end

  return nil
end

-- ============================================================================
-- Public API: Operations
-- ============================================================================

---Initiate second wave unloading operations for a single zone
---Directs barges to offload areas and RORO ships to follow, creating logistics chain RORO->Barge->Beach
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param saveData SBJ__SaveData Save data to track barge-RORO relationships
---@param filteredUnits CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if second wave unloading successfully started
function SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, filteredUnits)
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor }[]
  local roros = {}
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor, dest: CMO__Waypoint[] }[]
  local barges = {}
  local logEntries = {}

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit then
      if unit.name == SHIP_NAMES.BARGE and unit.type == "Ship" and unit:inArea(zone.lstAnchorageArea) then
        local tag, msg, dest = processBarge(unit, zone, saveData)
        table.insert(logEntries, string.format("  [%s] %s", tag, msg))
        if dest then
          table.insert(barges, { unit = unit, zone = zone, dest = dest })
        end
      end

      if unit.name == SHIP_NAMES.RORO and unit.type == "Ship" and unit:inArea(zone.lstAnchorageArea) then
        table.insert(roros, { unit = unit, zone = zone })
      end
    end
  end

  for _, roro in ipairs(roros) do
    for _, barge in ipairs(barges) do
      if barge.unit:inArea(roro.zone.lstAnchorageArea) then
        local tag, msg = pairROROWithBarge(roro, barge, saveData)
        table.insert(logEntries, string.format("  [%s] %s", tag, msg))
      end
    end
  end

  if #logEntries > 0 then
    Logger.log(SECOND_WAVE_TAG, string.format(
      "[%s] Second wave unloading: %d entries\n%s",
      zone.name, #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Offload vehicles from ship cargo to the beach
---Deletes cargo from ship and spawns facility units in line formation at calculated positions
---@param params SBJ__VehicleOffloadParams Offload parameters (ship, number, bearing, distances)
---@return integer|nil # Number of vehicles successfully offloaded, or nil on error
function SecondWaveUnloading.offloadVehicles(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end

  local ACVlocations = GameUtils.generateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance,
    firstDistance = params.firstDistance
  })

  local cargoItems = extractCargoItems(ship, params.num)
  local logEntries = {}
  local resultCount = 0

  for idx, item in ipairs(cargoItems) do
    local tag, msg = spawnOffloadedVehicle(ship, item, ACVlocations[idx])
    table.insert(logEntries, string.format("  [%s] %s", tag, msg))

    if tag == "FAIL" then
      Logger.log(SECOND_WAVE_TAG, string.format(
        "Offload vehicles: failed at #%d\n%s",
        idx, table.concat(logEntries, "\n")
      ))
      return
    end

    resultCount = resultCount + 1
  end

  if #logEntries > 0 then
    Logger.log(SECOND_WAVE_TAG, string.format(
      "Offload vehicles: %d units offloaded\n%s",
      resultCount, table.concat(logEntries, "\n")
    ))
  end

  return resultCount
end

return SecondWaveUnloading
