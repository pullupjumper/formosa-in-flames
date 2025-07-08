local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local RunwayRepairment = require("src.modules.runwayRepairment")
local CONFIG = require("src.core.constants")

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

RunwayRepairment.repairRunway(CONFIG, saveData, 'China')
RunwayRepairment.repairRunway(CONFIG, saveData, 'Taiwan')
