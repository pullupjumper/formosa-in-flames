gKH = require('src.core.gKH_State_Standalone')
CONFIG = require("src.core.constants")
local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

if unit then
  local score = ScenEdit_GetScore("Taiwan")

  if unit.type == 'Aircraft' then
    if unit.condition == 'Parked' and unit.dbid == CONFIG.platformDBID5 then
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.destroyingAircraftOnTheGround),
        "Destroyed an helicopter on the ground."
      )
    elseif unit.dbid == CONFIG.platformDBID12 or unit.dbid == CONFIG.platformDBID13 then
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.uav),
        "Destroyed a recon UAV."
      )
    end
  end

  if unit.type == 'Ship' then
    if unit.dbid == CONFIG.platformDBID7
        or unit.dbid == CONFIG.platformDBID8
        or unit.dbid == CONFIG.platformDBID9
        or unit.dbid == CONFIG.platformDBID10 then
      ScenEdit_SetScore("Taiwan", (score + CONFIG.s.lst), "You have destroyed a ship (LST).")
    elseif unit.dbid == CONFIG.platformDBID6 then
      ScenEdit_SetScore("Taiwan", (score + CONFIG.s.lhd), "You have destroyed a ship (LHD).")
    elseif unit.dbid == CONFIG.platformDBID11 then
      ScenEdit_SetScore("Taiwan", (score + CONFIG.s.cv), "You have destroyed a carrier.")
    else
      ScenEdit_SetScore("Taiwan", (score + CONFIG.s.ddg), "You have destroyed a ship.")
    end
  end

  if unit.type == 'Submarine' then
    ScenEdit_SetScore(
      "Taiwan",
      (score + CONFIG.s.sub),
      "You have destroyed a submarine."
    )
  end

  if unit.type == 'Facility' then
    if unit.dbid == CONFIG.platformDBID22 or
        unit.dbid == CONFIG.platformDBID24 or
        string.find(unit.name, 'DF') or
        string.find(unit.name, 'CJ') then
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.tel),
        "You have destroyed a TEL."
      )
    elseif unit.dbid == CONFIG.platformDBID25 then
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.tel),
        "You have destroyed a GPS jammer."
      )
      TurnOffGPSEffectByUnit(unit)
    elseif unit.dbid == CONFIG.platformDBID53 then
      DestroyAmmoSecHandler(unit, 'China', 'mlrs', saveData)
      DestroyAmmoSecHandler(unit, 'China', 'srbm', saveData)
      DestroyAmmoSecHandler(unit, 'China', 'glcm', saveData)
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.destroyingAmmo),
        "You have destroyed a ammo revetment."
      )
    elseif unit.dbid == CONFIG.platformDBID50 then
      DestroyAmmoSecHandler(unit, 'China', 'mlrs', saveData)
      DestroyAmmoSecHandler(unit, 'China', 'srbm', saveData)
      DestroyAmmoSecHandler(unit, 'China', 'glcm', saveData)
      ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.destroyingAmmoTruck),
        "You have destroyed an ammunition truck."
      )
    else
      for _, DBID in ipairs(CONFIG.c.IADS.C2FacilityDBIDs) do
        if unit.dbid == DBID and not saveData.c.IADS.C2[unit.guid] then
          ScenEdit_SetScore(
            "Taiwan",
            (score + CONFIG.s.destroyingCivilianFacility),
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
