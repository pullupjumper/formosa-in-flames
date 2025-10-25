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

if not unit then
  return
end


if saveData.c.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.c.ground.glcm, unit, true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.c.ground.mlrs, unit, true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.c.ground.srbm, unit, true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end


if saveData.c.ground.mrbm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.c.ground.mrbm, unit, true)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, true)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
