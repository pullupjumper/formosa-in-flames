local gKH = require("src.core.gKH_State_Standalone")
local Launcher = require("src.modules.launcher")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

local systems = { "srbm", "mrbm", "mlrs", "glcm" }
Launcher.addLaunchers(config.c.ground, systems, "China")
Launcher.initLauncherContexts(config.c.ground, saveData.c.ground, systems)
