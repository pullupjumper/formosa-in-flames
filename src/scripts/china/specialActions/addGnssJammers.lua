local GnssJamming = require("src.modules.ew.gnssJamming")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local constants = require("src.core.constants")
local gKH = require("src.core.gKH_State_Standalone")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  Logger.error("saveData is nil")
  return
end

GnssJamming.removeJammers(config.c.gnssJamming.jammers, constants.SIDES.ENEMY)
GnssJamming.addGnssJammers(config.c.gnssJamming.jammers, constants.SIDES.ENEMY)
