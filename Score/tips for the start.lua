local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForStart,
    { latitude = 'N 24.47.50', longitude = 'E 112.23.56' }
)
ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForASWInNortheasternWaterOfTaiwan,
    { latitude = 'N 24.47.50', longitude = 'E 112.23.56' }
)
ScenEdit_SpecialMessage(
    'Taiwan',
    CONFIG.s.const.msg.tipForHuntingCarrier,
    { latitude = 'N 21.30.53', longitude = 'E 121.46.06' }
)
