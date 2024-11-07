local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if CONFIG.u.SIGINT.isActivated then
    HandleSIGINT(CONFIG, CONFIG.t.ground.srbm.batteries, true, 'China')
    HandleSIGINT(CONFIG, CONFIG.t.IADS.ROCC, true, 'China')
    HandleSIGINT(CONFIG, CONFIG.t.IADS.TAAOC, true, 'China')
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
