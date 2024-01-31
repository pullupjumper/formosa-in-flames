local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    return
end

for index, value in ipairs(CONFIG.c.srbm.onFacility.const.contingencyRunways) do
    local contact = ScenEdit_GetContact({ side = "China", guid = value.base.guid })
    local runwayContact = ScenEdit_GetContact({ side = "China", guid = value.runway.guid })

    if contact ~= nil and runwayContact ~= nil and runwayContact.BDA ~= nil then
        local runway = SE_GetUnit({ guid = contact.actualunitid })

        if runway ~= nil then
            local num = getCount(runway.embarkedUnits['Aircraft'])

            if num >= 6 then
                CONFIG.c.srbm.onFacility.strikePackage[2].targetList[1] = initTargetList('China', 'STRIKE ON RUNWAY 4')
                CONFIG.c.srbm.onFacility.strikePackage[2].targetList[2] = initTargetList('China', 'STRIKE ON RUNWAY 5')
                CONFIG.c.srbm.onFacility.strikePackage[2].targetList[3] = initTargetList('China', 'STRIKE ON RUNWAY 6')
                break
            end
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
