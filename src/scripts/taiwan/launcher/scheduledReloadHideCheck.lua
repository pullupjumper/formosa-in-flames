local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local Launcher = require("src.modules.launcher")
local config = require("src.core.config")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

local wpnSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, wpnSystem in ipairs(wpnSystems) do
  if saveData.t.ground[wpnSystem] and saveData.t.ground[wpnSystem].enabled then
    Launcher.checkBatteryState(config, saveData.t.ground[wpnSystem], false, "Taiwan")
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
