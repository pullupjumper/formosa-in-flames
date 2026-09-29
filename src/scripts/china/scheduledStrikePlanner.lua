local PersistentState = require("src.core.persistentState")
local config = require("src.core.config")
local StrikePlanner = require("src.modules.strikePlanner.init")

PersistentState.update(function(saveData)
  StrikePlanner.process(config, saveData)
end)
