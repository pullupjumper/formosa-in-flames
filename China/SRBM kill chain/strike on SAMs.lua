local contact = ScenEdit_UnitC()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if contact == nil then
    return
end

local emission = nil

if contact.emissions ~= nil then
    emission = contact.emissions[1]['sensor_dbid']
end

local isSAM = emission ~= nil and (emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID1
    or emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID2
    or emission == CONFIG.c.srbm.onSAM.const.tk2SensorDBID)
-- or emission == CONFIG.c.srbm.onSAM.const.pac3SensorDBID

if isSAM then
    if IsDestroyedOrRTB(CONFIG.c.srbm.onSAM.h6nTemp, 1)
        and IsDestroyedOrRTB(CONFIG.c.srbm.onSAM.wz8Temp, 1) then
        CONFIG.c.srbm.onSAM.h6nTemp = LaunchUnits(
            CONFIG.c.srbm.onSAM.const.h6nBaseGUID,
            CONFIG.c.srbm.onSAM.const.h6nCourse,
            1,
            CONFIG.c.srbm.onSAM.const.h6nDBID,
            'Aircraft'
        )
    end

    local result = { batteryIndex = 1, groupIndex = 1 }
    result = AttackContact(contact, 2, CONFIG.c.srbm.onSAM.const.batteries, result.batteryIndex, result.groupIndex)
    CONFIG.c.srbm.onSAM.isStrikeActivated = true
    ScenEdit_SpecialMessage('China', 'Emissions from ' .. tostring(contact.name))
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
