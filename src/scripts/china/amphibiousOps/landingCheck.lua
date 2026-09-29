local PersistentState = require("src.core.persistentState")
local config = require("src.core.config")
local LandingOps = require("src.modules.landingOps.init")

PersistentState.update(function(saveData)
  LandingOps.process(config, saveData)
end)
