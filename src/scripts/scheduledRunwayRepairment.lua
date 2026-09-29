local PersistentState = require("src.core.persistentState")
local RunwayRepairment = require("src.modules.runwayRepairment")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.read(function(saveData)
  RunwayRepairment.repairSide(config, saveData, constants.SIDES.ENEMY)
  RunwayRepairment.repairSide(config, saveData, constants.SIDES.PLAYER)
end)
