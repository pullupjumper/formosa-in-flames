local units = VP_GetSide({ Side = 'China' }).units
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

-- local function setCoursesForAllShips(CONFIG)
--     local shipInfo = CONFIG.c.landingOperation.const.shipInfo
--     local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo

--     for _, value in ipairs(units) do
--         local unit = SE_GetUnit({ guid = value.guid })

--         for _, infoItem in ipairs(shipLocationInfo) do
--             if unit and unit:inArea(infoItem.from.stagingArea) then
--                 unit.manualSpeed = shipInfo.shipSpeed

--                 if unit.dbid == infoItem.to.result.type075.dbid then
--                     local locationIndex = infoItem.to.result.type075.locationIndex
--                     local location = infoItem.to.result.type075.locations[locationIndex]
--                     unit.course = GetCourseByPoints({ location })
--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type075.locationIndex = locationIndex
--                 elseif unit.dbid == infoItem.to.result.type072iii.dbid then
--                     local locationIndex = infoItem.to.result.type072iii.locationIndex
--                     local location = infoItem.to.result.type072iii.locations[locationIndex]
--                     unit.course = GetCourseByPoints({ location })
--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type072iii.locationIndex = locationIndex
--                 elseif unit.dbid == infoItem.to.result.type072a.dbid then
--                     local locationIndex = infoItem.to.result.type072a.locationIndex
--                     local location = infoItem.to.result.type072a.locations[locationIndex]
--                     unit.course = GetCourseByPoints({ location })
--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type072a.locationIndex = locationIndex
--                 elseif unit.dbid == infoItem.to.result.type073a.dbid then
--                     local locationIndex = infoItem.to.result.type073a.locationIndex
--                     local location = infoItem.to.result.type073a.locations[locationIndex]
--                     unit.course = GetCourseByPoints({ location })
--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type073a.locationIndex = locationIndex
--                 elseif unit.dbid == infoItem.to.result.type072a2.dbid then
--                     local locationIndex = infoItem.to.result.type072a2.locationIndex
--                     local location = infoItem.to.result.type072a2.locations[locationIndex]
--                     unit.course = GetCourseByPoints({ location })
--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type072a2.locationIndex = locationIndex
--                 elseif unit.dbid == infoItem.to.result.type071.dbid then
--                     local locationIndex = infoItem.to.result.type071.locationIndex

--                     if locationIndex > 2 then
--                         local location = infoItem.to.result.type071InLSTArea.locations[locationIndex - 2]
--                         unit.course = GetCourseByPoints({ location })
--                     else
--                         local location = infoItem.to.result.type071.locations[locationIndex]
--                         unit.course = GetCourseByPoints({ location })
--                     end

--                     locationIndex = locationIndex + 1
--                     infoItem.to.result.type071.locationIndex = locationIndex
--                 end
--             end
--         end

--         CONFIG.c.landingOperation.isLandingShipsArrived = true
--         CONFIG.c.landingOperation.isLandingShipsStartedMoving = false
--     end
-- end

local function setCoursesForAllShips(CONFIG)
    local shipInfo = CONFIG.c.landingOperation.const.shipInfo
    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        for _, infoItem in ipairs(shipLocationInfo) do
            if unit and unit:inArea(infoItem.from.stagingArea) then
                local groupNameForLHD = infoItem.name .. ' LHD/LPD Grp'
                local groupNameForLST = infoItem.name .. ' LST Grp'
                local groupForLHD = ScenEdit_GetUnit({ unitname = groupNameForLHD })
                local groupForLST = ScenEdit_GetUnit({ unitname = groupNameForLST })
                local locationFor075 = infoItem.to.result.type075.locations[1]
                local locationFor072a = infoItem.to.result.type072a.locations[1]

                if unit.dbid == infoItem.to.result.type075.dbid then
                    local locationIndex = infoItem.to.result.type075.locationIndex

                    if groupForLHD and GetCount(groupForLHD.course) == 0 then
                        groupForLHD.course = GetCourseByPoints({ locationFor075 })
                        groupForLHD.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type075.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type075.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLHD
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type075.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type076.dbid then
                    local locationIndex = infoItem.to.result.type076.locationIndex

                    if groupForLHD and GetCount(groupForLHD.course) == 0 then
                        groupForLHD.course = GetCourseByPoints({ locationFor075 })
                        groupForLHD.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type076.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type076.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLHD
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type076.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type072iii.dbid then
                    local locationIndex = infoItem.to.result.type072iii.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type072iii.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type072iii.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type072iii.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type072a.dbid then
                    local locationIndex = infoItem.to.result.type072a.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type072a.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type072a.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type072a.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.ferry1.dbid then
                    local locationIndex = infoItem.to.result.ferry1.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.ferry1.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.ferry1.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.ferry1.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type073a.dbid then
                    local locationIndex = infoItem.to.result.type073a.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type073a.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type073a.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type073a.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type072a2.dbid then
                    local locationIndex = infoItem.to.result.type072a2.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        ScenEdit_SetUnit({
                            guid = unit.guid,
                            latitude = infoItem.to.result.type072a2.locations[locationIndex].latitude,
                            longitude = infoItem.to.result.type072a2.locations[locationIndex].longitude,
                            manualSpeed = 0,
                        })
                    end

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type072a2.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type071.dbid then
                    local locationIndex = infoItem.to.result.type071.locationIndex
                    local len = GetCount(infoItem.to.result.type071.locations)

                    if locationIndex > len then
                        if groupForLST and GetCount(groupForLST.course) == 0 then
                            groupForLST.course = GetCourseByPoints({ locationFor072a })
                            groupForLST.manualSpeed = shipInfo.shipSpeed
                        end

                        unit.group = groupNameForLST
                    else
                        if groupForLHD and GetCount(groupForLHD.course) == 0 then
                            groupForLHD.course = GetCourseByPoints({ locationFor075 })
                            groupForLHD.manualSpeed = shipInfo.shipSpeed
                        end

                        unit.group = groupNameForLHD
                    end

                    if CONFIG.c.landingOperation.isTesting then
                        if locationIndex > len then
                            ScenEdit_SetUnit({
                                guid = unit.guid,
                                latitude = infoItem.to.result.type071InLSTArea.locations[locationIndex - len].latitude,
                                longitude = infoItem.to.result.type071InLSTArea.locations[locationIndex - len].longitude,
                                manualSpeed = 0,
                            })
                        else
                            ScenEdit_SetUnit({
                                guid = unit.guid,
                                latitude = infoItem.to.result.type071.locations[locationIndex].latitude,
                                longitude = infoItem.to.result.type071.locations[locationIndex].longitude,
                                manualSpeed = 0,
                            })
                        end
                    end

                    locationIndex = locationIndex + 1
                    infoItem.to.result.type071.locationIndex = locationIndex
                end
            end
        end
    end

    for _, group in pairs(CONFIG.c.landingOperation.const.sag) do
        -- local unit = SE_GetUnit({ guid = group.guid })
        local unit = SE_GetUnit({ side = 'China', unitname = group.groupName })

        if unit ~= nil then
            unit.course = group.to.archorageArea

            if CONFIG.c.landingOperation.isTesting then
                local count = GetCount(group.to.archorageArea)
                local type052d = 0
                local type054a = 0

                for _, u in ipairs(unit.group.unitlist) do
                    local ship = SE_GetUnit({ guid = u })

                    if ship then
                        if ship.dbid == CONFIG.const.platformBDID48 then
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

                        if ship.dbid == CONFIG.const.platformBDID49 then
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
                    end
                end
            end
        end
    end

    CONFIG.c.landingOperation.isLandingShipsArrived = true
    CONFIG.c.landingOperation.isLandingShipsStartedMoving = false
end

local function getUnitsInAnchorageArea(CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones
    local unitsInAnchorageArea1 = {}
    local isUnitMoving = false

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit.dbid == CONFIG.const.platformBDID6
                or unit.dbid == CONFIG.const.platformBDID7
                or unit.dbid == CONFIG.const.platformBDID8
                or unit.dbid == CONFIG.const.platformBDID9
                or unit.dbid == CONFIG.const.platformBDID10
                or unit.dbid == CONFIG.const.platformBDID32
                or unit.dbid == CONFIG.const.platformBDID54
                or unit.dbid == CONFIG.const.platformBDID56) then
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
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

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

local function transferCargosAndAssignHelicoptersToMissions(unitsInAnchorageArea1, CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

    for _, zone in ipairs(operationalZones) do
        for _, u in ipairs(unitsInAnchorageArea1) do
            if u ~= nil and
                (u.dbid == CONFIG.const.platformBDID6 or u.dbid == CONFIG.const.platformBDID54) and
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

            if u ~= nil and u.dbid == CONFIG.const.platformBDID7 and u:inArea(zone.anchorageArea) then
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

    for _, value in ipairs(CONFIG.c.landingOperation.const.transportAircraft) do
        TransferCargo(
            value.guid,
            'Aircraft',
            value.dbid,
            value.cargoItemsForTransfer[1].loadoutId,
            value.cargoItemsForTransfer[1].cargoItems
        )
        AssignEmbarkedUnitsToMissions(
            value.guid,
            'Aircraft',
            value.dbid,
            value.missions
        )
    end
end

local function startAmphibiousLandingAttack(CONFIG)
    local result = getUnitsInAnchorageArea(CONFIG)

    if GetCount(result.units) > 15 and not result.isUnitMoving then
        createCargoMissions()
        transferCargosAndAssignHelicoptersToMissions(result.units, CONFIG)
        CONFIG.c.landingOperation.isLandingShipsArrived = false
        CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = true
        CONFIG.c.landingOperation.amphibiousLandingAttackStartTime = ScenEdit_CurrentTime()
    end
end

local function setLandingMissionStartTime(CONFIG)
    CONFIG.c.landingOperation.airlandingMissionStartTime = ScenEdit_CurrentTime()
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

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

local function setCoursesForLSTs(CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        for _, zone in ipairs(operationalZones) do
            if unit and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
                if unit.dbid == CONFIG.const.platformBDID10 or unit.dbid == CONFIG.const.platformBDID32 then
                    unit.group = "none"
                    unit.course = nil
                    unit.manualSpeed = zone.LSTSettings.speed
                    ScenEdit_AssignUnitToMission(unit.guid, zone.boat.missions[1].name)

                    -- local grpName = zone.name .. ' LSM Grp'
                    -- unit.group = grpName
                    -- -- unit.course = nil
                    -- unit.manualSpeed = zone.LSTSettings.speed
                    -- local grp = SE_GetUnit({ unitname = grpName })
                    -- grp.formation = { spacing_unit = 1, lead = unit.guid, name = 'Line', spacing = 0.5 }

                    -- if grp and grp.mission == nil then
                    --     ScenEdit_AssignUnitToMission(grp.guid, zone.boat.missions[1].name)
                    -- end
                else
                    local destinationTemp = World_GetPointFromBearing({
                        LATITUDE = unit.latitude,
                        LONGITUDE = unit.longitude,
                        BEARING = zone.LSTSettings.course.bearing,
                        DISTANCE = zone.LSTSettings.course.distance
                    })

                    if unit.group and unit.group.name == (zone.name .. ' LST Grp') then
                        unit.group = 'none'
                    end

                    unit.course = GetCourseByPoints({ destinationTemp })
                    unit.manualSpeed = zone.LSTSettings.speed
                end
            end

            -- if unit and unit.name==(zone.name .. ' LST Grp') then
            --     unit.formation = { spacing_unit = 1, name = 'Line', spacing = 0.2 }
            -- end
        end
    end

    for _, group in pairs(CONFIG.c.landingOperation.const.sag) do
        local unit = SE_GetUnit({ side = 'China', unitname = group.groupName })

        if unit ~= nil then
            unit.course = group.to.amphibiousVehicleStagingArea
        end
    end
end

local function getContactNumInArea(contacts, area)
    local filteredContacts = {}

    for _, contact in ipairs(contacts) do
        if contact:inArea(area) and contact.typed == 8 then
            table.insert(filteredContacts, contact)
        end
    end

    return GetCount(filteredContacts)
end

local function startAirLanding(CONFIG)
    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
    local contacts = ScenEdit_GetContacts('China')
    local elapsedTime = 0
    local landingAttackStartTime = CONFIG.c.landingOperation.amphibiousLandingAttackStartTime

    if landingAttackStartTime then
        elapsedTime = ScenEdit_CurrentTime() - landingAttackStartTime
    end

    if contacts == nil then
        return
    end

    local contactNum = getContactNumInArea(contacts, shipLocationInfo[1].airLandingZone)
    local isContactNumLessThan = contactNum < shipLocationInfo[1].numOfContactsInAirLandingZone
    local isTimeExceeded = landingAttackStartTime and elapsedTime >= CONFIG.c.landingOperation.const.periodOfTime

    if isContactNumLessThan or isTimeExceeded then
        setLandingMissionStartTime(CONFIG)
        setCoursesForLSTs(CONFIG)
        ScenEdit_MsgBox('Start air landing', 0)
        CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = false
    end
end

local function retransferCargos(CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones
    local elapsedTime = ScenEdit_CurrentTime() - CONFIG.c.landingOperation.airlandingMissionStartTime

    if elapsedTime >= (3600 * 2) then
        for _, zone in ipairs(operationalZones) do
            for _, value in ipairs(units) do
                local unit = SE_GetUnit({ guid = value.guid })

                if unit and (unit.dbid == CONFIG.const.platformBDID6 or unit.dbid == CONFIG.const.platformBDID54) then
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

                if unit and unit.dbid == CONFIG.const.platformBDID7 then
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

if CONFIG.c.landingOperation.isLandingShipsStartedMoving then
    setCoursesForAllShips(CONFIG)
end

if CONFIG.c.landingOperation.isLandingShipsArrived then
    startAmphibiousLandingAttack(CONFIG)
    CONFIG.c.air.landBased.gbu.isStrikeActivated = true
end

if CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched then
    startAirLanding(CONFIG)
end

if CONFIG.c.landingOperation.airlandingMissionStartTime ~= nil then
    retransferCargos(CONFIG)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
