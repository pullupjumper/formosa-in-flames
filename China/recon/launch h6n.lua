local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end


saveData.c.recon.h6nTemp = LaunchUnits(
    CONFIG.c.recon.h6nBaseGUID,
    CONFIG.c.recon.h6nCourse,
    1,
    CONFIG.c.recon.h6nDBID,
    'Aircraft'
)


gKH.State.SaveTableToKey(saveData, "SaveData")
