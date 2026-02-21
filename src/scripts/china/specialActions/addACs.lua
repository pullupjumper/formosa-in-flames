local UnitGenerator = require("src.modules.unitGenerator")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

UnitGenerator.addAircraft(config.c.air.landBased.deployedACs)
UnitGenerator.initAircraftContexts(saveData.c.air.landBased, config.c.commsJamming.aircraftDefaults)
