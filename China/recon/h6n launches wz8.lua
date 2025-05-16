local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if unit then
  local wz8 = LaunchWZ8(unit, CONFIG.c.recon.courses.WZ8)

  if wz8 then
    -- saveData.c.recon.temp.WZ8 = { { unit = wz8.guid } }
    for _, q in ipairs(saveData.c.recon.queue) do
      if q.unitGUID == unit.guid then
        q.unitGUID = wz8.guid
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
