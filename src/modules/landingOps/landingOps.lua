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

-- ---@param points table<number, {latitude:string|number, longitude:string|number}>
-- function GetCourseByPoints(points)
--   local course = {}
--   for k, v in pairs(points) do
--     course[k] = { TypeOf = 'ManualPlottedCourseWaypoint', latitude = v.latitude, longitude = v.longitude }
--   end
--   return course
-- end


-- ---@class ShipLocationParam:table
-- ---@field ship CMO__Unit
-- ---@field num number
-- ---@field bearing number
-- ---@field distance number
-- ---@param params SBJ__Location_Params
-- function GenerateACVLocations(params)
--   local locations = {}
--   local ship = params.ship
--   local bearing = params.bearing
--   local distance = params.distance

--   local col = GenerateLocations({
--     initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
--     num = params.num,
--     bearing = (bearing + 90),
--     distance = distance
--   })

--   locations = InsertList(locations, col)
--   return locations
-- end

-- ---@param params SBJ__OffloadVehicles_Params
-- ---@return table<number, CMO__Location>
-- function GenerateLocationsForOffload(params)
--   local numTemp = params.num
--   local bearingTemp = params.bearing
--   local distanceTemp = 0
--   local firstDistance = params.firstDistance
--   local locations = {}
--   local locationTemp = { latitude = params.ship.latitude, longitude = params.ship.longitude }

--   if numTemp == 0 then
--     return {}
--   end

--   for i = 1, numTemp, 1 do
--     if i > 1 then
--       distanceTemp = params.distance
--     else
--       distanceTemp = firstDistance
--     end

--     locationTemp = World_GetPointFromBearing({
--       LATITUDE = locationTemp.latitude,
--       LONGITUDE = locationTemp.longitude,
--       BEARING = bearingTemp,
--       DISTANCE = distanceTemp
--     })

--     table.insert(locations, locationTemp)
--   end

--   return locations
-- end

---@param params SBJ__OffloadVehicles_Params
---@return number|nil
function OffloadVehicles(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end
  local ACVlocations = GenerateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance,
    firstDistance = params.firstDistance
  })
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

---@param params SBJ__ACVLocation_Params
---@return number|nil
function LaunchACV(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end

  local destination = params.destination
  -- local ACVlocations = GenerateACVLocations(params)
  local ACVlocations = GenerateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance
  })

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

-- ---@param units table<number, CMO_Unit>
-- ---@param course CMO__TableOfWaypoints
-- function SetCourseToUnits(course, units)
--   for k, v in ipairs(units) do
--     local unit = ScenEdit_GetUnit({ guid = v.guid })

--     -- unit.course = course
--     if unit then
--       local destinationTemp = World_GetPointFromBearing({
--         LATITUDE = unit.latitude,
--         LONGITUDE = unit.longitude,
--         BEARING = course.bearing,
--         DISTANCE = course.distance
--       })

--       unit.course = GetCourseByPoints({ destinationTemp })
--     end
--   end
-- end

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

return {
  UpdateCargo = UpdateCargo,
  TransferCargo = TransferCargo,
  DeleteCargo = DeleteCargo,
  LaunchACV = LaunchACV,
  OffloadVehicles = OffloadVehicles,
  CalculateDestination = CalculateDestination
}
