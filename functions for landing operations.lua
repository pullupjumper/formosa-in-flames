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
end

---@param fromUnit string
---@param platformType string
---@param platformDBid number
---@param cargoItem CargoItem
function TransferCargo(fromUnit, platformType, platformDBid, cargoItem)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits[platformType]

    if platforms ~= nil then
        ScenEdit_SpecialMessage('China', tostring(platforms.name))

        for k, v in ipairs(platforms) do
            local unit = SE_GetUnit({ guid = v })

            if unit ~= nil and unit.dbid == platformDBid then
                UpdateCargo(base, unit, cargoItem)
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
function GenerateIFVLocations(params)
    local locations = {}
    local ship = params.ship
    local bearing = params.bearing
    local distance = params.distance

    if params.num == 10 then
        local col = GenerateLocations({
            initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
            num = 10,
            bearing = (bearing + 90),
            distance = distance
        })

        locations = InsertList(locations, col)
    elseif params.num == 40 then
        local firstLocation = World_GetPointFromBearing({
            LATITUDE = ship.latitude,
            LONGITUDE = ship.longitude,
            BEARING = (bearing + 180),
            DISTANCE = (distance * 1.5)
        })

        local firstRow = GenerateLocations({
            initialLocation = firstLocation,
            num = 4,
            bearing = bearing,
            distance = distance
        })

        for index, initLocation in ipairs(firstRow) do
            local col = GenerateLocations({
                initialLocation = initLocation,
                num = 10,
                bearing = (bearing + 90),
                distance = distance
            })

            locations = InsertList(locations, col)
        end
    end

    return locations
end

---@class IFVLocationParam:table
---@field transitBearing number
---@field transitDistance number
---@field ship CMO__Unit
---@field speed number
---@param params IFVLocationParam
function LaunchAmphibiousIFV(params)
    local ship = params.ship
    local transitBearing = params.transitBearing
    local transitDistance = params.transitDistance
    local speed = params.speed
    local IFVlocations = GenerateIFVLocations(params)

    local destinationTemp = {}
    local courseTemp = {}
    -- local unitTemp = {}

    if ship == nil or ship.IsDestroyed then
        return
    end

    DeleteCargo(ship, { type = 2, num = params.num, dbid = 3 })

    for k, v in ipairs(IFVlocations) do
        destinationTemp = World_GetPointFromBearing({
            LATITUDE = v.latitude,
            LONGITUDE = v.longitude,
            BEARING = transitBearing,
            DISTANCE = transitDistance
        })

        courseTemp = GetCourseByPoints({ destinationTemp })

        local addedUnit = ScenEdit_AddUnit({
            side = 'China',
            type = 'Vehicle',
            name = 'AAV7',
            dbid = 3,
            LATITUDE = v.latitude,
            LONGITUDE = v.longitude,
        })

        if addedUnit == nil then
            return
        end

        ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })
        addedUnit.throttle = 'Full'
        addedUnit.course = courseTemp
        addedUnit.manualSpeed = speed
        addedUnit.manualAltitude = -2
    end
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
        for j = 1, unit[1], 1 do
            unit[2].base = shipId
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
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        print('CONFIG == nil')
        ScenEdit_MsgBox('CONFIG == nil', 1)
        return
    end

    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
    local shipInfo = CONFIG.c.landingOperation.const.shipInfo
    local cargoList = CONFIG.c.landingOperation.const.cargoList

    for _, infoItem in ipairs(shipLocationInfo) do
        for _, area in ipairs(infoItem.from.areas) do
            local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
            local firstRp071 = GetPointFromBearing({
                initialLocation = firstRp075,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            local firstRp072a = GetPointFromBearing({
                initialLocation = firstRp071,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            local firstRp072iii = GetPointFromBearing({
                initialLocation = firstRp072a,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            local firstRp073a = GetPointFromBearing({
                initialLocation = firstRp072iii,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })

            AddUnitsByRP(
                {
                    initialLocation = firstRp075,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance,
                    num = infoItem.from.num.type075
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = 'Type 075',
                    dbid = CONFIG.const.platformBDID6,
                    cargo = cargoList.type075,
                    heading = area.heading.vertical,
                    manualSpeed = shipInfo.shipSpeed,
                },
                {
                    { 12, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Warhorse',
                        dbid = CONFIG.const.platformBDID2,
                        loadoutid = CONFIG.const.loadoutDBID3
                    } },
                    { 13, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Wardog',
                        dbid = CONFIG.const.platformBDID5,
                        loadoutid = CONFIG.const.loadoutDBID2
                    } },
                    { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.const.platformBDID1 } },
                }
            )

            AddUnitsByRP(
                {
                    initialLocation = firstRp071,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance,
                    num = infoItem.from.num.type071
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = 'Type 071',
                    dbid = CONFIG.const.platformBDID7,
                    cargo = cargoList.type071,
                    heading = area.heading.vertical,
                    manualSpeed = shipInfo.shipSpeed,
                },
                {
                    { 4, {
                        side = 'China',
                        type = 'aircraft',
                        name = 'Warhorse',
                        dbid = CONFIG.const.platformBDID2,
                        loadoutid = CONFIG.const.loadoutDBID3
                    } },
                    { 4, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.const.platformBDID1 } },
                }
            )

            AddUnitsByRP(
                {
                    initialLocation = firstRp072a,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance,
                    num = infoItem.from.num.type072a
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = 'Type 072A',
                    dbid = CONFIG.const.platformBDID9,
                    cargo = cargoList.type072a,
                    heading = area.heading.vertical,
                    manualSpeed = shipInfo.shipSpeed,
                },
                nil
            )

            AddUnitsByRP(
                {
                    initialLocation = firstRp072iii,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance,
                    num = infoItem.from.num.type072iii
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = 'Type 072III',
                    dbid = CONFIG.const.platformBDID8,
                    cargo = cargoList.type072iii,
                    heading = area.heading.vertical,
                    manualSpeed = shipInfo.shipSpeed,
                },
                nil
            )

            AddUnitsByRP(
                {
                    initialLocation = firstRp073a,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance,
                    num = infoItem.from.num.type073a
                },
                {
                    side = 'China',
                    type = 'Ship',
                    name = 'Type 073A',
                    dbid = CONFIG.const.platformBDID10,
                    cargo = cargoList.type073a,
                    heading = area.heading.vertical,
                    manualSpeed = shipInfo.shipSpeed,
                },
                nil
            )
        end
    end

    -- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

function CalculateDestination()
    -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    -- if CONFIG == nil then
    --     print('CONFIG == nil')
    --     ScenEdit_MsgBox('CONFIG == nil', 1)
    --     return
    -- end

    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
    local shipInfo = CONFIG.c.landingOperation.const.shipInfo

    for _, infoItem in ipairs(shipLocationInfo) do
        for _, area in ipairs(infoItem.to.areas) do
            local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
            local firstRp071 = ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
            local firstRp072iii = GetPointFromBearing({
                initialLocation = firstRp075,
                bearing = area.heading.vertical,
                distance = shipInfo.distanceBetweenLSTAndLPDArea
            })
            local firstRp072a = GetPointFromBearing({
                initialLocation = firstRp072iii,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            local firstRp073a = GetPointFromBearing({
                initialLocation = firstRp072a,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            local firstRp071InLSTArea = GetPointFromBearing({
                initialLocation = firstRp073a,
                bearing = area.heading.vertical,
                distance = shipInfo.verticalDistance
            })
            InsertList(
                infoItem.to.result.type075.locations,
                GenerateLocations({
                    initialLocation = firstRp075,
                    num = area.num.type075,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
            InsertList(
                infoItem.to.result.type071.locations,
                GenerateLocations({
                    initialLocation = firstRp071,
                    num = area.num.type071,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
            InsertList(
                infoItem.to.result.type072iii.locations,
                GenerateLocations({
                    initialLocation = firstRp072iii,
                    num = area.num.type072iii,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
            InsertList(
                infoItem.to.result.type072a.locations,
                GenerateLocations({
                    initialLocation = firstRp072a,
                    num = area.num.type072a,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
            InsertList(
                infoItem.to.result.type073a.locations,
                GenerateLocations({
                    initialLocation = firstRp073a,
                    num = area.num.type073a,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
            InsertList(
                infoItem.to.result.type071InLSTArea.locations,
                GenerateLocations({
                    initialLocation = firstRp071InLSTArea,
                    num = area.num.type071InLSTArea,
                    bearing = area.heading.horizontal,
                    distance = shipInfo.horizontalDistance
                }))
        end
    end

    -- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end
