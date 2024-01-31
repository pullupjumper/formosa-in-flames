local contact = ScenEdit_UnitC()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if contact == nil then
    return
end

local emission = contact.emissions[1]['sensor_dbid']

if emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID1 or emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID2 then
    if hasDestroyedOrRTB(CONFIG.c.srbm.onSAM.h6nTemp, 1)
        and hasDestroyedOrRTB(CONFIG.c.srbm.onSAM.wz8Temp, 1) then
        CONFIG.c.srbm.onSAM.h6nTemp = launchUnits(
            CONFIG.c.srbm.onSAM.const.h6nBaseGUID,
            CONFIG.c.srbm.onSAM.const.h6nCourse,
            1,
            CONFIG.c.srbm.onSAM.const.h6nDBID,
            'Aircraft'
        )
    end

    local result = { batteryIndex = 1, groupIndex = 1 }
    result = attackContact(contact, 2, CONFIG.c.srbm.onSAM.const.batteries, result.batteryIndex, result.groupIndex)
    CONFIG.c.srbm.onSAM.isStrikeActivated = true
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
