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

for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
  if saveData.c.ground[missileSystem] and saveData.c.ground[missileSystem].enabled then
    MissileSystem.checkMissileSystemState(saveData.c.ground[missileSystem], true, constants.SIDES.ENEMY)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
