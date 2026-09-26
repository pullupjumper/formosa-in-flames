local PersistentState = require("src.core.persistentState")
local RunwayRepairment = require("src.modules.runwayRepairment")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.read(function(saveData)
  RunwayRepairment.repairRunway(config, PersistentState.runwayRepair(saveData, constants.SIDES.ENEMY).runways)
  RunwayRepairment.repairRunway(config, PersistentState.runwayRepair(saveData, constants.SIDES.PLAYER).runways)
end)
