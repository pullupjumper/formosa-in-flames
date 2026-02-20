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
  Sigint.collectSigint(config, saveData.u.sigint, "US", true, config.u.sigint,
    saveData.c.ground.mlrs.firingUnits,
    saveData.c.ground.srbm.firingUnits,
    saveData.c.ground.glcm.firingUnits,
    saveData.c.iads.c2)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
