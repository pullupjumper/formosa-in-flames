local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

CONFIG.c.srbm.onFacility.lastReconTime = ScenEdit_CurrentTime()
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
