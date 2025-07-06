local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local CONFIG = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end


if saveData.c.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, unit, 'glcm', true)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, true)
  end
end

if saveData.c.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, unit, 'mlrs', true)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, true)
  end
end

if saveData.c.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, unit, 'srbm', true)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, true)
  end
end

if saveData.c.ground.mrbm.isActivated then
  local result = Launcher.isMetWithAmmoTrucks(CONFIG, saveData, unit, 'mrbm', true)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, true)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
