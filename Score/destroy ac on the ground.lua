local unit = ScenEdit_UnitX()
local score = ScenEdit_GetScore("Taiwan")
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not unit then
    return
end

if unit.condition == 'Parked' and unit.dbid == CONFIG.const.platformBDID5 then
    ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.const.destroyingAircraftOnTheGround),
        "Destory a helicopter on the ground"
    )
elseif unit.dbid == CONFIG.const.platformBDID12 or unit.dbid == CONFIG.const.platformBDID13 then
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.uav), "Destory a recon UAV")
elseif unit.dbid == CONFIG.const.platformBDID22 then
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.mlrs), "Destory a MLRS launcher")
end

-- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
