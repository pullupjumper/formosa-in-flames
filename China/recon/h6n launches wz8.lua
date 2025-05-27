local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if unit then
  for _, q in ipairs(saveData.c.recon.queue) do
    if q.unitGUID == unit.guid then
      local course = nil

      if q.isTracking then
        course = CONFIG.c.recon.courses.WZ8[2]
      else
        course = CONFIG.c.recon.courses.WZ8[1]
      end

      local wz8 = LaunchWZ8(unit, course)

      if wz8 then
        q.unitGUID = wz8.guid
      end
    end
  end

  -- local wz8 = LaunchWZ8(unit, CONFIG.c.recon.courses.WZ8)

  -- if wz8 then
  --   for _, q in ipairs(saveData.c.recon.queue) do
  --     if q.unitGUID == unit.guid then
  --       q.unitGUID = wz8.guid
  --     end
  --   end
  -- end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
