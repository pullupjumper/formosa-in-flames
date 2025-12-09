local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local IADS = require("src.modules.IADS")
local GPSJamming = require("src.modules.EW.GPSJamming")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Facility' then
    if unit.dbid == constants.PLATFORMS.UNDERGROUND_SHELTER then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.undergroundShelterIsDestroyed),
        "Underground shelter has been destoryed"
      )
    elseif unit.dbid == constants.PLATFORMS.AMMO_TRUCK or unit.dbid == constants.PLATFORMS.AMMO then
      local text = unit.dbid == constants.PLATFORMS.AMMO and "ammo revetment." or "ammunition truck."
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.mlrs)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.srbm)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.glcm)
      Logger.log("score", "An " .. text .. " has been destoryed.")
    elseif unit.dbid == constants.PLATFORMS.FPS117 or
        unit.dbid == constants.PLATFORMS.TPS43F or
        unit.dbid == constants.PLATFORMS.HR3000 or
        unit.dbid == constants.PLATFORMS.GE592 then
      IADS.removeDestroyedUnitContextFromIADS(saveData.t.IADS.ROCC, 'radar', unit)
    elseif unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 or unit.dbid == constants.PLATFORMS.PAC3 then
      IADS.removeDestroyedUnitContextFromIADS(saveData.t.IADS.ROCC, 'SAM', unit)
    elseif unit.dbid == constants.PLATFORMS.TC2 or unit.dbid == constants.PLATFORMS.SKY_GUARD then
      IADS.removeDestroyedUnitContextFromIADS(saveData.t.IADS.TAAOC, 'SAM', unit)
    elseif unit.dbid == constants.PLATFORMS.C2 or unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
      IADS.processC2Disruption(saveData.t.IADS, unit)
    elseif unit.dbid == constants.PLATFORMS.GPS_JAMMER then
      GPSJamming.removeJammingZoneByName(saveData.t.GPSJamming.jammers, 'Taiwan', unit.name)
    end
  end

  if unit.type == 'Aircraft' then
    if unit.dbid == constants.PLATFORMS.E2K then
      saveData.t.air.landBased.AEW[unit.guid] = nil
    else
      saveData.t.air.landBased.AC[unit.guid] = nil
    end

    if unit.dbid == constants.PLATFORMS.RC135V then
      saveData.u.SIGINT.RA[unit.guid] = nil
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
