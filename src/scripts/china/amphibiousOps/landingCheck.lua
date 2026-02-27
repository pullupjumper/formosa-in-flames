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

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

---Find an operation descriptor by zone name
---@param operations SBJ__AmphibiousOperationDescriptor[] Operation descriptors to search
---@param name string Zone name to match
---@return SBJ__AmphibiousOperationDescriptor|nil # Matched descriptor, or nil if not found
local function findOperationByName(operations, name)
  for _, op in ipairs(operations) do
    if op.name == name then return op end
  end
  return nil
end

for _, zone in ipairs(config.c.amphibOps.operationalZones) do
  local zoneState = saveData.c.amphibOps.zoneStates[zone.name]
  local operation = findOperationByName(config.c.amphibOps.operations, zone.name)

  if not operation then
    Logger.error(string.format("Operation not found for zone: %s", zone.name))
    goto continue
  end

  -- Phase 1: Fleet movement
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.MOVING and GameUtils.isAfterStartTime(saveData.c.amphibOps.startTime) then
    local done = ShipMovement.moveToStagingArea(config.c.amphibOps, saveData, filteredShips, operation)
    if done then
      zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
    end
  end

  -- Phase 2: Arrival check + logistics loading
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL then
    local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredShips)
    local hasArrived = Utils.getCount(result.units) > zone.arrivalThreshold and not result.isUnitMoving

    if hasArrived then
      local ok = AmphibiousLogistics.createCargoMissions(zone) and
          AmphibiousLogistics.transferAndAssign(zone, result.units)
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT
        zoneState.amphibiousAssaultStartTime = currentTime

        -- Transport aircraft loading: Taoyuan only (temporary)
        if zone.name == "Taoyuan" then
          AmphibiousLogistics.transferAndAssignTransportAircraft(config.c.amphibOps.transportAircraft)
        end

        -- GJ-11 recon mission: Taoyuan only (temporary)
        if zone.name == "Taoyuan" then
          local entry = Utils.deepCopy(config.c.recon.template.GJ11_RECON)
          ---@cast entry SBJ__ReconQueueEntry
          local _, flightTime = GameUtils.calculatePathDistanceAndTime(entry.course, entry.speed)
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
  end

  -- Phase 3: Amphibious assault
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT then
    local contactCount = AmphibiousAssault.countContactsInArea(contacts, operation.airLandingZone)
    local elapsed = currentTime - (zoneState.amphibiousAssaultStartTime or currentTime)
    local shouldLaunch = contactCount < operation.contactThreshold or elapsed >= config.c.amphibOps.periodOfTime

    if shouldLaunch then
      local ok = AmphibiousAssault.setLandingMissionStartTime(zone, zoneState)
          and AmphibiousAssault.setCoursesForLSTs(zone, filteredShips, operation, config.c.amphibOps.sag)
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE
      end
    end
  end

  -- Phase 4: Second wave unloading
  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE then
    local result = UnitStatusUI.countUnitsInEachArea(config)
    local hasBeachhead = result[zone.name] and result[zone.name]["ZBD-05"] >= 1

    if hasBeachhead then
      local ok = SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, filteredShips)
      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.COMPLETED
      end
    end
  end
  ::continue::
end

-- Cargo retransfer
for _, zone in ipairs(config.c.amphibOps.operationalZones) do
  local zoneState = saveData.c.amphibOps.zoneStates[zone.name]
  if zoneState.airlandingMissionStartTime ~= nil then
    local elapsed = currentTime - zoneState.airlandingMissionStartTime
    if elapsed >= (3600 * 2) then
      local ok = AmphibiousLogistics.retransferCargos(zone, filteredShips)
      if ok then
        zoneState.airlandingMissionStartTime = currentTime
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
