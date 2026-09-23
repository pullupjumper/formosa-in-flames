local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.process(PersistentState.groundForces(saveData, constants.SIDES.PLAYER), config.t.ground, false, constants.SIDES.PLAYER)
end)
