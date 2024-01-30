local unit = ScenEdit_UnitX()
local score = ScenEdit_GetScore("Taiwan")

if unit.condition == 'Parked' then
    ScenEdit_SetScore("Taiwan", (score + SCORE_DESTROY_AC_ON_THE_GROUND), "Destory an aircraft on the ground")
elseif unit.dbid == PLATFORM_DBID_12 or unit.dbid == PLATFORM_DBID_13 then
    ScenEdit_SetScore("Taiwan", (score + SCORE_UAV), "Destory a recon UAV")
end
