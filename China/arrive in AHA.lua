local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end


if saveData.c.ground.glcm.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'glcm', true)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, true)
  end
end


if saveData.c.ground.mlrs.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'mlrs', true)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, true)
  end
end


if saveData.c.ground.srbm.isActivated then
  local result = IsMetWithAmmo(saveData, unit, 'srbm', true)

  if result.isMet then
    SetReloadStartTime(result.battery, unit, true)
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
