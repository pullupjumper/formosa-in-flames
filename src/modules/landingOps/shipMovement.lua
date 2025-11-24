local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

--- Ship Movement
---
--- Landing ship movement and positioning calculations for amphibious operations,
--- including destination pre-calculation, formation management, and SAG coordination
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
---@param resultTable table<string, table> Pre-calculated destination locations for all ship types
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
---@param resultTable table<string, table> Pre-calculated destination locations
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
---Type 071 ships can be assigned to either LPD area or LST area based on capacity
---When LPD area is full, overflow Type 071s are placed in LST area
---@param unit CMO__Unit The Type 071 ship to move
---@param resultTable table<string, table> Pre-calculated destination locations
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
---@param lat number|string Latitude coordinate
---@param lon number|string Longitude coordinate
---@param bearing number Ship heading in degrees
local function setShipPosition(ship, lat, lon, bearing)
  GameApi.ScenEdit_SetUnit({
    guid = ship.guid,
    latitude = lat,
    longitude = lon,
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
    LATITUDE = latitude,
    LONGITUDE = longitude,
    BEARING = bearing,
    DISTANCE = distance,
  })
end

---Handle Surface Action Group (SAG) movement to anchorage area
---Positions SAG ships in formation: Type 052D destroyers in center, Type 054A frigates at flanks
---In testing mode, ships are instantly teleported to their assigned positions
---@param config SBJ__CONFIG Global configuration for platform DBIDs
---@param group SBJ__SAGDescriptor SAG group descriptor with destination and unit list
---@param isTesting boolean If true, enables testing mode with instant teleportation
local function handleSAG(config, group, isTesting)
  local unit = GameApi.ScenEdit_GetUnit(group.groupName)

  if not unit then
    return
  end

  unit.course = group.to.archorageArea

  if isTesting then
    local count = #group.to.archorageArea
    local type052d, type054a = 0, 0

    for _, u in ipairs(unit.group.unitlist) do
      local ship = GameApi.ScenEdit_GetUnit(u)

      if ship then
        if ship.dbid == config.platform.TYPE_052D then
          if type052d == 0 then
            setShipPosition(
              ship,
              group.to.archorageArea[count].lat,
              group.to.archorageArea[count].lon,
              group.to.heading
            )
          else
            local point = getNextPosition(
              group.to.archorageArea[count].lat,
              group.to.archorageArea[count].lon,
              group.to.heading - 180,
              1.5
            )
            if point then
              setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
            end
          end

          type052d = type052d + 1
        elseif ship.dbid == config.platform.TYPE_054A then
          local angle = (type054a == 0) and -45 or 45
          local point = getNextPosition(
            group.to.archorageArea[count].lat,
            group.to.archorageArea[count].lon,
            group.to.heading - angle,
            1.5
          )
          if point then
            setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
          end
          type054a = type054a + 1
        end
      end
    end
  end
end

---Move all amphibious assault ships from staging area to designated anchorage positions
---Routes different ship types to their pre-calculated positions based on ship class
---Handles amphibious assault ships (Type 075/076), landing ships (Type 071/072/073), and auxiliary vessels
---Also coordinates Surface Action Group movements for escort duties
---@param config SBJ__CONFIG Global configuration (used for SAG platform identification)
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data containing pre-calculated destination positions
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all ship movement orders were successfully issued
function ShipMovement.moveToStagingArea(config, amphibOpsConfig, saveData, units)
  local shipSettings = amphibOpsConfig.shipSettings
  local initialLocations = amphibOpsConfig.initialLocations
  local calculations = saveData.c.PHIBOP.calculations
  local isTesting = saveData.c.PHIBOP.isTesting
  local allUnitsMoved = false

  for _, unitData in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(unitData.guid)

    if unit then
      for _, item in ipairs(initialLocations) do
        if unit:inArea(item.from.stagingArea) then
          local result = calculations[item.name].result
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
              handler(unit, result, shipType, shipSettings, isTesting)
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
                handler(unit, result, nameType, shipSettings, isTesting)
                break
              end
            end
          end
        end
      end
    end
  end

  for _, group in pairs(amphibOpsConfig.sag) do
    handleSAG(config, group, isTesting)
  end

  allUnitsMoved = true
  return allUnitsMoved
end

---Pre-calculate all destination positions for amphibious assault ships
---Generates a grid of anchorage positions for each ship type in each operational area
---Positions are calculated based on reference points with vertical and horizontal spacing
---Ship types are arranged in layers: Type 075 (LHD), Type 071 (LPD), Type 076, then LSTs
---Results are stored in saveData for later use during actual ship movement
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration with ship settings
---@param saveData SBJ__SaveData Save data where calculated positions will be stored
function ShipMovement.calculateDestination(amphibOpsConfig, saveData)
  local initialLocations = amphibOpsConfig.initialLocations
  local shipSettings = amphibOpsConfig.shipSettings

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.to.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
      local firstRp076 = GameApi.World_GetPointFromBearing({
        latitude = firstRp071.latitude,
        longitude = firstRp071.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpBarge = GameApi.World_GetPointFromBearing({
        latitude = firstRp075.latitude,
        longitude = firstRp075.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.distanceBetweenLSTAndLPDArea
      })
      local firstRpRORO = GameApi.World_GetPointFromBearing({
        latitude = firstRpBarge.latitude,
        longitude = firstRpBarge.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072a = GameApi.World_GetPointFromBearing({
        latitude = firstRpRORO.latitude,
        longitude = firstRpRORO.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072iii = GameApi.World_GetPointFromBearing({
        latitude = firstRp072a.latitude,
        longitude = firstRp072a.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpFerry = GameApi.World_GetPointFromBearing({
        latitude = firstRp072iii.latitude,
        longitude = firstRp072iii.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp071InLSTArea = GameApi.World_GetPointFromBearing({
        latitude = firstRpFerry.latitude,
        longitude = firstRpFerry.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp073a = GameApi.World_GetPointFromBearing({
        latitude = firstRp071InLSTArea.latitude,
        longitude = firstRp071InLSTArea.longitude,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type075.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp075,
          num = area.num.type075,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp071,
          num = area.num.type071,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type076.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp076,
          num = area.num.type076,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.barge.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpBarge,
          num = area.num.barge,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        })
      )
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.roro.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpRORO,
          num = area.num.roro,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072iii.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp072iii,
          num = area.num.type072iii,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072a.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp072a,
          num = area.num.type072a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.ferry.locations,
        GameUtils.generateLocations({
          initialLocation = firstRpFerry,
          num = area.num.ferry,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type073a.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp073a,
          num = area.num.type073a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.insertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071InLSTArea.locations,
        GameUtils.generateLocations({
          initialLocation = firstRp071InLSTArea,
          num = area.num.type071InLSTArea,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
    end
  end
end

return ShipMovement
