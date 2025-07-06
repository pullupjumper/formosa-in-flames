local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Launcher = require('src.modules.launcher')
local CONFIG = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end


if saveData.t.ground.glcm.isActivated then
  local result = Launcher.isMetWithAmmo(CONFIG, saveData, unit, 'glcm', false)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, false)
  end
end


if saveData.t.ground.mlrs.isActivated then
  local result = Launcher.isMetWithAmmo(CONFIG, saveData, unit, 'mlrs', false)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, false)
  end
end


if saveData.t.ground.srbm.isActivated then
  local result = Launcher.isMetWithAmmo(CONFIG, saveData, unit, 'srbm', false)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, false)
  end
end


if saveData.t.ground.ascm.isActivated then
  local result = Launcher.isMetWithAmmo(CONFIG, saveData, unit, 'ascm', false)

  if result.isMet then
    Launcher.setReloadStartTime(CONFIG, result.battery, unit, false)
  end
end

-- if CONFIG.c.ground.mlrs.isActivated then
--     local result = Launcher.IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'mlrs', true)

--     if result.isMet then
--         Launcher.SetReloadStartTime(CONFIG, result.battery, unit, true)
--     end
-- end

-- if CONFIG.c.ground.srbm.isActivated then
--     local result = Launcher.IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'srbm', true)

--     if result.isMet then
--         Launcher.SetReloadStartTime(CONFIG, result.battery, unit, true)
--     end
-- end

gKH.State.SaveTableToKey(saveData, "SaveData")
