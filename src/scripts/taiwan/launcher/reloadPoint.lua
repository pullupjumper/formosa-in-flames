gKH = require('src.core.gKH_State_Standalone')
local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end


if saveData.t.ground.mlrs.isActivated then
  local result = IsMetWithAmmoTrucks(saveData, unit, 'mlrs', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end

if saveData.t.ground.glcm.isActivated then
  local result = IsMetWithAmmoTrucks(saveData, unit, 'glcm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end

if saveData.t.ground.srbm.isActivated then
  local result = IsMetWithAmmoTrucks(saveData, unit, 'srbm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end

if saveData.t.ground.ascm.isActivated then
  local result = IsMetWithAmmoTrucks(saveData, unit, 'ascm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
