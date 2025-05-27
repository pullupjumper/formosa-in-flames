local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")
local contacts = ScenEdit_GetContacts('Taiwan')

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if contacts then
  for _, contact in ipairs(contacts) do
    if unit and unit.guid == contact.actualunitid then
      contact:DropContact()
    end
  end
end

if saveData.c.ground.glcm.isActivated then
  for _, battery in pairs(saveData.c.ground.glcm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        SetStateToHIDE(battery, unit)
      end
    end
  end
end

if saveData.c.ground.mlrs.isActivated then
  for _, battery in pairs(saveData.c.ground.mlrs.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        SetStateToHIDE(battery, unit)
      end
    end
  end
end

if saveData.c.ground.srbm.isActivated then
  for _, battery in pairs(saveData.c.ground.srbm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        SetStateToHIDE(battery, unit)
      end
    end
  end
end

if saveData.c.ground.mrbm.isActivated then
  for _, battery in pairs(saveData.c.ground.mrbm.batteries) do
    if unit then
      if battery.guid == unit.guid and battery.state == CONFIG.batteryState.REPOSITIONING then
        SetStateToHIDE(battery, unit)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
