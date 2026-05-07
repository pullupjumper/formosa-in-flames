local gKH = require("src.core.gKH_State_Standalone")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local Utils = require("src.utils.utils")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit and config.c.recon.isTesting then
  for _, entity in ipairs(saveData.c.recon.queue) do
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
