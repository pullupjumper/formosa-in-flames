local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.PLAYER)
local event = GameApi.ScenEdit_EventX()
local temp = {}
local saveData = gKH.State.LoadTableFromKey("SaveData")

local function setAntiShipMissionStartTime()
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local antiShipStartTime = os.date("%m/%d/%Y %I:%M:%S %p", currentTime)
  local reconStartTime3 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 10 * 60))
  local asuwAgainstACVStartTime = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 40 * 60))
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/SHIP/W/1").starttime = antiShipStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/SHIP/W/2").starttime = reconStartTime3
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/ACV/W").starttime = asuwAgainstACVStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/ACV/PENGHU").starttime = asuwAgainstACVStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "RECON/3").starttime = reconStartTime3
end

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.t.ground.ascm.test.isAntishipMissionActivated == false and contacts ~= nil then
  for _, value in ipairs(contacts) do
    if value:inArea(saveData.t.ground.ascm.test.nai1) and value.typed == 2 then
      table.insert(temp, value)
    end
  end

  if Utils.getCount(temp) > saveData.t.ground.ascm.test.shipNumInNai1 then
    setAntiShipMissionStartTime()
    saveData.t.ground.ascm.test.isAntishipMissionActivated = true
    event.isActive = false
    GameApi.ScenEdit_MsgBox("Launch ANT-SHIP mission", 0)
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
