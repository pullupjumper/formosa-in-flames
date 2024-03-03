local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not unit then
    return
end

if unit.condition == 'Parked' then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.const.aircraftIsDestroyedOnTheGround),
        "An aircraft is destoryed on the ground"
    )
end
