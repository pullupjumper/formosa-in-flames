local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end

-- if CONFIG.c.ground.mlrs.isActivated then
--     CheckBatteryState(CONFIG, 'mlrs', CONFIG.c.ground.mlrs.batteries, 'China', true)
-- end

-- if CONFIG.c.ground.srbm.isActivated then
--     CheckBatteryState(CONFIG, 'srbm', CONFIG.c.ground.srbm.batteries, 'China', true)
-- end

-- if CONFIG.c.ground.glcm.isActivated then
--     CheckBatteryState(CONFIG, 'glcm', CONFIG.c.ground.glcm.batteries, 'China', true)
-- end
if saveData.c.ground.mlrs.isActivated then
    CheckBatteryState(saveData, 'mlrs', 'China', true)
end

if saveData.c.ground.srbm.isActivated then
    CheckBatteryState(saveData, 'srbm', 'China', true)
end

if saveData.c.ground.glcm.isActivated then
    CheckBatteryState(saveData, 'glcm', 'China', true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
