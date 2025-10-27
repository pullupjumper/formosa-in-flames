local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local GPSJamming = require("src.modules.EW.GPSJamming")
local IADS = require("src.modules.IADS")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")
---@type CMO__SideUnit[]
local filteredUnits = GameApi.VP_GetSide({ side = 'China' })
    :unitsBy(config.unitType.FACILITY, tostring(config.fixedFacilityCategory.MOBILE_VEHICLE))

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Aircraft' then
    if unit.condition == 'Parked' and unit.dbid == config.platform.Z10 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed an helicopter on the ground."
      )
    elseif unit.dbid == config.platform.Y9DZ then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a recon aircraft."
      )
      saveData.c.SIGINT.RA[unit.guid] = nil
    elseif unit.dbid == config.platform.Y9 or unit.dbid == config.platform.J15D then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a communications jammer."
      )
      saveData.c.commsJamming.jammers[unit.guid] = nil
    elseif unit.dbid == config.platform.WZ8 or unit.dbid == config.platform.BZK005 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.uav),
        "Destroyed a recon UAV."
      )
      local type = 'BZK005'

      if unit.dbid == config.platform.WZ8 then
        type = 'WZ8'
      end

      for _, value in pairs(saveData.c.recon.temp[type]) do
        if value.guid == unit.guid then
          saveData.c.recon.temp[type][value.guid] = nil
        end
      end

      for index, q in ipairs(saveData.c.recon.queue) do
        if q.unitGUID == unit.guid then
          saveData.c.recon.queue[index] = nil
        end
      end
    end
  end

  if unit.type == 'Ship' then
    if unit.dbid == config.platform.TYPE_071
        or unit.dbid == config.platform.TYPE_072III
        or unit.dbid == config.platform.TYPE_072A
        or unit.dbid == config.platform.TYPE_073A then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.lst), "You have destroyed a ship (LST).")
    elseif unit.dbid == config.platform.TYPE_075 then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.lhd), "You have destroyed a ship (LHD).")
    elseif unit.dbid == config.platform.TYPE_002 then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.cv), "You have destroyed a carrier.")
    else
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.ddg), "You have destroyed a ship.")
    end
  end

  if unit.type == 'Submarine' then
    GameApi.ScenEdit_SetScore(
      "Taiwan",
      (score + config.s.sub),
      "You have destroyed a submarine."
    )
  end

  if unit.type == 'Facility' then
    if unit.dbid == config.platform.PHL16 or
        unit.dbid == config.platform.PHL03 or
        string.find(unit.name, 'DF') or
        string.find(unit.name, 'CJ') then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.tel),
        "You have destroyed a TEL."
      )
    elseif unit.dbid == config.platform.GPS_JAMMER then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.tel),
        "You have destroyed a GPS jammer."
      )
      -- GPSJamming.turnOffGPSEffectByUnit(config, unit)
      GPSJamming.removeJammingZoneByName(saveData.c.GPSJamming.jammers, 'China', unit.name)
    elseif unit.dbid == config.platform.AMMO then
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.mlrs)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.srbm)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.glcm)
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAmmo),
        "You have destroyed a ammo revetment."
      )
    elseif unit.dbid == config.platform.AMMO_TRUCK then
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.mlrs)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.srbm)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.glcm)
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAmmoTruck),
        "You have destroyed an ammunition truck."
      )
    elseif unit.dbid == config.platform.HQ22 or
        unit.dbid == config.platform.S300 or
        unit.dbid == config.platform.S400 or
        unit.dbid == config.platform.HQ12 then
      IADS.removeDestroyedUnitDataFromIADS(saveData, 'China', 'C2', 'SAM', unit)
      IADS.activateNearestRadar(
        config,
        filteredUnits,
        unit
      )
    elseif unit.dbid == config.platform.JY26 or unit.dbid == config.platform.YLC8B then
      IADS.removeDestroyedUnitDataFromIADS(saveData, 'China', 'C2', 'radar', unit)
      IADS.activateNearestRadar(
        config,
        filteredUnits,
        unit
      )
    else
      for _, DBID in ipairs(config.c.IADS.C2FacilityDBIDs) do
        if unit.dbid == DBID and not saveData.c.IADS.C2[unit.guid] then
          GameApi.ScenEdit_SetScore(
            "Taiwan",
            (score + config.s.destroyingCivilianFacility),
            "Destruction of civilian facilities"
          )
        elseif unit.dbid == DBID and saveData.c.IADS.C2[unit.guid] then
          IADS.processC2Disruption(saveData, 'China', unit)
        end
      end
    end
  end

  if unit.type == 'Ground unit' then

  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
