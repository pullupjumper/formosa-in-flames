local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

CheckBatteryState(CONFIG, 'mlrs', 'Taiwan', false)
CheckBatteryState(CONFIG, 'srbm', 'Taiwan', false)
CheckBatteryState(CONFIG, 'glcm', 'Taiwan', false)
CheckBatteryState(CONFIG, 'ascm', 'Taiwan', false)
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
