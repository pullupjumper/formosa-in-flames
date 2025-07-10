local gKH = require('src.core.gKH_State_Standalone')
local Recon = require('src.modules.strikePlanner.recon')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local CONFIG = require("src.core.constants")

local unit = GameApi.ScenEdit_UnitX()

if not unit then
  return
end

local saveData = gKH.State.LoadTableFromKey("SaveData")


if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit then
  for _, q in ipairs(saveData.c.recon.queue) do
    if q.unitGUID == unit.guid then
      local course = nil

      if q.isTracking then
        course = CONFIG.c.recon.courses.WZ8[2]
      else
        course = CONFIG.c.recon.courses.WZ8[1]
      end

      local wz8 = Recon.launchWZ8(unit, course)

      if wz8 then
        q.unitGUID = wz8.guid
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
