local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Facility' then
    if unit.dbid == config.platformDBID26 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.undergroundShelterIsDestroyed),
        "Underground shelter has been destoryed"
      )
    end

    if unit.dbid == config.platformDBID50 then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      Logger.log("An ammunition section has been destoryed.")
    end

    if unit.dbid == config.platformDBID53 then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      Logger.log("An ammunition has been destoryed.")
    end
  end

  if unit.type == 'Aircraft' then
    if unit.dbid == config.platformDBID38 then
      saveData.t.air.landBased.AEW[unit.guid] = nil
    else
      saveData.t.air.landBased.AC[unit.guid] = nil
    end

    if unit.dbid == config.platformDBID45 then
      saveData.u.SIGINT.RA[unit.guid] = nil
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
