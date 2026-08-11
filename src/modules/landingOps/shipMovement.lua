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
}


-- ============================================================================
-- Ship Position Utilities
-- ============================================================================

---Move a ship to a target location with specified speed
---In testing mode, teleports the ship directly to the destination
---@param unit CMO__Unit The ship unit to move
---@param location CMO__Location Target destination coordinates
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
---@param ship CMO__Unit The ship unit to reposition
---@param latitude number|string Latitude coordinate
---@param longitude number|string Longitude coordinate
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
---@param latitude number|string Starting latitude
---@param longitude number|string Starting longitude
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
---@param calculationResult table<string, SBJ__OperationZoneCalculationResult>|nil Calculation result lookup
---@param operationName string Operation name
---@return table<string, SBJ__ShipCalculationResult>|nil result Operation movement result
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
---@param unit CMO__Unit Ship unit
---@param resultEntry SBJ__ShipCalculationResult|nil Calculation result entry
---@param resultKey string Result key used for destination lookup
---@param speed number Ship speed in knots
---@param isTesting boolean Testing mode flag
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveShipToNextLocation(unit, resultEntry, resultKey, speed, isTesting)
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

  moveShip(unit, location, speed, isTesting)
  resultEntry.locationIndex = index + 1
  return {
    tag = "OK",
    fields = { ship = unit.name, dbid = unit.dbid, dest = resultKey, index = index }
  }
end

---Handle Type 071 movement with overflow to LST area
---@param unit CMO__Unit The Type 071 ship
---@param result table<string, SBJ__ShipCalculationResult> Full result table
---@param speed number Ship speed
---@param isTesting boolean Testing mode flag
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
---@param unit CMO__Unit Ship unit
---@param result table<string, SBJ__ShipCalculationResult> Calculation results
---@param speed number Ship speed
---@param isTesting boolean Testing mode flag
---@return SBJ__LogResult # Deferred log result describing the outcome
local function matchAndMoveShip(unit, result, speed, isTesting)
  for _, entry in ipairs(SHIP_TYPE_DBIDS) do
    if unit.dbid == entry.dbid then
      if entry.key == "type071" then
        return moveType071(unit, result, speed, isTesting)
      end
      return moveShipToNextLocation(unit, result[entry.key], entry.key, speed, isTesting)
    end
  end

  local nameKey = NAME_TO_KEY[unit.name]
  if nameKey then
    return moveShipToNextLocation(unit, result[nameKey], nameKey, speed, isTesting)
  end

  return { tag = "SKIP", fields = { ship = unit.name, dbid = unit.dbid, reason = "unmatched" } }
end

-- ============================================================================
-- SAG Formation Positioning
-- ============================================================================

---Handle Surface Action Group (SAG) movement to anchorage area
---Positions SAG ships in formation: Type 052D destroyers center, Type 054A frigates at flanks
---@param descriptor SBJ__SAGDescriptor SAG group descriptor with destination and unit list
---@param isTesting boolean If true, enables testing mode with instant teleportation
---@return SBJ__LogResult # Deferred log result describing the outcome
local function handleSAG(descriptor, isTesting)
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
          descriptor.to.heading
        )
        positioned = positioned + 1
      else
        local point = getNextPosition(
          anchoragePoint.latitude,
          anchoragePoint.longitude,
          descriptor.to.heading - 180,
          SAG_FORMATION.TRAIL_DISTANCE
        )
        if point then
          setShipPosition(ship, point.latitude, point.longitude, descriptor.to.heading)
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
        descriptor.to.heading - angle,
        SAG_FORMATION.FLANK_DISTANCE
      )
      if point then
        setShipPosition(ship, point.latitude, point.longitude, descriptor.to.heading)
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
---@param operationName string Operation name
---@param calculationResult table<string, SBJ__OperationZoneCalculationResult> Target table
local function initOperationResult(operationName, calculationResult)
  if calculationResult[operationName] then return end
  local result = {}
  for _, entry in ipairs(ALL_RESULT_KEYS) do
    result[entry.key] = { locations = {}, locationIndex = 1, dbid = entry.dbid }
  end
  calculationResult[operationName] = { name = operationName, result = result }
end

---Get a required reference point for a ship row
---@param area SBJ__OperationAreaDescriptor Area configuration
---@param key string Starting point key
---@return CMO__Location|nil point Reference point
---@return table<string, any>|nil errorFields Log fields describing the failure
local function getStartingReferencePoint(area, key)
  local startingPointArea = area.startingPoints and area.startingPoints[key]
  if not startingPointArea then
    return nil, { point = key, reason = "starting_point_area_missing" }
  end

  local points = GameApi.ScenEdit_GetReferencePoints({
    side = constants.SIDES.ENEMY, area = startingPointArea
  })

  if not points or not points[1] then
    return nil, { point = key, reason = "reference_point_missing" }
  end

  return points[1]
end

---Calculate starting points for all ship types from two reference points
---@param area SBJ__OperationAreaDescriptor Area configuration with startingPoints, heading
---@param formationSettings SBJ__AmphibiousFormationSettings Formation distance settings
---@return table<string, CMO__Location>|nil startingPoints Mapping of key to starting location
---@return table<string, any>|nil errorFields Log fields describing the failure
local function calculateStartingPoints(area, formationSettings)
  local startingPoints = {}
  local errorFields

  startingPoints.type075, errorFields = getStartingReferencePoint(area, "type075")
  if not startingPoints.type075 then return nil, errorFields end

  startingPoints.type071, errorFields = getStartingReferencePoint(area, "type071")
  if not startingPoints.type071 then return nil, errorFields end

  for _, row in ipairs(SHIP_ROW_LAYOUT) do
    local fromPoint = startingPoints[row.from]
    if not fromPoint then
      return nil, { point = row.key, from = row.from, reason = "source_point_missing" }
    end

    startingPoints[row.key] = GameApi.World_GetPointFromBearing({
      latitude = fromPoint.latitude,
      longitude = fromPoint.longitude,
      bearing = area.heading.vertical,
      distance = formationSettings[row.distanceKey],
    })

    if not startingPoints[row.key] then
      return nil, { point = row.key, from = row.from, reason = "derived_point_failed" }
    end
  end

  return startingPoints
end

---Generate and append locations for all ship types in an area
---@param opResult table<string, SBJ__ShipCalculationResult> Operation result to populate
---@param startingPoints table<string, CMO__Location> Starting points per ship type
---@param area SBJ__OperationAreaDescriptor Area configuration with heading and shipCounts
---@param horizontalDistance number Horizontal spacing
local function generateAllShipLocations(opResult, startingPoints, area, horizontalDistance)
  for _, entry in ipairs(ALL_RESULT_KEYS) do
    Utils.insertList(
      opResult[entry.key].locations,
      GameUtils.generateLocations({
        initialLocation = startingPoints[entry.key],
        num = area.shipCounts[entry.key],
        bearing = area.heading.horizontal,
        distance = horizontalDistance,
      })
    )
  end
end

---Pre-calculate all destination positions for amphibious assault ships
---Generates grid of anchorage positions for each ship type with layered arrangement and spacing
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration with ship settings
---@param calculationResult table<string, SBJ__OperationZoneCalculationResult> Calculation result where calculated positions will be stored
---@return boolean # True if all destination positions were calculated
function ShipMovement.calculateDestination(amphibOpsConfig, calculationResult)
  local formationSettings = amphibOpsConfig.formationSettings
  for _, operation in ipairs(amphibOpsConfig.operations) do
    for areaIndex, area in ipairs(operation.to.areas) do
      initOperationResult(operation.name, calculationResult)
      local startingPoints, errorFields = calculateStartingPoints(area, formationSettings)
      if not startingPoints then
        Logger.error(LogFormat.line("ERROR", LogFormat.merge(
          { operation = operation.name, areaIndex = areaIndex },
          errorFields or { reason = "starting_point_calculation_failed" })))
        return false
      end

      generateAllShipLocations(
        calculationResult[operation.name].result,
        startingPoints, area,
        formationSettings.horizontalDistance
      )
    end
  end

  return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Move amphibious assault ships from staging area to designated anchorage positions for a single operation
---Routes ships to pre-calculated positions by class and coordinates Surface Action Group movements
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data containing pre-calculated destination positions
---@param filteredUnits CMO__SideUnit[] Unit list from the side (filtered for ships)
---@param operation SBJ__AmphibiousOperationDescriptor Operation descriptor for the target zone
---@return boolean # True when all movement orders have been issued
function ShipMovement.moveToStagingArea(amphibOpsConfig, saveData, filteredUnits, operation)
  local formationSettings = amphibOpsConfig.formationSettings
  local calculationResult = saveData and saveData.c and saveData.c.amphibOps and saveData.c.amphibOps.calculationResult
  local isTesting = amphibOpsConfig.isTesting
  local result, errorFields = getOperationResult(calculationResult, operation.name)

  if not result then
    Logger.error(LogFormat.line("ERROR", LogFormat.merge(
      { operation = operation.name },
      errorFields or { reason = "calculation_result_missing" })))
    return false
  end

  local results = {}

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit and unit:inArea(operation.from.stagingArea) then
      table.insert(results, matchAndMoveShip(unit, result, formationSettings.shipSpeed, isTesting))
    end
  end

  for _, sagName in ipairs(operation.sagNames) do
    local descriptor = amphibOpsConfig.sag[sagName]
    if descriptor then
      table.insert(results, handleSAG(descriptor, isTesting))
    else
      table.insert(results, { tag = "SKIP", fields = { sag = sagName, reason = "sag_descriptor_not_found" } })
    end
  end

  local report = LogFormat.report(constants.TAGS.SHIP_MOVEMENT, "operation=" .. operation.name, "Move to staging area")
  report.addAll(results)
  report.emit()

  return not LogFormat.hasFailure(results)
end

return ShipMovement
