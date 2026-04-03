local gKH = require("src.core.gKH_State_Standalone")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local LandingOps = require("src.modules.landingOps.init")
local constants = require("src.core.constants")
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.ENEMY)
local currentTime = GameApi.ScenEdit_CurrentTime()
local filteredShips = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.SHIP)
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not filteredShips then
  Logger.error("filteredShips is nil")
  return
end

if not contacts then
  Logger.error("contacts is nil")
  return
end

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

LandingOps.process(config, saveData, contacts, currentTime, filteredShips)

gKH.State.SaveTableToKey(saveData, "SaveData")
