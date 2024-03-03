-- local unit = ScenEdit_UnitX()
local score = ScenEdit_GetScore("Taiwan")
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.sub), "Destory a submarine")
