-- addNewAirbase({26.94867429482294, 120.07456540897977}, 'Shuimen AB', 9, 4, 1, 1, 2, 'China')
function addNewAirbase(position, name, shelterNum, accessPointNum, runwayNum, taxiwayNum, ammoNum, side)
    local pt = {}
    local colPt = {}
    local distance1 = 0.1
    local distance2 = 0.1

    colPt = World_GetPointFromBearing({
        LATITUDE = position[1],
        LONGITUDE = position[2],
        BEARING = 90,
        DISTANCE = distance1
    })
    pt = colPt;

    for i = 1, runwayNum, 1 do
        local unit = ScenEdit_AddUnit({
            name = '',
            side = side,
            type = 'facility',
            dbid = 757,
            LATITUDE = pt.latitude,
            LONGITUDE = pt.longitude,
            group = name
        })
        unit.group = name
        pt = World_GetPointFromBearing({
            LATITUDE = pt.latitude, LONGITUDE = pt.longitude, BEARING = 180, DISTANCE = distance2
        })
    end

    colPt = World_GetPointFromBearing({
        LATITUDE = colPt.latitude,
        LONGITUDE = colPt.longitude,
        BEARING = 90,
        DISTANCE = distance1
    })
    pt = colPt;

    for i = 1, accessPointNum, 1 do
        local unit = ScenEdit_AddUnit({
            name = '',
            side = side,
            type = 'facility',
            dbid = 353,
            LATITUDE = pt.latitude,
            LONGITUDE = pt.longitude,
            group = name
        })
        unit.group = name
        pt = World_GetPointFromBearing({
            LATITUDE = pt.latitude, LONGITUDE = pt.longitude, BEARING = 180, DISTANCE = distance2
        })
    end

    colPt = World_GetPointFromBearing({
        LATITUDE = colPt.latitude,
        LONGITUDE = colPt.longitude,
        BEARING = 90,
        DISTANCE = distance1
    })
    pt = colPt;

    for i = 1, shelterNum, 1 do
        local unit = ScenEdit_AddUnit({
            name = '',
            side = side,
            type = 'facility',
            dbid = 52,
            LATITUDE = pt.latitude,
            LONGITUDE = pt.longitude,
            group = name
        })
        unit.group = name
        pt = World_GetPointFromBearing({
            LATITUDE = pt.latitude, LONGITUDE = pt.longitude, BEARING = 180, DISTANCE = distance2
        })
    end

    colPt = World_GetPointFromBearing({
        LATITUDE = colPt.latitude,
        LONGITUDE = colPt.longitude,
        BEARING = 90,
        DISTANCE = distance1
    })
    pt = colPt;

    for i = 1, taxiwayNum, 1 do
        local unit = ScenEdit_AddUnit({
            name = '',
            side = side,
            type = 'facility',
            dbid = 1421,
            LATITUDE = pt.latitude,
            LONGITUDE = pt.longitude,
            group = name
        })
        unit.group = name
        pt = World_GetPointFromBearing({
            LATITUDE = pt.latitude, LONGITUDE = pt.longitude, BEARING = 180, DISTANCE = distance2
        })
    end

    colPt = World_GetPointFromBearing({
        LATITUDE = colPt.latitude,
        LONGITUDE = colPt.longitude,
        BEARING = 90,
        DISTANCE = distance1
    })
    pt = colPt;

    for i = 1, ammoNum, 1 do
        local unit = ScenEdit_AddUnit({
            name = '',
            side = side,
            type = 'facility',
            dbid = 1731,
            LATITUDE = pt.latitude,
            LONGITUDE = pt.longitude,
            group = name
        })
        unit.group = name
        pt = World_GetPointFromBearing({
            LATITUDE = pt.latitude, LONGITUDE = pt.longitude, BEARING = 180, DISTANCE = distance2
        })
    end
end

function createCargoToUnits(baseGUID, unitDBID, cargo)
    local airbase = ScenEdit_GetUnit({ guid = baseGUID })

    if airbase ~= nil and airbase.embarkedUnits.Boats ~= nil then
        for k, v in ipairs(airbase.embarkedUnits.Boats) do
            local unit = ScenEdit_GetUnit({ guid = v })

            if unit.dbid == unitDBID then
                for index, value in ipairs(cargo) do
                    for i = 1, value.num, 1 do
                        value:createUnitCargo(value.type, value.dbid)
                    end
                end
            end
        end
    end
end

function hostUnitsToParent(baseGUID, num, unitDBID, unitType, toUnit)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    local count = 0
    local temp = {}

    if base ~= nil and base.embarkedUnits[unitType] ~= nil then
        for index, v in ipairs(base.embarkedUnits[unitType]) do
            local unit = ScenEdit_GetUnit({ guid = v })

            if unit ~= nil
                and unit.dbid == unitDBID
                and unit.readytime_v == 0
                and unit.condition == 'Parked'
                and count < num then
                -- ScenEdit_AssignUnitToMission(unit.guid, missionName)
                -- local a = ScenEdit_HostUnitToParent({ HostedUnitNameOrID = unit.guid, SelectedHostNameOrID = toUnitGUID })
                local toBase = SE_GetUnit({ guid = toUnit.guid })
                unit.base = toBase
                unit:Launch(true)
                unit:RTB(true)
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

function launchAircraft(baseGUID, num, name, course, side, weaponDBID)
    local airbase = ScenEdit_GetUnit({ guid = baseGUID, side = side })
    local count = 0
    local groupName = 'Flight ' .. name
    local temp = {}

    if airbase ~= nil and airbase.embarkedUnits.Aircraft ~= nil then
        for k, v in ipairs(airbase.embarkedUnits.Aircraft) do
            local unit = ScenEdit_GetUnit({ guid = v })
            local weapons = ScenEdit_GetLoadout({ UnitName = unit.name }).weapons
            local weaponNum = 0

            if weapons ~= nil then
                for i, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID then
                        weaponNum = w["wpn_current"]
                    end
                end
            end

            if unit.readytime_v == 0 and count < num and weaponNum > 0 then
                unit.group = groupName
                unit:Launch(true)
                unit.course = course
                count = count + 1
                table.insert(temp, { unit = unit })
            end

            if count >= num then
                break
            end
        end
    end

    return temp
end

function launchAC(baseGUID, course, num)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    local temp = {}
    local times = 0

    if base ~= nil and base.embarkedUnits.Aircraft ~= nil then
        for index, value in ipairs(base.embarkedUnits.Aircraft) do
            local unit = ScenEdit_GetUnit({ guid = value })

            if unit.readytime_v == 0 then
                unit:Launch(true)
                unit.course = course
                table.insert(temp, { unit = unit, hasLaunched = false })
                times = times + 1
            end

            if times >= num then
                break
            end
        end
    end

    return temp
end

function launchTaskedUnits(baseGUID)
    local base = SE_GetUnit({ guid = baseGUID })

    if base ~= nil then
        for index, value in ipairs(base.embarkedUnits.Aircraft) do
            local unit = SE_GetUnit({ guid = value })

            if unit ~= nil
                and unit.unitstate == 'Tasked'
                and (unit.dbid == 5856 or unit.dbid == 3708 or unit.dbid == 2930) then
                unit:Launch(true)
            end
        end
    end
end

function getRequiredUnitNum(embarkedUnits, num, unitDBID)
    local count = 0

    for index, value in ipairs(embarkedUnits) do
        local unit = SE_GetUnit({ guid = value })

        if unit ~= nil and unit.dbid == unitDBID then
            count = count + 1
        end
    end

    return num - count
end

function isAllUnitsUnassigned(units)
    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit ~= nil
            and (unit.dbid == CONFIG.const.platformBDID1 or unit.dbid == 5856 or unit.dbid == 2930 or unit.dbid == 3708)
            and (unit.unitstate == 'OnPlottedCourse' or unit.unitstate == 'OnFerryMission' or unit.unitstate == 'Tasked') then
            return false
        end
    end

    return true
end

function Filter(list, handler)
    local temp = {}

    for index, value in ipairs(list) do
        local result = handler(value)
        if result then
            table.insert(temp, value)
        end
    end

    return temp
end

function reposition(state, weaponNum, reloadingTime, handler)
    for index, stateValue in ipairs(state) do
        local unit = SE_GetUnit({ guid = stateValue.guid })

        if stateValue.reloadStartTime ~= nil and unit ~= nil then
            local currentTime = ScenEdit_CurrentTime()
            local diffTime = currentTime - stateValue.reloadStartTime

            if stateValue.state == 'hidingPosition'
                and unit:inArea(stateValue.hidingPosition)
                and diffTime >= reloadingTime then
                unit.course = Reverse(stateValue.course)
                ScenEdit_SetUnit({ guid = stateValue.guid, manualthrottle = 'Flank', manualSpeed = 30 })
                stateValue.state = 'repositioning'
                stateValue.hasReloaded = true
                break
            end
        end

        if unit ~= nil then
            handler(weaponNum, stateValue, unit)
        end
    end
end

function reloadMissile(launcherState, reloadTime, weaponDBID)
    for index, state in ipairs(launcherState) do
        local unit = SE_GetUnit({ guid = state.unit })
        if unit then
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

function refuelUnits(groupName, refuelingMission, area, side)
    local group = ScenEdit_GetUnit({ side = side, name = groupName })
    local mission = ScenEdit_GetMission(side, refuelingMission)
    if group == nil or mission == nil then return end

    if group:inArea(area) then
        ScenEdit_RefuelUnit({ side = side, name = groupName, missions = { mission.guid } })
    end
end

function initLaunchers(side, launcherState, magazineWeaponNum, handler)
    local units = VP_GetSide({ Side = side }).units
    local launchers = {}

    for index, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })
        handler(unit, launchers)
    end

    for index, unit in ipairs(launchers) do
        local state = { unit = unit.guid, mounts = {} }

        for mountIndex, mount in ipairs(unit.mounts) do
            local mountTemp = { reloadStartTime = nil, magazineWeaponNum = magazineWeaponNum }
            state.mounts[mountIndex] = mountTemp
        end

        table.insert(launcherState, state)
    end
end

function initUnitsForASW()
    -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG ~= nil then
        ScenEdit_GetMission('China', 'ASW CSG').isactive = true
        ScenEdit_GetMission('China', 'AEW CSG').isactive = true
        ScenEdit_GetMission('China', 'ASW PATROL AC').isactive = true
        ScenEdit_GetMission('China', 'ASW BASHI').isactive = true
        ScenEdit_GetMission('China', 'ASW EAST').isactive = true
        ScenEdit_GetMission('Taiwan', 'ASW EAST').isactive = true

        -- ScenEdit_GetEvent('(China) Landing ships move to area').isActive = false
        -- ScenEdit_GetEvent('(China) Strike on SAMs').isActive = false
        -- ScenEdit_GetEvent('(China) Launch H6N').isActive = false

        for index, value in ipairs(CONFIG.c.asw.const.submarine) do
            local sub = SE_GetUnit({ guid = value.guid })

            if sub ~= nil then
                ScenEdit_AssignUnitToMission(value.guid, value.missionName)
                sub.course = value.course
            end
        end
    else
        ScenEdit_GetMission('China', 'ASW CSG').isactive = false
        ScenEdit_GetMission('China', 'AEW CSG').isactive = false
        ScenEdit_GetMission('China', 'ASW PATROL AC').isactive = false
        ScenEdit_GetMission('China', 'ASW BASHI').isactive = false
        ScenEdit_GetMission('China', 'ASW EAST').isactive = false
        ScenEdit_GetMission('Taiwan', 'ASW EAST').isactive = false

        -- ScenEdit_GetEvent('(China) Landing ships move to area').isActive = true
        -- ScenEdit_GetEvent('(China) Strike on SAMs').isActive = true
        -- ScenEdit_GetEvent('(China) Launch H6N').isActive = true
    end
end

function isRunOutOfAmmo(mount)
    for weaponIndex, weapon in ipairs(mount['mount_weapons']) do
        if weapon['wpn_name'] ~= nil and weapon['wpn_current'] == 0 then
            return true
        end
    end
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
