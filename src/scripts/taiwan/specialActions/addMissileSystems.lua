local gKH = require("src.core.gKH_State_Standalone")
local MissileSystem = require("src.modules.missileSystem")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

MissileSystem.addMissileSystems(config.t.ground, "Taiwan")
MissileSystem.initMissileSystemContexts(config.t.ground, saveData.t.ground)
