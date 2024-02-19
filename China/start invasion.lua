local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

CONFIG.c.srbm.isStrikeActivated = true
ScenEdit_GetEvent('(China) (Landing operation) Landing ships move to area').isActive = true
ScenEdit_GetEvent('(China) (SRBM kill chain) Strike on SAMs').isActive = true
ScenEdit_GetEvent('(China) (SRBM kill chain) Launch H6N').isActive = true

ScenEdit_SetSidePosture("China", "Taiwan", "H")
ScenEdit_SetSidePosture("Taiwan", "China", "H")

for index, group in ipairs(CONFIG.c.landingOperation.const.sag) do
    local unit = SE_GetUnit({ guid = group.guid })

    if unit ~= nil then
        unit.course = group.course
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
