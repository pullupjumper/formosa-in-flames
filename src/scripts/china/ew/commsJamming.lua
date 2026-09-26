local PersistentState = require("src.core.persistentState")
local config = require("src.core.config")
local CommsJamming = require("src.modules.ew.commsJamming")

PersistentState.update(function(saveData)
  local jammingState = PersistentState.commsJamming(saveData)
  if jammingState.enabled then
    CommsJamming.processCommsJamming(config.c.commsJamming, jammingState)
  end
end)
