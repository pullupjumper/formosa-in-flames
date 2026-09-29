local PersistentState = require("src.core.persistentState")
local config = require("src.core.config")
local CommsJamming = require("src.modules.ew.commsJamming")

PersistentState.update(function(saveData)
  CommsJamming.process(config, saveData)
end)
