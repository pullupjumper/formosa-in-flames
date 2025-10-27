local gKH = require('src.core.gKH_State_Standalone')
local SIGINT = require('src.modules.EW.sigint')
local config = require('src.core.constants')
local Logger = require("src.utils.logger")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.u.SIGINT.isActivated then
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.ground.srbm.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.ground.glcm.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.ground.mlrs.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.ground.ascm.firingUnits, true)
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.IADS.ROCC, true)
  SIGINT.handleSIGINT(config, saveData, 'China', saveData.t.IADS.TAAOC, true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
