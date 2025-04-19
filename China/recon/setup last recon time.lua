local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

saveData.c.ground.mlrs.lastReconTime = ScenEdit_CurrentTime()
saveData.c.ground.srbm.lastReconTime = ScenEdit_CurrentTime()
saveData.c.ground.glcm.lastReconTime = ScenEdit_CurrentTime()
gKH.State.SaveTableToKey(saveData, "SaveData")
