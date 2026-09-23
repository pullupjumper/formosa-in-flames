local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local PersistentState = require("src.core.persistentState")

PersistentState.update(function(saveData)
  UnitGenerator.addAircraft(config.t.air.landBased.deployedACs)
  UnitGenerator.initAircraftContexts(saveData.t.air.landBased, config.c.commsJamming.aircraftDefaults)
end)
