local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local GPSJamming = require("src.modules.EW.GPSJamming")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Aircraft' then
    if unit.condition == 'Parked' and unit.dbid == config.platform.Z_10 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed an helicopter on the ground."
      )
    elseif unit.dbid == config.platform.Y_9DZ then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a recon aircraft."
      )
      saveData.c.SIGINT.RA[unit.guid] = nil
    elseif unit.dbid == config.platform.Y_9 or unit.dbid == config.platform.J_15D then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAircraftOnTheGround),
        "Destroyed a communications jammer."
      )
      saveData.c.commsJamming.jammers[unit.guid] = nil
    elseif unit.dbid == config.platform.WZ_8 or unit.dbid == config.platform.BZK_005 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.uav),
        "Destroyed a recon UAV."
      )
      local type = 'BZK005'

      if unit.dbid == config.platform.WZ_8 then
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
    if unit.dbid == config.platform.PHL_16 or
        unit.dbid == config.platform.PHL_03 or
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
      GPSJamming.turnOffGPSEffectByUnit(config, unit)
    elseif unit.dbid == config.platform.AMMO then
      Launcher.destroyAmmoSecHandler(unit, 'China', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'China', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'China', 'glcm', saveData)
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAmmo),
        "You have destroyed a ammo revetment."
      )
    elseif unit.dbid == config.platform.AMMO_TRUCK then
      Launcher.destroyAmmoSecHandler(unit, 'China', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'China', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'China', 'glcm', saveData)
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + config.s.destroyingAmmoTruck),
        "You have destroyed an ammunition truck."
      )
    else
      for _, DBID in ipairs(config.c.IADS.C2FacilityDBIDs) do
        if unit.dbid == DBID and not saveData.c.IADS.C2[unit.guid] then
          GameApi.ScenEdit_SetScore(
            "Taiwan",
            (score + config.s.destroyingCivilianFacility),
            "Destruction of civilian facilities"
          )
        end
      end
    end
  end

  if unit.type == 'Ground unit' then

  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
