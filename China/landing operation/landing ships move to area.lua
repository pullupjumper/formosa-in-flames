local units = VP_GetSide({ Side = 'China' }).units
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

local shipInfo = CONFIG.c.landingOperation.const.shipInfo
local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
local idx = CONFIG.c.landingOperation.idxShipLocationInfo
local cargoInfoForTransfer = CONFIG.c.landingOperation.const.cargoInfoForTransfer

local function setCoursesToAllShips()
    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil then
            unit.manualSpeed = shipInfo.shipSpeed

            if unit.dbid == shipLocationInfo[idx].to.result.type075.dbid then
                local locationIndex = shipLocationInfo[idx].to.result.type075.locationIndex
                local location = shipLocationInfo[idx].to.result.type075.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                shipLocationInfo[idx].to.result.type075.locationIndex = locationIndex
            elseif unit.dbid == shipLocationInfo[idx].to.result.type072iii.dbid then
                local locationIndex = shipLocationInfo[idx].to.result.type072iii.locationIndex
                local location = shipLocationInfo[idx].to.result.type072iii.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                shipLocationInfo[idx].to.result.type072iii.locationIndex = locationIndex
            elseif unit.dbid == shipLocationInfo[idx].to.result.type072a.dbid then
                local locationIndex = shipLocationInfo[idx].to.result.type072a.locationIndex
                local location = shipLocationInfo[idx].to.result.type072a.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                shipLocationInfo[idx].to.result.type072a.locationIndex = locationIndex
            elseif unit.dbid == shipLocationInfo[idx].to.result.type073a.dbid then
                local locationIndex = shipLocationInfo[idx].to.result.type073a.locationIndex
                local location = shipLocationInfo[idx].to.result.type073a.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                shipLocationInfo[idx].to.result.type073a.locationIndex = locationIndex
            elseif unit.dbid == shipLocationInfo[idx].to.result.type071.dbid then
                local locationIndex = shipLocationInfo[idx].to.result.type071.locationIndex

                if locationIndex > 2 then
                    local location = shipLocationInfo[idx].to.result.type071InLSTArea.locations[locationIndex - 2]
                    unit.course = getCourseByPoints({ location })
                else
                    local location = shipLocationInfo[idx].to.result.type071.locations[locationIndex]
                    unit.course = getCourseByPoints({ location })
                end

                locationIndex = locationIndex + 1
                shipLocationInfo[idx].to.result.type071.locationIndex = locationIndex
            end
        end
    end
end

local function getUnitsInAnchorageArea()
    local unitsInAnchorageArea1 = {}

    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit.dbid == CONFIG.const.platformBDID6
                or unit.dbid == CONFIG.const.platformBDID7
                or unit.dbid == CONFIG.const.platformBDID8
                or unit.dbid == CONFIG.const.platformBDID9
                or unit.dbid == CONFIG.const.platformBDID10) then
            if unit.unitstate ~= 'Unassigned' then
                break
            end

            for i, info in ipairs(cargoInfoForTransfer) do
                if unit:inArea(info.anchorageArea) or unit:inArea(info.LSTAnchorageArea) then
                    table.insert(unitsInAnchorageArea1, unit)
                end
            end
        end
    end

    return unitsInAnchorageArea1
end

local function createCargoMissions()
    for index, m in ipairs(CONFIG.c.landingOperation.const.cargoMissionList) do
        local mission = ScenEdit_AddMission('China', m.name, 'Cargo', { zone = m.zone })
        mission.isactive = false
        ScenEdit_SetMission('China', m.name, m.setting)
    end
end

local function transferCargosAndAssignHelicoptersToMissions(unitsInAnchorageArea1)
    for index, info in ipairs(cargoInfoForTransfer) do
        for i, u in ipairs(unitsInAnchorageArea1) do
            -- local u = SE_GetUnit({ guid = v.guid })

            if u ~= nil and u.dbid == CONFIG.const.platformBDID6 and u:inArea(info.anchorageArea) then
                transferCargo(
                    u.guid,
                    'Boats',
                    info.boat.dbid,
                    info.boat.cargoItem
                )
                transferCargo(
                    u.guid,
                    'Aircraft',
                    info.tansportHelicopter.dbid,
                    info.tansportHelicopter.cargoItem
                )
                assignEmbarkedUnitsToMission(
                    u.guid,
                    'Boats',
                    info.boat.dbid,
                    info.boat.missions
                )
                assignEmbarkedUnitsToMission(
                    u.guid,
                    'Aircraft',
                    info.tansportHelicopter.dbid,
                    info.tansportHelicopter.missions
                )
                assignUnitToFerryMission(
                    u.guid,
                    13,
                    info.attackHelicopter1.dbid,
                    'Aircraft',
                    info.attackHelicopter1.missions[1]
                )
                assignUnitToFerryMission(
                    u.guid,
                    13,
                    info.attackHelicopter2.dbid,
                    'Aircraft',
                    info.attackHelicopter2.missions[1]
                )
            end

            if u ~= nil and u.dbid == CONFIG.const.platformBDID7 and u:inArea(info.anchorageArea) then
                transferCargo(
                    u.guid,
                    'Boats',
                    info.boat.dbid,
                    info.boat.cargoItem
                )
                transferCargo(
                    u.guid,
                    'Aircraft',
                    info.tansportHelicopter.dbid,
                    info.tansportHelicopter.cargoItem
                )
                assignEmbarkedUnitsToMission(
                    u.guid,
                    'Boats',
                    info.boat.dbid,
                    info.boat.missions
                )
                assignEmbarkedUnitsToMission(
                    u.guid,
                    'Aircraft',
                    info.tansportHelicopter.dbid,
                    info.tansportHelicopter.missions
                )
            end
        end
    end

    for index, value in ipairs(CONFIG.c.landingOperation.const.helicopterInBase) do
        assignUnitToFerryMission(
            value.guid,
            value.num,
            CONFIG.const.platformBDID5,
            'Aircraft',
            value.missionName
        )
    end
end

local function setLandingMissionStartTime()
    -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    -- if CONFIG == nil then
    --     print('CONFIG == nil')
    --     ScenEdit_MsgBox('CONFIG == nil', 1)
    --     return
    -- end

    local currentTime = ScenEdit_CurrentTime()
    CONFIG.c.landingOperation.airlandingMissionStartTime = currentTime
    local airlandingMissionStartTime1 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime))
    local airlandingMissionStartTime2 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 10 * 60))
    local airlandingMissionStartTime3 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 20 * 60))
    local airlandingMissionStartTime4 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 38 * 60))
    local landingMissionStartTime = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 4 * 60))

    ScenEdit_GetMission('China', 'LANDING ZONE').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE BAO').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE ZHUWEI').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE NORTH WAY').starttime = landingMissionStartTime
    ScenEdit_GetMission('China', 'LANDING ZONE NORTH LEO').starttime = landingMissionStartTime

    ScenEdit_GetMission('China', 'AIRLANDING ZONE').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE 4').starttime = airlandingMissionStartTime4
    ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE NORTH 4').starttime = airlandingMissionStartTime4
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 1').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE PARK 4').starttime = airlandingMissionStartTime4
    ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 1').starttime = airlandingMissionStartTime1
    ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 2').starttime = airlandingMissionStartTime2
    ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 3').starttime = airlandingMissionStartTime3
    -- ScenEdit_GetMission('China', 'AIRLANDING ZONE TAIPING 4').starttime = airlandingMissionStartTime4
    -- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

local function setupCoursesToLSTs()
    local unitsInWestLSTAnchorageArea = {}
    local unitsInNorthLSTAnchorageArea = {}
    local unitsInSouthLSTAnchorageArea = {}

    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit:inArea(cargoInfoForTransfer[1].LSTAnchorageArea)
                or unit:inArea(cargoInfoForTransfer[2].LSTAnchorageArea)
                or unit:inArea(cargoInfoForTransfer[3].LSTAnchorageArea)) then
            table.insert(unitsInWestLSTAnchorageArea, unit)
            unit.manualSpeed = shipInfo.shipSpeed
        end

        if unit ~= nil and unit:inArea(cargoInfoForTransfer[4].LSTAnchorageArea) then
            table.insert(unitsInNorthLSTAnchorageArea, unit)
            unit.manualSpeed = shipInfo.shipSpeed
        end

        if unit ~= nil and unit:inArea(cargoInfoForTransfer[5].LSTAnchorageArea) then
            table.insert(unitsInSouthLSTAnchorageArea, unit)
            unit.manualSpeed = shipInfo.shipSpeed
        end
    end

    setCourseToUnits(
        {
            bearing = shipInfo.heading.west.vertical,
            distance = shipInfo.transitDistance
        },
        unitsInWestLSTAnchorageArea
    )
    setCourseToUnits(
        {
            bearing = shipInfo.heading.north.vertical,
            distance = shipInfo.transitDistance
        },
        unitsInNorthLSTAnchorageArea
    )
    setCourseToUnits(
        {
            bearing = shipInfo.heading.south.vertical,
            distance = shipInfo.transitDistance
        },
        unitsInSouthLSTAnchorageArea
    )
end

local function retransferCargos()
    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit.dbid == CONFIG.const.platformBDID6 or unit.dbid == CONFIG.const.platformBDID7) then
            transferCargo(
                unit.guid,
                'Boats',
                cargoInfoForTransfer[1].boat.dbid,
                cargoInfoForTransfer[1].boat.cargoItem
            )
            transferCargo(
                unit.guid,
                'Aircraft',
                cargoInfoForTransfer[1].tansportHelicopter.dbid,
                cargoInfoForTransfer[1].tansportHelicopter.cargoItem
            )
        end
    end
end

if CONFIG.c.landingOperation.isLandingShipsStartedMoving then
    setCoursesToAllShips()
    CONFIG.c.landingOperation.isLandingShipsArrived = true
    CONFIG.c.landingOperation.isLandingShipsStartedMoving = false
end

if CONFIG.c.landingOperation.isLandingShipsArrived then
    local unitsInAnchorageArea1 = getUnitsInAnchorageArea()

    if getCount(unitsInAnchorageArea1) > 15 then
        createCargoMissions()
        transferCargosAndAssignHelicoptersToMissions(unitsInAnchorageArea1)
        CONFIG.c.landingOperation.isLandingShipsArrived = false
        CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = true
        CONFIG.c.landingOperation.amphibiousLandingAttackStartTime = ScenEdit_CurrentTime()
        CONFIG.c.mlrs.onMobileUnit.isStrikeActivated = true
    end
end

if CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched then
    local contacts = ScenEdit_GetContacts('China')
    local filteredContacts = {}
    local diff = 0
    local landingAttackStartTime = CONFIG.c.landingOperation.amphibiousLandingAttackStartTime

    if landingAttackStartTime ~= nil then
        diff = ScenEdit_CurrentTime() - landingAttackStartTime
    end

    if contacts == nil then
        return
    end

    for index, value in ipairs(contacts) do
        if value:inArea(shipLocationInfo[idx].airLandingZone) and value.typed == 8 then
            table.insert(filteredContacts, value)
        end
    end

    if getCount(filteredContacts) < shipLocationInfo[idx].numOfContactsInAirLandingZone
        or (landingAttackStartTime ~= nil and diff >= CONFIG.c.landingOperation.const.periodOfTime) then
        setLandingMissionStartTime()
        setupCoursesToLSTs()
        ScenEdit_MsgBox('Launch amphibious landing attack', 0)
        CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = false
    end
end

if CONFIG.c.landingOperation.airlandingMissionStartTime ~= nil then
    local diffTime = ScenEdit_CurrentTime() - CONFIG.c.landingOperation.airlandingMissionStartTime

    if diffTime >= (3600 * 2) then
        retransferCargos()
        local currentTime = ScenEdit_CurrentTime()
        CONFIG.c.landingOperation.airlandingMissionStartTime = currentTime
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
