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

local function initC2()
    local units = VP_GetSide({ Side = "Taiwan" }).units
    local unitsFromChina = VP_GetSide({ Side = "China" }).units

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        for i, operationalZone in ipairs(CONFIG.t.C2.operationalZones) do
            if unit ~= nil and unit:inArea(operationalZone.area) then
                if unit.dbid == CONFIG.const.platformBDID15 or unit.dbid == CONFIG.const.platformBDID14 then
                    local data = {
                        guid = unit.guid,
                        OODA = unit.OODA,
                        isOutOfComms = false,
                        outofcomms = 0,
                    }
                    table.insert(CONFIG.t.C2.operationalZones[i].ROCC.units, data)
                end

                if unit.dbid == CONFIG.const.platformBDID33 or unit.dbid == CONFIG.const.platformBDID34 then
                    local data = {
                        guid = unit.guid,
                        OODA = unit.OODA,
                        isOutOfComms = false,
                        outofcomms = 0,
                    }
                    table.insert(CONFIG.t.C2.operationalZones[i].TAAOC.units, data)
                end
            end
        end
    end

    for _, value in ipairs(unitsFromChina) do
        local unit = SE_GetUnit({ guid = value.guid })

        for index, operationalZone in ipairs(CONFIG.c.C2.operationalZones) do
            if unit ~= nil and unit:inArea(operationalZone.area) then
                if unit.dbid == CONFIG.const.platformBDID18
                    or unit.dbid == CONFIG.const.platformBDID19
                    or unit.dbid == CONFIG.const.platformBDID21 then
                    local data = {
                        guid = unit.guid,
                        OODA = unit.OODA,
                        isOutOfComms = false,
                        outofcomms = 0,
                    }
                    table.insert(CONFIG.c.C2.operationalZones[index].C2.units, data)
                end
            end
        end
    end

    ScenEdit_SpecialMessage('Taiwan', 'C2 init done.')
    ScenEdit_SpecialMessage('China', 'C2 init done.')
end

local function initCommsJammers(side)
    local units = VP_GetSide({ Side = side }).units

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit and (unit.dbid == CONFIG.const.platformBDID35 or unit.dbid == CONFIG.const.platformBDID37) then
            table.insert(CONFIG.c.commsJamming.jammers, { guid = unit.guid })
        end
    end
end

local function initAC()
    local units = VP_GetSide({ Side = 'Taiwan' }).units

    for _, value in ipairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit and unit.type == 'Aircraft' and unit.dbid == CONFIG.const.platformBDID38 then
            table.insert(
                CONFIG.t.aircraft.AEW,
                {
                    guid = unit.guid,
                    OODA = unit.OODA,
                    comms_level = 40,
                    comms_base = 40,
                    comms_threshold = 30,
                    outofcomms = 0,
                }
            )
        elseif unit and unit.type == 'Aircraft' then
            table.insert(
                CONFIG.t.aircraft.AC,
                {
                    guid = unit.guid,
                    OODA = unit.OODA,
                    comms_level = 40,
                    comms_base = 40,
                    comms_threshold = 30,
                    outofcomms = 0,
                }
            )
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

    if CONFIG.t.C2.isActivated then
        initC2()
    end

    if CONFIG.c.commsJamming.isActivated then
        initCommsJammers('China')
    end

    if CONFIG.t.aircraft.isActivated then
        initAC()
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
