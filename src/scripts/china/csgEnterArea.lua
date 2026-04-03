local GameApi = require("src.utils.gameApi")
local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "CAP/E").isactive = true
GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "ASW/CSG").isactive = false
GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, "ASW/PATROL AC").isactive = false
saveData.c.surface.lacm.enabled = true

gKH.State.SaveTableToKey(saveData, "SaveData")
