local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local ShipMovement = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

---@type {key: string, dbid: number}[]
local SHIP_TYPE_DBIDS = {
  { key = "type075",    dbid = constants.PLATFORMS.TYPE_075 },
  { key = "type076",    dbid = constants.PLATFORMS.TYPE_076 },
  { key = "type072iii", dbid = constants.PLATFORMS.TYPE_072III },
  { key = "type072a",   dbid = constants.PLATFORMS.TYPE_072A },
  { key = "type073a",   dbid = constants.PLATFORMS.TYPE_073A },
  { key = "type071",    dbid = constants.PLATFORMS.TYPE_071 },
  { key = "type082",    dbid = constants.PLATFORMS.TYPE_082 }
}

---@type table<string, string>
local NAME_TO_KEY = {
  Ferry = "ferry",
  RORO  = "roro",
  Barge = "barge",
}

local SAG_FORMATION = {
  FLANK_DISTANCE  = 1.5,
  TRAIL_DISTANCE  = 1.5,
  PORT_ANGLE      = -45,
  STARBOARD_ANGLE = 45,
}

---@type {key: string, dbid: number}[]
local ALL_RESULT_KEYS = {
  { key = "type075",          dbid = constants.PLATFORMS.TYPE_075 },
  { key = "type071",          dbid = constants.PLATFORMS.TYPE_071 },
  { key = "type076",          dbid = constants.PLATFORMS.TYPE_076 },
  { key = "type072iii",       dbid = constants.PLATFORMS.TYPE_072III },
  { key = "type072a",         dbid = constants.PLATFORMS.TYPE_072A },
  { key = "type073a",         dbid = constants.PLATFORMS.TYPE_073A },
  { key = "type071InLSTArea", dbid = constants.PLATFORMS.TYPE_071 },
  { key = "ferry",            dbid = constants.PLATFORMS.FERRY },
  { key = "roro",             dbid = constants.PLATFORMS.FERRY },
  { key = "barge",            dbid = constants.PLATFORMS.BARGE },
  { key = "type082",          dbid = constants.PLATFORMS.TYPE_082 }
}

---@type {key: string, from: string, distanceKey: string}[]
local SHIP_ROW_LAYOUT = {
  { key = "type076",          from = "type071",          distanceKey = "verticalDistance" },
  { key = "barge",            from = "type075",          distanceKey = "distanceBetweenLSTAndLPDArea" },
  { key = "roro",             from = "barge",            distanceKey = "verticalDistance" },
  { key = "type072a",         from = "roro",             distanceKey = "verticalDistance" },
  { key = "type072iii",       from = "type072a",         distanceKey = "verticalDistance" },
  { key = "ferry",            from = "type072iii",       distanceKey = "verticalDistance" },
  { key = "type071InLSTArea", from = "ferry",            distanceKey = "verticalDistance" },
  { key = "type073a",         from = "type071InLSTArea", distanceKey = "verticalDistance" },
  { key = "type082",          from = "type073a",         distanceKey = "verticalDistance" }
}


-- ============================================================================
-- Ship Position Utilities
-- ============================================================================

---Move a ship to a target location with specified speed
---In testing mode, teleports the ship directly to the destination
---@param unit CMO__Unit
---@param location CMO__Location
---@param speed number Ship movement speed in knots
---@param isTesting boolean If true, teleports ship instantly for testing
local function moveShip(unit, location, speed, isTesting)
  unit.course = { location }
  unit.manualSpeed = speed

  if isTesting then
    GameApi.ScenEdit_SetUnit({
      guid = unit.guid,
      latitude = location.latitude,
      longitude = location.longitude,
      manualSpeed = 0
    })
  end
end

---Set ship position and heading instantly (used in testing mode)
---@param ship CMO__Unit
---@param latitude number|string
---@param longitude number|string
---@param bearing number Ship heading in degrees
local function setShipPosition(ship, latitude, longitude, bearing)
  GameApi.ScenEdit_SetUnit({
    guid = ship.guid,
    latitude = latitude,
    longitude = longitude,
    heading = bearing,
  })
end

---Calculate a new position from a starting point given bearing and distance
---@param latitude number|string
---@param longitude number|string
---@param bearing number Direction in degrees (0-360)
---@param distance number Distance in nautical miles
---@return CMO__Location # New position coordinates
local function getNextPosition(latitude, longitude, bearing, distance)
  return GameApi.World_GetPointFromBearing({
    latitude = latitude,
    longitude = longitude,
    bearing = bearing,
    distance = distance,
  })
end

-- ============================================================================
-- Ship Type Movement
-- ============================================================================

---Get pre-calculated movement result for an operation
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>|nil
---@param operationName string
---@return table<string, SBJ__ShipCalculationState>|nil result Operation movement result
---@return table<string, any>|nil errorFields Log fields describing the failure
local function getOperationResult(calculationResult, operationName)
  if not calculationResult then
    return nil, { reason = "calculation_result_missing" }
  end

  local operationResult = calculationResult[operationName]
  if not operationResult or not operationResult.result then
    return nil, { reason = "calculation_result_missing" }
  end

  return operationResult.result
end

---Move ship to next pre-calculated location and increment index
---@param unit CMO__Unit
---@param resultEntry SBJ__ShipCalculationState|nil
---@param resultKey string
---@param params {speed: number, isTesting: boolean} Ship speed in knots and testing mode flag
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveShipToNextLocation(unit, resultEntry, resultKey, params)
  if not resultEntry or not resultEntry.locations or not resultEntry.locationIndex then
    return {
      tag = "FAIL",
      fields = { ship = unit.name, dbid = unit.dbid, dest = resultKey, reason = "calculation_entry_missing" }
    }
  end

  local index = resultEntry.locationIndex
  local location = resultEntry.locations[index]
  if not location then
    return {
      tag = "SKIP",
      fields = { ship = unit.name, dbid = unit.dbid, dest = resultKey, index = index, reason = "no_location" }
    }
  end

  moveShip(unit, location, params.speed, params.isTesting)
  resultEntry.locationIndex = index + 1
  return {
    tag = "OK",
    fields = { ship = unit.name, dbid = unit.dbid, dest = resultKey, index = index }
  }
end

---Handle Type 071 movement with overflow to LST area
---@param unit CMO__Unit
---@param result table<string, SBJ__ShipCalculationState>
---@param speed number
---@param isTesting boolean
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveType071(unit, result, speed, isTesting)
  local entry = result.type071
  local lstEntry = result.type071InLSTArea
  if not entry or not entry.locations or not entry.locationIndex or not lstEntry or not lstEntry.locations then
    return {
      tag = "FAIL",
      fields = { ship = unit.name, dbid = unit.dbid, dest = "type071", reason = "calculation_entry_missing" }
    }
  end

  local index = entry.locationIndex
  local len = #entry.locations
  local location
  if index > len then
    location = lstEntry.locations[index - len]
  else
    location = entry.locations[index]
  end
  if not location then
    return {
      tag = "SKIP",
      fields = { ship = unit.name, dbid = unit.dbid, dest = "type071", index = index, reason = "no_location" }
    }
  end

  moveShip(unit, location, speed, isTesting)
  entry.locationIndex = index + 1
  return {
    tag = "OK",
    fields = {
      ship = unit.name,
      dbid = unit.dbid,
      dest = "type071",
      area = index > len and "LST" or "LPD",
      index = index
    }
  }
end

---Match ship by DBID or name and move to next location
---@param unit CMO__Unit
---@param result table<string, SBJ__ShipCalculationState>
---@param speed number
---@param isTesting boolean
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveMatchingShip(unit, result, speed, isTesting)
  local params = { speed = speed, isTesting = isTesting }
  for _, entry in ipairs(SHIP_TYPE_DBIDS) do
    if unit.dbid == entry.dbid then
      if entry.key == "type071" then
        return moveType071(unit, result, speed, isTesting)
      end
      return moveShipToNextLocation(unit, result[entry.key], entry.key, params)
    end
  end

  local nameKey = NAME_TO_KEY[unit.name]
  if nameKey then
    return moveShipToNextLocation(unit, result[nameKey], nameKey, params)
  end

  return { tag = "SKIP", fields = { ship = unit.name, dbid = unit.dbid, reason = "unmatched" } }
end

-- ============================================================================
-- SAG Formation Positioning
-- ============================================================================

---Handle Surface Action Group (SAG) movement to anchorage area
---Positions SAG ships in formation: Type 052D destroyers center, Type 054A frigates at flanks
---@param descriptor SBJ__SAGDescriptor
---@param heading number Zone heading the SAG faces at anchorage
---@param isTesting boolean If true, enables testing mode with instant teleportation
---@return SBJ__LogResult # Deferred log result describing the outcome
local function processSAG(descriptor, heading, isTesting)
  local anchorageArea = descriptor.to and descriptor.to.anchorageArea
  if not anchorageArea or #anchorageArea == 0 then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "anchorage_area_missing" } }
  end

  local anchoragePoint = anchorageArea[#anchorageArea]
  if not anchoragePoint or not anchoragePoint.latitude or not anchoragePoint.longitude then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "anchorage_point_missing" } }
  end

  local unit = GameApi.ScenEdit_GetUnit(descriptor.groupName)
  if not unit then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "sag_group_not_found" } }
  end

  unit.course = anchorageArea

  if not isTesting then
    return { tag = "OK", fields = { sag = descriptor.groupName, action = "course_set" } }
  end

  if not unit.group or not unit.group.unitlist then
    return { tag = "FAIL", fields = { sag = descriptor.groupName, reason = "sag_unitlist_missing" } }
  end

  unit.course = nil
  local type052d, type054a = 0, 0
  local positioned, skipped = 0, 0

  for _, guid in ipairs(unit.group.unitlist) do
    local ship = GameApi.ScenEdit_GetUnit(guid)

    if not ship then
      skipped = skipped + 1
    elseif ship.dbid == constants.PLATFORMS.TYPE_052D then
      if type052d == 0 then
        setShipPosition(
          ship,
          anchoragePoint.latitude,
          anchoragePoint.longitude,
          heading
        )
        positioned = positioned + 1
      else
        local point = getNextPosition(
          anchoragePoint.latitude,
          anchoragePoint.longitude,
          heading - 180,
          SAG_FORMATION.TRAIL_DISTANCE
        )
        if point then
          setShipPosition(ship, point.latitude, point.longitude, heading)
          positioned = positioned + 1
        else
          skipped = skipped + 1
        end
      end

      type052d = type052d + 1
    elseif ship.dbid == constants.PLATFORMS.TYPE_054A then
      local angle = (type054a == 0) and SAG_FORMATION.PORT_ANGLE or SAG_FORMATION.STARBOARD_ANGLE
      local point = getNextPosition(
        anchoragePoint.latitude,
        anchoragePoint.longitude,
        heading - angle,
        SAG_FORMATION.FLANK_DISTANCE
      )
      if point then
        setShipPosition(ship, point.latitude, point.longitude, heading)
        positioned = positioned + 1
      else
        skipped = skipped + 1
      end
      type054a = type054a + 1
    else
      skipped = skipped + 1
    end
  end

  return {
    tag = "OK",
    fields = {
      sag = descriptor.groupName,
      action = "course_set",
      positioned = positioned,
      skipped = skipped
    }
  }
end

-- ============================================================================
-- Destination Calculation
-- ============================================================================

---Initialize calculation result structure for an operation
---@param operationName string
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>
local function initOperationResult(operationName, calculationResult)
  if calculationResult[operationName] then return end
  local result = {}
  for _, entry in ipairs(ALL_RESULT_KEYS) do
    result[entry.key] = { locations = {}, locationIndex = 1, dbid = entry.dbid }
  end
  calculationResult[operationName] = { name = operationName, result = result }
end

---Get a required reference point for a ship row
---@param startingPoints SBJ__StartingPoints
---@param key string
---@return CMO__Location|nil point Reference point
---@return table<string, any>|nil errorFields Log fields describing the failure
local function getStartingReferencePoint(startingPoints, key)
  local startingPointArea = startingPoints and startingPoints[key]
  if not startingPointArea then
    return nil, { point = key, reason = "starting_point_area_missing" }
  end

  local points = GameApi.ScenEdit_GetReferencePoints({
    side = constants.SIDES.RED, area = startingPointArea
  })

  if not points or not points[1] then
    return nil, { point = key, reason = "reference_point_missing" }
  end

  return points[1]
end

---Calculate starting points for all ship types from two reference points
---@param startingPoints SBJ__StartingPoints
---@param heading number Bearing the ship rows are stacked along
---@param formationSettings SBJ__AmphibiousFormationConfig
---@return table<string, CMO__Location>|nil startingPointMap Mapping of key to starting location
---@return table<string, any>|nil errorFields Log fields describing the failure
local function calculateStartingPoints(startingPoints, heading, formationSettings)
  local startingPointMap = {}
  local errorFields

  startingPointMap.type075, errorFields = getStartingReferencePoint(startingPoints, "type075")
  if not startingPointMap.type075 then return nil, errorFields end

  startingPointMap.type071, errorFields = getStartingReferencePoint(startingPoints, "type071")
  if not startingPointMap.type071 then return nil, errorFields end

  for _, row in ipairs(SHIP_ROW_LAYOUT) do
    local fromPoint = startingPointMap[row.from]
    if not fromPoint then
      return nil, { point = row.key, from = row.from, reason = "source_point_missing" }
    end

    startingPointMap[row.key] = GameApi.World_GetPointFromBearing({
      latitude = fromPoint.latitude,
      longitude = fromPoint.longitude,
      bearing = heading,
      distance = formationSettings[row.distanceKey],
    })

    if not startingPointMap[row.key] then
      return nil, { point = row.key, from = row.from, reason = "derived_point_failed" }
    end
  end

  return startingPointMap
end

---Generate and append locations for all ship types in an area
---@param opResult table<string, SBJ__ShipCalculationState>
---@param startingPointMap table<string, CMO__Location>
---@param shipCounts SBJ__FleetCompositionConfig
---@param heading number Zone heading; ships of one type line up perpendicular to it
---@param formationSettings SBJ__AmphibiousFormationConfig
local function buildAllShipLocations(opResult, startingPointMap, shipCounts, heading, formationSettings)
  for _, entry in ipairs(ALL_RESULT_KEYS) do
    Utils.addAll(
      opResult[entry.key].locations,
      GameUtils.buildLocations({
        initialLocation = startingPointMap[entry.key],
        num = shipCounts[entry.key],
        bearing = heading - formationSettings.rowBearingOffset,
        distance = formationSettings.horizontalDistance,
      })
    )
  end
end

---Pre-calculate all destination positions for amphibious assault ships
---Generates grid of anchorage positions for each ship type with layered arrangement and spacing
---@param zones SBJ__OperationalZoneDescriptor[]
---@param formationSettings SBJ__AmphibiousFormationConfig
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>
---@return boolean # True if all destination positions were calculated
function ShipMovement.calculateDestination(zones, formationSettings, calculationResult)
  for _, zone in ipairs(zones) do
    for groupIndex, group in ipairs(zone.fleet.groups) do
      initOperationResult(zone.name, calculationResult)
      local startingPointMap, errorFields =
          calculateStartingPoints(group.to.startingPoints, zone.heading, formationSettings)
      if not startingPointMap then
        Logger.error(LogFormat.line("ERROR", LogFormat.merge(
          { operation = zone.name, areaIndex = groupIndex },
          errorFields or { reason = "starting_point_calculation_failed" })))
        return false
      end

      buildAllShipLocations(
        calculationResult[zone.name].result,
        startingPointMap, group.shipCounts, zone.heading, formationSettings
      )
    end
  end

  return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Move amphibious assault ships from staging area to designated anchorage positions for a single zone
---Routes ships to pre-calculated positions by class and coordinates Surface Action Group movements
---@param zone SBJ__OperationalZoneDescriptor
---@param calculationResult table<string, SBJ__OperationZoneCalculationState> Pre-calculated destination positions indexed by zone name
---@param filteredUnits CMO__SideUnit[]
---@param formationSettings SBJ__AmphibiousFormationConfig
---@param isTesting boolean If true, enables testing mode with instant teleportation
---@return boolean # True when all movement orders have been issued
function ShipMovement.moveToStagingArea(zone, calculationResult, filteredUnits, formationSettings, isTesting)
  local result, errorFields = getOperationResult(calculationResult, zone.name)

  if not result then
    Logger.error(LogFormat.line("ERROR", LogFormat.merge(
      { operation = zone.name },
      errorFields or { reason = "calculation_result_missing" })))
    return false
  end

  local results = {}

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit and unit:inArea(zone.fleet.stagingArea) then
      table.insert(results, moveMatchingShip(unit, result, formationSettings.shipSpeed, isTesting))
    end
  end

  for _, descriptor in ipairs(zone.sags) do
    table.insert(results, processSAG(descriptor, zone.heading, isTesting))
  end

  local report = LogFormat.report(constants.TAGS.SHIP_MOVEMENT, "operation=" .. zone.name, "Move to staging area")
  report.addAll(results)
  report.emit()

  return not LogFormat.hasFailure(results)
end

return ShipMovement
