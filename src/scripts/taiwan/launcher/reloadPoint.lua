local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local config = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end


if saveData.t.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(config, saveData, unit, 'mlrs', false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end

if saveData.t.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(config, saveData, unit, 'glcm', false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end

if saveData.t.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(config, saveData, unit, 'srbm', false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end

if saveData.t.ground.ascm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(config, saveData, unit, 'ascm', false)

  if result.isMet then
    Launcher.setReloadStartTime(config, result.battery, unit, false)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
