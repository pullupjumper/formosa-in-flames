local PersistentState = require("src.core.persistentState")
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end

PersistentState.update(function(saveData)
  LandingOps.launchACV(config, saveData, ship)
end)
