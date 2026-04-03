local gKH = require("src.core.gKH_State_Standalone")
local MissileSystem = require("src.modules.missileSystem.init")
local config = require("src.core.config")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

MissileSystem.addMissileSystems(config.c.ground, constants.SIDES.ENEMY)
MissileSystem.initMissileSystemContexts(config.c.ground, saveData.c.ground)
