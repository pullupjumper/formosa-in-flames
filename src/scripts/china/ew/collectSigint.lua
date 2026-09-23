local PersistentState = require("src.core.persistentState")
local Sigint = require("src.modules.ew.sigint")
local config = require("src.core.config")
local constants = require("src.core.constants")

PersistentState.update(function(saveData)
  if saveData.c.sigint.enabled then
    Sigint.collectSigint(config, saveData.c.sigint, constants.SIDES.ENEMY, true, config.c.sigint,
      saveData.t.ground.srbm.firingUnits,
      saveData.t.ground.glcm.firingUnits,
      saveData.t.ground.mlrs.firingUnits,
      saveData.t.ground.ascm.firingUnits,
      saveData.t.iads.rocc,
      saveData.t.iads.taaoc)
  end
end)
