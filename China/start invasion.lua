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
ScenEdit_GetEvent('(Score) Unit is damaged').isActive = false

ScenEdit_SetSidePosture("China", "Taiwan", "H")
ScenEdit_SetSidePosture("Taiwan", "China", "H")

ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForMlrs,
    { latitude = 'N 25.28.28', longitude = 'E 119.45.23' }
)
ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForRelocatingAircraft,
    { latitude = 'N 21.30.53', longitude = 'E 121.46.06' }
)
ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForHelicopterBase,
    { latitude = 'N 21.30.53', longitude = 'E 121.46.06' }
)
ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForReload,
    { latitude = 'N 21.30.53', longitude = 'E 121.46.06' }
)

for index, group in ipairs(CONFIG.c.landingOperation.const.sag) do
    local unit = SE_GetUnit({ guid = group.guid })

    if unit ~= nil then
        unit.course = group.course
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
