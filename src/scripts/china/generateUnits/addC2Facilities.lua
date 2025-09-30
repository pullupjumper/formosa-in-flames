local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')
local Logger = require("src.utils.logger")
local gKH = require('src.core.gKH_State_Standalone')

local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

-- Use the new unitGenerator API
UnitGenerator.removeC2Facilities(config)
UnitGenerator.addC2Facilities(config)

-- Use the new initC2Facilities function
UnitGenerator.initC2Facilities(config, saveData)

gKH.State.SaveTableToKey(saveData, "SaveData")
