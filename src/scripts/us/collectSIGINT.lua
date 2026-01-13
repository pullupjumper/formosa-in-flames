local gKH = require("src.core.gKH_State_Standalone")
local SIGINT = require("src.modules.EW.sigint")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.u.SIGINT.enabled then
  SIGINT.handleSIGINT(config, saveData.u.SIGINT, "US", saveData.c.ground.mlrs.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData.u.SIGINT, "US", saveData.c.ground.srbm.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData.u.SIGINT, "US", saveData.c.ground.glcm.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData.u.SIGINT, "US", saveData.c.IADS.C2, true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
