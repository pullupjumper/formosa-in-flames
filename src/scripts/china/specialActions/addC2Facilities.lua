local config = require("src.core.config")
local Logger = require("src.utils.logger")
local gKH = require("src.core.gKH_State_Standalone")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

IntegratedAirDefenseSystem.removeC2Facilities(config.c.iads)
IntegratedAirDefenseSystem.addC2Facilities(config.c.iads)
IntegratedAirDefenseSystem.initC2FacilitiesContext(config.c.iads, saveData.c.iads)

gKH.State.SaveTableToKey(saveData, "SaveData")
