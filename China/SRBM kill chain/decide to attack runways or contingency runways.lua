local STRIKE_ON_FACILITY = gKH.State.LoadTableFromKey("STRIKE_ON_FACILITY")


for index, value in ipairs(CONTINGENCY_RUNWAYS) do
    local contact = ScenEdit_GetContact({ side = "China", guid = value.base.guid })
    local runwayContact = ScenEdit_GetContact({ side = "China", guid = value.runway.guid })

    if contact ~= nil and runwayContact ~= nil and runwayContact.BDA ~= nil then
        local runway = SE_GetUnit({ guid = contact.actualunitid })

        if runway ~= nil then
            local num = getCount(runway.embarkedUnits['Aircraft'])

            if num >= 6 then
                STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[2].targetList[1] = initTargetList('China', 'STRIKE ON RUNWAY 4')
                STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[2].targetList[2] = initTargetList('China', 'STRIKE ON RUNWAY 5')
                STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[2].targetList[3] = initTargetList('China', 'STRIKE ON RUNWAY 6')
                break
            end
        end
    end
end


if STRIKE_ON_FACILITY ~= nil then
    gKH.State.SaveTableToKey(STRIKE_ON_FACILITY, "STRIKE_ON_FACILITY")
end
