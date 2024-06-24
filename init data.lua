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

function initTargetList(side, missionName)
    local m = ScenEdit_GetMission(side, missionName)
    local temp = {}

    if m == nil then
        return temp
    end

    for index, value in ipairs(m.targetlist) do
        table.insert(temp, { guid = value, strikeTimes = 0 })
    end

    return temp
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

function initUnitsAndTargetList()
    CONFIG.c.srbm.packages[1].targetList[1] = initTargetList('China', 'STRIKE ON RADAR')
    CONFIG.c.srbm.packages[2].targetList[1] = initTargetList('China', 'STRIKE ON RUNWAY')
    CONFIG.c.srbm.packages[2].targetList[2] = initTargetList('China', 'STRIKE ON RUNWAY 2')
    CONFIG.c.srbm.packages[2].targetList[3] = initTargetList('China', 'STRIKE ON RUNWAY 3')
    CONFIG.c.srbm.packages[3].targetList[1] = initTargetList('China', 'STRIKE ON PORT')
    CONFIG.c.srbm.packages[4].targetList[1] = initTargetList('China', 'STRIKE ON SHELTER')
    CONFIG.c.srbm.packages[4].targetList[2] = initTargetList('China', 'STRIKE ON SHELTER 2')
    CONFIG.c.srbm.packages[4].targetList[3] = initTargetList('China', 'STRIKE ON SHELTER 3')
    CONFIG.c.glcm.packages[1].targetList[1] = initTargetList('China', 'STRIKE ON HELIPAD')
    CONFIG.c.glcm.packages[2].targetList[1] = initTargetList('China', 'STRIKE ON CONTINGENCY RUNWAY')

    for _, value in ipairs(CONFIG.c.srbm.packages[2].targetList[3]) do
        local contact = ScenEdit_GetContact({ side = 'China', guid = value.guid })

        if contact then
            table.insert(CONFIG.t.repairRunway.runways, { guid = contact.actualunitid, startTime = nil })
        end
    end

    local units = VP_GetSide({ Side = 'China' }).units

    for _, v in ipairs(units) do
        local unit = SE_GetUnit({ guid = v.guid })

        if unit and (unit.dbid == 55
                or unit.dbid == 43
                or unit.dbid == 757
                or unit.dbid == 1422
                or unit.dbid == 1424
                or unit.dbid == 1423
                or unit.dbid == 1421) then
            table.insert(CONFIG.c.repairRunway.runways, { guid = unit.guid, startTime = nil })
        end
    end
end

function initGPSJammers()
    for _, value in ipairs(CONFIG.c.GPSJamming.jammers) do
        local jammer = SE_GetUnit({ guid = value.guid })
        local eventName = value.eventName
        local event = ScenEdit_GetEvent(eventName)

        if jammer and event == nil then
            if jammer.dbid == CONFIG.const.platformBDID25 then
                local jammingArea = NewArea(
                    { latitude = jammer.latitude, longitude = jammer.longitude },
                    { side = 'China', distance = '15', shape = 'circle' }
                )
                local FilterType = { TargetSide = 'Taiwan', TargetType = 6 }
                UnitEntersAreaEvent(eventName, FilterType, jammingArea, 'GPSJamming()', 'add', false, true, true)
            end
        end
    end
end

-- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
if CONFIG.isSaved then
    gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

local _CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if _CONFIG ~= nil and getCount(_CONFIG.c.srbm.packages[1].targetList) <= 0 then
    initUnitsAndTargetList()
    -- initUnitsForASW()
    calculateDestination()

    if CONFIG.c.GPSJamming.isStrikeActivated then
        initGPSJammers()
    end

    if CONFIG.isDevMode then
        ScenEdit_SpecialMessage('Taiwan', 'Init data and save.')
        gKH.State.SaveTableToKey(CONFIG, "CONFIG")
    end
else
    ScenEdit_SpecialMessage('Taiwan', 'Does not init data.')
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
