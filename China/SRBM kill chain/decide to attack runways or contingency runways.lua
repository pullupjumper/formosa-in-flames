local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

for _, value in ipairs(CONFIG.c.srbm.const.contingencyRunways) do
    local contact = ScenEdit_GetContact({ side = "China", guid = value.base.guid })
    local runwayContact = ScenEdit_GetContact({ side = "China", guid = value.runway.guid })

    if contact and runwayContact and runwayContact.BDA then
        local runway = SE_GetUnit({ guid = contact.actualunitid })

        if runway then
            local num = getCount(runway.embarkedUnits['Aircraft'])

            if num >= 6 then
                CONFIG.c.srbm.package[2].targetList[1] = initTargetList('China', 'STRIKE ON RUNWAY 4')
                CONFIG.c.srbm.package[2].targetList[2] = initTargetList('China', 'STRIKE ON RUNWAY 5')
                CONFIG.c.srbm.package[2].targetList[3] = initTargetList('China', 'STRIKE ON RUNWAY 6')
                break
            end
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
