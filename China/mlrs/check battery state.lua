local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if not CONFIG.c.mlrs.isStrikeActivated then
    return
end

checkBatteryState(CONFIG, 'mlrs', CONFIG.c.mlrs.batteries)

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
