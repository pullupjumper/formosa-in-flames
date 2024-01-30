function addLandingShipsForTest()
    for key, shipType in pairs(LANDING_OPERATION.SHIP_LOCATION_INFO[1].to.result) do
        for index, location in ipairs(shipType.locations) do
            local embarkedUnits = nil

            if shipType.dbid == PLATFORM_DBID_6 then
                embarkedUnits = {
                    { 12, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Warhorse',
                        dbid = PLATFORM_DBID_2,
                        loadoutid = LOADOUT_DBID_3
                    } },
                    { 13, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Wardog',
                        dbid = PLATFORM_DBID_4,
                        loadoutid = LOADOUT_DBID_1
                    } },
                    { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = PLATFORM_DBID_1 } },
                }
            end

            if shipType.dbid == PLATFORM_DBID_6 and index > 3 then
                embarkedUnits = {
                    { 12, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Warhorse',
                        dbid = PLATFORM_DBID_2,
                        loadoutid = LOADOUT_DBID_3
                    } },
                    { 13, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Wardog',
                        dbid = PLATFORM_DBID_5,
                        loadoutid = LOADOUT_DBID_2
                    } },
                    { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = PLATFORM_DBID_1 } },
                }
            end

            if shipType.dbid == PLATFORM_DBID_7 then
                embarkedUnits = {
                    { 4, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Warhorse',
                        dbid = PLATFORM_DBID_2,
                        loadoutid = LOADOUT_DBID_3
                    } },
                    { 4, { side = 'China', type = 'ship', name = 'Warbird', dbid = PLATFORM_DBID_1 } },
                }
            end

            addUnitsByRp(
                {
                    initialLocation = location,
                    bearing = LANDING_OPERATION.SHIP_LOCATION_INFO[1].to.areas[1].heading.horizontal,
                    distance = LANDING_OPERATION.SHIP_INFO.horizontalDistance,
                    num = 1
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = key,
                    dbid = shipType.dbid,
                    cargo = LANDING_OPERATION.CARGOLIST[key],
                    heading = LANDING_OPERATION.SHIP_LOCATION_INFO[1].to.areas[1].heading.vertical,
                    manualSpeed = LANDING_OPERATION.SHIP_INFO.shipSpeed,
                },
                embarkedUnits
            )
        end
    end

    local type052dLocationsWest = ScenEdit_GetReferencePoints({
        side = "China",
        area = { "RP-4330", "RP-4331", "RP-7756", "RP-7757" }
    })
    local type052dLocationsNorth = ScenEdit_GetReferencePoints({
        side = "China",
        area = { "RP-4334", "RP-4335", "RP-7758", "RP-7759" }
    })

    local type055LocationsWest = ScenEdit_GetReferencePoints({
        side = "China",
        area = { "RP-4332" }
    })
    local type055LocationsNorth = ScenEdit_GetReferencePoints({
        side = "China",
        area = { "RP-4333" }
    })

    if type052dLocationsWest == nil
        or type052dLocationsNorth == nil
        or type055LocationsWest == nil
        or type055LocationsNorth == nil then
        return
    end

    for k, v in ipairs(type052dLocationsWest) do
        local unit = ScenEdit_AddUnit({
            side = 'China',
            type = 'Ship',
            name = 'Type 052D',
            dbid = 2296,
            latitude = type052dLocationsWest[k].latitude,
            longitude = type052dLocationsWest[k].longitude,
            heading = LANDING_OPERATION.SHIP_INFO.heading.west.vertical
        })
        ScenEdit_SetEMCON("Unit", unit.guid, "Radar=Active;OECM=Active")
    end


    for k, v in ipairs(type052dLocationsNorth) do
        local unit = ScenEdit_AddUnit({
            side = 'China',
            type = 'Ship',
            name = 'Type 052D',
            dbid = 2296,
            latitude = type052dLocationsNorth[k].latitude,
            longitude = type052dLocationsNorth[k].longitude,
            heading = LANDING_OPERATION.SHIP_INFO.heading.north.vertical
        })
        ScenEdit_SetEMCON("Unit", unit.guid, "Radar=Active;OECM=Active")
    end

    for k, v in ipairs(type055LocationsWest) do
        local unit = ScenEdit_AddUnit({
            side = 'China',
            type = 'Ship',
            name = 'Type 055',
            dbid = 2834,
            latitude = type055LocationsWest[k].latitude,
            longitude = type055LocationsWest[k].longitude,
            heading = LANDING_OPERATION.SHIP_INFO.heading.west.vertical
        })
        ScenEdit_SetEMCON("Unit", unit.guid, "Radar=Active;OECM=Active")
    end

    for k, v in ipairs(type055LocationsNorth) do
        local unit = ScenEdit_AddUnit({
            side = 'China',
            type = 'Ship',
            name = 'Type 055',
            dbid = 2834,
            latitude = type055LocationsNorth[k].latitude,
            longitude = type055LocationsNorth[k].longitude,
            heading = LANDING_OPERATION.SHIP_INFO.heading.north.vertical
        })
        ScenEdit_SetEMCON("Unit", unit.guid, "Radar=Active;OECM=Active")
    end
end

function clearDestination()
    for key, shipType in pairs(LANDING_OPERATION.SHIP_LOCATION_INFO[1].to.result) do
        shipType.locations = {}
    end
end

LANDING_OPERATION.SHIP_LOCATION_INFO[1].to.areas[1].num = {
    type075 = 3,
    type071 = 2,
    type072iii = 7,
    type072a = 6,
    type073a = 2,
    type071InLSTArea = 2,
}
clearDestination()
calculateDestination()
addLandingShipsForTest()
