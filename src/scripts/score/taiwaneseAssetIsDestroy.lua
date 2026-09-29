local PersistentState = require("src.core.persistentState")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local GnssJamming = require("src.modules.ew.gnssJamming")
local CommsJamming = require("src.modules.ew.commsJamming")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()

PersistentState.update(function(saveData)
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
        MissileSystem.processSupplyAssetDestruction(saveData, unit)
        Logger.log(constants.TAGS.SCORE, "An " .. text .. " has been destoryed.")
      elseif unit.dbid == constants.PLATFORMS.C2 or unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
        IntegratedAirDefenseSystem.processC2Disruption(saveData, unit)
      elseif unit.dbid == constants.PLATFORMS.GPS_JAMMER then
        GnssJamming.processJammerDestruction(config, unit)
      else
        IntegratedAirDefenseSystem.processUnitDestruction(config, saveData, unit)
      end
    end

    if unit.type == constants.UNIT_TYPES.AIRCRAFT then
      CommsJamming.removeDestroyedUnit(saveData, unit)

      if unit.dbid == constants.PLATFORMS.RC135V then
        PersistentState.sigint(saveData, "US").reconAircraft[unit.guid] = nil
      end
    end
  end
end)
