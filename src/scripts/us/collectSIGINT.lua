local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
  return
end

if saveData.u.SIGINT.isActivated then
  HandleSIGINT(saveData, saveData.c.ground.mlrs.batteries, true)
  HandleSIGINT(saveData, saveData.c.ground.srbm.batteries, true)
  HandleSIGINT(saveData, saveData.c.ground.glcm.batteries, true)
  HandleSIGINT(saveData, saveData.c.IADS.C2, true)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
