local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.constants")
local saveData = gKH.State.LoadTableFromKey("SaveData")
local Launcher = require('src.modules.launcher')
local unit = GameApi.ScenEdit_UnitX()


if saveData == nil then
  Logger.error('saveData is nil')
  return
end


if saveData.c.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData, unit, 'glcm', true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData, unit, 'mlrs', true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData, unit, 'srbm', true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.mrbm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData, unit, 'mrbm', true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
