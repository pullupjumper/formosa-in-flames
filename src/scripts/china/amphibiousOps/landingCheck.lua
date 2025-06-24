GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall
ShipMovement = require('src.modules.landingOps.shipMovement')
AmphibiousLogistics = require('src.modules.landingOps.amphibiousLogistics')
AmphibiousAssault = require('src.modules.landingOps.amphibiousAssault')
SecondWaveUnloading = require('src.modules.landingOps.secondWaveUnloading')
CountUnitsInEachArea = require('src.modules.unitStatusUI').CountUnitsInEachArea

local contacts, err = SafeCall("GameApi.ScenEdit_GetContacts", GameApi.ScenEdit_GetContacts, 'China')

if not contacts then
  Logger.error("Error in ScenEdit_GetContacts: " .. err)
  return
end

local currentTime, err = SafeCall("GameApi.ScenEdit_CurrentTime", GameApi.ScenEdit_CurrentTime)

if not currentTime then
  Logger.error("Error in ScenEdit_CurrentTime: " .. err)
  return
end

local side, err = SafeCall("GameApi.VP_GetSide", GameApi.VP_GetSide, { side = 'China' })

if not side then
  Logger.error("Error in VP_GetSide: " .. err)
  return
end

local units = side.units

---@type SBJ__SaveData
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

-- local function retransferCargos(saveData)
--   local operationalZones = CONFIG.c.PHIBOP.operationalZones
--   local elapsedTime = ScenEdit_CurrentTime() - saveData.c.PHIBOP.airlandingMissionStartTime

--   if elapsedTime >= (3600 * 2) then
--     for _, zone in ipairs(operationalZones) do
--       for _, item in ipairs(units) do
--         local unit = SE_GetUnit({ guid = item.guid })

--         if unit and (unit.dbid == CONFIG.platformDBID6 or unit.dbid == CONFIG.platformDBID54) then
--           TransferCargo(
--             unit.guid,
--             'Boats',
--             zone.boat.dbid,
--             zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
--             zone.boat.cargoItemsForTransfer.type075[1].cargoItems
--           )
--           TransferCargo(
--             unit.guid,
--             'Aircraft',
--             zone.tansportHelicopter.dbid,
--             zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
--             zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
--           )
--           TransferCargo(
--             unit.guid,
--             'Aircraft',
--             zone.tansportHelicopter.dbid,
--             zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
--             zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
--           )
--         end

--         if unit and unit.dbid == CONFIG.platformDBID7 then
--           TransferCargo(
--             unit.guid,
--             'Boats',
--             zone.boat.dbid,
--             zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
--             zone.boat.cargoItemsForTransfer.type071[1].cargoItems
--           )
--           TransferCargo(
--             unit.guid,
--             'Aircraft',
--             zone.tansportHelicopter.dbid,
--             zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
--             zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
--           )
--         end
--       end
--     end
--   end
-- end


if saveData.c.PHIBOP.isShipsStartedMoving and IsAfterStartTime(saveData.c.PHIBOP.startTime) then
  local hasIssuedShipMovementOrder = ShipMovement.MoveToStagingArea(saveData, CONFIG, units)

  if hasIssuedShipMovementOrder then
    saveData.c.PHIBOP.isWaitingForShipArrival = true
    saveData.c.PHIBOP.isShipsStartedMoving = false
  end
end

if saveData.c.PHIBOP.isWaitingForShipArrival then
  local result = AmphibiousLogistics.GetUnitsInAnchorageArea(CONFIG, units)
  local hasArrived = GetCount(result.units) > 15 and not result.isUnitMoving

  if hasArrived then
    local creatingCompleted = AmphibiousLogistics.CreateCargoMissions(CONFIG)
    local transferingCompleted = AmphibiousLogistics.TransferAndAssign(CONFIG, result.units)
    local hasAssignedAndTransfered = creatingCompleted and transferingCompleted

    if hasAssignedAndTransfered then
      saveData.c.PHIBOP.isWaitingForShipArrival = false
      saveData.c.PHIBOP.isWaitingForAmphibiousAssault = true
      saveData.c.PHIBOP.amphibiousAssaultStartTime = currentTime
      saveData.c.air.ATO['CAS/N/1'].isActivated = true
    end
  end
end

if saveData.c.PHIBOP.isWaitingForAmphibiousAssault then
  local initialLocations = CONFIG.c.PHIBOP.initialLocations
  local elapsedTime = 0
  local amphibiousAssaultStartTime = saveData.c.PHIBOP.amphibiousAssaultStartTime

  if amphibiousAssaultStartTime then
    elapsedTime = currentTime - amphibiousAssaultStartTime
  end

  local contactCount = AmphibiousAssault.CountContactsInArea(contacts, initialLocations[1].airLandingZone)
  local isContactCountLessThan = contactCount < initialLocations[1].numOfContactsInAirLandingZone
  local isTimeExceeded = amphibiousAssaultStartTime and elapsedTime >= CONFIG.c.PHIBOP.periodOfTime
  local shouldLaunchAmphibiousAssault = isContactCountLessThan or isTimeExceeded

  if shouldLaunchAmphibiousAssault then
    local settingStartTimeCompleted = AmphibiousAssault.SetLandingMissionStartTime(CONFIG, saveData)
    local settingCoursesCompleted = AmphibiousAssault.SetCoursesForLSTs(CONFIG, units)
    local hasLaunchedAmphibiousAssault = settingStartTimeCompleted and settingCoursesCompleted

    if hasLaunchedAmphibiousAssault then
      local result, err = SafeCall("GameApi.ScenEdit_MsgBox", GameApi.ScenEdit_MsgBox, "Start air landing", 0)

      if not result then
        Logger.error("Error in ScenEdit_MsgBox: " .. err)
      end

      saveData.c.PHIBOP.isWaitingForAmphibiousAssault = false
      saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = true
    end
  end
end

if saveData.c.PHIBOP.isWaitingForSecondWaveUnloading then
  local result = CountUnitsInEachArea()
  local hasEstablishedBeachheads = GetCount(result) > 0 and result['Taoyuan']['ZBD-05'] >= 1

  if hasEstablishedBeachheads then
    local hasStartedSecondWaveUnloading = SecondWaveUnloading.StartSecondWaveUnloading(CONFIG, saveData, units)

    if hasStartedSecondWaveUnloading then
      saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = false
    end
  end
end

if saveData.c.PHIBOP.airlandingMissionStartTime ~= nil then
  local elapsedTime = currentTime - saveData.c.PHIBOP.airlandingMissionStartTime
  local isTimeExceeded = elapsedTime >= (3600 * 2)

  if isTimeExceeded then
    local hasTransfered = AmphibiousLogistics.RetransferCargos(CONFIG, units)

    if hasTransfered then
      saveData.c.PHIBOP.airlandingMissionStartTime = currentTime
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
--OnPlottedCourse OnFerryMission RTB_Manual Tasked Unassigned
