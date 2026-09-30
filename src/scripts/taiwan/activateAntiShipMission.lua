local PersistentState = require("src.core.persistentState")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.PLAYER)
local event = GameApi.ScenEdit_EventX()
local temp = {}

local function setAntiShipMissionStartTime()
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local antiShipStartTime = os.date(constants.DATE_FORMAT, currentTime)
  local reconStartTime3 = os.date(constants.DATE_FORMAT, (currentTime + 10 * 60))
  local asuwAgainstACVStartTime = os.date(constants.DATE_FORMAT, (currentTime + 40 * 60))
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/SHIP/W/1").starttime = antiShipStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/SHIP/W/2").starttime = reconStartTime3
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/ACV/W").starttime = asuwAgainstACVStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "ASUW/ACV/PENGHU").starttime = asuwAgainstACVStartTime
  GameApi.ScenEdit_GetMission(constants.SIDES.PLAYER, "RECON/3").starttime = reconStartTime3
end

PersistentState.update(function(saveData)
  local trigger = PersistentState.ground(saveData, constants.SIDES.PLAYER).missileSystemTypes.ascm.test

  if trigger.isAntishipMissionActivated == false and contacts ~= nil then
    for _, value in ipairs(contacts) do
      if value:inArea(trigger.nai1) and value.typed == 2 then
        table.insert(temp, value)
      end
    end

    if Utils.getCount(temp) > trigger.shipNumInNai1 then
      setAntiShipMissionStartTime()
      trigger.isAntishipMissionActivated = true
      event.isActive = false
      GameApi.ScenEdit_MsgBox("Launch ANT-SHIP mission", 0)
    end
  end
end)
