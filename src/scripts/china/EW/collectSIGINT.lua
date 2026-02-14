local gKH = require("src.core.gKH_State_Standalone")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.u.sigint.enabled then
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.ground.srbm.firingUnits, true, config.c.sigint)
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.ground.glcm.firingUnits, true, config.c.sigint)
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.ground.mlrs.firingUnits, true, config.c.sigint)
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.ground.ascm.firingUnits, true, config.c.sigint)
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.iads.rocc, true, config.c.sigint)
  Sigint.handleSigint(config, saveData.c.sigint, "China", saveData.t.iads.taaoc, true, config.c.sigint)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
