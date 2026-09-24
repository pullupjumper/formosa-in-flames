local PersistentState = require("src.core.persistentState")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.ENEMY)

if not contacts then
  Logger.error("contacts is nil")
  return
end

PersistentState.update(function(saveData)
  StrikePlanner.process(config, saveData, contacts)
end)
