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

local wpnSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, wpnSystem in ipairs(wpnSystems) do
  if saveData.c.ground[wpnSystem] and saveData.c.ground[wpnSystem].enabled then
    MissileSystem.checkBatteryState(config, saveData.c.ground[wpnSystem], true, "China")
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
