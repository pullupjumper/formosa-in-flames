local PersistentState = require("src.core.persistentState")
local RunwayRepairment = require("src.modules.runwayRepairment")
local config = require("src.core.config")

PersistentState.read(function(saveData)
  RunwayRepairment.repairRunway(config, saveData.c.repairRunway.runways)
  RunwayRepairment.repairRunway(config, saveData.t.repairRunway.runways)
end)
