local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local Launcher = require('src.modules.launcher')
local config = require("src.core.constants")
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

Launcher.checkBatteryState(config, saveData.t.ground.mlrs, false)
Launcher.checkBatteryState(config, saveData.t.ground.srbm, false)
Launcher.checkBatteryState(config, saveData.t.ground.glcm, false)
Launcher.checkBatteryState(config, saveData.t.ground.ascm, false)
gKH.State.SaveTableToKey(saveData, "SaveData")
