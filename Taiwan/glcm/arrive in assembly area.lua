local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

--------------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.t.glcm.batteries) do
    if unit == nil then
        ScenEdit_MsgBox('Is nil', 1)
        return
    end

    battery.reloadStartTime = ScenEdit_CurrentTime()
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
