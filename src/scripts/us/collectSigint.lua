local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")

PersistentState.update(function(saveData)
  Sigint.processSide(config, saveData, "US")
end)
