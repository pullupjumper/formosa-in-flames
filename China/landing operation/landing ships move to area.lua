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
                local groupNameForLHD = infoItem.name .. ' LHD/LPD Landing Ship Group'
                local groupNameForLST = infoItem.name .. ' LST Landing Ship Group'
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

                    unit.group = groupNameForLHD
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type075.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type072iii.dbid then
                    local locationIndex = infoItem.to.result.type072iii.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
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

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type072a.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type073a.dbid then
                    local locationIndex = infoItem.to.result.type073a.locationIndex

                    if groupForLST and GetCount(groupForLST.course) == 0 then
                        groupForLST.course = GetCourseByPoints({ locationFor072a })
                        groupForLST.manualSpeed = shipInfo.shipSpeed
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

                    unit.group = groupNameForLST
                    locationIndex = locationIndex + 1
                    infoItem.to.result.type072a2.locationIndex = locationIndex
                elseif unit.dbid == infoItem.to.result.type071.dbid then
                    local locationIndex = infoItem.to.result.type071.locationIndex

                    if locationIndex > 2 then
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

                    locationIndex = locationIndex + 1
                    infoItem.to.result.type071.locationIndex = locationIndex
                end
            end
        end

        CONFIG.c.landingOperation.isLandingShipsArrived = true
        CONFIG.c.landingOperation.isLandingShipsStartedMoving = false
    end
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
                or unit.dbid == CONFIG.const.platformBDID32) then
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
        for _, missionName in ipairs(zone.boat.missions) do
            local mission = ScenEdit_AddMission('China', missionName, 'Cargo', { zone = zone.boat.zone })
            -- mission.isactive = false
            ScenEdit_SetMission('China', missionName, zone.boat.settings)
            ScenEdit_SetDoctrine({ side = 'China', mission = missionName }, { automatic_evasion = false })
        end

        for _, missionName in ipairs(zone.tansportHelicopter.missions) do
            local mission = ScenEdit_AddMission('China', missionName, 'Cargo', { zone = zone.tansportHelicopter.zone })
            -- mission.isactive = false
            ScenEdit_SetMission('China', missionName, zone.tansportHelicopter.settings)
            ScenEdit_SetDoctrine({ side = 'China', mission = missionName }, { automatic_evasion = false })
        end
    end
end

local function transferCargosAndAssignHelicoptersToMissions(unitsInAnchorageArea1, CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

    for _, zone in ipairs(operationalZones) do
        for _, u in ipairs(unitsInAnchorageArea1) do
            if u ~= nil and u.dbid == CONFIG.const.platformBDID6 and u:inArea(zone.anchorageArea) then
                -- TransferCargo(
                --     u.guid,
                --     'Boats',
                --     zone.boat.dbid,
                --     zone.boat.cargoItem
                -- )
                -- TransferCargo(
                --     u.guid,
                --     'Aircraft',
                --     zone.tansportHelicopter.dbid,
                --     zone.tansportHelicopter.cargoItem
                -- )
                TransferCargo(
                    u.guid,
                    'Boats',
                    zone.boat.dbid,
                    0,
                    zone.boat.cargoItem
                )
                TransferCargo(
                    u.guid,
                    'Aircraft',
                    zone.tansportHelicopter.dbid,
                    zone.tansportHelicopter.cargoItems[1].loadoutId,
                    zone.tansportHelicopter.cargoItems[1].cargoItem
                )
                TransferCargo(
                    u.guid,
                    'Aircraft',
                    zone.tansportHelicopter.dbid,
                    zone.tansportHelicopter.cargoItems[2].loadoutId,
                    zone.tansportHelicopter.cargoItems[2].cargoItem
                )
                AssignEmbarkedUnitsToEachMissionByMissionNum(
                    u.guid,
                    'Boats',
                    zone.boat.dbid,
                    zone.boat.missions
                )
                AssignEmbarkedUnitsToEachMissionByMissionNum(
                    u.guid,
                    'Aircraft',
                    zone.tansportHelicopter.dbid,
                    zone.tansportHelicopter.missions
                )
                AssignEmbarkedUnitToMissionByUnitNum(
                    u.guid,
                    13,
                    zone.attackHelicopter1.dbid,
                    'Aircraft',
                    zone.attackHelicopter1.missions[1]
                )
                AssignEmbarkedUnitToMissionByUnitNum(
                    u.guid,
                    13,
                    zone.attackHelicopter2.dbid,
                    'Aircraft',
                    zone.attackHelicopter2.missions[1]
                )
            end

            if u ~= nil and u.dbid == CONFIG.const.platformBDID7 and u:inArea(zone.anchorageArea) then
                -- TransferCargo(
                --     u.guid,
                --     'Boats',
                --     zone.boat.dbid,
                --     zone.boat.cargoItem
                -- )
                -- TransferCargo(
                --     u.guid,
                --     'Aircraft',
                --     zone.tansportHelicopter.dbid,
                --     zone.tansportHelicopter.cargoItem
                -- )
                TransferCargo(
                    u.guid,
                    'Boats',
                    zone.boat.dbid,
                    0,
                    zone.boat.cargoItem
                )
                TransferCargo(
                    u.guid,
                    'Aircraft',
                    zone.tansportHelicopter.dbid,
                    zone.tansportHelicopter.cargoItems[1].loadoutId,
                    zone.tansportHelicopter.cargoItems[1].cargoItem
                )
                AssignEmbarkedUnitsToEachMissionByMissionNum(
                    u.guid,
                    'Boats',
                    zone.boat.dbid,
                    zone.boat.missions
                )
                AssignEmbarkedUnitsToEachMissionByMissionNum(
                    u.guid,
                    'Aircraft',
                    zone.tansportHelicopter.dbid,
                    zone.tansportHelicopter.missions
                )
            end
        end
    end

    -- for _, value in ipairs(CONFIG.c.landingOperation.const.helicopterAtBase) do
    --     AssignEmbarkedUnitToMissionByUnitNum(
    --         value.guid,
    --         value.num,
    --         CONFIG.const.platformBDID5,
    --         'Aircraft',
    --         value.missionName
    --     )
    -- end

    for _, value in ipairs(CONFIG.c.landingOperation.const.transportAircraft) do
        TransferCargo(
            value.guid,
            'Aircraft',
            value.dbid,
            value.cargoItems[1].loadoutId,
            value.cargoItems[1].cargoItem
        )
        AssignEmbarkedUnitToMissionByUnitNum(
            value.guid,
            value.num,
            CONFIG.const.platformBDID40,
            'Aircraft',
            value.missionName
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
    local airlandingMissionStartTime1 = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime()))
    local airlandingMissionStartTime2 = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + 30 * 60))
    local airlandingMissionStartTime3 = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + 60 * 60))
    local landingMissionStartTime = os.date("%m/%d/%Y %I:%M:%S %p", (ScenEdit_CurrentTime() + 4 * 60))

    ScenEdit_GetMission('China', 'LANDING ZONE').starttime = landingMissionStartTime
    -- ScenEdit_GetMission('China', 'LANDING ZONE BAO').starttime = landingMissionStartTime
    -- ScenEdit_GetMission('China', 'LANDING ZONE ZHUWEI').starttime = landingMissionStartTime
    -- ScenEdit_GetMission('China', 'LANDING ZONE NORTH WAY').starttime = landingMissionStartTime
    -- ScenEdit_GetMission('China', 'LANDING ZONE NORTH LEO').starttime = landingMissionStartTime
    -- ScenEdit_GetMission('China', 'LANDING ZONE JIALUTANG').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE PENGHU').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE SISHU').starttime = landingMissionStartTime

    ScenEdit_GetMission('China', 'AIRLANDING ZONE 1').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 1').starttime = airlandingMissionStartTime1
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 2').starttime = airlandingMissionStartTime2
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 1').starttime = airlandingMissionStartTime1
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 2').starttime = airlandingMissionStartTime2
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 1').starttime = airlandingMissionStartTime1
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 2').starttime = airlandingMissionStartTime2
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 3').starttime = airlandingMissionStartTime3
    ScenEdit_GetMission('China', 'AIRLANDING ZONE CHANGLONG 1').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE CHANGLONG 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE CHANGLONG 3').starttime = airlandingMissionStartTime3
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PENGHU 1').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PENGHU 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PENGHU 3').starttime = airlandingMissionStartTime3
end

local function setCoursesForLSTs(CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        for _, zone in ipairs(operationalZones) do
            if unit and unit:inArea(zone.LSTAnchorageArea) then
                if unit.dbid == CONFIG.const.platformBDID10 or unit.dbid == CONFIG.const.platformBDID32 then
                    unit.course = nil
                    unit.manualSpeed = zone.LSTSettings.speed
                    ScenEdit_AssignUnitToMission(unit.guid, zone.boat.missions[1])
                else
                    local destinationTemp = World_GetPointFromBearing({
                        LATITUDE = unit.latitude,
                        LONGITUDE = unit.longitude,
                        BEARING = zone.LSTSettings.course.bearing,
                        DISTANCE = zone.LSTSettings.course.distance
                    })
                    unit.course = GetCourseByPoints({ destinationTemp })
                    unit.manualSpeed = zone.LSTSettings.speed
                end
            end
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
    local diff = 0
    local landingAttackStartTime = CONFIG.c.landingOperation.amphibiousLandingAttackStartTime

    if landingAttackStartTime then
        diff = ScenEdit_CurrentTime() - landingAttackStartTime
    end

    if contacts == nil then
        return
    end

    local contactNum = getContactNumInArea(contacts, shipLocationInfo[1].airLandingZone)
    local isContactNumLessThan = contactNum < shipLocationInfo[1].numOfContactsInAirLandingZone
    local isTimeExceeded = landingAttackStartTime and diff >= CONFIG.c.landingOperation.const.periodOfTime

    if isContactNumLessThan or isTimeExceeded then
        setLandingMissionStartTime(CONFIG)
        setCoursesForLSTs(CONFIG)
        ScenEdit_MsgBox('Start air landing', 0)
        CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = false
    end
end

local function retransferCargos(CONFIG)
    local operationalZones = CONFIG.c.landingOperation.const.operationalZones
    local diffTime = ScenEdit_CurrentTime() - CONFIG.c.landingOperation.airlandingMissionStartTime

    if diffTime >= (3600 * 2) then
        for _, zone in ipairs(operationalZones) do
            for _, value in ipairs(units) do
                local unit = SE_GetUnit({ guid = value.guid })

                -- if unit and (unit.dbid == CONFIG.const.platformBDID6 or unit.dbid == CONFIG.const.platformBDID7) then
                --     TransferCargo(
                --         unit.guid,
                --         'Boats',
                --         zone.boat.dbid,
                --         zone.boat.cargoItem
                --     )
                --     TransferCargo(
                --         unit.guid,
                --         'Aircraft',
                --         zone.tansportHelicopter.dbid,
                --         zone.tansportHelicopter.cargoItem
                --     )
                -- end
                if unit and unit.dbid == CONFIG.const.platformBDID6 then
                    TransferCargo(
                        unit.guid,
                        'Boats',
                        zone.boat.dbid,
                        0,
                        zone.boat.cargoItem
                    )
                    TransferCargo(
                        unit.guid,
                        'Aircraft',
                        zone.tansportHelicopter.dbid,
                        zone.tansportHelicopter.cargoItems[1].loadoutId,
                        zone.tansportHelicopter.cargoItems[1].cargoItem
                    )
                    TransferCargo(
                        unit.guid,
                        'Aircraft',
                        zone.tansportHelicopter.dbid,
                        zone.tansportHelicopter.cargoItems[2].loadoutId,
                        zone.tansportHelicopter.cargoItems[2].cargoItem
                    )
                end

                if unit and unit.dbid == CONFIG.const.platformBDID7 then
                    TransferCargo(
                        unit.guid,
                        'Boats',
                        zone.boat.dbid,
                        0,
                        zone.boat.cargoItem
                    )
                    TransferCargo(
                        unit.guid,
                        'Aircraft',
                        zone.tansportHelicopter.dbid,
                        zone.tansportHelicopter.cargoItems[1].loadoutId,
                        zone.tansportHelicopter.cargoItems[1].cargoItem
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
end

if CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched then
    startAirLanding(CONFIG)
end

if CONFIG.c.landingOperation.airlandingMissionStartTime ~= nil then
    retransferCargos(CONFIG)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
