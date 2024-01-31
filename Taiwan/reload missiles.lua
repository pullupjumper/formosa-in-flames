local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end


if CONFIG.t.asm.isAntishipMissionActivated then
    reloadMissile(CONFIG.t.asm.launcherState, CONFIG.t.asm.const.reloadTime)
end

if CONFIG.t.glcm.isReloadActivated then
    reloadMissile(CONFIG.t.glcm.launcherState, CONFIG.t.glcm.const.reloadTime)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
