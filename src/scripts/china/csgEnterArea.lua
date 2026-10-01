local GameApi = require("src.utils.gameApi")
local PersistentState = require("src.core.persistentState")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  GameApi.ScenEdit_GetMission(constants.SIDES.RED, "CAP/E").isactive = true
  GameApi.ScenEdit_GetMission(constants.SIDES.RED, "ASW/CSG").isactive = false
  GameApi.ScenEdit_GetMission(constants.SIDES.RED, "ASW/PATROL AC").isactive = false
  PersistentState.lacm(saveData).enabled = true
end)
