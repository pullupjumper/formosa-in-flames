local unit = ScenEdit_UnitX()

if unit.condition == 'Parked' then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore("Taiwan", (score + SCORE_AC_IS_DESTROYED_ON_THE_GROUND), "An aircraft is destoryed on the ground")
end
