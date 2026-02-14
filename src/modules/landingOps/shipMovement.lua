local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

local ShipMovement = {}

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

---Handle ship movement for standard amphibious assault ship types
---Assigns next available location from pre-calculated positions and increments index
---@param unit CMO__Unit The ship unit to move
---@param resultTable table<string, SBJ__ShipCalculationResult> Pre-calculated destination locations for all ship types
---@param shipType string Ship type identifier (type075, type076, type072iii, etc.)
---@param shipSettings table<string, number> Ship movement configuration
---@param isTesting boolean If true, enables testing mode with instant teleportation
local function handleShipType(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable[shipType].locationIndex
  local location = resultTable[shipType].locations[index]
  moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[shipType].locationIndex = index + 1
end

---Handle ship movement for auxiliary vessels identified by name (ferry, RORO, barge)
---Similar to handleShipType but uses ship name instead of DBID for matching
---@param unit CMO__Unit The ship unit to move
---@param resultTable table<string, SBJ__ShipCalculationResult> Pre-calculated destination locations
---@param nameType string Ship name type (ferry, RORO, barge)
---@param shipSettings table<string, number> Ship movement configuration
---@param isTesting boolean If true, enables testing mode with instant teleportation
local function handleNameType(unit, resultTable, nameType, shipSettings, isTesting)
  nameType = string.lower(nameType)
  local index = resultTable[nameType].locationIndex
  local location = resultTable[nameType].locations[index]
  moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[nameType].locationIndex = index + 1
end

---Handle Type 071 LPD movement with overflow support to LST area
---When LPD area is full, overflow Type 071s are placed in LST area
---@param unit CMO__Unit The Type 071 ship to move
---@param resultTable table<string, SBJ__ShipCalculationResult> Pre-calculated destination locations
---@param shipType string Ship type identifier (always "type071")
---@param shipSettings table<string, number> Ship movement configuration
---@param isTesting boolean If true, enables testing mode with instant teleportation
local function handle071(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable.type071.locationIndex
  local len = #resultTable.type071.locations
  local location
  if index > len then
    location = resultTable.type071InLSTArea.locations[index - len]
  else
    location = resultTable.type071.locations[index]
  end
  moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable.type071.locationIndex = index + 1
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

---Handle Surface Action Group (SAG) movement to anchorage area
---Positions SAG ships in formation: Type 052D destroyers center, Type 054A frigates at flanks
---@param descriptor SBJ__SAGDescriptor SAG group descriptor with destination and unit list
---@param isTesting boolean If true, enables testing mode with instant teleportation
local function handleSAG(descriptor, isTesting)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.groupName)
  if not unit then return end
  unit.course = descriptor.to.anchorageArea

  if isTesting then
    local count = #descriptor.to.anchorageArea
    local type052d, type054a = 0, 0

    for _, guid in ipairs(unit.group.unitlist) do
      local ship = GameApi.ScenEdit_GetUnit(guid)

      if ship then
        if ship.dbid == constants.PLATFORMS.TYPE_052D then
          if type052d == 0 then
            setShipPosition(
              ship,
              descriptor.to.anchorageArea[count].latitude,
              descriptor.to.anchorageArea[count].longitude,
              descriptor.to.heading
            )
          else
            local point = getNextPosition(
              descriptor.to.anchorageArea[count].latitude,
              descriptor.to.anchorageArea[count].longitude,
              descriptor.to.heading - 180,
              1.5
            )
            if point then
              setShipPosition(ship, point.latitude, point.longitude, descriptor.to.heading)
            end
          end

          type052d = type052d + 1
        elseif ship.dbid == constants.PLATFORMS.TYPE_054A then
          local angle = (type054a == 0) and -45 or 45
          local point = getNextPosition(
            descriptor.to.anchorageArea[count].latitude,
            descriptor.to.anchorageArea[count].longitude,
            descriptor.to.heading - angle,
            1.5
          )
          if point then
            setShipPosition(ship, point.latitude, point.longitude, descriptor.to.heading)
          end
          type054a = type054a + 1
        end
      end
    end
  end
end

---Move all amphibious assault ships from staging area to designated anchorage positions
---Routes ships to pre-calculated positions by class and coordinates Surface Action Group movements
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data containing pre-calculated destination positions
---@param filteredUnits CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all ship movement orders were successfully issued
function ShipMovement.moveToStagingArea(amphibOpsConfig, saveData, filteredUnits)
  local formationSettings = amphibOpsConfig.formationSettings
  local operations = amphibOpsConfig.operations
  local calculationResult = saveData.c.amphibOps.calculationResult
  local isTesting = saveData.c.amphibOps.isTesting
  local allUnitsMoved = false

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit then
      for _, operation in ipairs(operations) do
        if unit:inArea(operation.from.stagingArea) then
          local result = calculationResult[operation.name].result
          local matched = false

          for shipType, handler in pairs({
            type075 = handleShipType,
            type076 = handleShipType,
            type072iii = handleShipType,
            type072a = handleShipType,
            type073a = handleShipType,
            type071 = handle071,
          }) do
            if unit.dbid == result[shipType].dbid then
              handler(unit, result, shipType, formationSettings, isTesting)
              matched = true
              break
            end
          end

          if not matched then
            for nameType, handler in pairs({
              ferry = handleNameType,
              RORO = handleNameType,
              barge = handleNameType,
            }) do
              if unit.name == nameType:gsub("^%l", string.upper) then
                handler(unit, result, nameType, formationSettings, isTesting)
                break
              end
            end
          end
        end
      end
    end
  end

  for _, SAGDescriptor in pairs(amphibOpsConfig.sag) do
    handleSAG(SAGDescriptor, isTesting)
  end

  allUnitsMoved = true
  return allUnitsMoved
end

---Pre-calculate all destination positions for amphibious assault ships
---Generates grid of anchorage positions for each ship type with layered arrangement and spacing
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration with ship settings
---@param calculationResult table<string, SBJ__OperationZoneCalculationResult> Calculation result where calculated positions will be stored
function ShipMovement.calculateDestination(amphibOpsConfig, calculationResult)
  local operations = amphibOpsConfig.operations
  local formationSettings = amphibOpsConfig.formationSettings

  for _, operation in ipairs(operations) do
    for _, area in ipairs(operation.to.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
      local firstRp076 = GameApi.World_GetPointFromBearing({
        latitude = firstRp071.latitude,
        longitude = firstRp071.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRpBarge = GameApi.World_GetPointFromBearing({
        latitude = firstRp075.latitude,
        longitude = firstRp075.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.distanceBetweenLSTAndLPDArea
      })
      local firstRpRORO = GameApi.World_GetPointFromBearing({
        latitude = firstRpBarge.latitude,
        longitude = firstRpBarge.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRp072a = GameApi.World_GetPointFromBearing({
        latitude = firstRpRORO.latitude,
        longitude = firstRpRORO.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRp072iii = GameApi.World_GetPointFromBearing({
        latitude = firstRp072a.latitude,
        longitude = firstRp072a.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRpFerry = GameApi.World_GetPointFromBearing({
        latitude = firstRp072iii.latitude,
        longitude = firstRp072iii.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRp071InLSTArea = GameApi.World_GetPointFromBearing({
        latitude = firstRpFerry.latitude,
        longitude = firstRpFerry.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })
      local firstRp073a = GameApi.World_GetPointFromBearing({
        latitude = firstRp071InLSTArea.latitude,
        longitude = firstRp071InLSTArea.longitude,
        bearing = area.heading.vertical,
        distance = formationSettings.verticalDistance
      })

      if not calculationResult[operation.name] then
        calculationResult[operation.name] = {
          name = operation.name,
          result = {
            type075 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_075, },
            type071 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
            type076 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_076, },
            type072iii = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072III, },
            type072a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072A, },
            type073a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_073A, },
            type071InLSTArea = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
            ferry = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
            roro = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
            barge = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.BARGE, },
          }
        }
      end

      Utils.insertList(
        calculationResult[operation.name].result.type075.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp075,
          num = area.num.type075,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type071.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp071,
          num = area.num.type071,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type076.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp076,
          num = area.num.type076,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.barge.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpBarge,
          num = area.num.barge,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        })
      )
      Utils.insertList(
        calculationResult[operation.name].result.roro.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpRORO,
          num = area.num.roro,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type072iii.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp072iii,
          num = area.num.type072iii,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type072a.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp072a,
          num = area.num.type072a,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.ferry.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpFerry,
          num = area.num.ferry,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type073a.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp073a,
          num = area.num.type073a,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
      Utils.insertList(
        calculationResult[operation.name].result.type071InLSTArea.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp071InLSTArea,
          num = area.num.type071InLSTArea,
          bearing = area.heading.horizontal,
          distance = formationSettings.horizontalDistance
        }))
    end
  end
end

return ShipMovement
