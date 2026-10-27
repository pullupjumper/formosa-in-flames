local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local AcvWave = require("src.modules.landingOps.acvWave")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local FireSupportGate = require("src.modules.landingOps.fireSupportGate")
local HeliWave = require("src.modules.landingOps.heliWave")
local Hovercraft = require("src.modules.landingOps.hovercraft")
local MineClearing = require("src.modules.landingOps.mineClearing")
local ObstacleClearing = require("src.modules.landingOps.obstacleClearing")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local MissileSystem = require("src.modules.missileSystem.init")
local StrikePlanner = require("src.modules.strikePlanner.init")

local Coordinator = {}

-- ============================================================================
-- Helpers
-- ============================================================================

---Airlift the zone's land-based transport aircraft and queue its recon flight
---@param config SBJ__Config
---@param landingState SBJ__LandingOpsState
---@param zone SBJ__OperationalZoneDescriptor
local function startZoneAirSetup(config, landingState, zone)
  if zone.air.transportAircraft then
    AmphibiousLogistics.transferAndAssignTransportAircraft(zone.air.transportAircraft)
  end
  if zone.air.reconTemplate then
    StrikePlanner.addReconEntry(landingState.recon, config.red.recon.templates[zone.air.reconTemplate])
  end
end

---MOVING: sail to the holding areas after the operation start time
---@type SBJ__PhaseStep
local function stepMoving(tickCtx, zone, zoneState)
  local config = tickCtx.config
  if not GameUtils.isAfterStartTime(config.red.triggers.amphibiousOps.startTime) then
    return
  end

  local done = ShipMovement.moveToHoldingAreas(
    zone,
    tickCtx.landingState.amphibOps.calculationResult,
    tickCtx.filteredShips,
    config.red.amphibOps
  )
  if done then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
  end
end

---WAITING_ARRIVAL: when all ships settled in the holding areas, create the cargo missions and load
---@type SBJ__PhaseStep
local function stepWaitingArrival(tickCtx, zone, zoneState)
  local result = AmphibiousLogistics.getUnitsInHoldingAreas(zone, tickCtx.filteredShips)
  local hasArrived = #result.units > zone.movement.arrivalThreshold and not result.isUnitMoving
  if not hasArrived then
    return
  end

  local ok = AmphibiousLogistics.createCargoMissions(zone) and AmphibiousLogistics.transferAndAssign(zone, result.units)
  if ok then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT
    zoneState.amphibiousAssaultStartTime = tickCtx.currentTime
    startZoneAirSetup(tickCtx.config, tickCtx.landingState, zone)
  end
end

---WAITING_ASSAULT: launch when the enemy contacts thin out, the wait times out, or fast-forward applies
---@type SBJ__PhaseStep
local function stepWaitingAssault(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  local contactCount = AmphibiousAssault.countContactsInArea(tickCtx.contacts, zone.air.landingZone)
  local elapsed = tickCtx.currentTime - (zoneState.amphibiousAssaultStartTime or tickCtx.currentTime)
  local shouldLaunch = contactCount < zone.air.contactThreshold or
      elapsed >= amphibOps.periodSec or
      DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT)
  if not shouldLaunch then
    return
  end

  -- Lay this zone's mines first so the fast-forward sweep in startMineClearing has mines to remove
  if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
    MineClearing.createMinefields(amphibOps, zone.name)
  end

  if MineClearing.startMineClearing(amphibOps, zone, zoneState, tickCtx.filteredShips) then
    AmphibiousAssault.recordLandingStartTime(zoneState)
    zoneState.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING
  end
end

---MINE_CLEARING: when the lanes are cleared, pair the assault boats and move the ships to the launch stations
---@type SBJ__PhaseStep
local function stepMineClearing(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  if not MineClearing.updateMineClearing(amphibOps, zoneState) then
    return
  end

  local ok = AssaultBoat.pairBoats(zone, zoneState, tickCtx.filteredShips) and
      AmphibiousAssault.moveToLaunchStations(amphibOps, zone, tickCtx.filteredShips)
  if ok then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT
    HeliWave.schedule(tickCtx, zone, zoneState)
  end
end

---BOAT_ASSAULT: launch boats every tick. When all boats arrive, start obstacle clearing
---@type SBJ__PhaseStep
local function stepBoatAssault(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  AssaultBoat.launchBoats(amphibOps, zone, zoneState)

  if AssaultBoat.updateBoats(amphibOps, zoneState) and
      ObstacleClearing.startObstacleClearing(amphibOps, zone, zoneState, tickCtx.currentTime) then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING
  end
end

---OBSTACLE_CLEARING: when the obstacles are cleared, go to assault landing
---@type SBJ__PhaseStep
local function stepObstacleClearing(tickCtx, zone, zoneState)
  if ObstacleClearing.updateObstacleClearing(tickCtx.config.red.amphibOps, zoneState, tickCtx.currentTime) then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
  end
end

---ASSAULT_LANDING: the beachhead is held once the zone's own force size (ZBD-05 + ZTD-05) has landed
---@type SBJ__PhaseStep
local function stepAssaultLanding(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  local counts = AmphibiousAssault.countUnitsInEachArea(amphibOps.zones)[zone.name]
  local landedVehicles = 0
  for _, acvType in ipairs(AmphibiousAssault.ACV_TYPES) do
    landedVehicles = landedVehicles + (counts and counts[acvType.name] or 0)
  end
  local hasBeachhead = landedVehicles >= zone.landing.beachheadVehicles
  if hasBeachhead then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING
  end
end

---Check if every ship and craft on the deploy line has released its ACVs, hovercraft and boats
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return boolean # True if no ACV, hovercraft or boat is left on the deploy line
local function isDeployLineReleased(tickCtx, zone, zoneState)
  return not AmphibiousAssault.hasUnreleasedACV(zone, tickCtx.filteredShips) and
      not Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, tickCtx.filteredShips) and
      not AssaultBoat.hasPendingBoats(zoneState)
end

---WAITING_ADMIN_OFFLOADING: once the deploy line has released everything, start admin offloading. Then the zone is done
---@type SBJ__PhaseStep
local function stepWaitingAdminOffloading(tickCtx, zone, zoneState)
  if not isDeployLineReleased(tickCtx, zone, zoneState) then
    return
  end

  local ok = AdminOffloading.startAdminOffloading(zone, tickCtx.landingState.amphibOps.barges, tickCtx.filteredShips)
  if ok then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.COMPLETED
  end
end

---Landing phases only: hovercraft sail after the first ACV wave is full or the wait times out.
---The update runs every tick. Only the launch is gated.
---@type SBJ__PhaseStep
local function stepHovercraft(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  if AcvWave.isFirstWaveFull(zoneState, AcvWave.buildZoneWaveConfig(amphibOps.tuning.acvWave, zone), tickCtx.currentTime) then
    Hovercraft.launchHovercraft(amphibOps, zone, zoneState, tickCtx.filteredShips)
  end
  Hovercraft.updateHovercraft(amphibOps, zoneState)
end

---Phase order, from top to bottom. The steps are not exclusive: a step that advances the phase lets
---the next step run in the same tick. A zone can cross several phases at once.
---@type { phase: string, step: SBJ__PhaseStep }[]
local PHASE_STEPS = {
  { phase = constants.AMPHIBIOUS_PHASES.MOVING,                   step = stepMoving },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL,          step = stepWaitingArrival },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,          step = stepWaitingAssault },
  { phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING,            step = stepMineClearing },
  { phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,             step = stepBoatAssault },
  { phase = constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING,        step = stepObstacleClearing },
  { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING,          step = stepAssaultLanding },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING, step = stepWaitingAdminOffloading },
}

---Process a single operational zone through all amphibious phases
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
local function processZone(tickCtx, zone)
  local zoneState = tickCtx.landingState.amphibOps.zoneStates[zone.name]

  for _, entry in ipairs(PHASE_STEPS) do
    if zoneState.phase == entry.phase then
      entry.step(tickCtx, zone, zoneState)
    end
  end

  HeliWave.update(tickCtx, zone, zoneState)

  if constants.AMPHIBIOUS_LANDING_PHASES[zoneState.phase] then
    stepHovercraft(tickCtx, zone, zoneState)
  end
end

---Process the periodic transfer of remaining cargo for zones with active airlanding missions
---@param tickCtx SBJ__LandingTickContext
local function processRemainingCargoTransfer(tickCtx)
  local config, landingState = tickCtx.config, tickCtx.landingState
  local currentTime, filteredShips = tickCtx.currentTime, tickCtx.filteredShips
  for _, zone in ipairs(config.red.amphibOps.zones) do
    local zoneState = landingState.amphibOps.zoneStates[zone.name]
    if zoneState.airlandingMissionStartTime then
      local elapsed = currentTime - zoneState.airlandingMissionStartTime
      if elapsed >= config.red.amphibOps.remainingCargoTransferSec then
        local ok = AmphibiousLogistics.transferRemainingCargos(zone, filteredShips)
        if ok then
          zoneState.airlandingMissionStartTime = currentTime
        end
      end
    end
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Process all landing operation phases for the current event tick
---@param config SBJ__Config
---@param landingState SBJ__LandingOpsState
---@param params SBJ__LandingTickParams
function Coordinator.process(config, landingState, params)
  ---@type SBJ__LandingTickContext
  local tickCtx = {
    config = config,
    landingState = landingState,
    contacts = params.contacts,
    currentTime = params.currentTime,
    filteredShips = params.filteredShips
  }
  for _, zone in ipairs(config.red.amphibOps.zones) do
    processZone(tickCtx, zone)
  end

  processRemainingCargoTransfer(tickCtx)

  local gateResult = FireSupportGate.evaluate(config, landingState, MissileSystem.getAmmoInventory)
  if gateResult then
    Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT, LogFormat.line(gateResult.tag, gateResult.fields))
  end
end

return Coordinator
