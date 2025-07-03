local gKH = require('src.core.gKH_State_Standalone')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not saveData then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

RemoveC2Facilities()
ADDC2Facilities()
InitC2Facilities(saveData)

gKH.State.SaveTableToKey(saveData, "SaveData")
