local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local RunwayRepairment = require("src.modules.runwayRepairment")
local unit = GameApi.ScenEdit_UnitX()

PersistentState.update(function(saveData)
  if unit then
    RunwayRepairment.processRunwayDamage(PersistentState.runwayRepair(saveData, unit.side), unit)
  end
end)
