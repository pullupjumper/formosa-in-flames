local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

for _, value in ipairs(CONFIG.c.srbm.const.contingencyRunways) do
    local contact = ScenEdit_GetContact({ side = "China", guid = value.base.guid })
    local runwayContact = ScenEdit_GetContact({ side = "China", guid = value.runway.guid })

    if contact and runwayContact and runwayContact.BDA then
        local runway = SE_GetUnit({ guid = contact.actualunitid })

        if runway then
            local num = GetCount(runway.embarkedUnits['Aircraft'])

            if num >= 6 then
                CONFIG.c.srbm.packages[2].targetList[1] = InitTargetList('China', 'STRIKE ON RUNWAY 4')
                CONFIG.c.srbm.packages[2].targetList[2] = InitTargetList('China', 'STRIKE ON RUNWAY 5')
                CONFIG.c.srbm.packages[2].targetList[3] = InitTargetList('China', 'STRIKE ON RUNWAY 6')
                break
            end
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
