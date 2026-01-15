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
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.ground.srbm.firingUnits, true, config.c.SIGINT)
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.ground.glcm.firingUnits, true, config.c.SIGINT)
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.ground.mlrs.firingUnits, true, config.c.SIGINT)
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.ground.ascm.firingUnits, true, config.c.SIGINT)
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.IADS.ROCC, true, config.c.SIGINT)
  SIGINT.handleSIGINT(config, saveData.c.SIGINT, "China", saveData.t.IADS.TAAOC, true, config.c.SIGINT)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
