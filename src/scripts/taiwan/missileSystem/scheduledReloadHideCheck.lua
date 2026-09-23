local PersistentState = require("src.core.persistentState")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  MissileSystem.process(saveData.t.ground, false, constants.SIDES.PLAYER)
end)
