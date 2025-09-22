local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local IADS = require("src.modules.IADS")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Facility' then
    if unit.dbid == config.platform.UNDERGROUND_SHELTER then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.undergroundShelterIsDestroyed),
        "Underground shelter has been destoryed"
      )
    elseif unit.dbid == config.platform.AMMO_TRUCK then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      Logger.log("An ammunition section has been destoryed.")
    elseif unit.dbid == config.platform.AMMO then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      Logger.log("An ammunition has been destoryed.")
    elseif unit.dbid == config.platform.FPS117 or
        unit.dbid == config.platform.TPS43F or
        unit.dbid == config.platform.HR3000 or
        unit.dbid == config.platform.GE592 then
      IADS.removeDestroyedUnitDataFromIADS(saveData, 'Taiwan', 'ROCC', 'radar', unit)
    elseif unit.dbid == config.platform.CUSTOMED_TK3 or unit.dbid == config.platform.PAC3 then
      IADS.removeDestroyedUnitDataFromIADS(saveData, 'Taiwan', 'ROCC', 'SAM', unit)
    elseif unit.dbid == config.platform.TC2 or unit.dbid == config.platform.SKY_GUARD then
      IADS.removeDestroyedUnitDataFromIADS(saveData, 'Taiwan', 'TAAOC', 'SAM', unit)
    elseif unit.dbid == config.platform.C2 or unit.dbid == config.platform.BUNKER_SECTOR_CONTROL_STATION then
      IADS.processC2Disruption(saveData, 'Taiwan', unit)
    end
  end

  if unit.type == 'Aircraft' then
    if unit.dbid == config.platform.E2K then
      saveData.t.air.landBased.AEW[unit.guid] = nil
    else
      saveData.t.air.landBased.AC[unit.guid] = nil
    end

    if unit.dbid == config.platform.RC135V then
      saveData.u.SIGINT.RA[unit.guid] = nil
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
