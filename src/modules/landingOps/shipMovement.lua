GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
Utils = require("src.utils.utils")
GameUtils = require("src.utils.gameUtils")

ShipMovement = {}

---@param unit CMO__Unit
---@param location CMO__Location
---@param speed number
---@param isTesting boolean
function ShipMovement._moveShip(unit, location, speed, isTesting)
  unit.course = { location }
  unit.manualSpeed = speed

  if isTesting then
    local result, err = Utils.SafeCall("GameApi.ScenEdit_SetUnit", GameApi.ScenEdit_SetUnit, {
      guid = unit.guid,
      latitude = location.latitude,
      longitude = location.longitude,
      manualSpeed = 0
    })

    if not result then
      Logger.error("Error in ScenEdit_SetUnit: " .. err)
    end
  end
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param shipType string
---@param shipSettings table<string, number>
---@param isTesting boolean
function ShipMovement._handleShipType(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable[shipType].locationIndex
  local location = resultTable[shipType].locations[index]
  ShipMovement._moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[shipType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param nameType string
---@param shipSettings table<string, number>
---@param isTesting boolean
function ShipMovement._handleNameType(unit, resultTable, nameType, shipSettings, isTesting)
  nameType = string.lower(nameType)
  local index = resultTable[nameType].locationIndex
  local location = resultTable[nameType].locations[index]
  ShipMovement._moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[nameType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param shipType string
---@param shipSettings table<string, number>
---@param isTesting boolean
function ShipMovement._handle071(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable.type071.locationIndex
  local len = #resultTable.type071.locations
  local location
  if index > len then
    location = resultTable.type071InLSTArea.locations[index - len]
  else
    location = resultTable.type071.locations[index]
  end
  ShipMovement._moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable.type071.locationIndex = index + 1
end

---@param ship CMO__Unit
---@param lat number|string
---@param lon number|string
---@param bearing number
function ShipMovement._setShipPosition(ship, lat, lon, bearing)
  local result, err = Utils.SafeCall("GameApi.ScenEdit_SetUnit", GameApi.ScenEdit_SetUnit, {
    guid = ship.guid,
    latitude = lat,
    longitude = lon,
    heading = bearing,
  })

  if not result then
    Logger.error("Error in ScenEdit_SetUnit: " .. err)
  end
end

---@param latitude number|string
---@param longitude number|string
---@param bearing number
---@param distance number
---@return CMO__Location
function ShipMovement._getNextPosition(latitude, longitude, bearing, distance)
  local point, err = Utils.SafeCall("GameApi.World_GetPointFromBearing", GameApi.World_GetPointFromBearing, {
    LATITUDE = latitude,
    LONGITUDE = longitude,
    BEARING = bearing,
    DISTANCE = distance,
  })

  if not point then
    Logger.error("Error in World_GetPointFromBearing: " .. err)
  end

  return point
end

---@param group table<string, table>
---@param isTesting boolean
function ShipMovement._handleSAG(group, isTesting)
  local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, group.groupName)

  if not unit then
    Logger.error("Error in ScenEdit_GetUnit: " .. err)
    goto continue
  end

  unit.course = group.to.archorageArea

  if isTesting then
    local count = #group.to.archorageArea
    local type052d, type054a = 0, 0

    for _, u in ipairs(unit.group.unitlist) do
      local ship, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, u)

      if not ship then
        Logger.error("Error in ScenEdit_GetUnit: " .. err)
        goto continue2
      end

      if ship.dbid == CONFIG.platformDBID48 then
        if type052d == 0 then
          ShipMovement._setShipPosition(ship, group.to.archorageArea[count].lat, group.to.archorageArea[count].lon,
            group.to.heading)
        else
          local point = ShipMovement._getNextPosition(
            group.to.archorageArea[count].lat,
            group.to.archorageArea[count].lon,
            group.to.heading - 180,
            1.5
          )
          ShipMovement._setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
        end

        type052d = type052d + 1
      elseif ship.dbid == CONFIG.platformDBID49 then
        local angle = (type054a == 0) and -45 or 45
        local point = ShipMovement._getNextPosition(
          group.to.archorageArea[count].lat,
          group.to.archorageArea[count].lon,
          group.to.heading - angle,
          1.5
        )
        ShipMovement._setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
        type054a = type054a + 1
      end

      ::continue2::
    end
  end
  ::continue::
end

---comment
---@param saveData SBJ__SaveData
---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit
---@return boolean
function ShipMovement.MoveToStagingArea(saveData, CONFIG, units)
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local calculations = saveData.c.PHIBOP.calculations
  local isTesting = saveData.c.PHIBOP.isTesting
  local allUnitsMoved = false

  for _, unitData in ipairs(units) do
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, unitData.guid)

    if not unit then
      Logger.error('Failed to get unit ' .. unitData.guid .. ': ' .. err)
      goto continue
    end

    for _, item in ipairs(initialLocations) do
      if unit and unit:inArea(item.from.stagingArea) then
        local result = calculations[item.name].result
        local matched = false

        for shipType, handler in pairs({
          type075 = ShipMovement._handleShipType,
          type076 = ShipMovement._handleShipType,
          type072iii = ShipMovement._handleShipType,
          type072a = ShipMovement._handleShipType,
          type073a = ShipMovement._handleShipType,
          type071 = ShipMovement._handle071,
        }) do
          if unit.dbid == result[shipType].dbid then
            handler(unit, result, shipType, shipSettings, isTesting)
            matched = true
            break
          end
        end

        if not matched then
          for nameType, handler in pairs({
            ferry = ShipMovement._handleNameType,
            RORO = ShipMovement._handleNameType,
            barge = ShipMovement._handleNameType,
          }) do
            if unit.name == nameType:gsub("^%l", string.upper) then
              handler(unit, result, nameType, shipSettings, isTesting)
              break
            end
          end
        end
      end
    end

    ::continue::
  end

  -- 這裡可改用 handleSAG(group, isTesting) 模組化處理 SAG 群組移動
  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    ShipMovement._handleSAG(group, isTesting)
  end

  allUnitsMoved = true
  return allUnitsMoved
end

---comment
---@param saveData SBJ__SaveData
function ShipMovement.CalculateDestination(saveData)
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local shipSettings = CONFIG.c.PHIBOP.shipSettings

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.to.areas) do
      local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
      local firstRp076 = GetPointFromBearing({
        initialLocation = firstRp071,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpBarge = GetPointFromBearing({
        initialLocation = firstRp075,
        bearing = area.heading.vertical,
        distance = shipSettings.distanceBetweenLSTAndLPDArea
      })
      local firstRpRORO = GetPointFromBearing({
        initialLocation = firstRpBarge,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072a = GetPointFromBearing({
        initialLocation = firstRpRORO,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp072iii = GetPointFromBearing({
        initialLocation = firstRp072a,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpFerry = GetPointFromBearing({
        initialLocation = firstRp072iii,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp071InLSTArea = GetPointFromBearing({
        initialLocation = firstRpFerry,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp073a = GetPointFromBearing({
        initialLocation = firstRp071InLSTArea,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type075.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp075,
          num = area.num.type075,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp071,
          num = area.num.type071,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type076.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp076,
          num = area.num.type076,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.barge.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRpBarge,
          num = area.num.barge,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        })
      )
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.roro.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRpRORO,
          num = area.num.roro,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072iii.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp072iii,
          num = area.num.type072iii,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072a.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp072a,
          num = area.num.type072a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.ferry.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRpFerry,
          num = area.num.ferry,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type073a.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp073a,
          num = area.num.type073a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      Utils.InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071InLSTArea.locations,
        GameUtils.GenerateLocations({
          initialLocation = firstRp071InLSTArea,
          num = area.num.type071InLSTArea,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
    end
  end
end

return ShipMovement
