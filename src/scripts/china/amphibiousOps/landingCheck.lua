local gKH = require("src.core.gKH_State_Standalone")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local config = require("src.core.config")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local UnitStatusUI = require("src.modules.unitStatusUI")
local constants = require("src.core.constants")
local contacts = GameApi.ScenEdit_GetContacts("China")
local currentTime = GameApi.ScenEdit_CurrentTime()
local filteredShips = GameApi.VP_GetSide({ side = "China" }):unitsBy(constants.UNIT_TYPES.SHIP)
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if not filteredShips then
  Logger.error("filteredShips is nil")
  return
end

if not contacts then
  Logger.error("contacts is nil")
  return
end

if not currentTime then
  Logger.error("currentTime is nil")
  return
end

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.c.amphibOps.isShipsStartedMoving and GameUtils.isAfterStartTime(saveData.c.amphibOps.startTime) then
  local hasIssuedShipMovementOrder = ShipMovement.moveToStagingArea(config.c.amphibOps, saveData, filteredShips)

  if hasIssuedShipMovementOrder then
    saveData.c.amphibOps.isWaitingForShipArrival = true
    saveData.c.amphibOps.isShipsStartedMoving = false
  end
end

if saveData.c.amphibOps.isWaitingForShipArrival then
  local result = AmphibiousLogistics.getUnitsInAnchorageArea(config.c.amphibOps, filteredShips)
  local hasArrived = Utils.getCount(result.units) > 15 and not result.isUnitMoving

  if hasArrived then
    local creatingCompleted = AmphibiousLogistics.createCargoMissions(config.c.amphibOps)
    local transferingCompleted = AmphibiousLogistics.transferAndAssign(config.c.amphibOps, result.units)
    local hasAssignedAndTransfered = creatingCompleted and transferingCompleted

    if hasAssignedAndTransfered then
      saveData.c.amphibOps.isWaitingForShipArrival = false
      saveData.c.amphibOps.isWaitingForAmphibiousAssault = true
      saveData.c.amphibOps.amphibiousAssaultStartTime = currentTime
      local entry = Utils.deepCopy(config.c.recon.template.GJ11_RECON)
      ---@cast entry SBJ__ReconQueueEntry
      local distance, flightTime = GameUtils.calculatePathDistanceAndTime(entry.course, entry.speed)
      local endTime = currentTime + flightTime
      entry.takeoffTime = os.date("%Y-%m-%d %H:%M:%S", currentTime) --[[@as string]]
      entry.endTime = os.date("%Y-%m-%d %H:%M:%S", endTime) --[[@as string]]
      entry.hasLaunched = false
      entry.isFinished = false
      entry.trackingTargetGUID = nil
      table.insert(saveData.c.recon.queue, entry)
    end
  end
end

if saveData.c.amphibOps.isWaitingForAmphibiousAssault then
  local operations = config.c.amphibOps.operations
  local elapsedTime = 0
  local amphibiousAssaultStartTime = saveData.c.amphibOps.amphibiousAssaultStartTime

  if amphibiousAssaultStartTime then
    elapsedTime = currentTime - amphibiousAssaultStartTime
  end

  local contactCount = AmphibiousAssault.countContactsInArea(contacts, operations[1].airLandingZone)
  local isContactCountLessThan = contactCount < operations[1].numOfContactsInAirLandingZone
  local isTimeExceeded = amphibiousAssaultStartTime and elapsedTime >= config.c.amphibOps.periodOfTime
  local shouldLaunchAmphibiousAssault = isContactCountLessThan or isTimeExceeded

  if shouldLaunchAmphibiousAssault then
    local settingStartTimeCompleted = AmphibiousAssault.setLandingMissionStartTime(config.c.amphibOps, saveData)
    local settingCoursesCompleted = AmphibiousAssault.setCoursesForLSTs(config.c.amphibOps, filteredShips)
    local hasLaunchedAmphibiousAssault = settingStartTimeCompleted and settingCoursesCompleted

    if hasLaunchedAmphibiousAssault then
      GameApi.ScenEdit_MsgBox("Start air landing", 0)
      saveData.c.amphibOps.isWaitingForAmphibiousAssault = false
      saveData.c.amphibOps.isWaitingForSecondWaveUnloading = true
    end
  end
end

if saveData.c.amphibOps.isWaitingForSecondWaveUnloading then
  local result = UnitStatusUI.countUnitsInEachArea(config)
  local hasEstablishedBeachheads = Utils.getCount(result) > 0 and result["Taoyuan"]["ZBD-05"] >= 1

  if hasEstablishedBeachheads then
    local hasStartedSecondWaveUnloading = SecondWaveUnloading.startSecondWaveUnloading(
      config.c.amphibOps, saveData, filteredShips
    )

    if hasStartedSecondWaveUnloading then
      saveData.c.amphibOps.isWaitingForSecondWaveUnloading = false
    end
  end
end

if saveData.c.amphibOps.airlandingMissionStartTime ~= nil then
  local elapsedTime = currentTime - saveData.c.amphibOps.airlandingMissionStartTime
  local isTimeExceeded = elapsedTime >= (3600 * 2)

  if isTimeExceeded then
    local hasTransfered = AmphibiousLogistics.retransferCargos(config.c.amphibOps, filteredShips)

    if hasTransfered then
      saveData.c.amphibOps.airlandingMissionStartTime = currentTime
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
