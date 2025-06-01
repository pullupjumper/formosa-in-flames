local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end


saveData.c.recon.temp.H6N = LaunchUnits(
  CONFIG.c.recon.bases.H6N.guid,
  CONFIG.c.recon.courses.H6N,
  1,
  CONFIG.platformDBID76,
  'Aircraft'
)


gKH.State.SaveTableToKey(saveData, "SaveData")
