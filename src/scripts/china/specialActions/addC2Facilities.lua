local config = require("src.core.config")
local PersistentState = require("src.core.persistentState")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")

PersistentState.update(function(saveData)
  IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)
end)
