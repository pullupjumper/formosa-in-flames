local GPSJamming = require("src.modules.EW.GPSJamming")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local gKH = require("src.core.gKH_State_Standalone")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

GPSJamming.removeJammers(config.c.GPSJamming.jammers, "China")
GPSJamming.addGPSJammers(config.c.GPSJamming.jammers, "China")
