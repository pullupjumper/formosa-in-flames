local units = VP_GetSide({ Side = 'China' }).units
local LANDING_OPERATION = gKH.State.LoadTableFromKey("LANDING_OPERATION")
local MLRS_ON_MOBILE_TARGETS = gKH.State.LoadTableFromKey("MLRS_ON_MOBILE_TARGETS")


if LANDING_OPERATION.IS_LANDING_SHIPS_STARTED_MOVING then
    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil then
            unit.manualSpeed = LANDING_OPERATION.SHIP_INFO.shipSpeed

            if unit.dbid == LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type075.dbid then
                local locationIndex = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type075.locationIndex
                local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type075.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type075.locationIndex =
                    locationIndex
            elseif unit.dbid == LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type072iii.dbid then
                local locationIndex = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type072iii.locationIndex
                local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type072iii.locations
                    [locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type072iii.locationIndex =
                    locationIndex
            elseif unit.dbid == LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type072a.dbid then
                local locationIndex = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type072a.locationIndex
                local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type072a.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type072a.locationIndex =
                    locationIndex
            elseif unit.dbid == LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type073a.dbid then
                local locationIndex = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type073a.locationIndex
                local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type073a.locations[locationIndex]
                unit.course = getCourseByPoints({ location })
                locationIndex = locationIndex + 1
                LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type073a.locationIndex =
                    locationIndex
            elseif unit.dbid == LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type071.dbid then
                local locationIndex = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                    .result.type071.locationIndex

                if locationIndex > 2 then
                    local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                        .result.type071InLSTArea.locations
                        [locationIndex - 2]
                    unit.course = getCourseByPoints({ location })
                else
                    local location = LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to
                        .result.type071.locations
                        [locationIndex]
                    unit.course = getCourseByPoints({ location })
                end

                locationIndex = locationIndex + 1
                LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].to.result.type071.locationIndex =
                    locationIndex
            end
        end
    end

    LANDING_OPERATION.IS_LANDING_SHIPS_ARRIVED = true
    LANDING_OPERATION.IS_LANDING_SHIPS_STARTED_MOVING = false
end

if LANDING_OPERATION.IS_LANDING_SHIPS_ARRIVED then
    local unitsInAnchorageArea1 = {}

    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit.dbid == PLATFORM_DBID_6
                or unit.dbid == PLATFORM_DBID_7
                or unit.dbid == PLATFORM_DBID_8
                or unit.dbid == PLATFORM_DBID_9
                or unit.dbid == PLATFORM_DBID_10) then
            if unit.unitstate ~= 'Unassigned' then
                break
            end

            -- if unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].anchorageArea) or unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].LSTAnchorageArea) then
            --     table.insert(unitsInAnchorageArea1, unit)
            -- end
            for i, info in ipairs(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER) do
                if unit:inArea(info.anchorageArea) or unit:inArea(info.LSTAnchorageArea) then
                    table.insert(unitsInAnchorageArea1, unit)
                end
            end
        end
    end

    if getCount(unitsInAnchorageArea1) > 15 then
        -- for index, unit in ipairs(unitsInAnchorageArea1) do
        --     if unit.dbid == PLATFORM_DBID_6 then
        --         transferCargo(
        --             unit.guid,
        --             'Boats',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.cargoList
        --         )
        --         transferCargo(
        --             unit.guid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.cargoList
        --         )
        --         assignEmbarkedUnitsToMission(
        --             unit.guid,
        --             'Boats',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.missions
        --         )
        --         assignEmbarkedUnitsToMission(
        --             unit.guid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.missions
        --         )
        --         assignUnitToFerryMission(
        --             unit.guid,
        --             13,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].attackHelicopter1.dbid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].attackHelicopter1.missions[1]
        --         )
        --         assignUnitToFerryMission(
        --             unit.guid,
        --             13,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].attackHelicopter2.dbid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].attackHelicopter2.missions[1]
        --         )
        --     end

        --     if unit.dbid == PLATFORM_DBID_7 and unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].anchorageArea) then
        --         transferCargo(
        --             unit.guid,
        --             'Boats',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.cargoList
        --         )
        --         transferCargo(
        --             unit.guid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.cargoList
        --         )
        --         assignEmbarkedUnitsToMission(
        --             unit.guid,
        --             'Boats',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.missions
        --         )
        --         assignEmbarkedUnitsToMission(
        --             unit.guid,
        --             'Aircraft',
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.dbid,
        --             LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.missions
        --         )
        --     end
        -- end
        createCargoMission()

        for index, info in ipairs(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER) do
            for i, u in ipairs(unitsInAnchorageArea1) do
                -- local u = SE_GetUnit({ guid = v.guid })

                if u ~= nil and u.dbid == PLATFORM_DBID_6 and u:inArea(info.anchorageArea) then
                    transferCargo(
                        u.guid,
                        'Boats',
                        info.boat.dbid,
                        info.boat.cargoList
                    )
                    transferCargo(
                        u.guid,
                        'Aircraft',
                        info.tansportHelicopter.dbid,
                        info.tansportHelicopter.cargoList
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

                if u ~= nil and u.dbid == PLATFORM_DBID_7 and u:inArea(info.anchorageArea) then
                    transferCargo(
                        u.guid,
                        'Boats',
                        info.boat.dbid,
                        info.boat.cargoList
                    )
                    transferCargo(
                        u.guid,
                        'Aircraft',
                        info.tansportHelicopter.dbid,
                        info.tansportHelicopter.cargoList
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

        for index, value in ipairs(HELICOPTER_BASE) do
            assignUnitToFerryMission(
                value.guid,
                value.num,
                PLATFORM_DBID_5,
                'Aircraft',
                value.missionName
            )
        end

        LANDING_OPERATION.IS_LANDING_SHIPS_ARRIVED = false
        LANDING_OPERATION.IS_AMPHIBIOUS_LANDING_ATTACK_LAUNCHED = true
        MLRS_ON_MOBILE_TARGETS.IS_STRIKE_ACTIVATED = true
    end
end

if LANDING_OPERATION.IS_AMPHIBIOUS_LANDING_ATTACK_LAUNCHED then
    local contacts = ScenEdit_GetContacts('China')
    local filteredContacts = {}

    if contacts == nil then
        return
    end

    for index, value in ipairs(contacts) do
        if value:inArea(LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].airLandingZone) and value.typed == 8 then
            table.insert(filteredContacts, value)
        end
    end

    if getCount(filteredContacts) < LANDING_OPERATION.SHIP_LOCATION_INFO[LANDING_OPERATION.IDX_SHIP_LOCATION_INFO].numOfContactsInAirLandingZone then
        local unitsInWestLSTAnchorageArea = {}
        local unitsInNorthLSTAnchorageArea = {}
        local unitsInSouthLSTAnchorageArea = {}
        setMissionStartTime()

        for index, value in ipairs(units) do
            local unit = SE_GetUnit({ guid = value.guid })

            if unit ~= nil
                and (unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].LSTAnchorageArea)
                    or unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[2].LSTAnchorageArea)
                    or unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[3].LSTAnchorageArea)) then
                table.insert(unitsInWestLSTAnchorageArea, unit)
                unit.manualSpeed = LANDING_OPERATION.SHIP_INFO.shipSpeed
            end

            if unit ~= nil and unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[4].LSTAnchorageArea) then
                table.insert(unitsInNorthLSTAnchorageArea, unit)
                unit.manualSpeed = LANDING_OPERATION.SHIP_INFO.shipSpeed
            end

            if unit ~= nil and unit:inArea(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[5].LSTAnchorageArea) then
                table.insert(unitsInSouthLSTAnchorageArea, unit)
                unit.manualSpeed = LANDING_OPERATION.SHIP_INFO.shipSpeed
            end
        end

        setCourseToUnits(
            {
                bearing = LANDING_OPERATION.SHIP_INFO.heading.west.vertical,
                distance = LANDING_OPERATION.SHIP_INFO.transitDistance
            },
            unitsInWestLSTAnchorageArea
        )
        setCourseToUnits(
            {
                bearing = LANDING_OPERATION.SHIP_INFO.heading.north.vertical,
                distance = LANDING_OPERATION.SHIP_INFO.transitDistance
            },
            unitsInNorthLSTAnchorageArea
        )
        setCourseToUnits(
            {
                bearing = LANDING_OPERATION.SHIP_INFO.heading.south.vertical,
                distance = LANDING_OPERATION.SHIP_INFO.transitDistance
            },
            unitsInSouthLSTAnchorageArea
        )
        ScenEdit_MsgBox('Launch amphibious landing attack', 0)
        LANDING_OPERATION.IS_AMPHIBIOUS_LANDING_ATTACK_LAUNCHED = false
    end
end

if LANDING_OPERATION.AIRLANDING_MISSION_STARTTIME ~= nil then
    local diffTime = ScenEdit_CurrentTime() - LANDING_OPERATION.AIRLANDING_MISSION_STARTTIME

    if diffTime >= (3600 * 2) then
        for index, value in ipairs(units) do
            local unit = SE_GetUnit({ guid = value.guid })

            if unit ~= nil
                and (unit.dbid == PLATFORM_DBID_6 or unit.dbid == PLATFORM_DBID_7) then
                transferCargo(
                    unit.guid,
                    'Boats',
                    LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.dbid,
                    LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].boat.cargoList
                )
                transferCargo(
                    unit.guid,
                    'Aircraft',
                    LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.dbid,
                    LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER[1].tansportHelicopter.cargoList
                )
            end
        end

        local currentTime = ScenEdit_CurrentTime()
        LANDING_OPERATION.AIRLANDING_MISSION_STARTTIME = currentTime
    end
end


if LANDING_OPERATION ~= nil and MLRS_ON_MOBILE_TARGETS ~= nil then
    gKH.State.SaveTableToKey(LANDING_OPERATION, "LANDING_OPERATION")
    gKH.State.SaveTableToKey(LANDING_OPERATION, "MLRS_ON_MOBILE_TARGETS")
end
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
