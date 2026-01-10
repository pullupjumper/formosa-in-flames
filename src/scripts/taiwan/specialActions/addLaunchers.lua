local gKH = require("src.core.gKH_State_Standalone")
local Launcher = require("src.modules.launcher")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

Launcher.addLaunchers(saveData.t.ground, { "srbm", "ascm", "mlrs", "glcm" }, "Taiwan")
