local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

MissileSystem.checkMissileSystemState(saveData.c.ground, true, constants.SIDES.ENEMY)

gKH.State.SaveTableToKey(saveData, "SaveData")
