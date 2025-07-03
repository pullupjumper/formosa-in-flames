local gKH = require('src.core.gKH_State_Standalone')
local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

if unit and saveData.t.IADS.isActivated then
  if saveData.t.IADS.ROCC[unit.guid] then
    for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].radar) do
      local actualUnit = SE_GetUnit({ guid = data.guid })

      if actualUnit then
        -- local OODA = GetOODA(CONFIG.t.IADS.ratio.ROCC)
        -- local detect = data.OODA.detection
        -- local target = data.OODA.targeting
        -- actualUnit.OODA = {
        --     detection = detect + OODA.detection,
        --     targeting = target + OODA.targeting,
        --     evasion = OODA.evasion
        -- }
        -- data.currOODA = actualUnit.OODA
        SE_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end

    for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].SAM) do
      local actualUnit = SE_GetUnit({ guid = data.guid })

      if actualUnit then
        -- local OODA = GetOODA(CONFIG.t.IADS.ratio.ROCC)
        -- local detect = data.OODA.detection
        -- local target = data.OODA.targeting
        -- actualUnit.OODA = {
        --     detection = detect + OODA.detection,
        --     targeting = target + OODA.targeting,
        --     evasion = OODA.evasion
        -- }
        -- data.currOODA = actualUnit.OODA
        SE_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end
  end

  if saveData.t.IADS.TAAOC[unit.guid] then
    for _, data in pairs(saveData.t.IADS.TAAOC[unit.guid].SAM) do
      local actualUnit = SE_GetUnit({ guid = data.guid })

      if actualUnit then
        -- local OODA = GetOODA(CONFIG.t.IADS.ratio.TAAOC)
        -- local detect = data.OODA.detection
        -- local target = data.OODA.targeting
        -- actualUnit.OODA = {
        --     detection = detect + OODA.detection,
        --     targeting = target + OODA.targeting,
        --     evasion = OODA.evasion
        -- }
        -- data.currOODA = actualUnit.OODA
        SE_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end
  end
end
gKH.State.SaveTableToKey(saveData, "SaveData")
