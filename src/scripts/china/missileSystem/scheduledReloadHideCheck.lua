local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local MissileSystem = require("src.modules.missileSystem")
local config = require("src.core.config")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

local missileSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, missileSystem in ipairs(missileSystems) do
  if saveData.c.ground[missileSystem] and saveData.c.ground[missileSystem].enabled then
    MissileSystem.checkMissileSystemState(config, saveData.c.ground[missileSystem], true, "China")
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
