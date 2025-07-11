local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local gKH = require('src.core.gKH_State_Standalone')
local config = require("src.core.constants")
local Launcher = require('src.modules.launcher')
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")
local contacts = GameApi.ScenEdit_GetContacts('China')

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if contacts then
  for _, contact in ipairs(contacts) do
    if unit and unit.guid == contact.actualunitid then
      contact:DropContact()
    end
  end
end

if saveData.t.ground.glcm.isActivated then
  for _, battery in pairs(saveData.t.ground.glcm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == config.batteryState.REPOSITIONING then
        Launcher.setStateToHIDE(config, battery, unit)
      end
    end
  end
end

if saveData.t.ground.mlrs.isActivated then
  for _, battery in pairs(saveData.t.ground.mlrs.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == config.batteryState.REPOSITIONING then
        Launcher.setStateToHIDE(config, battery, unit)
      end
    end
  end
end

if saveData.t.ground.srbm.isActivated then
  for _, battery in pairs(saveData.t.ground.srbm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == config.batteryState.REPOSITIONING then
        Launcher.setStateToHIDE(config, battery, unit)
      end
    end
  end
end

if saveData.t.ground.ascm.isActivated then
  for _, battery in pairs(saveData.t.ground.ascm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == config.batteryState.REPOSITIONING then
        Launcher.setStateToHIDE(config, battery, unit)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
