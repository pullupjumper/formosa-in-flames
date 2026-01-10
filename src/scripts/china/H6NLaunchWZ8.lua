local gKH = require("src.core.gKH_State_Standalone")
local Recon = require("src.modules.strikePlanner.recon")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not unit then
  Logger.error("unit is nil")
  return
end

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit then
  for _, entry in ipairs(saveData.c.recon.queue) do
    if entry.unitGUID == unit.guid then
      local course = nil
      course = constants.COURSES.WZ8
      local wz8 = Recon.launchWZ8(unit, course)

      if wz8 then
        entry.unitGUID = wz8.guid
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
