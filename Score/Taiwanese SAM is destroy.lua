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

if unit.dbid == CONFIG.const.platformBDID14 or unit.dbid == CONFIG.const.platformBDID15 then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.samIsDestroyed), "A SAM battery is destoryed")
end
