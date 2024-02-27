local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

--------------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.t.glcm.batteries) do
    if unit then
        battery.reloadStartTime = ScenEdit_CurrentTime()
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
