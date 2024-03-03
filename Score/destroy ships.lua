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

if unit.dbid == CONFIG.const.platformBDID7
    or unit.dbid == CONFIG.const.platformBDID8
    or unit.dbid == CONFIG.const.platformBDID9
    or unit.dbid == CONFIG.const.platformBDID10 then
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lst), "Destroy a LST")
elseif unit.dbid == CONFIG.const.platformBDID6 then
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lhd), "Destroy a LHD")
elseif unit.dbid == CONFIG.const.platformBDID11 then
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.cv), "Destroy a carrier")
else
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.ddg), "Destroy other ships")
end

-- gKH.State.SaveTableToKey(CONFIG, "CONFIG")
