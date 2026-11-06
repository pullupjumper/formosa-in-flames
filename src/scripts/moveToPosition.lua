local PersistentState = require("src.core.persistentState")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local unit = GameApi.ScenEdit_UnitX()
local event = GameApi.ScenEdit_EventX()

if not event then
  Logger.error("event is nil")
  return
end

if not unit then
  Logger.error("unit is nil")
  return
end

PersistentState.update(function(saveData)
  MissileSystem.processArrival(config, saveData, unit, event)
end)
