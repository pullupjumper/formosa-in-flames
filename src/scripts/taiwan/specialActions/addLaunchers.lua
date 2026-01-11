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

local systems = { "srbm", "ascm", "mlrs", "glcm" }
Launcher.addLaunchers(config.t.ground, systems, "Taiwan")
Launcher.initLauncherContexts(config.t.ground, saveData.t.ground, systems)
