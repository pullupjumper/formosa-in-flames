local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local config = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if not unit then
  return
end


if saveData.t.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.t.ground.glcm, unit, false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end


if saveData.t.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.t.ground.mlrs, unit, false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end


if saveData.t.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.t.ground.srbm, unit, false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end


if saveData.t.ground.ascm.isActivated then
  local result = Launcher.isMetWithAmmo(config, saveData.t.ground.ascm, unit, false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
