local PersistentState = require("src.core.persistentState")
local Recon = require("src.modules.strikePlanner.recon")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local unit = GameApi.ScenEdit_UnitX()

if not unit then
  Logger.error("unit is nil")
  return
end

PersistentState.update(function(saveData)
  Recon.launchWZ8(saveData.c.recon, unit)
end)
