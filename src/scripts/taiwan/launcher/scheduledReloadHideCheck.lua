local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local CONFIG = require("src.core.constants")
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

Launcher.checkBatteryState(CONFIG, saveData, 'mlrs', 'Taiwan', false)
Launcher.checkBatteryState(CONFIG, saveData, 'srbm', 'Taiwan', false)
Launcher.checkBatteryState(CONFIG, saveData, 'glcm', 'Taiwan', false)
Launcher.checkBatteryState(CONFIG, saveData, 'ascm', 'Taiwan', false)
gKH.State.SaveTableToKey(saveData, "SaveData")
