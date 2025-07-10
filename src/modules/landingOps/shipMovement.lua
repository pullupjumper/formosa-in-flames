local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local CONFIG = require("src.core.constants")

local ShipMovement = {}

---@param unit CMO__Unit
---@param location CMO__Location
---@param speed number
---@param isTesting boolean
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

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param shipType string
---@param shipSettings table<string, number>
---@param isTesting boolean
local function handleShipType(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable[shipType].locationIndex
  local location = resultTable[shipType].locations[index]
  moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[shipType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param nameType string
---@param shipSettings table<string, number>
---@param isTesting boolean
local function handleNameType(unit, resultTable, nameType, shipSettings, isTesting)
  nameType = string.lower(nameType)
  local index = resultTable[nameType].locationIndex
  local location = resultTable[nameType].locations[index]
  moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[nameType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param shipType string
---@param shipSettings table<string, number>
---@param isTesting boolean
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

---@param ship CMO__Unit
---@param lat number|string
---@param lon number|string
---@param bearing number
local function setShipPosition(ship, lat, lon, bearing)
  GameApi.ScenEdit_SetUnit({
    guid = ship.guid,
    latitude = lat,
    longitude = lon,
    heading = bearing,
  })
end

---@param latitude number|string
---@param longitude number|string
---@param bearing number
---@param distance number
---@return CMO__Location
local function getNextPosition(latitude, longitude, bearing, distance)
  return GameApi.World_GetPointFromBearing({
    LATITUDE = latitude,
    LONGITUDE = longitude,
    BEARING = bearing,
    DISTANCE = distance,
  })
end

---@param group table<string, table>
---@param isTesting boolean
local function handleSAG(group, isTesting)
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
        if ship.dbid == CONFIG.platformDBID48 then
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
        elseif ship.dbid == CONFIG.platformDBID49 then
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

---comment
---@param saveData SBJ__SaveData
---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit
---@return boolean
function ShipMovement.moveToStagingArea(saveData, CONFIG, units)
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
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

  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    handleSAG(group, isTesting)
  end

  allUnitsMoved = true
  return allUnitsMoved
end

---comment
---@param saveData SBJ__SaveData
function ShipMovement.calculateDestination(saveData)
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local shipSettings = CONFIG.c.PHIBOP.shipSettings

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.to.areas) do
      local firstRp075 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = GameApi.ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
      local firstRp076 = GameApi.World_GetPointFromBearing({
        latitude = firstRp071.latitude,
        longitude = firstRp071.longitude,
        -- initialLocation = firstRp071,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpBarge = GameApi.World_GetPointFromBearing({
        latitude = firstRp075.latitude,
        longitude = firstRp075.longitude,
        -- initialLocation = firstRp075,
        bearing = area.heading.vertical,
        distance = shipSettings.distanceBetweenLSTAndLPDArea
      })
      local firstRpRORO = GameApi.World_GetPointFromBearing({
        latitude = firstRpBarge.latitude,
        longitude = firstRpBarge.longitude,
        -- initialLocation = firstRpBarge,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072a = GameApi.World_GetPointFromBearing({
        latitude = firstRpRORO.latitude,
        longitude = firstRpRORO.longitude,
        -- initialLocation = firstRpRORO,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072iii = GameApi.World_GetPointFromBearing({
        latitude = firstRp072a.latitude,
        longitude = firstRp072a.longitude,
        -- initialLocation = firstRp072a,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpFerry = GameApi.World_GetPointFromBearing({
        latitude = firstRp072iii.latitude,
        longitude = firstRp072iii.longitude,
        -- initialLocation = firstRp072iii,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp071InLSTArea = GameApi.World_GetPointFromBearing({
        latitude = firstRpFerry.latitude,
        longitude = firstRpFerry.longitude,
        -- initialLocation = firstRpFerry,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp073a = GameApi.World_GetPointFromBearing({
        latitude = firstRp071InLSTArea.latitude,
        longitude = firstRp071InLSTArea.longitude,
        -- initialLocation = firstRp071InLSTArea,
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
