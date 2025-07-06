local gKH = require('src.core.gKH_State_Standalone')
local CONFIG = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end


if saveData.c.ground.glcm.isActivated then
  for _, battery in pairs(saveData.c.ground.glcm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        Launcher.setWCSToFree(CONFIG, battery, unit)
      end
    end
  end
end

if saveData.c.ground.mlrs.isActivated then
  for _, battery in pairs(saveData.c.ground.mlrs.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        Launcher.setWCSToFree(CONFIG, battery, unit)
      end
    end
  end
end

if saveData.c.ground.srbm.isActivated then
  for _, battery in pairs(saveData.c.ground.srbm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        Launcher.setWCSToFree(CONFIG, battery, unit)
      end
    end
  end
end

if saveData.c.ground.mrbm.isActivated then
  for _, battery in pairs(saveData.c.ground.mrbm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        Launcher.setWCSToFree(CONFIG, battery, unit)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
