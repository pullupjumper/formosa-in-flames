local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

CheckBatteryState(CONFIG, 'srbm', CONFIG.t.srbm.batteries, 'Taiwan', false)
CheckBatteryState(CONFIG, 'glcm', CONFIG.t.glcm.batteries, 'Taiwan', false)

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
