GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall

---@param unit CMO__Unit
---@param location CMO__Location
---@param speed number
---@param isTesting boolean
function _moveShip(unit, location, speed, isTesting)
  unit.course = { location }
  unit.manualSpeed = speed

  if isTesting then
    local result, err = SafeCall("GameApi.ScenEdit_SetUnit", GameApi.ScenEdit_SetUnit, {
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
function _handleShipType(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable[shipType].locationIndex
  local location = resultTable[shipType].locations[index]
  _moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[shipType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param nameType string
---@param shipSettings table<string, number>
---@param isTesting boolean
function _handleNameType(unit, resultTable, nameType, shipSettings, isTesting)
  nameType = string.lower(nameType)
  local index = resultTable[nameType].locationIndex
  local location = resultTable[nameType].locations[index]
  _moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable[nameType].locationIndex = index + 1
end

---@param unit CMO__Unit
---@param resultTable table<string, table>
---@param shipType string
---@param shipSettings table<string, number>
---@param isTesting boolean
function _handle071(unit, resultTable, shipType, shipSettings, isTesting)
  local index = resultTable.type071.locationIndex
  local len = #resultTable.type071.locations
  local location
  if index > len then
    location = resultTable.type071InLSTArea.locations[index - len]
  else
    location = resultTable.type071.locations[index]
  end
  _moveShip(unit, location, shipSettings.shipSpeed, isTesting)
  resultTable.type071.locationIndex = index + 1
end

---@param ship CMO__Unit
---@param lat number|string
---@param lon number|string
---@param bearing number
function _setShipPosition(ship, lat, lon, bearing)
  local result, err = SafeCall("GameApi.ScenEdit_SetUnit", GameApi.ScenEdit_SetUnit, {
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
function _getNextPosition(latitude, longitude, bearing, distance)
  local point, err = SafeCall("GameApi.World_GetPointFromBearing", GameApi.World_GetPointFromBearing, {
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
function _handleSAG(group, isTesting)
  local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, group.groupName)

  if not unit then
    Logger.error("Error in ScenEdit_GetUnit: " .. err)
    goto continue
  end

  unit.course = group.to.archorageArea

  if isTesting then
    local count = #group.to.archorageArea
    local type052d, type054a = 0, 0

    for _, u in ipairs(unit.group.unitlist) do
      local ship, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, u)

      if not ship then
        Logger.error("Error in ScenEdit_GetUnit: " .. err)
        goto continue2
      end

      if ship.dbid == CONFIG.platformDBID48 then
        if type052d == 0 then
          _setShipPosition(ship, group.to.archorageArea[count].lat, group.to.archorageArea[count].lon, group.to.heading)
        else
          local point = _getNextPosition(
            group.to.archorageArea[count].lat,
            group.to.archorageArea[count].lon,
            group.to.heading - 180,
            1.5
          )
          _setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
        end

        type052d = type052d + 1
      elseif ship.dbid == CONFIG.platformDBID49 then
        local angle = (type054a == 0) and -45 or 45
        local point = _getNextPosition(
          group.to.archorageArea[count].lat,
          group.to.archorageArea[count].lon,
          group.to.heading - angle,
          1.5
        )
        _setShipPosition(ship, point.latitude, point.longitude, group.to.heading)
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
function MoveToStagingArea(saveData, CONFIG, units)
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local calculations = saveData.c.PHIBOP.calculations
  local isTesting = saveData.c.PHIBOP.isTesting
  local allUnitsMoved = false

  for _, unitData in ipairs(units) do
    local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, unitData.guid)

    if not unit then
      Logger.error('Failed to get unit ' .. unitData.guid .. ': ' .. err)
      goto continue
    end

    for _, item in ipairs(initialLocations) do
      if unit:inArea(item.from.stagingArea) then
        local result = calculations[item.name].result
        local matched = false

        for shipType, handler in pairs({
          type075 = _handleShipType,
          type076 = _handleShipType,
          type072iii = _handleShipType,
          type072a = _handleShipType,
          type073a = _handleShipType,
          type071 = _handle071,
        }) do
          if unit.dbid == result[shipType].dbid then
            handler(unit, result, shipType, shipSettings, isTesting)
            matched = true
            break
          end
        end

        if not matched then
          for nameType, handler in pairs({
            ferry = _handleNameType,
            RORO = _handleNameType,
            barge = _handleNameType,
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
    _handleSAG(group, isTesting)
  end

  allUnitsMoved = true
  return allUnitsMoved
end

return {
  _moveShip = _moveShip,
  _setShipPosition = _setShipPosition,
  _getNextPosition = _getNextPosition,
  _handleShipType = _handleShipType,
  _handleNameType = _handleNameType,
  _handle071 = _handle071,
  _handleSAG = _handleSAG,
  MoveToStagingArea = MoveToStagingArea
}
