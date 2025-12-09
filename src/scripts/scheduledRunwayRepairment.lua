local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local RunwayRepairment = require("src.modules.runwayRepairment")
local config = require("src.core.config")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

RunwayRepairment.repairRunway(config, saveData.c.repairRunway.runways)
RunwayRepairment.repairRunway(config, saveData.t.repairRunway.runways)
