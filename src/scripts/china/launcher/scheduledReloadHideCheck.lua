local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local config = require("src.core.constants")
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if saveData.c.ground.mlrs.isActivated then
  Launcher.checkBatteryState(config, saveData, 'mlrs', 'China', true)
end

if saveData.c.ground.srbm.isActivated then
  Launcher.checkBatteryState(config, saveData, 'srbm', 'China', true)
end

if saveData.c.ground.glcm.isActivated then
  Launcher.checkBatteryState(config, saveData, 'glcm', 'China', true)
end

if saveData.c.ground.mrbm.isActivated then
  Launcher.checkBatteryState(config, saveData, 'mrbm', 'China', true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
