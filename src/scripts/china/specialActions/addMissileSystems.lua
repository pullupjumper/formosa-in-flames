local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.deploySide(config, saveData, constants.SIDES.ENEMY)
end)
