local GameApi = require("src.utils.gameApi")
local PersistentState = require("src.core.persistentState")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "CAP/E").isactive = true
  GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "ASW/CSG").isactive = false
  GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "ASW/PATROL AC").isactive = false
  PersistentState.lacm(saveData).enabled = true
end)
