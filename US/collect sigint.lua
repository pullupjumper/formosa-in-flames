local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if CONFIG.u.SIGINT.isActivated then
    HandleSIGINT(CONFIG, CONFIG.c.ground.mlrs.batteries, true)
    HandleSIGINT(CONFIG, CONFIG.c.ground.srbm.batteries, true)
    HandleSIGINT(CONFIG, CONFIG.c.ground.glcm.batteries, true)
    HandleSIGINT(CONFIG, CONFIG.c.IADS.C2, true)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
