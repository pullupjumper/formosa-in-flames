local gKH = require('src.core.gKH_State_Standalone')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local config = require("src.core.constants")
local ShipMovement = require('src.modules.landingOps.shipMovement')
local AmphibiousLogistics = require('src.modules.landingOps.amphibiousLogistics')
local AmphibiousAssault = require('src.modules.landingOps.amphibiousAssault')
local SecondWaveUnloading = require('src.modules.landingOps.secondWaveUnloading')
local UnitStatusUI = require("src.modules.unitStatusUI")
local contacts = GameApi.ScenEdit_GetContacts('China')
local currentTime = GameApi.ScenEdit_CurrentTime()
---@type CMO__SideUnit[]
local filteredShips = GameApi.VP_GetSide({ side = 'China' }):unitsBy(config.unitType.SHIP)
---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

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

if saveData.c.PHIBOP.isShipsStartedMoving and GameUtils.isAfterStartTime(saveData.c.PHIBOP.startTime) then
  local hasIssuedShipMovementOrder = ShipMovement.moveToStagingArea(config, config.c.PHIBOP, saveData, filteredShips)

  if hasIssuedShipMovementOrder then
    saveData.c.PHIBOP.isWaitingForShipArrival = true
    saveData.c.PHIBOP.isShipsStartedMoving = false
  end
end

if saveData.c.PHIBOP.isWaitingForShipArrival then
  local result = AmphibiousLogistics.getUnitsInAnchorageArea(config, config.c.PHIBOP, filteredShips)
  local hasArrived = Utils.getCount(result.units) > 15 and not result.isUnitMoving

  if hasArrived then
    local creatingCompleted = AmphibiousLogistics.createCargoMissions(config.c.PHIBOP)
    local transferingCompleted = AmphibiousLogistics.transferAndAssign(config, config.c.PHIBOP, result.units)
    local hasAssignedAndTransfered = creatingCompleted and transferingCompleted

    if hasAssignedAndTransfered then
      saveData.c.PHIBOP.isWaitingForShipArrival = false
      saveData.c.PHIBOP.isWaitingForAmphibiousAssault = true
      saveData.c.PHIBOP.amphibiousAssaultStartTime = currentTime
      local time = os.date("%Y-%m-%d %H:%M:%S", currentTime)
      table.insert(saveData.c.dynamicOperations.reconSchedule, {
        time = time,
        type = "reconUAV",
        delay = 0,
        executed = false,
        operations = {
          {
            type = "air",
            executed = false,
            template = {
              name = "CAS/N/1",
              targetType = "infantry",
              isFirstWave = true,
              strikeInterval = 0 * 60,
              packages = config.c.packageTemplate.CAS_N_1
            }
          }
        }
      })
    end
  end
end

if saveData.c.PHIBOP.isWaitingForAmphibiousAssault then
  local initialLocations = config.c.PHIBOP.initialLocations
  local elapsedTime = 0
  local amphibiousAssaultStartTime = saveData.c.PHIBOP.amphibiousAssaultStartTime

  if amphibiousAssaultStartTime then
    elapsedTime = currentTime - amphibiousAssaultStartTime
  end

  local contactCount = AmphibiousAssault.countContactsInArea(contacts, initialLocations[1].airLandingZone)
  local isContactCountLessThan = contactCount < initialLocations[1].numOfContactsInAirLandingZone
  local isTimeExceeded = amphibiousAssaultStartTime and elapsedTime >= config.c.PHIBOP.periodOfTime
  local shouldLaunchAmphibiousAssault = isContactCountLessThan or isTimeExceeded

  if shouldLaunchAmphibiousAssault then
    local settingStartTimeCompleted = AmphibiousAssault.setLandingMissionStartTime(config.c.PHIBOP, saveData)
    local settingCoursesCompleted = AmphibiousAssault.setCoursesForLSTs(config, config.c.PHIBOP, filteredShips)
    local hasLaunchedAmphibiousAssault = settingStartTimeCompleted and settingCoursesCompleted

    if hasLaunchedAmphibiousAssault then
      GameApi.ScenEdit_MsgBox("Start air landing", 0)
      saveData.c.PHIBOP.isWaitingForAmphibiousAssault = false
      saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = true
    end
  end
end

if saveData.c.PHIBOP.isWaitingForSecondWaveUnloading then
  local result = UnitStatusUI.countUnitsInEachArea(config)
  local hasEstablishedBeachheads = Utils.getCount(result) > 0 and result['Taoyuan']['ZBD-05'] >= 1

  if hasEstablishedBeachheads then
    local hasStartedSecondWaveUnloading = SecondWaveUnloading.startSecondWaveUnloading(
      config, config.c.PHIBOP, saveData, filteredShips
    )

    if hasStartedSecondWaveUnloading then
      saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = false
    end
  end
end

if saveData.c.PHIBOP.airlandingMissionStartTime ~= nil then
  local elapsedTime = currentTime - saveData.c.PHIBOP.airlandingMissionStartTime
  local isTimeExceeded = elapsedTime >= (3600 * 2)

  if isTimeExceeded then
    local hasTransfered = AmphibiousLogistics.retransferCargos(config, config.c.PHIBOP, filteredShips)

    if hasTransfered then
      saveData.c.PHIBOP.airlandingMissionStartTime = currentTime
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
