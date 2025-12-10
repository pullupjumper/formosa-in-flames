local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

UnitGenerator.addAircraft(config.t.air.landBased.deployedACs)
UnitGenerator.initAircraftContexts(saveData.t.air.landBased)

gKH.State.SaveTableToKey(saveData, "SaveData")
