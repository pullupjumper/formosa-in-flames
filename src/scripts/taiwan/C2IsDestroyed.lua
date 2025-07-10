local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local unit = GameApi.ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if unit and saveData.t.IADS.isActivated then
  if saveData.t.IADS.ROCC[unit.guid] then
    for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].radar) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit then
        GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end

    for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].SAM) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit then
        GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end

    saveData.t.IADS.ROCC[unit.guid] = nil
  end

  if saveData.t.IADS.TAAOC[unit.guid] then
    for _, data in pairs(saveData.t.IADS.TAAOC[unit.guid].SAM) do
      local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

      if actualUnit then
        GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
        data.isOutOfComms = true
      end
    end

    saveData.t.IADS.TAAOC[unit.guid] = nil
  end
end
gKH.State.SaveTableToKey(saveData, "SaveData")
