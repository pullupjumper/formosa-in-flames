local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local Launcher = require("src.modules.launcher")
local config = require("src.core.config")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

local wpnSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, wpnSystem in ipairs(wpnSystems) do
  if saveData.c.ground[wpnSystem] and saveData.c.ground[wpnSystem].isActivated then
    Launcher.checkBatteryState(config, saveData.c.ground[wpnSystem], true, "China")
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
