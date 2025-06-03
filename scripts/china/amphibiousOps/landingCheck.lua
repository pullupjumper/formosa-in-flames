local units = VP_GetSide({ Side = 'China' }).units
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

-- local function setCoursesForAllShips(saveData)
--   local shipSettings = CONFIG.c.PHIBOP.shipSettings
--   local initialLocations = CONFIG.c.PHIBOP.initialLocations
--   local calculations = saveData.c.PHIBOP.calculations

--   for _, _item in ipairs(units) do
--     local actualUnit = SE_GetUnit({ guid = _item.guid })

--     for _, item in ipairs(initialLocations) do
--       if actualUnit and actualUnit:inArea(item.from.stagingArea) then
--         local groupNameForLHD = item.name .. ' LHD/LPD Grp'
--         local groupNameForLST = item.name .. ' LST Grp'
--         local groupForLHD = ScenEdit_GetUnit({ unitname = groupNameForLHD })
--         local groupForLST = ScenEdit_GetUnit({ unitname = groupNameForLST })
--         local locationFor075 = calculations[item.name].result.type075.locations[1]
--         local locationFor072a = calculations[item.name].result.type072a.locations[1]

--         if actualUnit.dbid == calculations[item.name].result.type075.dbid then
--           local locationIndex = calculations[item.name].result.type075.locationIndex

--           if groupForLHD and GetCount(groupForLHD.course) == 0 then
--             groupForLHD.course = GetCourseByPoints({ locationFor075 })
--             groupForLHD.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.type075.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.type075.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLHD
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type075.locationIndex = locationIndex
--         elseif actualUnit.dbid == calculations[item.name].result.type076.dbid then
--           local locationIndex = calculations[item.name].result.type076.locationIndex

--           if groupForLHD and GetCount(groupForLHD.course) == 0 then
--             groupForLHD.course = GetCourseByPoints({ locationFor075 })
--             groupForLHD.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.type076.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.type076.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLHD
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type076.locationIndex = locationIndex
--         elseif actualUnit.dbid == calculations[item.name].result.type072iii.dbid then
--           local locationIndex = calculations[item.name].result.type072iii.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.type072iii.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.type072iii.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type072iii.locationIndex = locationIndex
--         elseif actualUnit.dbid == calculations[item.name].result.type072a.dbid then
--           local locationIndex = calculations[item.name].result.type072a.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.type072a.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.type072a.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type072a.locationIndex = locationIndex
--         elseif actualUnit.name == 'Ferry' then
--           local locationIndex = calculations[item.name].result.ferry.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.ferry.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.ferry.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.ferry.locationIndex = locationIndex
--         elseif actualUnit.name == 'RORO' then
--           local locationIndex = calculations[item.name].result.roro.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.roro.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.roro.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.roro.locationIndex = locationIndex
--         elseif actualUnit.name == 'Barge' then
--           local locationIndex = calculations[item.name].result.barge.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.barge.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.barge.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.barge.locationIndex = locationIndex
--         elseif actualUnit.dbid == calculations[item.name].result.type073a.dbid then
--           local locationIndex = calculations[item.name].result.type073a.locationIndex

--           if groupForLST and GetCount(groupForLST.course) == 0 then
--             groupForLST.course = GetCourseByPoints({ locationFor072a })
--             groupForLST.manualSpeed = shipSettings.shipSpeed
--           end

--           if saveData.c.PHIBOP.isTesting then
--             ScenEdit_SetUnit({
--               guid = actualUnit.guid,
--               latitude = calculations[item.name].result.type073a.locations[locationIndex].latitude,
--               longitude = calculations[item.name].result.type073a.locations[locationIndex].longitude,
--               manualSpeed = 0,
--             })
--           end

--           actualUnit.group = groupNameForLST
--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type073a.locationIndex = locationIndex
--         elseif actualUnit.dbid == calculations[item.name].result.type071.dbid then
--           local locationIndex = calculations[item.name].result.type071.locationIndex
--           local len = GetCount(calculations[item.name].result.type071.locations)

--           if locationIndex > len then
--             if groupForLST and GetCount(groupForLST.course) == 0 then
--               groupForLST.course = GetCourseByPoints({ locationFor072a })
--               groupForLST.manualSpeed = shipSettings.shipSpeed
--             end

--             actualUnit.group = groupNameForLST
--           else
--             if groupForLHD and GetCount(groupForLHD.course) == 0 then
--               groupForLHD.course = GetCourseByPoints({ locationFor075 })
--               groupForLHD.manualSpeed = shipSettings.shipSpeed
--             end

--             actualUnit.group = groupNameForLHD
--           end

--           if saveData.c.PHIBOP.isTesting then
--             if locationIndex > len then
--               ScenEdit_SetUnit({
--                 guid = actualUnit.guid,
--                 latitude = calculations[item.name].result.type071InLSTArea.locations
--                     [locationIndex - len].latitude,
--                 longitude = calculations[item.name].result.type071InLSTArea.locations
--                     [locationIndex - len].longitude,
--                 manualSpeed = 0,
--               })
--             else
--               ScenEdit_SetUnit({
--                 guid = actualUnit.guid,
--                 latitude = calculations[item.name].result.type071.locations[locationIndex].latitude,
--                 longitude = calculations[item.name].result.type071.locations[locationIndex].longitude,
--                 manualSpeed = 0,
--               })
--             end
--           end

--           locationIndex = locationIndex + 1
--           calculations[item.name].result.type071.locationIndex = locationIndex
--         end
--       end
--     end
--   end

--   for _, group in pairs(CONFIG.c.PHIBOP.sag) do
--     -- local unit = SE_GetUnit({ guid = group.guid })
--     local unit = SE_GetUnit({ side = 'China', unitname = group.groupName })
--     if unit == nil then goto continue end
--     unit.course = group.to.archorageArea

--     if saveData.c.PHIBOP.isTesting then
--       local count = GetCount(group.to.archorageArea)
--       local type052d = 0
--       local type054a = 0

--       for _, u in ipairs(unit.group.unitlist) do
--         local ship = SE_GetUnit({ guid = u })
--         if ship == nil then goto continue2 end

--         if ship.dbid == CONFIG.platformDBID48 then
--           if type052d == 0 then
--             ScenEdit_SetUnit({
--               guid = ship.guid,
--               latitude = group.to.archorageArea[count].lat,
--               longitude = group.to.archorageArea[count].lon,
--               heading = group.to.heading,
--             })
--           else
--             local point = World_GetPointFromBearing({
--               LATITUDE = group.to.archorageArea[count].lat,
--               LONGITUDE = group.to.archorageArea[count].lon,
--               BEARING = group.to.heading - 180,
--               DISTANCE = 1.5,
--             })
--             ScenEdit_SetUnit({
--               guid = ship.guid,
--               latitude = point.latitude,
--               longitude = point.longitude,
--               heading = group.to.heading,
--             })
--           end
--           type052d = type052d + 1
--         end

--         if ship.dbid == CONFIG.platformDBID49 then
--           if type054a == 0 then
--             local point = World_GetPointFromBearing({
--               LATITUDE = group.to.archorageArea[count].lat,
--               LONGITUDE = group.to.archorageArea[count].lon,
--               BEARING = group.to.heading - 45,
--               DISTANCE = 1.5,
--             })
--             ScenEdit_SetUnit({
--               guid = ship.guid,
--               latitude = point.latitude,
--               longitude = point.longitude,
--               heading = group.to.heading,
--             })
--           else
--             local point = World_GetPointFromBearing({
--               LATITUDE = group.to.archorageArea[count].lat,
--               LONGITUDE = group.to.archorageArea[count].lon,
--               BEARING = group.to.heading + 45,
--               DISTANCE = 1.5,
--             })
--             ScenEdit_SetUnit({
--               guid = ship.guid,
--               latitude = point.latitude,
--               longitude = point.longitude,
--               heading = group.to.heading,
--             })
--           end
--           type054a = type054a + 1
--         end

--         ::continue2::
--       end
--     end

--     ::continue::
--   end

--   saveData.c.PHIBOP.isShipsArrivedInStagingArea = true
--   saveData.c.PHIBOP.isShipsStartedMoving = false
-- end

local function setCoursesForAllShips(saveData)
  local shipSettings = CONFIG.c.PHIBOP.shipSettings
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local calculations = saveData.c.PHIBOP.calculations

  for _, _item in ipairs(units) do
    local actualUnit = SE_GetUnit({ guid = _item.guid })

    for _, item in ipairs(initialLocations) do
      if actualUnit and actualUnit:inArea(item.from.stagingArea) then
        if actualUnit.dbid == calculations[item.name].result.type075.dbid then
          local locationIndex = calculations[item.name].result.type075.locationIndex
          local location = calculations[item.name].result.type075.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type075.locationIndex = locationIndex
        elseif actualUnit.dbid == calculations[item.name].result.type076.dbid then
          local locationIndex = calculations[item.name].result.type076.locationIndex
          local location = calculations[item.name].result.type076.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type076.locationIndex = locationIndex
        elseif actualUnit.dbid == calculations[item.name].result.type072iii.dbid then
          local locationIndex = calculations[item.name].result.type072iii.locationIndex
          local location = calculations[item.name].result.type072iii.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type072iii.locationIndex = locationIndex
        elseif actualUnit.dbid == calculations[item.name].result.type072a.dbid then
          local locationIndex = calculations[item.name].result.type072a.locationIndex
          local location = calculations[item.name].result.type072a.locations[locationIndex]

          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type072a.locationIndex = locationIndex
        elseif actualUnit.name == 'Ferry' then
          local locationIndex = calculations[item.name].result.ferry.locationIndex
          local location = calculations[item.name].result.ferry.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.ferry.locationIndex = locationIndex
        elseif actualUnit.name == 'RORO' then
          local locationIndex = calculations[item.name].result.roro.locationIndex
          local location = calculations[item.name].result.roro.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.roro.locationIndex = locationIndex
        elseif actualUnit.name == 'Barge' then
          local locationIndex = calculations[item.name].result.barge.locationIndex
          local location = calculations[item.name].result.barge.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.barge.locationIndex = locationIndex
        elseif actualUnit.dbid == calculations[item.name].result.type073a.dbid then
          local locationIndex = calculations[item.name].result.type073a.locationIndex
          local location = calculations[item.name].result.type073a.locations[locationIndex]
          actualUnit.course = { location }
          actualUnit.manualSpeed = shipSettings.shipSpeed

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type073a.locationIndex = locationIndex
        elseif actualUnit.dbid == calculations[item.name].result.type071.dbid then
          local locationIndex = calculations[item.name].result.type071.locationIndex
          local len = GetCount(calculations[item.name].result.type071.locations)
          local location = nil

          if locationIndex > len then
            location = calculations[item.name].result.type071InLSTArea.locations[locationIndex - len]
            actualUnit.course = { location }
            actualUnit.manualSpeed = shipSettings.shipSpeed
          else
            location = calculations[item.name].result.type071.locations[locationIndex]
            actualUnit.course = { location }
            actualUnit.manualSpeed = shipSettings.shipSpeed
          end

          if saveData.c.PHIBOP.isTesting then
            ScenEdit_SetUnit({
              guid = actualUnit.guid,
              latitude = location.latitude,
              longitude = location.longitude,
              manualSpeed = 0,
            })
          end

          locationIndex = locationIndex + 1
          calculations[item.name].result.type071.locationIndex = locationIndex
        end
      end
    end
  end

  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    -- local unit = SE_GetUnit({ guid = group.guid })
    local unit = SE_GetUnit({ side = 'China', unitname = group.groupName })
    if unit == nil then goto continue end
    unit.course = group.to.archorageArea

    if saveData.c.PHIBOP.isTesting then
      local count = GetCount(group.to.archorageArea)
      local type052d = 0
      local type054a = 0

      for _, u in ipairs(unit.group.unitlist) do
        local ship = SE_GetUnit({ guid = u })
        if ship == nil then goto continue2 end

        if ship.dbid == CONFIG.platformDBID48 then
          if type052d == 0 then
            ScenEdit_SetUnit({
              guid = ship.guid,
              latitude = group.to.archorageArea[count].lat,
              longitude = group.to.archorageArea[count].lon,
              heading = group.to.heading,
            })
          else
            local point = World_GetPointFromBearing({
              LATITUDE = group.to.archorageArea[count].lat,
              LONGITUDE = group.to.archorageArea[count].lon,
              BEARING = group.to.heading - 180,
              DISTANCE = 1.5,
            })
            ScenEdit_SetUnit({
              guid = ship.guid,
              latitude = point.latitude,
              longitude = point.longitude,
              heading = group.to.heading,
            })
          end
          type052d = type052d + 1
        end

        if ship.dbid == CONFIG.platformDBID49 then
          if type054a == 0 then
            local point = World_GetPointFromBearing({
              LATITUDE = group.to.archorageArea[count].lat,
              LONGITUDE = group.to.archorageArea[count].lon,
              BEARING = group.to.heading - 45,
              DISTANCE = 1.5,
            })
            ScenEdit_SetUnit({
              guid = ship.guid,
              latitude = point.latitude,
              longitude = point.longitude,
              heading = group.to.heading,
            })
          else
            local point = World_GetPointFromBearing({
              LATITUDE = group.to.archorageArea[count].lat,
              LONGITUDE = group.to.archorageArea[count].lon,
              BEARING = group.to.heading + 45,
              DISTANCE = 1.5,
            })
            ScenEdit_SetUnit({
              guid = ship.guid,
              latitude = point.latitude,
              longitude = point.longitude,
              heading = group.to.heading,
            })
          end
          type054a = type054a + 1
        end

        ::continue2::
      end
    end

    ::continue::
  end

  saveData.c.PHIBOP.isShipsArrivedInStagingArea = true
  saveData.c.PHIBOP.isShipsStartedMoving = false
end

local function getUnitsInAnchorageArea()
  local operationalZones = CONFIG.c.PHIBOP.operationalZones
  local unitsInAnchorageArea1 = {}
  local isUnitMoving = false

  for _, item in ipairs(units) do
    local unit = SE_GetUnit({ guid = item.guid })

    if unit ~= nil
        and (unit.dbid == CONFIG.platformDBID6
          or unit.dbid == CONFIG.platformDBID7
          or unit.dbid == CONFIG.platformDBID8
          or unit.dbid == CONFIG.platformDBID9
          or unit.dbid == CONFIG.platformDBID10
          or unit.dbid == CONFIG.platformDBID32
          or unit.dbid == CONFIG.platformDBID54
          or unit.dbid == CONFIG.platformDBID56
          or unit.dbid == CONFIG.platformDBID72) then
      if unit.unitstate ~= 'Unassigned' then
        isUnitMoving = true
        break
      end

      for _, zone in ipairs(operationalZones) do
        if unit:inArea(zone.anchorageArea) or unit:inArea(zone.LSTAnchorageArea) then
          table.insert(unitsInAnchorageArea1, unit)
        end
      end
    end
  end

  return { units = unitsInAnchorageArea1, isUnitMoving = isUnitMoving }
end

local function createCargoMissions()
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      ScenEdit_AddMission('China', mission.name, 'Cargo', { zone = zone.boat.zone })
      ScenEdit_SetMission('China', mission.name, zone.boat.settings)
      ScenEdit_SetDoctrine({ side = 'China', mission = mission.name }, { automatic_evasion = false })
    end

    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      ScenEdit_AddMission('China', mission.name, 'Cargo', { zone = zone.tansportHelicopter.zone })
      ScenEdit_SetMission('China', mission.name, zone.tansportHelicopter.settings)
      ScenEdit_SetDoctrine({ side = 'China', mission = mission.name }, { automatic_evasion = false })
    end
  end
end

local function transferCargosAndAssignHelicoptersToMissions(unitsInAnchorageArea1)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea1) do
      if u ~= nil and
          (u.dbid == CONFIG.platformDBID6 or u.dbid == CONFIG.platformDBID54) and
          u:inArea(zone.anchorageArea) then
        TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.attackHelicopter.dbid,
          zone.attackHelicopter.missions
        )

        if zone.reconUAV then
          AssignEmbarkedUnitsToMissions(
            u.guid,
            'Aircraft',
            zone.reconUAV.dbid,
            zone.reconUAV.missions
          )
        end
      end

      if u ~= nil and u.dbid == CONFIG.platformDBID7 and u:inArea(zone.anchorageArea) then
        TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
      end
    end
  end

  for _, item in ipairs(CONFIG.c.PHIBOP.transportAircraft) do
    TransferCargo(
      item.guid,
      'Aircraft',
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignEmbarkedUnitsToMissions(
      item.guid,
      'Aircraft',
      item.dbid,
      item.missions
    )
  end
end

local function startAmphibiousAssault(saveData)
  local result = getUnitsInAnchorageArea()

  if GetCount(result.units) > 15 and not result.isUnitMoving then
    createCargoMissions()
    transferCargosAndAssignHelicoptersToMissions(result.units)
    saveData.c.PHIBOP.isShipsArrivedInStagingArea = false
    saveData.c.PHIBOP.isAmphibiousAssaultLaunched = true
    saveData.c.PHIBOP.amphibiousAssaultStartTime = ScenEdit_CurrentTime()
    saveData.c.air.ATO['CAS/N/1'].isActivated = true
  end
end

local function setLandingMissionStartTime(saveData)
  saveData.c.PHIBOP.airlandingMissionStartTime = ScenEdit_CurrentTime()
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      local startTime = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + mission.startTime))
      ScenEdit_GetMission('China', mission.name).starttime = startTime
    end

    for _, mission in ipairs(zone.boat.missions) do
      local startTime = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + mission.startTime))
      ScenEdit_GetMission('China', mission.name).starttime = startTime
    end

    for _, mission in ipairs(zone.attackHelicopter.missions) do
      local startTime = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + mission.startTime))
      ScenEdit_GetMission('China', mission.name).starttime = startTime
    end
  end
end

local function setCoursesForLSTs()
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, item in ipairs(units) do
    local unit = SE_GetUnit({ guid = item.guid })

    for _, zone in ipairs(operationalZones) do
      if unit and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
        local destinationTemp = World_GetPointFromBearing({
          LATITUDE = unit.latitude,
          LONGITUDE = unit.longitude,
          BEARING = zone.LSTSettings.course.bearing,
          DISTANCE = zone.LSTSettings.course.distance
        })

        if unit.group and unit.group.name == (zone.name .. ' LST Grp') then
          unit.group = 'none'
        end

        if unit.name ~= 'RORO' and unit.name ~= 'Barge' then
          unit.course = { destinationTemp }
          unit.manualSpeed = zone.LSTSettings.speed
        end
      end
    end
  end

  for _, group in pairs(CONFIG.c.PHIBOP.sag) do
    local unit = SE_GetUnit({ side = 'China', unitname = group.groupName })

    if unit ~= nil then
      unit.course = group.to.amphibiousVehicleStagingArea
    end
  end
end

local function countContactsInArea(contacts, area)
  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(area) and contact.typed == 8 then
      table.insert(filteredContacts, contact)
    end
  end

  return GetCount(filteredContacts)
end

local function startAirLanding(saveData)
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local contacts = ScenEdit_GetContacts('China')
  local elapsedTime = 0
  local amphibiousAssaultStartTime = saveData.c.PHIBOP.amphibiousAssaultStartTime

  if amphibiousAssaultStartTime then
    elapsedTime = ScenEdit_CurrentTime() - amphibiousAssaultStartTime
  end

  if contacts == nil then return end

  local contactNum = countContactsInArea(contacts, initialLocations[1].airLandingZone)
  local isContactCountLessThan = contactNum < initialLocations[1].numOfContactsInAirLandingZone
  local isTimeExceeded = amphibiousAssaultStartTime and elapsedTime >= CONFIG.c.PHIBOP.periodOfTime

  if isContactCountLessThan or isTimeExceeded then
    setLandingMissionStartTime(CONFIG)
    setCoursesForLSTs()
    ScenEdit_MsgBox('Start air landing', 0)
    saveData.c.PHIBOP.isAmphibiousAssaultLaunched = false
    saveData.c.PHIBOP.isSecondWaveStarted = true
  end
end

local function retransferCargos(saveData)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones
  local elapsedTime = ScenEdit_CurrentTime() - saveData.c.PHIBOP.airlandingMissionStartTime

  if elapsedTime >= (3600 * 2) then
    for _, zone in ipairs(operationalZones) do
      for _, item in ipairs(units) do
        local unit = SE_GetUnit({ guid = item.guid })

        if unit and (unit.dbid == CONFIG.platformDBID6 or unit.dbid == CONFIG.platformDBID54) then
          TransferCargo(
            unit.guid,
            'Boats',
            zone.boat.dbid,
            zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
            zone.boat.cargoItemsForTransfer.type075[1].cargoItems
          )
          TransferCargo(
            unit.guid,
            'Aircraft',
            zone.tansportHelicopter.dbid,
            zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
            zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
          )
          TransferCargo(
            unit.guid,
            'Aircraft',
            zone.tansportHelicopter.dbid,
            zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
            zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
          )
        end

        if unit and unit.dbid == CONFIG.platformDBID7 then
          TransferCargo(
            unit.guid,
            'Boats',
            zone.boat.dbid,
            zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
            zone.boat.cargoItemsForTransfer.type071[1].cargoItems
          )
          TransferCargo(
            unit.guid,
            'Aircraft',
            zone.tansportHelicopter.dbid,
            zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
            zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
          )
        end
      end
    end
  end
end

local function calculateSphericalCenter(coords)
  -- 檢查輸入是否有效
  if not coords or #coords < 4 then
    return nil, "需要至少4個座標點來形成四方形"
  end

  -- 初始化笛卡爾座標總和
  local xSum = 0
  local ySum = 0
  local zSum = 0

  -- 將經緯度轉換為笛卡爾座標並計算總和
  for _, point in ipairs(coords) do
    if not point.latitude or not point.longitude then
      return nil, "每個座標點必須包含latitude和longitude屬性"
    end

    -- 將角度轉換為弧度
    local latRad = math.rad(point.latitude)
    local lonRad = math.rad(point.longitude)

    -- 轉換到笛卡爾座標
    local x = math.cos(latRad) * math.cos(lonRad)
    local y = math.cos(latRad) * math.sin(lonRad)
    local z = math.sin(latRad)

    xSum = xSum + x
    ySum = ySum + y
    zSum = zSum + z
  end

  -- 計算平均值
  local count = #coords
  local xAvg = xSum / count
  local yAvg = ySum / count
  local zAvg = zSum / count

  -- 將平均笛卡爾座標轉回經緯度
  local hyp = math.sqrt(xAvg * xAvg + yAvg * yAvg)
  local centerLat = math.deg(math.atan2(zAvg, hyp))
  local centerLon = math.deg(math.atan2(yAvg, xAvg))

  return {
    latitude = centerLat,
    longitude = centerLon
  }
end

local setCoursesForBarges = function(saveData)
  local result = CountUnitsInEachArea()

  if GetCount(result) > 0 and result['Taoyuan']['ZBD-05'] >= 1 then
    local operationalZones = CONFIG.c.PHIBOP.operationalZones
    local roros = {}
    local barges = {}

    for _, item in ipairs(units) do
      local actualUnit = SE_GetUnit({ guid = item.guid })

      for _, zone in ipairs(operationalZones) do
        if actualUnit and actualUnit.name == 'Barge' and actualUnit.type == 'Ship' and actualUnit:inArea(zone.LSTAnchorageArea) then
          local points = ScenEdit_GetReferencePoints({ side = "China", area = zone.offloadArea })
          local centerPoint = calculateSphericalCenter(points)

          if centerPoint then
            local d1 = Tool_Range({ latitude = actualUnit.latitude, longitude = actualUnit.longitude },
              centerPoint)
            local b1 = Tool_Bearing({ latitude = actualUnit.latitude, longitude = actualUnit.longitude },
              centerPoint)
            local b2 = math.abs(zone.LSTSettings.course.bearing - b1)
            local d2 = d1 * math.cos(b2 * 2 * math.pi / 360)
            local destination = World_GetPointFromBearing({
              latitude = actualUnit.latitude,
              longitude = actualUnit.longitude,
              distance = d2,
              bearing = zone.LSTSettings.course.bearing
            })
            actualUnit.course = { destination }
            actualUnit.manualSpeed = zone.LSTSettings.speed
            table.insert(barges, { unit = actualUnit, zone = zone, dest = destination })
            saveData.c.PHIBOP.barges[actualUnit.guid] = { guid = actualUnit.guid, roros = {} }
          end
        end

        if actualUnit and actualUnit.name == 'RORO' and actualUnit.type == 'Ship' and actualUnit:inArea(zone.LSTAnchorageArea) then
          table.insert(roros, { unit = actualUnit, zone = zone })
        end
      end
    end

    for _, item in ipairs(roros) do
      for _, barge in ipairs(barges) do
        if barge.unit:inArea(item.zone.LSTAnchorageArea) then
          table.insert(saveData.c.PHIBOP.barges[barge.unit.guid].roros, item.unit.guid)
          local destination = World_GetPointFromBearing({
            latitude = item.unit.latitude,
            longitude = item.unit.longitude,
            distance = item.zone.LSTSettings.course.distance,
            bearing = item.zone.LSTSettings.course.bearing
          })
          item.unit.course = { destination, barge.dest }
          item.unit.manualSpeed = item.zone.LSTSettings.speed
        end
      end
    end

    saveData.c.PHIBOP.isSecondWaveStarted = false
  end
end

if saveData.c.PHIBOP.isShipsStartedMoving then
  setCoursesForAllShips(saveData)
end

if saveData.c.PHIBOP.isShipsArrivedInStagingArea then
  startAmphibiousAssault(saveData)
end

if saveData.c.PHIBOP.isAmphibiousAssaultLaunched then
  startAirLanding(saveData)
end

if saveData.c.PHIBOP.isSecondWaveStarted then
  setCoursesForBarges(saveData)
end

if saveData.c.PHIBOP.airlandingMissionStartTime ~= nil then
  retransferCargos(saveData)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
