local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if unit and saveData.c.IADS.isActivated then
  if saveData.c.IADS.C2[unit.guid] then
    for _, data in pairs(saveData.c.IADS.C2[unit.guid].radar) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit == nil then goto continue end
      -- local OODA = GetOODA(CONFIG.c.IADS.ratio.C2)
      -- local detect = data.OODA.detection
      -- local target = data.OODA.targeting
      -- actualUnit.OODA = {
      --     detection = detect + OODA.detection,
      --     targeting = target + OODA.targeting,
      --     evasion = OODA.evasion
      -- }
      -- data.currOODA = actualUnit.OODA
      GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
      data.isOutOfComms = true

      ::continue::
    end

    for _, data in pairs(saveData.c.IADS.C2[unit.guid].SAM) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit == nil then goto continue end
      -- local OODA = GetOODA(CONFIG.c.IADS.ratio.C2)
      -- local detect = data.OODA.detection
      -- local target = data.OODA.targeting
      -- actualUnit.OODA = {
      --     detection = detect + OODA.detection,
      --     targeting = target + OODA.targeting,
      --     evasion = OODA.evasion
      -- }
      -- data.currOODA = actualUnit.
      GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
      data.isOutOfComms = true

      ::continue::
    end

    saveData.c.IADS.C2[unit.guid] = nil
  end
end
gKH.State.SaveTableToKey(saveData, "SaveData")
