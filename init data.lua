local function initRunways()
    CONFIG.c.srbm.packages[1].targetList[1] = InitTargetList('China', 'STRIKE ON RADAR')
    CONFIG.c.srbm.packages[2].targetList[1] = InitTargetList('China', 'STRIKE ON RUNWAY')
    CONFIG.c.srbm.packages[2].targetList[2] = InitTargetList('China', 'STRIKE ON RUNWAY 2')
    CONFIG.c.srbm.packages[2].targetList[3] = InitTargetList('China', 'STRIKE ON RUNWAY 3')
    CONFIG.c.srbm.packages[3].targetList[1] = InitTargetList('China', 'STRIKE ON PORT')
    CONFIG.c.srbm.packages[4].targetList[1] = InitTargetList('China', 'STRIKE ON SHELTER')
    CONFIG.c.srbm.packages[4].targetList[2] = InitTargetList('China', 'STRIKE ON SHELTER 2')
    CONFIG.c.srbm.packages[4].targetList[3] = InitTargetList('China', 'STRIKE ON SHELTER 3')
    CONFIG.c.glcm.packages[1].targetList[1] = InitTargetList('China', 'STRIKE ON HELIPAD')
    CONFIG.c.glcm.packages[2].targetList[1] = InitTargetList('China', 'STRIKE ON CONTINGENCY RUNWAY')

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

local function initGPSJammers()
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

if _CONFIG ~= nil and GetCount(_CONFIG.c.srbm.packages[1].targetList) <= 0 then
    initRunways()
    CalculateDestination()

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
