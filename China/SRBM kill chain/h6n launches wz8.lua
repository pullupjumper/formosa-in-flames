local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit ~= nil then
    local wz8 = launchWZ8(unit, CONFIG.c.srbm.onSAM.const.wz8Course, nil)
    table.insert(CONFIG.c.srbm.onSAM.wz8Temp, { unit = wz8.guid })
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
