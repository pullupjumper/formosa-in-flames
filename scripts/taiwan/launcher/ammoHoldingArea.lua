local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end


if saveData.t.ground.glcm.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'glcm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end


if saveData.t.ground.mlrs.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'mlrs', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end


if saveData.t.ground.srbm.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'srbm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end


if saveData.t.ground.ascm.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'ascm', false)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, false)
  end
end

-- if CONFIG.c.ground.mlrs.isActivated then
--     local result = IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'mlrs', true)

--     if result.isMet then
--         SetReloadStartTime(result.battery, unit, true)
--     end
-- end

-- if CONFIG.c.ground.srbm.isActivated then
--     local result = IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'srbm', true)

--     if result.isMet then
--         SetReloadStartTime(result.battery, unit, true)
--     end
-- end

gKH.State.SaveTableToKey(saveData, "SaveData")
