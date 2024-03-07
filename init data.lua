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
        table.insert(temp, { guid = value, strikeTime = nil })
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

    initLaunchers(
        'Taiwan',
        CONFIG.t.asm.launcherState,
        CONFIG.t.asm.const.magazineWeaponNum,
        function(unit, launchers)
            if unit.dbid == 3531 then
                table.insert(launchers, unit)
            end
        end
    )
end

-- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
if CONFIG.isDevMode then
    -- ScenEdit_MsgBox('Save config.', 1)
    gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

local _CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if _CONFIG ~= nil and getCount(_CONFIG.c.srbm.packages[1].targetList) <= 0 then
    initUnitsAndTargetList()
    initUnitsForASW()
    calculateDestination()

    if CONFIG.isDevMode then
        ScenEdit_MsgBox('Init data and save.', 1)
        gKH.State.SaveTableToKey(CONFIG, "CONFIG")
    end
else
    ScenEdit_MsgBox('Not init data', 1)
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
