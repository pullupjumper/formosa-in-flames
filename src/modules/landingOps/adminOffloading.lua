local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")

local AdminOffloading = {}

-- ============================================================================
-- Constants
-- ============================================================================


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

---Build the course for a barge to reach the offload area.
---Project the barge position onto the LST approach bearing line with spherical geometry.
---@param zone SBJ__OperationalZoneDescriptor
---@param unit CMO__Unit
---@return CMO__Waypoint[]|nil # Destination waypoint, or nil on error
local function buildCourseForBarge(zone, unit)
  local points = GameApi.ScenEdit_GetReferencePoints({ side = constants.SIDES.RED, area = zone.landing.offloadArea })

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

  local b2 = math.abs(zone.heading - b1)
  local d2 = d1 * math.cos(b2 * 2 * math.pi / 360)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    distance = d2,
    bearing = zone.heading
  })

  if not destination then
    return nil
  end

  return destination
end

---Build the course for a RORO ship to follow the barge to the beach.
---Return a two-waypoint course: the first at the LST approach distance, the second at the barge destination.
---@param zone SBJ__OperationalZoneDescriptor
---@param unit CMO__Unit
---@param bargeDest CMO__Waypoint[] Barge's destination waypoint
---@return CMO__Waypoint[]|nil # Two-waypoint course (approach, then barge position), or nil on error
local function buildCourseForRORO(zone, unit, bargeDest)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    distance = zone.landing.lstSettings.distance,
    bearing = zone.heading
  })

  if not destination then
    return nil
  end

  return { destination, bargeDest }
end

-- ============================================================================
-- Unit Classification and Processing
-- ============================================================================

---Process a barge unit for admin offloading.
---Create the course, set the speed, and add the barge to the barge registry.
---@param unit CMO__Unit
---@param zone SBJ__OperationalZoneDescriptor
---@param barges table<string, SBJ__BargeState> Barge registry indexed by barge GUID
---@return CMO__Waypoint[]|nil dest Barge destination for RORO pairing, nil when the course failed
---@return SBJ__LogResult result Deferred log result describing the outcome
local function processBarge(unit, zone, barges)
  local destination = buildCourseForBarge(zone, unit)

  if not destination then
    return nil, {
      tag = "SKIP",
      fields = { ship = unit.name, guid = unit.guid, reason = "course_calculation_failed" }
    }
  end

  unit.course = { destination }
  unit.manualSpeed = zone.landing.lstSettings.speed
  barges[unit.guid] = { guid = unit.guid, roros = {} }
  return destination, {
    tag = "OK",
    fields = { ship = unit.name, guid = unit.guid, action = "course_set" }
  }
end

---Pair a RORO ship with a barge for the logistics chain.
---Add the RORO to the roros list of the barge and set the RORO course.
---@param roroEntry { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor }
---@param bargeEntry SBJ__BargeEntry
---@param barges table<string, SBJ__BargeState> Barge registry indexed by barge GUID
---@return SBJ__LogResult # Deferred log result describing the outcome
local function pairROROWithBarge(roroEntry, bargeEntry, barges)
  table.insert(barges[bargeEntry.unit.guid].roros, roroEntry.unit.guid)
  local course = buildCourseForRORO(roroEntry.zone, roroEntry.unit, bargeEntry.dest)

  if not course then
    return {
      tag = "SKIP",
      fields = {
        ship = roroEntry.unit.name,
        guid = roroEntry.unit.guid,
        barge = bargeEntry.unit.guid,
        reason = "roro_course_failed"
      }
    }
  end

  roroEntry.unit.course = course
  roroEntry.unit.manualSpeed = roroEntry.zone.landing.lstSettings.speed
  return {
    tag = "OK",
    fields = {
      ship = roroEntry.unit.name,
      guid = roroEntry.unit.guid,
      barge = bargeEntry.unit.guid,
      action = "paired"
    }
  }
end

-- ============================================================================
-- Vehicle Offloading
-- ============================================================================

---Find cargo items on a ship, up to the given count
---@param ship CMO__Unit
---@param num number
---@return SBJ__CargoItem[] # Cargo items found
local function findCargoItems(ship, num)
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

---Create one offloaded vehicle at the given location
---@param ship CMO__Unit
---@param item SBJ__CargoItem
---@param location CMO__Location
---@param index integer
---@return SBJ__LogResult # Deferred log result describing the outcome
local function createOffloadedVehicle(ship, item, location, index)
  ship:deleteUnitCargo(item.guid)
  local unitType = CARGO_TYPE_MAP[item.type] or DEFAULT_CARGO_TYPE

  local vehicle = GameApi.ScenEdit_AddUnit({
    side      = constants.SIDES.RED,
    type      = unitType,
    latitude  = location.latitude,
    longitude = location.longitude,
    dbid      = item.dbid,
    unitname  = item.name,
  })

  if not vehicle then
    return {
      tag = "FAIL",
      fields = { unit = item.name, dbid = item.dbid, index = index, reason = "add_unit_failed" }
    }
  end

  return {
    tag = "OK",
    fields = { unit = item.name, type = unitType, dbid = item.dbid, index = index }
  }
end

---Create every extracted cargo item as a vehicle. Stop at the first failure.
---@param ship CMO__Unit
---@param cargoItems SBJ__CargoItem[]
---@param locations CMO__Location[]
---@return integer|nil count Vehicles offloaded, nil when a spawn failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function createOffloadedVehicles(ship, cargoItems, locations)
  local results = {}

  for index, item in ipairs(cargoItems) do
    local result = createOffloadedVehicle(ship, item, locations[index], index)
    table.insert(results, result)

    if result.tag == "FAIL" then
      return nil, results
    end
  end

  return #results, results
end

-- ============================================================================
-- Public API: Queries
-- ============================================================================

---Check if the logistics bridge of a barge is destroyed.
---The bridge GUID must exist and its unit must be destroyed.
---@param barges table<string, SBJ__BargeState> Barge registry indexed by barge GUID
---@param ship CMO__Unit
---@return boolean # True if the bridge was created and is now destroyed
function AdminOffloading.isBridgeDestroyed(barges, ship)
  if barges[ship.guid] and barges[ship.guid].bridgeGUID then
    local bridge = GameApi.ScenEdit_GetUnit(barges[ship.guid].bridgeGUID)

    if not bridge then
      return true
    end

    return false
  end

  return true
end

---Check if a barge has an extended logistics bridge.
---The barge creates the bridge when it reaches the offload position for vehicle transfer.
---@param barges table<string, SBJ__BargeState> Barge registry indexed by barge GUID
---@param ship CMO__Unit
---@return boolean # True if barge has an active bridge GUID
function AdminOffloading.hasExtendedBridge(barges, ship)
  return barges[ship.guid].bridgeGUID ~= nil
end

---Get the operational zone for a barge-RORO pair.
---The units must be in the same ACV area and closer than pairingRangeNm to each other.
---@param zones SBJ__OperationalZoneDescriptor[]
---@param barge CMO__Unit
---@param roro CMO__Unit
---@param pairingRangeNm number
---@return SBJ__OperationalZoneDescriptor|nil # Zone descriptor, or nil if the units are not in position
function AdminOffloading.getBargeROROZone(zones, barge, roro, pairingRangeNm)
  for _, zone in ipairs(zones) do
    local distance = GameApi.Tool_Range(roro.guid, barge.guid)

    if distance and roro:inArea(zone.landing.acv.area) and barge:inArea(zone.landing.acv.area) and distance < pairingRangeNm then
      return zone
    end
  end

  return nil
end

-- ============================================================================
-- Public API: Operations
-- ============================================================================

---Start admin offloading in a single zone.
---Direct barges to the offload areas and RORO ships to follow. This creates the logistics chain RORO -> Barge -> Beach.
---@param zone SBJ__OperationalZoneDescriptor
---@param barges table<string, SBJ__BargeState> Barge registry indexed by barge GUID
---@param filteredUnits CMO__SideUnit[]
---@return boolean # True if admin offloading started
function AdminOffloading.startAdminOffloading(zone, barges, filteredUnits)
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor }[]
  local roros = {}
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor, dest: CMO__Waypoint[] }[]
  local bargeEntries = {}
  local report = LogFormat.report(constants.TAGS.ADMIN_OFFLOADING, "zone=" .. zone.name, "Admin offloading")

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit then
      if unit.name == SHIP_NAMES.BARGE and unit.type == "Ship" and unit:inArea(zone.movement.holdingAreas.deployLine) then
        local dest, result = processBarge(unit, zone, barges)
        report.add(result.tag, result.fields)
        if dest then
          table.insert(bargeEntries, { unit = unit, zone = zone, dest = dest })
        end
      end

      if unit.name == SHIP_NAMES.RORO and unit.type == "Ship" and unit:inArea(zone.movement.holdingAreas.deployLine) then
        table.insert(roros, { unit = unit, zone = zone })
      end
    end
  end

  for _, roro in ipairs(roros) do
    for _, barge in ipairs(bargeEntries) do
      if barge.unit:inArea(roro.zone.movement.holdingAreas.deployLine) then
        local result = pairROROWithBarge(roro, barge, barges)
        report.add(result.tag, result.fields)
      end
    end
  end

  report.emit()

  return true
end

---Offload vehicles from the cargo of a ship to the beach.
---Delete the cargo from the ship. Create facility units in a line at calculated positions.
---@param params SBJ__VehicleOffloadParams
---@return integer|nil # Number of vehicles offloaded, or nil on error
function AdminOffloading.offloadVehicles(params)
  local ship = params.ship
  if not ship or ship.IsDestroyed then return end

  local acvLocations = GameUtils.buildLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance,
    firstDistance = params.firstDistance
  })

  local cargoItems = findCargoItems(ship, params.num)
  local count, results = createOffloadedVehicles(ship, cargoItems, acvLocations)

  local report = LogFormat.report(
    constants.TAGS.ADMIN_OFFLOADING, "ship=" .. (ship.name or ship.guid), "Offload vehicles")
  report.addAll(results)
  report.emit()

  return count
end

return AdminOffloading
