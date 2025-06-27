gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if saveData.c.ground.mlrs.isActivated then
  CheckBatteryState(saveData, 'mlrs', 'China', true)
end

if saveData.c.ground.srbm.isActivated then
  CheckBatteryState(saveData, 'srbm', 'China', true)
end

if saveData.c.ground.glcm.isActivated then
  CheckBatteryState(saveData, 'glcm', 'China', true)
end

if saveData.c.ground.mrbm.isActivated then
  CheckBatteryState(saveData, 'mrbm', 'China', true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
