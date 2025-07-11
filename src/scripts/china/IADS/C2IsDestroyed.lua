local gKH = require('src.core.gKH_State_Standalone')
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error('saveData is nil')
  return
end

if unit and saveData.c.IADS.isActivated then
  if saveData.c.IADS.C2[unit.guid] then
    for _, data in pairs(saveData.c.IADS.C2[unit.guid].radar) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit == nil then goto continue end
      GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
      data.isOutOfComms = true

      ::continue::
    end

    for _, data in pairs(saveData.c.IADS.C2[unit.guid].SAM) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit == nil then goto continue end
      GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
      data.isOutOfComms = true

      ::continue::
    end

    saveData.c.IADS.C2[unit.guid] = nil
  end
end
gKH.State.SaveTableToKey(saveData, "SaveData")
