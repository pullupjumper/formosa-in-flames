local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local GPSJamming = require("src.modules.EW.GPSJamming")
local IADS = require("src.modules.IADS")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")
---@type CMO__SideUnit[]
local filteredUnits = GameApi.VP_GetSide({ side = "China" })
    :unitsBy(constants.UNIT_TYPES.FACILITY, constants.FIXED_FACILITY_CATEGORIES.MOBILE_VEHICLE)

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == "Aircraft" then
    if unit.condition == "Parked" and unit.dbid == constants.PLATFORMS.Z10 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed an helicopter on the ground."
      )
    elseif unit.dbid == constants.PLATFORMS.Y9DZ then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a recon aircraft."
      )
      saveData.c.SIGINT.RA[unit.guid] = nil
    elseif unit.dbid == constants.PLATFORMS.Y9 or
        unit.dbid == constants.PLATFORMS.J16D or
        unit.dbid == constants.PLATFORMS.J15D then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a communications jammer."
      )
      saveData.c.commsJamming.jammers[unit.guid] = nil
    elseif unit.dbid == constants.PLATFORMS.WZ8 or
        unit.dbid == constants.PLATFORMS.BZK005 or
        unit.dbid == constants.PLATFORMS.WZ7 or
        unit.dbid == constants.PLATFORMS.GJ11 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.uav),
        "Destroyed a recon UAV."
      )

      -- Remove from reconnaissance queue
      for index, entry in ipairs(saveData.c.recon.queue) do
        if entry.unitGUID == unit.guid then
          saveData.c.recon.queue[index] = nil
        end
      end
    end
  end

  if unit.type == "Ship" then
    if unit.dbid == constants.PLATFORMS.TYPE_071 or
        unit.dbid == constants.PLATFORMS.TYPE_072III or
        unit.dbid == constants.PLATFORMS.TYPE_072A or
        unit.dbid == constants.PLATFORMS.TYPE_073A then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.lst), "You have destroyed a ship (LST).")
    elseif unit.dbid == constants.PLATFORMS.TYPE_075 then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.lhd), "You have destroyed a ship (LHD).")
    elseif unit.dbid == constants.PLATFORMS.TYPE_002 then
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.cv), "You have destroyed a carrier.")
    else
      GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.ddg), "You have destroyed a ship.")
    end
  end

  if unit.type == "Submarine" then
    GameApi.ScenEdit_SetScore(
      "Taiwan",
      (score + config.s.sub),
      "You have destroyed a submarine."
    )
  end

  if unit.type == "Facility" then
    if unit.dbid == constants.PLATFORMS.PHL16 or
        unit.dbid == constants.PLATFORMS.PHL03 or
        string.find(unit.name, "DF") or
        string.find(unit.name, "CJ") then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.tel),
        "You have destroyed a TEL."
      )
    elseif unit.dbid == constants.PLATFORMS.GPS_JAMMER then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.tel),
        "You have destroyed a GPS jammer."
      )
      -- GPSJamming.turnOffGPSEffectByUnit(config, unit)
      GPSJamming.removeJammingZoneByName(saveData.c.GPSJamming.jammers, "China", unit.name)
    elseif unit.dbid == constants.PLATFORMS.AMMO or unit.dbid == constants.PLATFORMS.AMMO_TRUCK then
      local text = unit.dbid == constants.PLATFORMS.AMMO and "ammo revetment." or "ammunition truck."
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.mlrs)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.srbm)
      Launcher.handleSupplyAssetDestruction(unit, saveData.c.ground.glcm)
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAmmo),
        "You have destroyed a " .. text
      )
    elseif unit.dbid == constants.PLATFORMS.HQ22 or
        unit.dbid == constants.PLATFORMS.S300 or
        unit.dbid == constants.PLATFORMS.S400 or
        unit.dbid == constants.PLATFORMS.HQ12 then
      IADS.removeDestroyedUnitContextFromIADS(saveData.c.IADS.C2, "SAM", unit)
      IADS.activateNearestRadar(
        config,
        filteredUnits,
        unit
      )
    elseif unit.dbid == constants.PLATFORMS.JY26 or unit.dbid == constants.PLATFORMS.YLC8B then
      IADS.removeDestroyedUnitContextFromIADS(saveData.c.IADS.C2, "radar", unit)
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
          IADS.processC2Disruption(saveData.c.IADS, unit)
        end
      end
    end
  end

  if unit.type == "Ground unit" then

  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
