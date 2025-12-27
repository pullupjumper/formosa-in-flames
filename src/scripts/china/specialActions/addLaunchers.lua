local gKH = require("src.core.gKH_State_Standalone")
local Launcher = require("src.modules.launcher")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

Launcher.addLaunchers(saveData.c.ground, { "srbm", "mrbm", "mlrs", "glcm" }, "China")
