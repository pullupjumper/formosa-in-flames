local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  local sigintCtx = PersistentState.sigint(saveData, constants.SIDES.ENEMY)

  if sigintCtx.enabled then
    Sigint.collectSigint(config, sigintCtx, constants.SIDES.ENEMY, true, config.c.sigint,
      PersistentState.sigintEmitters(saveData, constants.SIDES.ENEMY))
  end
end)
