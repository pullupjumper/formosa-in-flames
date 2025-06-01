---@param fromUnit CMO__Unit
---@param toUnit CMO__Unit
---@param cargoItem CargoItem
function UpdateCargo(fromUnit, toUnit, cargoItem)
  local cargoGuidList = {}
  local count = 0

  if fromUnit == nil or fromUnit.cargo[1].cargo == nil then
    return
  end

  for k, v in ipairs(fromUnit.cargo[1].cargo) do
    if v.dbid == cargoItem.dbid then
      table.insert(cargoGuidList, v.guid)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for k, v in ipairs(cargoGuidList) do
    fromUnit:deleteUnitCargo(v)
  end

  for i = 1, cargoItem.num, 1 do
    toUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
  end
end

---@param fromUnit CMO__Unit
---@param cargoItem CargoItem
function DeleteCargo(fromUnit, cargoItem)
  local cargoGuidList = {}
  local count = 0
  local resultCount = 0

  -- if fromUnit == nil or (fromUnit.cargo[1].cargo == nil) then
  --     return
  -- end

  if fromUnit == nil or
      fromUnit.cargo == nil or
      cargoItem.num == 0 or
      (fromUnit.cargo and fromUnit.cargo[1] == nil) then
    return 0
  end

  for k, v in ipairs(fromUnit.cargo[1].cargo) do
    if v.dbid == cargoItem.dbid then
      table.insert(cargoGuidList, v.guid)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for k, v in ipairs(cargoGuidList) do
    local result = fromUnit:deleteUnitCargo(v)

    if result then
      resultCount = resultCount + 1
    end
  end

  return resultCount
end

---@param fromUnit string
---@param platformType string
---@param platformDBid number
---@param loadoutDBID number
---@param cargoItems table<number, CargoItem>
function TransferCargo(fromUnit, platformType, platformDBid, loadoutDBID, cargoItems)
  local base = ScenEdit_GetUnit({ guid = fromUnit })
  if base == nil then return end
  local platforms = base.embarkedUnits[platformType]
  local baseContainingCargo = base

  if platforms ~= nil then
    local count = GetCount(cargoItems)

    for k, v in ipairs(platforms) do
      local unit = SE_GetUnit({ guid = v })

      if platformType == 'Aircraft' then
        if unit ~= nil and unit.dbid == platformDBid and unit.loadoutdbid == loadoutDBID then
          if count > 1 then
            for _, item in ipairs(cargoItems[k]) do
              UpdateCargo(baseContainingCargo, unit, item)
            end
          else
            for _, item in ipairs(cargoItems[1]) do
              UpdateCargo(baseContainingCargo, unit, item)
            end
          end
        end
      else
        if unit ~= nil and unit.dbid == platformDBid then
          if count > 1 then
            for _, item in ipairs(cargoItems[k]) do
              UpdateCargo(baseContainingCargo, unit, item)
            end
          else
            for _, item in ipairs(cargoItems[1]) do
              UpdateCargo(baseContainingCargo, unit, item)
            end
          end
        end
      end
    end
  end
end

---@class Point
---@field latitude string
---@field longitude string
---@param points table<number, Point>
function GetCourseByPoints(points)
  local course = {}
  for k, v in pairs(points) do
    course[k] = { TypeOf = 'ManualPlottedCourseWaypoint', latitude = v.latitude, longitude = v.longitude }
  end
  return course
end

---@class LocationParam:table
---@field initialLocation table
---@field num number
---@field bearing number
---@field distance number
---@param params LocationParam
function GenerateLocations(params)
  local numTemp = params.num
  local bearingTemp = params.bearing
  local distanceTemp = 0
  local locations = {}
  local locationTemp = params.initialLocation

  if numTemp == 0 then
    return {}
  end

  for i = 1, numTemp, 1 do
    if i > 1 then
      distanceTemp = params.distance
    end

    locationTemp = World_GetPointFromBearing({
      LATITUDE = locationTemp.latitude,
      LONGITUDE = locationTemp.longitude,
      BEARING = bearingTemp,
      DISTANCE = distanceTemp
    })

    table.insert(locations, locationTemp)
  end

  return locations
end

---@class ShipLocationParam:table
---@field ship CMO__Unit
---@field num number
---@field bearing number
---@field distance number
---@param params LocationParam
function GenerateACVLocations(params)
  local locations = {}
  local ship = params.ship
  local bearing = params.bearing
  local distance = params.distance

  local col = GenerateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = (bearing + 90),
    distance = distance
  })

  locations = InsertList(locations, col)
  return locations
end

function GenerateLocationsForOffload(params)
  local numTemp = params.num
  local bearingTemp = params.bearing
  local distanceTemp = 0
  local firstDistance = params.firstDistance
  local locations = {}
  local locationTemp = { latitude = params.ship.latitude, longitude = params.ship.longitude }

  if numTemp == 0 then
    return {}
  end

  for i = 1, numTemp, 1 do
    if i > 1 then
      distanceTemp = params.distance
    else
      distanceTemp = firstDistance
    end

    locationTemp = World_GetPointFromBearing({
      LATITUDE = locationTemp.latitude,
      LONGITUDE = locationTemp.longitude,
      BEARING = bearingTemp,
      DISTANCE = distanceTemp
    })

    table.insert(locations, locationTemp)
  end

  return locations
end

function OffloadVehicles(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end
  local ACVlocations = GenerateLocationsForOffload(params)
  local cargoList = {}
  local count = 0
  local resultCount = 0

  for index, v in ipairs(ship.cargo[1].cargo) do
    table.insert(cargoList, { guid = v.guid, dbid = v.dbid, name = v.name })
    count = count + 1

    if count == params.num then
      break
    end
  end

  for index, v in ipairs(cargoList) do
    ship:deleteUnitCargo(v.guid)

    local u = ScenEdit_AddUnit({
      side      = 'China',
      type      = 'Facility',
      latitude  = ACVlocations[index].latitude,
      longitude = ACVlocations[index].longitude,
      dbid      = v.dbid,
      unitname  = v.name,
    })

    if u then
      resultCount = resultCount + 1
    end
  end

  return resultCount
end

---@class ACVLocationParam:table
---@field transitBearing number
---@field transitDistance number
---@field ship CMO__Unit
---@field speed number
---@field destination table
---@param params ACVLocationParam
function LaunchACV(params)
  local ship = params.ship
  local destination = params.destination
  local ACVlocations = GenerateACVLocations(params)
  if ship == nil or ship.IsDestroyed then return end
  local zbd = DeleteCargo(ship, { type = 2, num = params.num, dbid = 241 })
  local ztd = DeleteCargo(ship, { type = 2, num = params.num - zbd, dbid = 240 })
  local index = 0
  local count = 0

  if ztd > 0 then
    for i = 1, ztd, 1 do
      local addedUnit = ScenEdit_AddUnit({
        side = 'China',
        type = 'Vehicle',
        name = 'ZTD-05',
        dbid = 240,
        LATITUDE = ACVlocations[i].latitude,
        LONGITUDE = ACVlocations[i].longitude,
      })
      if addedUnit == nil then return end
      ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })
      addedUnit.throttle = 'Full'
      addedUnit.course = destination
      index = i
      count = count + 1
    end
  end

  if zbd > 0 then
    for i = index + 1, index + zbd, 1 do
      local addedUnit = ScenEdit_AddUnit({
        side = 'China',
        type = 'Vehicle',
        name = 'ZBD-05',
        dbid = 241,
        LATITUDE = ACVlocations[i].latitude,
        LONGITUDE = ACVlocations[i].longitude,
      })
      if addedUnit == nil then return end
      ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })
      addedUnit.throttle = 'Full'
      addedUnit.course = destination
      count = count + 1
    end
  end

  return count
end

---@param units table<number, CMO_Unit>
---@param course CMO__TableOfWaypoints
function SetCourseToUnits(course, units)
  for k, v in ipairs(units) do
    local unit = ScenEdit_GetUnit({ guid = v.guid })

    -- unit.course = course
    if unit then
      local destinationTemp = World_GetPointFromBearing({
        LATITUDE = unit.latitude,
        LONGITUDE = unit.longitude,
        BEARING = course.bearing,
        DISTANCE = course.distance
      })

      unit.course = GetCourseByPoints({ destinationTemp })
    end
  end
end

---@class EmbarkedUnit
---@field num number
---@field unit CMO__Unit
---@param shipId string
---@param units table<number, EmbarkedUnit>
function AddUnitsToShip(shipId, units)
  for k, unit in ipairs(units) do
    -- local name = unit[2].name

    for j = 1, unit[1], 1 do
      unit[2].base = shipId
      -- unit[2].name = name .. ' #' .. j
      ScenEdit_AddUnit(unit[2])
    end
  end
end

---@param params LocationParam
---@param unit CMO__Unit
---@param embarkedUnits table<number, EmbarkedUnit>|nil
function AddUnitsByRP(params, unit, embarkedUnits)
  local locations = GenerateLocations(params)
  local unitTemp = nil

  for k, v in ipairs(locations) do
    unit.latitude = v.latitude
    unit.longitude = v.longitude
    unitTemp = ScenEdit_AddUnit(unit)

    if unitTemp and unit.cargo then
      for key, cargoItem in ipairs(unit.cargo) do
        for i = 1, cargoItem.num, 1 do
          unitTemp:createUnitCargo(cargoItem.type, cargoItem.dbid)
        end
      end

      if embarkedUnits then
        AddUnitsToShip(unitTemp.guid, embarkedUnits)
      end
    end
  end
end

function GetPointFromBearing(params)
  local initialLocation = params.initialLocation
  local bearing = params.bearing
  local distance = params.distance

  return GenerateLocations({
    initialLocation = initialLocation,
    num = 2,
    bearing = bearing,
    distance = distance
  })[2]
end

function AddLandingShips()
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local cargoList = CONFIG.c.PHIBOP.cargoList

  for _, item in ipairs(initialLocations) do
    for _, area in ipairs(item.from.areas) do
      local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
      local firstRp071 = GetPointFromBearing({
        initialLocation = firstRp075,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRp076 = GetPointFromBearing({
        initialLocation = firstRp071,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })
      local firstRpBarge = GetPointFromBearing({
        initialLocation = firstRp076,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
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

      local firstRp073a = GetPointFromBearing({
        initialLocation = firstRpFerry,
        bearing = area.heading.vertical,
        distance = shipSettings.verticalDistance
      })

      AddUnitsByRP(
        {
          initialLocation = firstRp075,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type075
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 075',
          dbid = CONFIG.platformDBID6,
          cargo = cargoList.type075,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          { 6, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID2,
            loadoutid = CONFIG.loadoutDBID3
          } },
          { 6, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID2,
            loadoutid = CONFIG.loadoutDBID4
          } },
          { 13, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID5,
            loadoutid = CONFIG.loadoutDBID2
          } },
          { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp071,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type071
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 071',
          dbid = CONFIG.platformDBID7,
          cargo = cargoList.type071,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          { 4, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID2,
            loadoutid = CONFIG.loadoutDBID3
          } },
          { 4, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp076,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type076
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 076',
          dbid = CONFIG.platformDBID54,
          cargo = cargoList.type075,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        {
          { 6, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID2,
            loadoutid = CONFIG.loadoutDBID3
          } },
          { 6, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID2,
            loadoutid = CONFIG.loadoutDBID4
          } },
          { 13, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID5,
            loadoutid = CONFIG.loadoutDBID2
          } },
          { 8, {
            side = 'China',
            type = 'aircraft',
            name = item.names[1],
            dbid = CONFIG.platformDBID55,
            loadoutid = CONFIG.loadoutDBID6
          } },
          { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.platformDBID1 } },
        }
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpBarge,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.barge
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Barge',
          dbid = CONFIG.platformDBID72,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpRORO,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.roro
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'RORO',
          dbid = CONFIG.platformDBID56,
          cargo = cargoList.barge,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp072a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type072a
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 072A',
          dbid = CONFIG.platformDBID9,
          cargo = cargoList.type072a,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp072iii,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type072iii
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 072III',
          dbid = CONFIG.platformDBID8,
          cargo = cargoList.type072iii,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRpFerry,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.ferry
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Ferry',
          dbid = CONFIG.platformDBID56,
          cargo = cargoList.ferry,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )

      AddUnitsByRP(
        {
          initialLocation = firstRp073a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance,
          num = item.from.num.type073a
        },
        {
          side = 'China',
          type = 'Ship',
          name = 'Type 073A',
          dbid = CONFIG.platformDBID10,
          cargo = cargoList.type073a,
          heading = area.heading.vertical,
          manualSpeed = shipSettings.shipSpeed,
        },
        nil
      )
    end
  end
end

function CalculateDestination(saveData)
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

      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type075.locations,
        GenerateLocations({
          initialLocation = firstRp075,
          num = area.num.type075,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071.locations,
        GenerateLocations({
          initialLocation = firstRp071,
          num = area.num.type071,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type076.locations,
        GenerateLocations({
          initialLocation = firstRp076,
          num = area.num.type076,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.barge.locations,
        GenerateLocations({
          initialLocation = firstRpBarge,
          num = area.num.barge,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        })
      )
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.roro.locations,
        GenerateLocations({
          initialLocation = firstRpRORO,
          num = area.num.roro,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072iii.locations,
        GenerateLocations({
          initialLocation = firstRp072iii,
          num = area.num.type072iii,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type072a.locations,
        GenerateLocations({
          initialLocation = firstRp072a,
          num = area.num.type072a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.ferry.locations,
        GenerateLocations({
          initialLocation = firstRpFerry,
          num = area.num.ferry,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type073a.locations,
        GenerateLocations({
          initialLocation = firstRp073a,
          num = area.num.type073a,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
      InsertList(
        saveData.c.PHIBOP.calculations[item.name].result.type071InLSTArea.locations,
        GenerateLocations({
          initialLocation = firstRp071InLSTArea,
          num = area.num.type071InLSTArea,
          bearing = area.heading.horizontal,
          distance = shipSettings.horizontalDistance
        }))
    end
  end
end

function RemoveLandingShips()
  local unitsFromChina = VP_GetSide({ Side = 'China' }).units
  for index, u in ipairs(unitsFromChina) do
    local unit = SE_GetUnit({ guid = u.guid })
    if unit == nil then goto continue end

    if unit.dbid == CONFIG.platformDBID6 or
        unit.dbid == CONFIG.platformDBID7 or
        unit.dbid == CONFIG.platformDBID8 or
        unit.dbid == CONFIG.platformDBID9 or
        unit.dbid == CONFIG.platformDBID10 or
        unit.dbid == CONFIG.platformDBID32 or
        unit.dbid == CONFIG.platformDBID54 or
        unit.dbid == CONFIG.platformDBID56 then
      ScenEdit_DeleteUnit({ side = 'China', guid = unit.guid })
    end

    ::continue::
  end
end
