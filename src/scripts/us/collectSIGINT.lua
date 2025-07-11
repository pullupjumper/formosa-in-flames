local gKH = require('src.core.gKH_State_Standalone')
local SIGINT = require('src.modules.EW.sigint')
local config = require('src.core.constants')
local Logger = require("src.utils.logger")

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.u.SIGINT.isActivated then
  SIGINT.handleSIGINT(config, saveData, 'US', saveData.c.ground.mlrs.batteries, true)
  SIGINT.handleSIGINT(config, saveData, 'US', saveData.c.ground.srbm.batteries, true)
  SIGINT.handleSIGINT(config, saveData, 'US', saveData.c.ground.glcm.batteries, true)
  SIGINT.handleSIGINT(config, saveData, 'US', saveData.c.IADS.C2, true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
