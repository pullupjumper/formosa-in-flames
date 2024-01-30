local unit = ScenEdit_UnitX()
local score = ScenEdit_GetScore("Taiwan")

if unit.dbid == PLATFORM_DBID_7
    or unit.dbid == PLATFORM_DBID_8
    or unit.dbid == PLATFORM_DBID_9
    or unit.dbid == PLATFORM_DBID_10 then
    ScenEdit_SetScore("Taiwan", (score + SCORE_LST), "Destroy a LST")
elseif unit.dbid == PLATFORM_DBID_6 then
    ScenEdit_SetScore("Taiwan", (score + SCORE_LHD), "Destroy a LHD")
elseif unit.dbid == PLATFORM_DBID_11 then
    ScenEdit_SetScore("Taiwan", (score + SCORE_CV), "Destroy a carrier")
else
    ScenEdit_SetScore("Taiwan", (score + SCORE_DDG), "Destroy other ships")
end
