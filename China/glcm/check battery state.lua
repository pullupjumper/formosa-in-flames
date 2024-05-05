local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if not CONFIG.c.glcm.isStrikeActivated then
    return
end

checkBatteryState(CONFIG, 'glcm', CONFIG.c.glcm.batteries)

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
