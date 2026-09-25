local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  Sigint.processSide(config, saveData, constants.SIDES.ENEMY)
end)
