local constants = require("src.core.constants")

local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")

local DebugFlow = require("src.modules.landingOps.debugFlow")

local ShipMovement = {}

-- ============================================================================
-- Constants
-- ============================================================================

---One row of the fleet layout. A row matches a unit by `name` when it has one, otherwise by `dbid`.
---@type {key: string, dbid: number, name?: string}[]
local SHIP_ROWS = {
  { key = "type075",    dbid = constants.PLATFORMS.TYPE_075 },
  { key = "type071",    dbid = constants.PLATFORMS.TYPE_071 },
  { key = "type076",    dbid = constants.PLATFORMS.TYPE_076 },
  { key = "type072iii", dbid = constants.PLATFORMS.TYPE_072III },
  { key = "type072a",   dbid = constants.PLATFORMS.TYPE_072A },
  { key = "type073a",   dbid = constants.PLATFORMS.TYPE_073A },
  { key = "ferry",      dbid = constants.PLATFORMS.FERRY,      name = "Ferry" },
  { key = "roro",       dbid = constants.PLATFORMS.FERRY,      name = "RORO" },
  { key = "barge",      dbid = constants.PLATFORMS.BARGE,      name = "Barge" },
  { key = "type082",    dbid = constants.PLATFORMS.TYPE_082 }
}

local SAG_FORMATION = {
  FLANK_DISTANCE  = 1.5,
  TRAIL_DISTANCE  = 1.5,
  PORT_ANGLE      = -45,
  STARBOARD_ANGLE = 45,
}

---@type {key: string, from: string, distanceKey: string}[]
local SHIP_ROW_LAYOUT = {
  { key = "type071",    from = "type075",    distanceKey = "verticalDistanceNm" },
  { key = "type076",    from = "type071",    distanceKey = "verticalDistanceNm" },
  { key = "barge",      from = "type075",    distanceKey = "deployLineSetbackNm" },
  { key = "roro",       from = "barge",      distanceKey = "verticalDistanceNm" },
  { key = "ferry",      from = "roro",       distanceKey = "verticalDistanceNm" },
  { key = "type072a",   from = "ferry",      distanceKey = "verticalDistanceNm" },
  { key = "type072iii", from = "type072a",   distanceKey = "verticalDistanceNm" },
  { key = "type073a",   from = "type072iii", distanceKey = "verticalDistanceNm" },
  { key = "type082",    from = "type073a",   distanceKey = "verticalDistanceNm" }
}

-- ============================================================================
-- Ship Movement
-- ============================================================================

---Move a ship to a target location. In testing mode, teleport it there instead of sailing
---@param unit CMO__Unit
---@param location CMO__Location
---@param amphibOps SBJ__AmphibOpsConfig
local function moveShip(unit, location, amphibOps)
  unit.course = { location }
  unit.manualSpeed = amphibOps.formation.shipSpeed

  if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MOVING) then
    DebugFlow.teleport(unit.guid, location)
    unit.manualSpeed = 0
  end
end

---Get the pre-calculated ship rows of a zone
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>|nil
---@param zoneName string
---@return table<string, SBJ__ShipCalculationState>|nil shipRowMap Ship rows by row key
---@return table<string, any>|nil errorFields Log fields describing the failure
local function getShipRowMap(calculationResult, zoneName)
  local zoneResult = calculationResult and calculationResult[zoneName]
  if not zoneResult or not zoneResult.result then
    return nil, { reason = "calculation_result_missing" }
  end

  return zoneResult.result
end

---Find the ship row of a unit: by DBID first, then by name for ferries, RORO and barges
---@param unit CMO__Unit
---@return string|nil # Row key, or nil if no row matches the unit
local function findShipRowKey(unit)
  for _, shipRow in ipairs(SHIP_ROWS) do
    if not shipRow.name and unit.dbid == shipRow.dbid then
      return shipRow.key
    end
  end

  for _, shipRow in ipairs(SHIP_ROWS) do
    if shipRow.name == unit.name then
      return shipRow.key
    end
  end
end

---Move a ship to the next pre-calculated location of its row and increment the index
---@param unit CMO__Unit
---@param row SBJ__ShipCalculationState|nil
---@param rowKey string
---@param amphibOps SBJ__AmphibOpsConfig
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveToNextLocation(unit, row, rowKey, amphibOps)
  if not row or not row.locations or not row.locationIndex then
    return {
      tag = "FAIL",
      fields = { ship = unit.name, dbid = unit.dbid, dest = rowKey, reason = "calculation_entry_missing" }
    }
  end

  local index = row.locationIndex
  local location = row.locations[index]
  if not location then
    return {
      tag = "SKIP",
      fields = { ship = unit.name, dbid = unit.dbid, dest = rowKey, index = index, reason = "no_location" }
    }
  end

  moveShip(unit, location, amphibOps)
  row.locationIndex = index + 1
  return {
    tag = "OK",
    fields = { ship = unit.name, dbid = unit.dbid, dest = rowKey, index = index }
  }
end

---Move the ship that matches a DBID or name to its next location
---@param unit CMO__Unit
---@param shipRowMap table<string, SBJ__ShipCalculationState>
---@param amphibOps SBJ__AmphibOpsConfig
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveMatchingShip(unit, shipRowMap, amphibOps)
  local rowKey = findShipRowKey(unit)
  if not rowKey then
    return { tag = "SKIP", fields = { ship = unit.name, dbid = unit.dbid, reason = "unmatched" } }
  end

  return moveToNextLocation(unit, shipRowMap[rowKey], rowKey, amphibOps)
end

-- ============================================================================
-- SAG Movement
-- ============================================================================

---Teleport SAG ships into formation around the holding point (testing mode).
---Type 052D destroyers take the center (extra ones trail behind). Type 054A frigates take the flanks.
---@param sagUnit CMO__Unit SAG group whose `group.unitlist` is set
---@param holdingPoint CMO__Location
---@param heading number Zone heading the SAG faces
---@return integer positioned
---@return integer skipped
function ShipMovement.teleportSagToFormation(sagUnit, holdingPoint, heading)
  local type052d, type054a = 0, 0
  local positioned, skipped = 0, 0

  for _, guid in ipairs(sagUnit.group.unitlist) do
    local ship = GameApi.ScenEdit_GetUnit(guid)
    local point, offsetBearing, offsetDistance

    if ship and ship.dbid == constants.PLATFORMS.TYPE_052D then
      if type052d == 0 then
        point = holdingPoint
      else
        offsetBearing, offsetDistance = heading - 180, SAG_FORMATION.TRAIL_DISTANCE
      end
      type052d = type052d + 1
    elseif ship and ship.dbid == constants.PLATFORMS.TYPE_054A then
      local angle = (type054a == 0) and SAG_FORMATION.PORT_ANGLE or SAG_FORMATION.STARBOARD_ANGLE
      offsetBearing, offsetDistance = heading - angle, SAG_FORMATION.FLANK_DISTANCE
      type054a = type054a + 1
    end

    if offsetBearing then
      point = GameApi.World_GetPointFromBearing({
        latitude = holdingPoint.latitude,
        longitude = holdingPoint.longitude,
        bearing = offsetBearing,
        distance = offsetDistance,
      })
    end

    if ship and point then
      DebugFlow.teleport(ship.guid, { latitude = point.latitude, longitude = point.longitude })
      ship.heading = heading
      positioned = positioned + 1
    else
      skipped = skipped + 1
    end
  end

  return positioned, skipped
end

---Move a Surface Action Group (SAG) to its holding area.
---In testing mode, also teleport the SAG ships into formation.
---@param sag SBJ__SAGDescriptor
---@param heading number Zone heading the SAG faces at its holding area
---@param amphibOps SBJ__AmphibOpsConfig
---@return SBJ__LogResult # Deferred log result describing the outcome
local function moveSag(sag, heading, amphibOps)
  local holdingArea = sag.to and sag.to.holdingArea
  if not holdingArea or #holdingArea == 0 then
    return { tag = "FAIL", fields = { sag = sag.groupName, reason = "holding_area_missing" } }
  end

  local holdingPoint = holdingArea[#holdingArea]
  if not holdingPoint or not holdingPoint.latitude or not holdingPoint.longitude then
    return { tag = "FAIL", fields = { sag = sag.groupName, reason = "holding_point_missing" } }
  end

  local sagUnit = GameApi.ScenEdit_GetUnit(sag.groupName)
  if not sagUnit then
    return { tag = "FAIL", fields = { sag = sag.groupName, reason = "sag_group_not_found" } }
  end

  sagUnit.course = holdingArea

  if not DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MOVING) then
    return { tag = "OK", fields = { sag = sag.groupName, action = "course_set" } }
  end

  if not sagUnit.group or not sagUnit.group.unitlist then
    return { tag = "FAIL", fields = { sag = sag.groupName, reason = "sag_unitlist_missing" } }
  end

  sagUnit.course = nil
  local positioned, skipped = ShipMovement.teleportSagToFormation(sagUnit, holdingPoint, heading)

  return {
    tag = "OK",
    fields = { sag = sag.groupName, action = "course_set", positioned = positioned, skipped = skipped }
  }
end

-- ============================================================================
-- Destination Calculation
-- ============================================================================

---Initialize the calculation result of a zone with an empty row per ship type
---@param zoneName string
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>
local function initShipRowMap(zoneName, calculationResult)
  if calculationResult[zoneName] then return end
  local shipRowMap = {}
  for _, shipRow in ipairs(SHIP_ROWS) do
    shipRowMap[shipRow.key] = { locations = {}, locationIndex = 1, dbid = shipRow.dbid }
  end
  calculationResult[zoneName] = { name = zoneName, result = shipRowMap }
end

---Get the first reference point of the Type 075 starting point area
---@param startingPoint string[]|nil Reference point names
---@return CMO__Location|nil point Reference point
---@return table<string, any>|nil errorFields Log fields describing the failure
local function getStartingReferencePoint(startingPoint)
  if not startingPoint then
    return nil, { point = "type075", reason = "starting_point_area_missing" }
  end

  local points = GameApi.ScenEdit_GetReferencePoints({ side = constants.SIDES.RED, area = startingPoint })

  if not points or not points[1] then
    return nil, { point = "type075", reason = "reference_point_missing" }
  end

  return points[1]
end

---Calculate the starting points for all ship types from the Type 075 reference point
---@param startingPoint string[]|nil Type 075 reference point names
---@param heading number Bearing the ship rows are stacked along
---@param formation SBJ__AmphibiousFormationConfig
---@return table<string, CMO__Location>|nil startingPointMap Mapping of key to starting location
---@return table<string, any>|nil errorFields Log fields describing the failure
local function calculateStartingPoints(startingPoint, heading, formation)
  local startingPointMap = {}
  local errorFields

  startingPointMap.type075, errorFields = getStartingReferencePoint(startingPoint)
  if not startingPointMap.type075 then return nil, errorFields end

  for _, row in ipairs(SHIP_ROW_LAYOUT) do
    local fromPoint = startingPointMap[row.from]
    if not fromPoint then
      return nil, { point = row.key, from = row.from, reason = "source_point_missing" }
    end

    startingPointMap[row.key] = GameApi.World_GetPointFromBearing({
      latitude = fromPoint.latitude,
      longitude = fromPoint.longitude,
      bearing = heading,
      distance = formation[row.distanceKey],
    })

    if not startingPointMap[row.key] then
      return nil, { point = row.key, from = row.from, reason = "derived_point_failed" }
    end
  end

  return startingPointMap
end

---Build the locations for all ship types in an area and append them to the rows
---@param shipRowMap table<string, SBJ__ShipCalculationState>
---@param params SBJ__BuildAllShipLocationsParams
local function buildAllShipLocations(shipRowMap, params)
  local formation = params.formation
  for _, shipRow in ipairs(SHIP_ROWS) do
    Utils.addAll(
      shipRowMap[shipRow.key].locations,
      GameUtils.buildLocations({
        initialLocation = params.startingPointMap[shipRow.key],
        num = params.shipCounts[shipRow.key],
        bearing = params.heading - formation.rowBearingOffset,
        distance = formation.horizontalDistanceNm,
      })
    )
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Build the destination positions for the amphibious assault ships.
---Generate a grid of holding positions for each ship type, with layers and spacing.
---@param zones SBJ__OperationalZoneDescriptor[]
---@param formation SBJ__AmphibiousFormationConfig
---@param calculationResult table<string, SBJ__OperationZoneCalculationState>
---@return boolean # True if all destination positions were built
function ShipMovement.buildHoldingPositions(zones, formation, calculationResult)
  for _, zone in ipairs(zones) do
    for groupIndex, group in ipairs(zone.fleet.groups) do
      initShipRowMap(zone.name, calculationResult)
      local startingPointMap, errorFields = calculateStartingPoints(group.to.startingPoint, zone.heading, formation)
      if not startingPointMap then
        Logger.error(LogFormat.line("ERROR", LogFormat.merge(
          { operation = zone.name, areaIndex = groupIndex },
          errorFields or { reason = "starting_point_calculation_failed" })))
        return false
      end

      buildAllShipLocations(calculationResult[zone.name].result, {
        startingPointMap = startingPointMap,
        shipCounts = group.shipCounts,
        heading = zone.heading,
        formation = formation,
      })
    end
  end

  return true
end

---Move the amphibious assault ships from the staging area to their holding positions in a single zone.
---Route ships to pre-calculated positions by class and coordinate the Surface Action Group movements.
---@param zone SBJ__OperationalZoneDescriptor
---@param calculationResult table<string, SBJ__OperationZoneCalculationState> Pre-calculated destination positions indexed by zone name
---@param filteredUnits CMO__SideUnit[]
---@param amphibOps SBJ__AmphibOpsConfig
---@return boolean # True when all movement orders have been issued
function ShipMovement.moveToHoldingAreas(zone, calculationResult, filteredUnits, amphibOps)
  local shipRowMap, errorFields = getShipRowMap(calculationResult, zone.name)

  if not shipRowMap then
    Logger.error(LogFormat.line("ERROR", LogFormat.merge(
      { operation = zone.name },
      errorFields or { reason = "calculation_result_missing" })))
    return false
  end

  local results = {}

  for _, sideUnit in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(sideUnit.guid)
    if unit and unit:inArea(zone.fleet.stagingArea) then
      table.insert(results, moveMatchingShip(unit, shipRowMap, amphibOps))
    end
  end

  for _, sag in ipairs(zone.sags) do
    table.insert(results, moveSag(sag, zone.heading, amphibOps))
  end

  local report = LogFormat.report(constants.TAGS.SHIP_MOVEMENT, "operation=" .. zone.name, "Move to holding areas")
  report.addAll(results)
  report.emit()

  return not LogFormat.hasFailure(results)
end

return ShipMovement
