local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

CONFIG.t.ground.mlrs.const.erectingTime = ScenEdit_CurrentTime()

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
