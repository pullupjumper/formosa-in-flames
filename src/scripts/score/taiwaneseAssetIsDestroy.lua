local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local GnssJamming = require("src.modules.ew.gnssJamming")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore(constants.SIDES.PLAYER)

  if unit.type == constants.UNIT_TYPES.FACILITY then
    if unit.dbid == constants.PLATFORMS.UNDERGROUND_SHELTER then
      GameApi.ScenEdit_SetScore(
        constants.SIDES.PLAYER,
        (score + config.s.undergroundShelterIsDestroyed),
        "Underground shelter has been destoryed"
      )
    elseif unit.dbid == constants.PLATFORMS.AMMO_TRUCK or unit.dbid == constants.PLATFORMS.AMMO then
      local text = unit.dbid == constants.PLATFORMS.AMMO and "ammo revetment." or "ammunition truck."
      MissileSystem.handleSupplyAssetDestruction(unit, saveData.c.ground.mlrs)
      MissileSystem.handleSupplyAssetDestruction(unit, saveData.c.ground.srbm)
      MissileSystem.handleSupplyAssetDestruction(unit, saveData.c.ground.glcm)
      Logger.log("score", "An " .. text .. " has been destoryed.")
    elseif unit.dbid == constants.PLATFORMS.FPS117 or
        unit.dbid == constants.PLATFORMS.TPS43F or
        unit.dbid == constants.PLATFORMS.HR3000 or
        unit.dbid == constants.PLATFORMS.GE592 then
      IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(saveData.t.iads.rocc, "radar", unit)
    elseif unit.dbid == constants.PLATFORMS.CUSTOMED_TK3 or
        unit.dbid == constants.PLATFORMS.PAC3 or
        unit.dbid == constants.PLATFORMS.CUSTOMED_SAM then
      IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(saveData.t.iads.rocc, "sam", unit)
    elseif unit.dbid == constants.PLATFORMS.TC2 or unit.dbid == constants.PLATFORMS.SKY_GUARD then
      IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(saveData.t.iads.taaoc, "sam", unit)
    elseif unit.dbid == constants.PLATFORMS.C2 or unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
      IntegratedAirDefenseSystem.processC2Disruption(saveData.t.iads, unit)
    elseif unit.dbid == constants.PLATFORMS.GPS_JAMMER then
      GnssJamming.removeJammingZoneByName(saveData.t.gnssJamming.jammers, constants.SIDES.PLAYER, unit.name)
    end
  end

  if unit.type == constants.UNIT_TYPES.AIRCRAFT then
    if unit.dbid == constants.PLATFORMS.E2K then
      saveData.t.air.landBased.AEW[unit.guid] = nil
    else
      saveData.t.air.landBased.AC[unit.guid] = nil
    end

    if unit.dbid == constants.PLATFORMS.RC135V then
      saveData.u.sigint.reconAircraft[unit.guid] = nil
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
