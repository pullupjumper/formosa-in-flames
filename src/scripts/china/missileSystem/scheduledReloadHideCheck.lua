local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.process(PersistentState.groundForces(saveData, constants.SIDES.ENEMY), true, constants.SIDES.ENEMY)
end)
