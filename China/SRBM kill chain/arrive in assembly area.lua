local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not CONFIG.c.srbm.isStrikeActivated then
    return
end

for _, battery in ipairs(CONFIG.c.srbm.batteries) do
    if unit then
        if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
            setReloadStartTime(battery, unit)
        end
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
