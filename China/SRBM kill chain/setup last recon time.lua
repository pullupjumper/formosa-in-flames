local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

CONFIG.c.srbm.lastReconTime = ScenEdit_CurrentTime()
CONFIG.c.glcm.lastReconTime = ScenEdit_CurrentTime()
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
