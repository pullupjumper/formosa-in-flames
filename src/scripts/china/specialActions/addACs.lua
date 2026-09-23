local PersistentState = require("src.core.persistentState")
local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")

PersistentState.read(function(saveData)
  UnitGenerator.addAircraft(config.c.air.landBased.deployedACs)
  -- UnitGenerator.initAircraftContexts(saveData.c.air.landBased, config.c.commsJamming.aircraftDefaults)
end)
