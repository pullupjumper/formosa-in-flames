local config = require("src.core.config")
local PersistentState = require("src.core.persistentState")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")

PersistentState.update(function(saveData)
  IntegratedAirDefenseSystem.removeC2Facilities(config.c.iads)
  IntegratedAirDefenseSystem.addC2Facilities(config.c.iads)
  IntegratedAirDefenseSystem.initC2FacilitiesContext(config.c.iads, saveData.c.iads)
end)
