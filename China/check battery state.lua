local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if CONFIG.c.mlrs.isStrikeActivated then
    CheckBatteryState(CONFIG, 'mlrs', CONFIG.c.mlrs.batteries, 'China', true)
end

if CONFIG.c.srbm.isStrikeActivated then
    CheckBatteryState(CONFIG, 'srbm', CONFIG.c.srbm.batteries, 'China', true)
end

if CONFIG.c.glcm.isStrikeActivated then
    CheckBatteryState(CONFIG, 'glcm', CONFIG.c.glcm.batteries, 'China', true)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
