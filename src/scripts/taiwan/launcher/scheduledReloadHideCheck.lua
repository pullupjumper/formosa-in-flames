local gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

CheckBatteryState(saveData, 'mlrs', 'Taiwan', false)
CheckBatteryState(saveData, 'srbm', 'Taiwan', false)
CheckBatteryState(saveData, 'glcm', 'Taiwan', false)
CheckBatteryState(saveData, 'ascm', 'Taiwan', false)
gKH.State.SaveTableToKey(saveData, "SaveData")
