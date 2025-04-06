local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end

if unit ~= nil then
    local wz8 = LaunchWZ8(unit, CONFIG.c.recon.wz8Course, nil)

    if wz8 then
        table.insert(saveData.c.recon.wz8Temp, { unit = wz8.guid })
    end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
