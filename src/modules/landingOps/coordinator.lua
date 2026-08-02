local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local UnitStatusUI = require("src.modules.unitStatusUI")
local MissileSystem = require("src.modules.missileSystem.init")
local Recon = require("src.modules.strikePlanner.recon")
local constants = require("src.core.constants")

local Coordinator = {}

---Phases considered "fleet has arrived at staging waters" for fire support gate
---@type table<string, true>
local ARRIVED_PHASES = {
  [constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT]     = true,
  [constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE] = true,
  [constants.AMPHIBIOUS_PHASES.COMPLETED]           = true,
}

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

---Handle temporary Taoyuan-only loading and reconnaissance setup
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param currentTime number Current scenario time in seconds
local function handleTaoyuanTemporarySetup(config, saveData, zone, currentTime)
  if zone.name ~= "Taoyuan" then
    return
  end

  AmphibiousLogistics.transferAndAssignTransportAircraft(config.c.amphibOps.transportAircraft)
  Recon.insertEntry(saveData.c.recon, config.c.recon.template.GJ11_RECON)
end

---Process a single operational zone through all amphibious phases
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param operation SBJ__AmphibiousOperationDescriptor Operation descriptor for the zone
---@param contacts CMO__Contact[] Contact list from the game
---@param currentTime number Current scenario time in seconds
---@param filteredShips CMO__SideUnit[] Unit list from the side filtered for ships
local function processZone(config, saveData, zone, operation, contacts, currentTime, filteredShips)
  local zoneState = saveData.c.amphibOps.zoneStates[zone.name]

  if zoneState.phase == constants.AMPHIBIOUS_PHASES.MOVING
      and GameUtils.isAfterStartTime(saveData.c.amphibOps.startTime) then
    local done = ShipMovement.moveToStagingArea(config.c.amphibOps, saveData, filteredShips, operation)
    if done then
      zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
    end
  end

  if zoneState.phase == constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL then
    local result = AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredShips)
    local hasArrived = Utils.getCount(result.units) > zone.arrivalThreshold and not result.isUnitMoving

    if hasArrived then
      local ok = AmphibiousLogistics.createCargoMissions(zone)
          and AmphibiousLogistics.transferAndAssign(zone, result.units)

      if ok then
        zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT
        zoneState.amphibiousAssaultStartTime = currentTime
        handleTaoyuanTemporarySetup(config, saveData, zone, currentTime)
      end
    end
  end

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
end

---Handle periodic cargo retransfer for zones with active airlanding missions
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param currentTime number Current scenario time in seconds
---@param filteredShips CMO__SideUnit[] Unit list from the side filtered for ships
local function processCargoRetransfer(config, saveData, currentTime, filteredShips)
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
end

---Process all landing operation phases for the current event tick
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Contact list from the game
---@param currentTime number Current scenario time in seconds
---@param filteredShips CMO__SideUnit[] Unit list from the side filtered for ships
function Coordinator.process(config, saveData, contacts, currentTime, filteredShips)
  for _, zone in ipairs(config.c.amphibOps.operationalZones) do
    local operation = findOperationByName(config.c.amphibOps.operations, zone.name)

    if operation then
      processZone(config, saveData, zone, operation, contacts, currentTime, filteredShips)
    else
      Logger.error(LogFormat.line("ERROR", { zone = zone.name, reason = "operation_not_found" }))
    end
  end

  processCargoRetransfer(config, saveData, currentTime, filteredShips)
  Coordinator.evaluateFireSupportGate(config, saveData)
end

---Check whether all configured operational zones have reached staging waters
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@return boolean # True when every zone's phase is at WAITING_ASSAULT or beyond
local function allZonesArrived(config, saveData)
  for _, zone in ipairs(config.c.amphibOps.operationalZones) do
    local zoneState = saveData.c.amphibOps.zoneStates[zone.name]
    if not zoneState or not ARRIVED_PHASES[zoneState.phase] then
      return false
    end
  end
  return true
end

---Update fireSupportOnHold flag based on SRBM ammo level and fleet arrival status.
---Hold engages when ammo drops below threshold while at least one zone has not yet arrived;
---hold releases unconditionally once every zone reaches WAITING_ASSAULT or later (phase machine
---is monotonic, so the release latches naturally).
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
function Coordinator.evaluateFireSupportGate(config, saveData)
  local amphib = saveData.c.amphibOps
  local arrived = allZonesArrived(config, saveData)

  if amphib.fireSupportOnHold and arrived then
    amphib.fireSupportOnHold = false
    Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT,
      LogFormat.line("RESUME", { scope = "fireSupportGate", reason = "all_zones_at_staging_waters" }))
    return
  end

  if amphib.fireSupportOnHold or arrived then
    return
  end

  local srbmCtx = saveData.c.ground and saveData.c.ground.srbm
  if not srbmCtx then return end

  local report = MissileSystem.getAmmoInventory(srbmCtx, constants.SIDES.ENEMY)
  if report.total.percentage < config.c.amphibOps.fireSupportHoldThreshold then
    amphib.fireSupportOnHold = true
    Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT, LogFormat.line("HOLD", {
      scope = "fireSupportGate",
      reason = "srbm_low",
      total = report.total.percentage,
      threshold = config.c.amphibOps.fireSupportHoldThreshold,
      firing = report.firing.percentage,
      resupply = report.resupply.percentage,
      depot = report.ammo.percentage
    }))
  end
end

return Coordinator
