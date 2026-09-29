local PersistentState = require("src.core.persistentState")
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local ship = GameApi.ScenEdit_UnitX()

if not ship then
  Logger.error("ship is nil")
  return
end

PersistentState.update(function(saveData)
  LandingOps.offloadVehicles(config, saveData, ship)
end)
