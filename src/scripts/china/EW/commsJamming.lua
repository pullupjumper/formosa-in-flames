local gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")
local CONFIG = require("src.core.constants")
local Logger = require("src.utils.logger")
local CommsJamming = require("src.modules.commsJamming")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end


if saveData.c.commsJamming.isActivated then
  -- local jammerTemp = nil
  -- local jammedNum = 0

  -- for _, jammer in ipairs(saveData.c.commsJamming.jammers) do
  --   local actualJammer = SE_GetUnit({ guid = jammer.guid })

  --   if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
  --     jammerTemp = actualJammer
  --     break
  --   end
  -- end

  -- local unitTemp = {}

  -- for key, item in pairs(saveData.t.IADS.ROCC) do
  --   for _, value in pairs(item.SAM) do
  --     unitTemp[value.guid] = value
  --   end
  --   for _, value in pairs(item.radar) do
  --     unitTemp[value.guid] = value
  --   end
  -- end

  -- for key, item in pairs(saveData.t.IADS.TAAOC) do
  --   for _, value in pairs(item.SAM) do
  --     unitTemp[value.guid] = value
  --   end
  -- end

  -- if jammerTemp then
  --   table.sort(unitTemp, function(a, b)
  --     local da = Tool_Range(jammerTemp.guid, a.guid)
  --     local db = Tool_Range(jammerTemp.guid, b.guid)
  --     return da < db
  --   end)
  -- end

  -- for _, affectedUnit in pairs(unitTemp) do
  --   jammedNum = commsJamming(affectedUnit, jammerTemp, jammedNum)
  -- end

  -- for _, AC in pairs(saveData.t.air.landBased.AC) do
  --   local actualAC = GameApi.ScenEdit_GetUnit(AC.guid)

  --   if actualAC and actualAC.condition == 'Airborne' then
  --     AC.commsLevel = AC.commsBase + getCommsLevel(saveData, actualAC.guid)

  --     if AC.commsLevel < AC.commsThreshold then
  --       GameApi.ScenEdit_SetUnit({ guid = AC.guid, outofcomms = true, RTB = true })
  --     end
  --   end
  -- end
  CommsJamming.handleCommsJamming(CONFIG, saveData)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
