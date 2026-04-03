local gKH = require("src.core.gKH_State_Standalone")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.u.sigint.enabled then
  Sigint.collectSigint(config, saveData.c.sigint, constants.SIDES.ENEMY, true, config.c.sigint,
    saveData.t.ground.srbm.firingUnits,
    saveData.t.ground.glcm.firingUnits,
    saveData.t.ground.mlrs.firingUnits,
    saveData.t.ground.ascm.firingUnits,
    saveData.t.iads.rocc,
    saveData.t.iads.taaoc)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
