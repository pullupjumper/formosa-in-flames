local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end


CONFIG.c.recon.h6nTemp = LaunchUnits(
    CONFIG.c.recon.const.h6nBaseGUID,
    CONFIG.c.recon.const.h6nCourse,
    1,
    CONFIG.c.recon.const.h6nDBID,
    'Aircraft'
)


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
