local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local Launcher = require('src.modules.launcher')
local config = require("src.core.constants")
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

Launcher.checkBatteryState(config, saveData, 'mlrs', 'Taiwan', false)
Launcher.checkBatteryState(config, saveData, 'srbm', 'Taiwan', false)
Launcher.checkBatteryState(config, saveData, 'glcm', 'Taiwan', false)
Launcher.checkBatteryState(config, saveData, 'ascm', 'Taiwan', false)
gKH.State.SaveTableToKey(saveData, "SaveData")
