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

local isSAM = emission ~= nil and (emission == CONFIG.c.recon.const.tk3SensorDBID1
    or emission == CONFIG.c.recon.const.tk3SensorDBID2
    or emission == CONFIG.c.recon.const.tk2SensorDBID)
-- or emission == CONFIG.c.recon.const.pac3SensorDBID

if isSAM then
    if IsDestroyedOrRTB(CONFIG.c.recon.h6nTemp, 1)
        and IsDestroyedOrRTB(CONFIG.c.recon.wz8Temp, 1) then
        CONFIG.c.recon.h6nTemp = LaunchUnits(
            CONFIG.c.recon.const.h6nBaseGUID,
            CONFIG.c.recon.const.h6nCourse,
            1,
            CONFIG.c.recon.const.h6nDBID,
            'Aircraft'
        )
    end

    local result = { batteryIndex = 1, groupIndex = 1 }
    result = AttackContact(contact, 2, CONFIG.c.recon.const.batteries, result.batteryIndex, result.groupIndex)
    CONFIG.c.recon.isStrikeActivated = true
    ScenEdit_SpecialMessage('China', 'Emissions from ' .. tostring(contact.name))
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
