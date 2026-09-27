local PersistentState = require("src.core.persistentState")
local StrikePlanner = require("src.modules.strikePlanner.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local unit = GameApi.ScenEdit_UnitX()

if not unit then
  Logger.error("unit is nil")
  return
end

PersistentState.update(function(saveData)
  StrikePlanner.launchWZ8(PersistentState.recon(saveData), unit)
end)
