local gKH = require('src.core.gKH_State_Standalone')
local config = require("src.core.config")
local Logger = require("src.utils.logger")
local CommsJamming = require("src.modules.EW.commsJamming")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.c.commsJamming.isActivated then
  CommsJamming.handleCommsJamming(config, saveData)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
