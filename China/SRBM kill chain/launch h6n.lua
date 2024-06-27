local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end


CONFIG.c.srbm.onSAM.h6nTemp = LaunchUnits(
    CONFIG.c.srbm.onSAM.const.h6nBaseGUID,
    CONFIG.c.srbm.onSAM.const.h6nCourse,
    1,
    CONFIG.c.srbm.onSAM.const.h6nDBID,
    'Aircraft'
)


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
