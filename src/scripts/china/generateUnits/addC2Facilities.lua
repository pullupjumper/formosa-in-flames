local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')
local Logger = require("src.utils.logger")
local gKH = require('src.core.gKH_State_Standalone')

local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

-- 使用新的 unitGenerator API
UnitGenerator.removeC2Facilities(config)
UnitGenerator.addC2Facilities(config)

-- 使用新的 initC2Facilities 函數
UnitGenerator.initC2Facilities(config, saveData)

gKH.State.SaveTableToKey(saveData, "SaveData")
