local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.addMissileSystems(config.c.ground, constants.SIDES.ENEMY)
  MissileSystem.initMissileSystemContexts(config.c.ground, saveData.c.ground)
end)
