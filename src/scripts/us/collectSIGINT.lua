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
  Sigint.handleSigint(config, saveData.u.sigint, "US", saveData.c.ground.mlrs.firingUnits, true, config.u.sigint)
  Sigint.handleSigint(config, saveData.u.sigint, "US", saveData.c.ground.srbm.firingUnits, true, config.u.sigint)
  Sigint.handleSigint(config, saveData.u.sigint, "US", saveData.c.ground.glcm.firingUnits, true, config.u.sigint)
  Sigint.handleSigint(config, saveData.u.sigint, "US", saveData.c.iads.c2, true, config.u.sigint)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
