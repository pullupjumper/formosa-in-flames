local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not CONFIG.c.srbm.isStrikeActivated then
    return
end

checkBatteryState(CONFIG, 'srbm', CONFIG.c.srbm.batteries)

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
