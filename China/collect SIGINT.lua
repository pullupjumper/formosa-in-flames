local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

if saveData.u.SIGINT.isActivated then
  HandleSIGINT(saveData, saveData.t.ground.srbm.batteries, true, 'China')
  HandleSIGINT(saveData, saveData.t.ground.glcm.batteries, true, 'China')
  HandleSIGINT(saveData, saveData.t.ground.mlrs.batteries, true, 'China')
  HandleSIGINT(saveData, saveData.t.ground.ascm.batteries, true, 'China')
  HandleSIGINT(saveData, saveData.t.IADS.ROCC, true, 'China')
  HandleSIGINT(saveData, saveData.t.IADS.TAAOC, true, 'China')
end

gKH.State.SaveTableToKey(saveData, "SaveData")
