local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

ScenEdit_GetEvent('(China) (Landing operation) Landing ships move to area').isActive = true
ScenEdit_GetEvent('(Score) Unit is damaged or destroyed before Chinese strike').isActive = false
ScenEdit_SetSidePosture("China", "Taiwan", "H")
ScenEdit_SetSidePosture("Taiwan", "China", "H")

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
