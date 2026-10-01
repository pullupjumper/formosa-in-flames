local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local Utils = require("src.utils.utils")
local unit = GameApi.ScenEdit_UnitX()

PersistentState.read(function(saveData)
  if unit and config.red.recon.isTesting then
    for _, entity in ipairs(PersistentState.recon(saveData).queue) do
      if entity.unitGUID == unit.guid then
        local course = Utils.deepCopy(entity.course)
        table.remove(course, 1)
        GameApi.ScenEdit_SetUnit({
          guid = unit.guid,
          latitude = entity.course[2].latitude,
          longitude = entity.course[2].longitude,
          course = course,
        })
      end
    end
  end
end)
