local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

for _, value in ipairs(CONFIG.c.ground.srbm.contingencyRunways) do
  local contact = ScenEdit_GetContact({ side = "China", guid = value.base.guid })
  local runwayContact = ScenEdit_GetContact({ side = "China", guid = value.runway.guid })

  if contact and runwayContact and runwayContact.BDA then
    local runway = SE_GetUnit({ guid = contact.actualunitid })

    if runway then
      local num = #runway.embarkedUnits['Aircraft']

      if num >= 6 then
        -- saveData.c.ground.srbm.packages[2].batchTargetlists[1] = InitTargetList('China', 'STRIKE/RUNWAY/4')
        -- saveData.c.ground.srbm.packages[2].batchTargetlists[2] = InitTargetList('China', 'STRIKE/RUNWAY/5')
        break
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
