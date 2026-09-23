local PersistentState = require("src.core.persistentState")
local config = require("src.core.config")
local CommsJamming = require("src.modules.ew.commsJamming")

PersistentState.update(function(saveData)
  if saveData.c.commsJamming.enabled then
    CommsJamming.processCommsJamming(config.c.commsJamming, saveData)
  end
end)
