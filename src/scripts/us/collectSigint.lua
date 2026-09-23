local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")

PersistentState.update(function(saveData)
  local sigintCtx = PersistentState.sigint(saveData, "US")

  if sigintCtx.enabled then
    Sigint.collectSigint(config, sigintCtx, "US", true, config.u.sigint,
      PersistentState.sigintEmitters(saveData, "US"))
  end
end)
