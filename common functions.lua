---@param list table
---@return number
function getCount(list)
    if list == nil then return 0 end
    local count = 0

    for k, v in ipairs(list) do
        count = count + 1
    end

    return count
end

---@param list table
---@return table
function reverse(list)
    local count = getCount(list)
    local temp = {}

    for i = count, 1, -1 do
        table.insert(temp, list[i])
    end

    return temp
end

---@param list table
---@param insertedList table
function insertList(list, insertedList)
    local count = getCount(insertedList)

    for i = 1, count, 1 do
        table.insert(list, insertedList[i])
    end

    return list
end

---@param units table<number, CMO__Unit>
---@param name string
function filterUnitsByName(units, name)
    local filteredUnits = {}
    if units == nil then return end

    for k, v in ipairs(units) do
        if string.find(v.name, name) then
            table.insert(filteredUnits, v)
        end
    end

    return filteredUnits
end

---@param fromUnit string
---@param platformType string
---@param platformDBID number
---@param missionList table<number, string>
function assignEmbarkedUnitsToMission(fromUnit, platformType, platformDBID, missionList)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits[platformType]
    local filteredPlatforms = {}
    local count = getCount(missionList)
    local index = 1

    if platforms ~= nil then
        for k, v in ipairs(platforms) do
            local unit = SE_GetUnit({ guid = v })

            if unit ~= nil and unit.dbid == platformDBID then
                table.insert(filteredPlatforms, unit)
            end
        end
    end

    if filteredPlatforms ~= nil then
        local platformNum = getCount(filteredPlatforms) // count

        for k, v in ipairs(filteredPlatforms) do
            -- local unit = SE_GetUnit({ guid = v })
            ScenEdit_AssignUnitToMission(v.guid, missionList[index])

            if k % platformNum == 0 and platformNum > 1 then
                index = index + 1
            end
        end
    end
end

---@param fromUnit CMO__Unit
---@param toUnit CMO__Unit
---@param cargoItem CargoItem
function updateCargo(fromUnit, toUnit, cargoItem)
    local cargoGuidList = {}
    local count = 0

    if fromUnit ~= nil and fromUnit.cargo[1].cargo ~= nil then
        for k, v in ipairs(fromUnit.cargo[1].cargo) do
            if v.dbid == cargoItem.dbid then
                table.insert(cargoGuidList, v.guid)
                count = count + 1
            end

            if count == cargoItem.num then
                break
            end
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
function deleteCargos(fromUnit, cargoItem)
    local cargoGuidList = {}
    local count = 0

    if fromUnit ~= nil and fromUnit.cargo[1].cargo ~= nil then
        for k, v in ipairs(fromUnit.cargo[1].cargo) do
            if v.dbid == cargoItem.dbid then
                table.insert(cargoGuidList, v.guid)
                count = count + 1
            end

            if count == cargoItem.num then
                break
            end
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
function transferCargo(fromUnit, platformType, platformDBid, cargoItem)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits[platformType]

    if platforms ~= nil then
        for k, v in ipairs(platforms) do
            local unit = SE_GetUnit({ guid = v })

            if unit ~= nil and unit.dbid == platformDBid then
                updateCargo(base, unit, cargoItem)
            end
        end
    end
end

function isRunOutOfAmmo(mount)
    for weaponIndex, weapon in ipairs(mount['mount_weapons']) do
        if weapon['wpn_name'] ~= nil and weapon['wpn_current'] == 0 then
            return true
        end
    end
end

---@param points table
function getCourseByPoints(points)
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
function generateLocations(params)
    local numTemp = params.num
    local bearingTemp = params.bearing
    local distanceTemp = 0
    local locations = {}
    local locationTemp = params.initialLocation

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
function generateIFVLocations(params)
    local locations = {}
    local ship = params.ship
    local bearing = params.bearing
    local distance = params.distance

    if params.num == 10 then
        local col = generateLocations({
            initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
            num = 10,
            bearing = (bearing + 90),
            distance = distance
        })

        locations = insertList(locations, col)
    elseif params.num == 40 then
        local firstLocation = World_GetPointFromBearing({
            LATITUDE = ship.latitude,
            LONGITUDE = ship.longitude,
            BEARING = (bearing + 180),
            DISTANCE = (distance * 1.5)
        })

        local firstRow = generateLocations({
            initialLocation = firstLocation,
            num = 4,
            bearing = bearing,
            distance = distance
        })

        for index, initLocation in ipairs(firstRow) do
            local col = generateLocations({
                initialLocation = initLocation,
                num = 10,
                bearing = (bearing + 90),
                distance = distance
            })

            locations = insertList(locations, col)
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
function launchAmphibiousIFV(params)
    local ship = params.ship
    local transitBearing = params.transitBearing
    local transitDistance = params.transitDistance
    local speed = params.speed
    local IFVlocations = generateIFVLocations(params)

    local destinationTemp = {}
    local courseTemp = {}
    -- local unitTemp = {}

    if ship ~= nil and ship.IsDestroyed ~= true then
        deleteCargos(ship, { type = 2, num = params.num, dbid = 3 })

        for k, v in ipairs(IFVlocations) do
            destinationTemp = World_GetPointFromBearing({
                LATITUDE = v.latitude,
                LONGITUDE = v.longitude,
                BEARING = transitBearing,
                DISTANCE = transitDistance
            })

            courseTemp = getCourseByPoints({ destinationTemp })

            local addedUnit = ScenEdit_AddUnit({
                side = 'China',
                type = 'Vehicle',
                name = 'AAV7',
                dbid = 3,
                LATITUDE = v.latitude,
                LONGITUDE = v.longitude,
            })

            -- unitTemp = SE_GetUnit({ guid = unitTemp.guid })
            if addedUnit ~= nil then
                ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = 'no' })
                addedUnit.throttle = 'Full'
                addedUnit.course = courseTemp
                addedUnit.manualSpeed = speed
                addedUnit.manualAltitude = -2
            end
        end
    end
end

---@param units table
---@param course table
function setCourseToUnits(course, units)
    for k, v in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })

        -- unit.course = course
        if unit ~= nil then
            local destinationTemp = World_GetPointFromBearing({
                LATITUDE = unit.latitude,
                LONGITUDE = unit.longitude,
                BEARING = course.bearing,
                DISTANCE = course.distance
            })

            unit.course = getCourseByPoints({ destinationTemp })
        end
    end
end

function createCargoMission()
    for index, m in ipairs(CONFIG.c.landingOperation.const.cargoMissionList) do
        local mission = ScenEdit_AddMission('China', m.name, 'Cargo', { zone = m.zone })
        mission.isactive = false
        ScenEdit_SetMission('China', m.name, m.setting)
    end
end

function setLandingMissionStartTime()
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        print('CONFIG == nil')
        ScenEdit_MsgBox('CONFIG == nil', 1)
        return
    end

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
    gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

function setAntiShipMissionStartTime()
    local currentTime = ScenEdit_CurrentTime()
    local antiShipStartTime = os.date("%m/%d/%Y %I:%M:%S %p", currentTime)
    -- local reconStartTime1 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime))
    -- local reconStartTime2 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 5 * 60))
    local reconStartTime3 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 5 * 60))
    ScenEdit_GetMission('Taiwan', 'ANTI-SHIP WEST').starttime = antiShipStartTime
    ScenEdit_GetMission('Taiwan', 'ANTI-SHIP NORTH').starttime = antiShipStartTime
    -- ScenEdit_GetMission('Taiwan', 'RECON1').starttime = reconStartTime1
    -- ScenEdit_GetMission('Taiwan', 'RECON2').starttime = reconStartTime2
    -- ScenEdit_GetMission('Taiwan', 'RECON3').starttime = reconStartTime3
    ScenEdit_GetMission('Taiwan', 'RECON4').starttime = reconStartTime3
end

---@param name string
---@param units table<number, CMO__Unit>
function isMissileHit(name, units)
    for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit ~= nil and string.find(unit.name, name) and unit.type == 'Weapon' then
            return false
        end
    end

    return true
end

---@param num number
---@param list table<number, CMO__Unit>
function hasDestroyedOrRTB(list, num)
    local times = 0

    for index, value in ipairs(list) do
        local unit = SE_GetUnit({ guid = value.unit })

        if unit == nil or (unit.unitstate == 'RTB_Manual' or unit.unitstate == 'RTB') then
            times = times + 1
        end

        if times >= num then
            return true
        end
    end

    return false
end

function assignUnitToFerryMission(baseGUID, num, unitDBID, unitType, missionName)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    local count = 0
    local temp = {}

    if base ~= nil and base.embarkedUnits[unitType] ~= nil then
        for index, v in ipairs(base.embarkedUnits[unitType]) do
            local unit = ScenEdit_GetUnit({ guid = v })

            if unit ~= nil and unit.dbid == unitDBID and unit.readytime_v == 0 and count < num then
                ScenEdit_AssignUnitToMission(unit.guid, missionName)
                table.insert(temp, unit)
                count = count + 1
            end

            if count >= num then
                break
            end
        end
    end

    return temp
end

function assingUnitToStrikeMission(baseGUID, num, weaponDBID, missionName, isEscort)
    local airbase = ScenEdit_GetUnit({ guid = baseGUID })
    local m = ScenEdit_GetMission(airbase.side, missionName)
    m.isactive = false
    local temp = {}
    local count = 0

    if airbase ~= nil and airbase.embarkedUnits.Aircraft ~= nil then
        for k, v in ipairs(airbase.embarkedUnits.Aircraft) do
            local unit = ScenEdit_GetUnit({ guid = v })
            local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
            local weaponNum = 0

            if weapons ~= nil then
                for i, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID then
                        weaponNum = w["wpn_current"]
                    end
                end
            end

            if unit.readytime_v == 0 and unit.mission == nil and count < num and weaponNum > 0 then
                if isEscort then
                    ScenEdit_AssignUnitToMission(unit.guid, missionName, true)
                else
                    ScenEdit_AssignUnitToMission(unit.guid, missionName)
                end

                count = count + 1
                table.insert(temp, { unit = unit.guid })

                if count >= num then
                    break
                end
            end
        end


        if m.isactive == false then
            m.isactive = true
        end
    end

    return temp
end

---@param baseGUID string
---@param course CMO__TableOfWaypoints
---@param num number
---@param unitDBID string
---@param unitType string @ Aircraft or Boats
function launchUnits(baseGUID, course, num, unitDBID, unitType)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    local count = 0
    local temp = {}

    if base ~= nil and base.embarkedUnits[unitType] ~= nil then
        for k, v in ipairs(base.embarkedUnits[unitType]) do
            local unit = ScenEdit_GetUnit({ guid = v })

            if unit.dbid == unitDBID and unit.readytime_v == 0 and count < num then
                unit:Launch(true)
                unit.course = course
                -- ScenEdit_SetUnit({ guid = unit.guid, course = course })
                count = count + 1
                table.insert(temp, { unit = unit.guid, hasLaunched = false })
            end

            if count >= num then
                break
            end
        end
    end

    return temp
end

---@param h6n CMO__Unit
---@param course CMO__TableOfWaypoints
---@param contact CMO__Contact
function launchWZ8(h6n, course, contact)
    local wz8 = ScenEdit_AddUnit({
        side = 'China',
        type = 'Aircraft',
        name = 'WZ-8',
        dbid = 6642,
        LATITUDE = h6n.latitude,
        LONGITUDE = h6n.longitude,
        loadoutid = 32885,
        altitude = h6n.altitude
    })
    local arcT = { 'PB1', 'PB2', 'SB1', 'SB2', 'SMF1', 'PMF2' };
    ScenEdit_UpdateUnit({ guid = wz8.guid, mode = 'add_sensor', dbid = 6073, arc_detect = arcT, arc_track = arcT })
    ScenEdit_SetEMCON('Unit', wz8.guid, 'Radar=Active')

    wz8 = SE_GetUnit({ guid = wz8.guid })
    wz8.manualSpeed = h6n.speed
    wz8.manualAltitude = h6n.altitude

    if course == nil and contact ~= nil then
        ScenEdit_SetDoctrine({ guid = wz8.guid }, { fuel_state_rtb = 0, withdraw_on_fuel = 0 })
        local distance = Tool_Range(h6n.guid, contact.guid)
        local shortDistance = distance / 2
        local bearing = Tool_Bearing(h6n.guid, contact.guid)
        local initialPosition = World_GetPointFromBearing({
            latitude = h6n.latitude,
            longitude = h6n.longitude,
            distance = shortDistance,
            bearing = bearing
        })
        local finalPosition = World_GetPointFromBearing({
            latitude = h6n.latitude,
            longitude = h6n.longitude,
            distance = distance,
            bearing = bearing
        })
        course = {
            { lat = 'N 27.04.39', lon = 'E 122.14.20', desiredAltitude = 30480, desiredSpeed = 3300 },
            { lat = 'N 24.57.09', lon = 'E 121.31.35', desiredAltitude = 30480, desiredSpeed = 3300 },
        }

        course[1].lat = initialPosition.latitude
        course[1].lon = initialPosition.longitude
        course[2].lat = finalPosition.latitude
        course[2].lon = finalPosition.longitude
    end

    wz8.course = course
    h6n:RTB(true)
    -- ScenEdit_MsgBox('Launch WZ-8 (' .. tostring(wz8.name), 1)
    return wz8
end

function attackContact(contact, qty, batteries, batteryIndex, groupIndex, weaponDBID)
    local launchedNum = 0

    if batteryIndex == nil then
        batteryIndex = 1
    end

    if groupIndex == nil then
        groupIndex = 1
    end

    for i = batteryIndex, getCount(batteries) do
        local group = ScenEdit_GetUnit({ guid = batteries[i].guid })

        if group ~= nil then
            for j = groupIndex, getCount(group.group.unitlist) do
                local guid = group.group.unitlist[j]
                local unit = ScenEdit_GetUnit({ guid = guid })
                local _weaponDBID = 0
                local weaponCurrentNum = 0
                local defaultNum = 1
                local mountDBID = unit.mounts[1]['mount_dbid']
                local wpnIndex = 1

                for mountIndex, mount in ipairs(unit.mounts) do
                    if weaponDBID ~= nil and type(weaponDBID) == "number" then
                        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                            if wpn['wpn_dbid'] == weaponDBID then
                                wpnIndex = wpnIdx
                                break
                            end
                        end
                    end

                    weaponCurrentNum = weaponCurrentNum + mount['mount_weapons'][wpnIndex]['wpn_current']
                end

                _weaponDBID = unit.mounts[1]['mount_weapons'][wpnIndex]['wpn_dbid']

                if weaponCurrentNum > 0 then
                    local result = ScenEdit_AttackContact(guid, contact.guid,
                        { mode = '1', qty = defaultNum, mount = mountDBID, weapon = _weaponDBID })

                    if result then
                        launchedNum = launchedNum + defaultNum
                    end
                end

                if (j + 1) > getCount(group.group.unitlist) then
                    groupIndex = 1
                    batteryIndex = i + 1
                else
                    groupIndex = j + 1
                    batteryIndex = i
                end

                if batteryIndex > getCount(batteries) then
                    batteryIndex = 1
                end

                if launchedNum >= qty then
                    -- ScenEdit_MsgBox('batteryIndex=' .. tostring(batteryIndex) .. ' groupIndex=' .. tostring(groupIndex), 0)
                    return { batteryIndex = batteryIndex, groupIndex = groupIndex }
                end
            end
        end
    end

    return { batteryIndex = batteryIndex, groupIndex = groupIndex }
end

function reloadMissile(launcherState, reloadTime, weaponDBID)
    for index, state in ipairs(launcherState) do
        local unit = SE_GetUnit({ guid = state.unit })

        if unit ~= nil then
            for mountIndex, mount in ipairs(unit.mounts) do
                if state.mounts[mountIndex].reloadStartTime == nil and isRunOutOfAmmo(mount) then
                    state.mounts[mountIndex].reloadStartTime = ScenEdit_CurrentTime()
                end

                if state.mounts[mountIndex].reloadStartTime ~= nil then
                    local currentTime = ScenEdit_CurrentTime()
                    local diffTime = currentTime - state.mounts[mountIndex].reloadStartTime
                    local magazineWeaponNum = state.mounts[mountIndex].magazineWeaponNum
                    local _weaponDBID = 0
                    local weaponCurrentNum = 0
                    local weaponDefaultNum = 0
                    local wpnIndex = 1

                    if weaponDBID ~= nil and type(weaponDBID) == "number" then
                        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                            if wpn['wpn_dbid'] == weaponDBID then
                                wpnIndex = wpnIdx
                                break
                            end
                        end
                    end

                    _weaponDBID = mount['mount_weapons'][wpnIndex]['wpn_dbid']
                    weaponCurrentNum = mount['mount_weapons'][wpnIndex]['wpn_current']
                    weaponDefaultNum = mount['mount_weapons'][wpnIndex]['wpn_default']

                    if diffTime >= reloadTime and magazineWeaponNum > 0 and weaponCurrentNum == 0 then
                        ScenEdit_AddReloadsToUnit({
                            guid = unit.guid,
                            wpn_dbid = _weaponDBID,
                            number = weaponDefaultNum
                        })
                        state.mounts[mountIndex].magazineWeaponNum = state.mounts[mountIndex].magazineWeaponNum -
                            weaponDefaultNum
                    end
                end
            end
        end
    end
end

function filterContacts(contacts, handler)
    local temp = {}

    if contacts ~= nil then
        for index, unit in ipairs(contacts) do
            local result = handler(unit)

            if result then
                table.insert(temp, unit)
            end
        end
    end

    return temp
end

function addUnitsToShip(shipId, units)
    for k, unit in ipairs(units) do
        local missionName = unit[3]

        for j = 1, unit[1], 1 do
            unit[2].base = shipId
            local returnedUnit = ScenEdit_AddUnit(unit[2])

            if missionName ~= nil then
                ScenEdit_AssignUnitToMission(returnedUnit.guid, missionName)
            end
        end
    end
end

-- @params {initialLocation, bearing, distance, num}
function addUnitsByRp(params, unit, embarkedUnits)
    local locations = generateLocations(params)
    local unitTemp = nil

    for k, v in ipairs(locations) do
        unit.latitude = v.latitude
        unit.longitude = v.longitude
        unitTemp = ScenEdit_AddUnit(unit)
        -- unitTemp = ScenEdit_UpdateUnitCargo({ guid = unitTemp.guid, mode = 'add_cargo', cargo = unit.cargo })

        if unit.cargo ~= nil then
            for k, v in ipairs(unit.cargo) do
                for i = 1, v.num, 1 do
                    unitTemp:createUnitCargo(v.type, v.dbid)
                end
            end
        end

        if embarkedUnits ~= nil then
            addUnitsToShip(unitTemp.guid, embarkedUnits)
        end
    end
end

function getPointFromBearing(params)
    local initialLocation = params.initialLocation
    local bearing = params.bearing
    local distance = params.distance

    return generateLocations({
        initialLocation = initialLocation,
        num = 2,
        bearing = bearing,
        distance = distance
    })[2]
end

function addLandingShips()
    -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    -- if CONFIG == nil then
    --     print('CONFIG == nil')
    --     ScenEdit_MsgBox('CONFIG == nil', 1)
    --     return
    -- end

    local idx = CONFIG.c.landingOperation.idxShipLocationInfo
    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
    local shipInfo = CONFIG.c.landingOperation.const.shipInfo
    local cargoList = CONFIG.c.landingOperation.const.cargoList

    for i, area in ipairs(shipLocationInfo[idx].from.areas) do
        local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
        local firstRp075_2 = getPointFromBearing({
            initialLocation = firstRp075,
            bearing = area.heading.horizontal,
            distance = 1.5
        })
        local firstRp071 = getPointFromBearing({
            initialLocation = firstRp075,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        local firstRp072a = getPointFromBearing({
            initialLocation = firstRp071,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        local firstRp072iii = getPointFromBearing({
            initialLocation = firstRp072a,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        local firstRp073a = getPointFromBearing({
            initialLocation = firstRp072iii,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        addUnitsByRp(
            {
                initialLocation = firstRp075,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 2
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
                    dbid = CONFIG.const.platformBDID4,
                    loadoutid = CONFIG.const.loadoutDBID1
                } },
                { 3, { side = 'China', type = 'ship', name = 'Warbird', dbid = CONFIG.const.platformBDID1 } },
            }
        )

        addUnitsByRp(
            {
                initialLocation = firstRp075_2,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 2
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

        addUnitsByRp(
            {
                initialLocation = firstRp071,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 4
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

        addUnitsByRp(
            {
                initialLocation = firstRp072a,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 4
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

        addUnitsByRp(
            {
                initialLocation = firstRp072iii,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 4
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

        addUnitsByRp(
            {
                initialLocation = firstRp073a,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance,
                num = 4
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

    -- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

function calculateDestination()
    -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    -- if CONFIG == nil then
    --     print('CONFIG == nil')
    --     ScenEdit_MsgBox('CONFIG == nil', 1)
    --     return
    -- end

    local idx = CONFIG.c.landingOperation.idxShipLocationInfo
    local shipLocationInfo = CONFIG.c.landingOperation.const.shipLocationInfo
    local shipInfo = CONFIG.c.landingOperation.const.shipInfo

    for i, area in ipairs(shipLocationInfo[idx].to.areas) do
        local firstRp075 = ScenEdit_GetReferencePoints(area.startingPoints.type075)[1]
        local firstRp071 = ScenEdit_GetReferencePoints(area.startingPoints.type071)[1]
        local firstRp072iii = getPointFromBearing({
            initialLocation = firstRp075,
            bearing = area.heading.vertical,
            distance = shipInfo.distanceBetweenLSTAndLPDArea
        })
        local firstRp072a = getPointFromBearing({
            initialLocation = firstRp072iii,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        local firstRp073a = getPointFromBearing({
            initialLocation = firstRp072a,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        local firstRp071InLSTArea = getPointFromBearing({
            initialLocation = firstRp073a,
            bearing = area.heading.vertical,
            distance = shipInfo.verticalDistance
        })
        insertList(
            shipLocationInfo[idx].to.result.type075.locations,
            generateLocations({
                initialLocation = firstRp075,
                num = area.num.type075,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
        insertList(
            shipLocationInfo[idx].to.result.type071.locations,
            generateLocations({
                initialLocation = firstRp071,
                num = area.num.type071,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
        insertList(
            shipLocationInfo[idx].to.result.type072iii.locations,
            generateLocations({
                initialLocation = firstRp072iii,
                num = area.num.type072iii,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
        insertList(
            shipLocationInfo[idx].to.result.type072a.locations,
            generateLocations({
                initialLocation = firstRp072a,
                num = area.num.type072a,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
        insertList(
            shipLocationInfo[idx].to.result.type073a.locations,
            generateLocations({
                initialLocation = firstRp073a,
                num = area.num.type073a,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
        insertList(
            shipLocationInfo[idx].to.result.type071InLSTArea.locations,
            generateLocations({
                initialLocation = firstRp071InLSTArea,
                num = area.num.type071InLSTArea,
                bearing = area.heading.horizontal,
                distance = shipInfo.horizontalDistance
            }))
    end

    -- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end
