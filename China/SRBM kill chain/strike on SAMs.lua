local contact = ScenEdit_UnitC()
local STRIKE_ON_SAM = gKH.State.LoadTableFromKey("STRIKE_ON_SAM")

-- local event = ScenEdit_EventX()
-- local event2 = ScenEdit_GetEvent('(China) Evaluate effects of the attack')

if contact == nil then
    return
end

local emission = contact.emissions[1]['sensor_dbid']

if emission == STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_1 or emission == STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_2 then
    if hasDestroyedOrRTB(STRIKE_ON_SAM.H6N_WITH_WZ8, 1) and hasDestroyedOrRTB(STRIKE_ON_SAM.RECON_WZ8, 1) then
        STRIKE_ON_SAM.H6N_WITH_WZ8 = launchUnits(
            STRIKE_ON_SAM.H6N_BASE_GUID,
            STRIKE_ON_SAM.H6N_COURSE,
            1,
            STRIKE_ON_SAM.H6N_DBID,
            'Aircraft'
        )
    end

    local result = { batteryIndex = 1, groupIndex = 1 }
    result = attackContact(contact, 2, STRIKE_ON_SAM.SRBM_BATTERIES, result.batteryIndex, result.groupIndex)
    STRIKE_ON_SAM.IS_STRIKE_ON_SAM_ACTIVATED = true
end


if STRIKE_ON_SAM ~= nil then
    gKH.State.SaveTableToKey(STRIKE_ON_SAM, "STRIKE_ON_SAM")
end
