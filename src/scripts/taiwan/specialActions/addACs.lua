local PersistentState = require("src.core.persistentState")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local config = require("src.core.config")

PersistentState.update(function(saveData)
  UnitGenerator.addAircraft(config.t.air.deployedACs)
  CommsJamming.updateTargetAircraft(config, saveData)
end)
