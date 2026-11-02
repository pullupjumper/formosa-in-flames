local config = require("src.core.config")
local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local LandingOps = require("src.modules.landingOps.init")

local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end

PersistentState.read(function(saveData)
  LandingOps.attackAirlandingZone(config, saveData, ship)
end)
