local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")

PersistentState.update(function(saveData)
  if saveData.u.sigint.enabled then
    Sigint.collectSigint(config, saveData.u.sigint, "US", true, config.u.sigint,
      saveData.c.ground.mlrs.firingUnits,
      saveData.c.ground.srbm.firingUnits,
      saveData.c.ground.glcm.firingUnits,
      saveData.c.iads.c2)
  end
end)
