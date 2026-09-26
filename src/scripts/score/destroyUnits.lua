local PersistentState = require("src.core.persistentState")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
local GnssJamming = require("src.modules.ew.gnssJamming")
local CommsJamming = require("src.modules.ew.commsJamming")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local filteredUnits = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.FACILITY)

if not filteredUnits then
  Logger.error("filteredUnits is nil")
  return
end

PersistentState.update(function(saveData)
  if unit then
    local score = GameApi.ScenEdit_GetScore(constants.SIDES.PLAYER)

    if unit.type == constants.UNIT_TYPES.AIRCRAFT then
      if unit.condition == "Parked" and unit.dbid == constants.PLATFORMS.Z10 then
        GameApi.ScenEdit_SetScore(
          constants.SIDES.PLAYER,
          (score + config.s.destroyingAircraftOnTheGround),
          "Destroyed an helicopter on the ground."
        )
      elseif unit.dbid == constants.PLATFORMS.Y9DZ then
        GameApi.ScenEdit_SetScore(
          constants.SIDES.PLAYER,
          (score + config.s.destroyingAircraftOnTheGround),
          "Destroyed a recon aircraft."
        )
        PersistentState.sigint(saveData, constants.SIDES.ENEMY).reconAircraft[unit.guid] = nil
      elseif unit.dbid == constants.PLATFORMS.Y9 or
          unit.dbid == constants.PLATFORMS.J16D or
          unit.dbid == constants.PLATFORMS.J15D then
        GameApi.ScenEdit_SetScore(
          constants.SIDES.PLAYER,
          (score + config.s.destroyingAircraftOnTheGround),
          "Destroyed a communications jammer."
        )
        CommsJamming.removeDestroyedUnit(PersistentState.commsJamming(saveData), unit.guid)
      elseif unit.dbid == constants.PLATFORMS.WZ8 or
          unit.dbid == constants.PLATFORMS.BZK005 or
          unit.dbid == constants.PLATFORMS.WZ7 or
          unit.dbid == constants.PLATFORMS.GJ11 then
        GameApi.ScenEdit_SetScore(
          constants.SIDES.PLAYER,
          (score + config.s.uav),
          "Destroyed a recon UAV."
        )

        -- Remove from reconnaissance queue
        -- for index, entry in ipairs(saveData.c.recon.queue) do
        --   if entry.unitGUID == unit.guid then
        --     saveData.c.recon.queue[index] = nil
        --   end
        -- end
      end
    end

    if unit.type == constants.UNIT_TYPES.SHIP then
      if unit.dbid == constants.PLATFORMS.TYPE_071 or
          unit.dbid == constants.PLATFORMS.TYPE_072III or
          unit.dbid == constants.PLATFORMS.TYPE_072A or
          unit.dbid == constants.PLATFORMS.TYPE_073A then
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.lst), "You have destroyed a ship (LST).")
      elseif unit.dbid == constants.PLATFORMS.TYPE_075 then
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.lhd), "You have destroyed a ship (LHD).")
      elseif unit.dbid == constants.PLATFORMS.TYPE_002 then
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.cv), "You have destroyed a carrier.")
      else
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.ddg), "You have destroyed a ship.")
      end
    end

    if unit.type == constants.UNIT_TYPES.SUBMARINE then
      GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.sub), "You have destroyed a submarine.")
    end

    if unit.type == constants.UNIT_TYPES.FACILITY then
      local iads = PersistentState.iads(saveData, constants.SIDES.ENEMY)

      if unit.dbid == constants.PLATFORMS.PHL16 or
          unit.dbid == constants.PLATFORMS.PHL03 or
          string.find(unit.name, "DF") or
          string.find(unit.name, "CJ") then
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.tel), "You have destroyed a TEL.")
      elseif unit.dbid == constants.PLATFORMS.GPS_JAMMER then
        GameApi.ScenEdit_SetScore(constants.SIDES.PLAYER, (score + config.s.tel), "You have destroyed a GPS jammer.")
        -- GPSJamming.turnOffGPSEffectByUnit(config, unit)
        GnssJamming.removeJammingZoneByName(PersistentState.gnssJammers(saveData, constants.SIDES.ENEMY), constants.SIDES.ENEMY, unit.name)
      elseif unit.dbid == constants.PLATFORMS.AMMO or unit.dbid == constants.PLATFORMS.AMMO_TRUCK then
        local text = unit.dbid == constants.PLATFORMS.AMMO and "ammo revetment." or "ammunition truck."
        MissileSystem.processSupplyAssetDestruction(unit, PersistentState.groundForces(saveData, constants.SIDES.ENEMY))
        GameApi.ScenEdit_SetScore(
          constants.SIDES.PLAYER,
          (score + config.s.destroyingAmmo),
          "You have destroyed a " .. text
        )
      elseif IntegratedAirDefenseSystem.isPLASAM(unit.dbid) then
        IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(iads.c2, "sam", unit)
        IntegratedAirDefenseSystem.activateNearestRadar(config, filteredUnits, unit)
      elseif unit.dbid == constants.PLATFORMS.JY26 or unit.dbid == constants.PLATFORMS.YLC8B then
        IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(iads.c2, "radar", unit)
        IntegratedAirDefenseSystem.activateNearestRadar(config, filteredUnits, unit)
      else
        for _, dbid in ipairs(config.c.iads.c2FacilityDBIDs) do
          if unit.dbid == dbid and not iads.c2[unit.guid] then
            GameApi.ScenEdit_SetScore(
              constants.SIDES.PLAYER,
              (score + config.s.destroyingCivilianFacility),
              "Destruction of civilian facilities"
            )
          elseif unit.dbid == dbid and iads.c2[unit.guid] then
            IntegratedAirDefenseSystem.processC2Disruption(iads, unit)
          end
        end
      end
    end

    if unit.type == "Ground unit" then

    end
  end
end)
