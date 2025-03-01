local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end


if CONFIG.c.ground.glcm.isStrikeActivated then
    for _, battery in pairs(CONFIG.c.ground.glcm.batteries) do
        if unit then
            if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
                SetWCSToFree(battery, unit)
            end
        end
    end
end

if CONFIG.c.ground.mlrs.isStrikeActivated then
    for _, battery in pairs(CONFIG.c.ground.mlrs.batteries) do
        if unit then
            if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
                SetWCSToFree(battery, unit)
            end
        end
    end
end

if CONFIG.c.ground.srbm.isStrikeActivated then
    for _, battery in pairs(CONFIG.c.ground.srbm.batteries) do
        if unit then
            if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
                SetWCSToFree(battery, unit)
            end
        end
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
