local gKH = require("src.core.gKH_State_Standalone")
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local ship = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if not ship then
  Logger.error("ship is nil")
  return
end

LandingOps.offloadVehicles(config.c.amphibOps, saveData, ship)

gKH.State.SaveTableToKey(saveData, "SaveData")
