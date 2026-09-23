local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.addMissileSystems(config.t.ground, constants.SIDES.PLAYER)
  MissileSystem.initMissileSystemContexts(config.t.ground, PersistentState.groundForces(saveData, constants.SIDES.PLAYER))
end)
