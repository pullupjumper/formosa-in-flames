local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

CONFIG.c.ground.mlrs.lastReconTime = ScenEdit_CurrentTime()
CONFIG.c.ground.srbm.lastReconTime = ScenEdit_CurrentTime()
CONFIG.c.ground.glcm.lastReconTime = ScenEdit_CurrentTime()
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
