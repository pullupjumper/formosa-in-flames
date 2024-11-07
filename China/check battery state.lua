local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if CONFIG.c.ground.mlrs.isStrikeActivated then
    CheckBatteryState(CONFIG, 'mlrs', CONFIG.c.ground.mlrs.batteries, 'China', true)
end

if CONFIG.c.ground.srbm.isStrikeActivated then
    CheckBatteryState(CONFIG, 'srbm', CONFIG.c.ground.srbm.batteries, 'China', true)
end

if CONFIG.c.ground.glcm.isStrikeActivated then
    CheckBatteryState(CONFIG, 'glcm', CONFIG.c.ground.glcm.batteries, 'China', true)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
