local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local RunwayRepairment = require("src.modules.runwayRepairment")

local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit then
  RunwayRepairment.whenRunwayIsDamaged(saveData, unit.side, unit)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
