local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if not CONFIG.c.glcm.isStrikeActivated then
    return
end

for _, battery in ipairs(CONFIG.c.glcm.batteries) do
    if unit then
        if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
            setReloadStartTime(battery, unit)
        end
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
