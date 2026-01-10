local config = require("src.core.config")
local Logger = require("src.utils.logger")
local gKH = require("src.core.gKH_State_Standalone")
local IADS = require("src.modules.IADS")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

IADS.removeC2Facilities(config.c.IADS)
IADS.addC2Facilities(config.c.IADS)
IADS.initC2FacilitiesContext(config.c.IADS, saveData.c.IADS)

gKH.State.SaveTableToKey(saveData, "SaveData")
