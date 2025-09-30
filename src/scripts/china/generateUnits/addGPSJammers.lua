local config = require('src.core.constants')
local GPSJamming = require('src.modules.EW.GPSJamming')
local Logger = require("src.utils.logger")
local gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

GPSJamming.removeJammers(saveData, 'China')
GPSJamming.addGPSJammers(config, saveData, 'China')
