local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end


CONFIG.c.srbm.onSAM.h6nTemp = launchUnits(
    CONFIG.c.srbm.onSAM.const.h6nBaseGUID,
    CONFIG.c.srbm.onSAM.const.h6nCourse,
    1,
    CONFIG.c.srbm.onSAM.const.h6nDBID,
    'Aircraft'
)


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
