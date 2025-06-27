gKH = require('src.core.gKH_State_Standalone')
Recon = require('src.modules.strikePlanner.recon')
GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
Utils = require("src.utils.utils")

local unit, err = Utils.SafeCall("GameApi.ScenEdit_UnitX", GameApi.ScenEdit_UnitX)

if not unit then
  Logger.error("Failed to get unit: " .. err)
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

      local wz8 = Recon.LaunchWZ8(unit, course)

      if wz8 then
        q.unitGUID = wz8.guid
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
