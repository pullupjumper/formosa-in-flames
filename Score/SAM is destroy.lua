local unit = ScenEdit_UnitX()

if unit.dbid == PLATFORM_DBID_14 or unit.dbid == PLATFORM_DBID_15 then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore("Taiwan", (score + SCORE_SAM_IS_DESTROYED), "A SAM battery is destoryed")
end
