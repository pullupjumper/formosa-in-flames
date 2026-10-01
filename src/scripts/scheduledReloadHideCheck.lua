local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.processSide(config, saveData, constants.SIDES.RED)
  MissileSystem.processSide(config, saveData, constants.SIDES.BLUE)
end)
