local gKH = require('src.core.gKH_State_Standalone')
local CONFIG = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")

  if unit.type == 'Facility' then
    if unit.dbid == CONFIG.platformDBID26 then
      GameApi.ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.undergroundShelterIsDestroyed),
        "Underground shelter has been destoryed"
      )
    end

    if unit.dbid == CONFIG.platformDBID50 then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      GameApi.ScenEdit_SpecialMessage('Taiwan', "An ammunition section has been destoryed.")
    end

    if unit.dbid == CONFIG.platformDBID53 then
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
      Launcher.destroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
      GameApi.ScenEdit_SpecialMessage('Taiwan', "An ammunition has been destoryed.")
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
