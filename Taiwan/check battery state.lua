local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

CheckBatteryState(CONFIG, 'mlrs', CONFIG.t.ground.mlrs.batteries, 'Taiwan', false)
CheckBatteryState(CONFIG, 'srbm', CONFIG.t.ground.srbm.batteries, 'Taiwan', false)
CheckBatteryState(CONFIG, 'glcm', CONFIG.t.ground.glcm.batteries, 'Taiwan', false)

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
