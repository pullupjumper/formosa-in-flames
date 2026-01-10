local GameApi = require("src.utils.gameApi")
local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

GameApi.ScenEdit_GetMission("China", "CAP/E").isactive = true
GameApi.ScenEdit_GetMission("China", "ASW/CSG").isactive = false
GameApi.ScenEdit_GetMission("China", "ASW/PATROL AC").isactive = false
saveData.c.surface.lacm.isActivated = true

gKH.State.SaveTableToKey(saveData, "SaveData")
