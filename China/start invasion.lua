local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

-- CONFIG.c.srbm.isStrikeActivated = true
ScenEdit_GetEvent('(China) (Landing operation) Landing ships move to area').isActive = true
ScenEdit_GetEvent('(China) (SRBM kill chain) Strike on SAMs').isActive = true
-- ScenEdit_GetEvent('(China) (SRBM kill chain) Launch H6N').isActive = true
ScenEdit_GetEvent('(Score) Unit is damaged or destroyed before Chinese strike').isActive = false

ScenEdit_SetSidePosture("China", "Taiwan", "H")
ScenEdit_SetSidePosture("Taiwan", "China", "H")

-- ScenEdit_SpecialMessage(
--     'Taiwan',
--     CONFIG.s.const.msg.tipForStartOfInvasion,
--     { latitude = 'N 25.28.28', longitude = 'E 119.45.23' }
-- )

for index, group in ipairs(CONFIG.c.landingOperation.const.sag) do
    local unit = SE_GetUnit({ guid = group.guid })

    if unit ~= nil then
        unit.course = group.course
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
