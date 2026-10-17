local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AdminUnloading = require("src.modules.landingOps.adminUnloading")
local MineClearing = require("src.modules.landingOps.mineClearing")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local ObstacleClearing = require("src.modules.landingOps.obstacleClearing")
local Hovercraft = require("src.modules.landingOps.hovercraft")
local AcvWave = require("src.modules.landingOps.acvWave")
local MissileSystem = require("src.modules.missileSystem.init")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")
local DebugFlow = require("src.modules.landingOps.debugFlow")

local Coordinator = {}

---Phases considered "fleet has arrived at staging waters" for fire support gate
---@type table<string, true>
local ARRIVED_PHASES = {
  [constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT]         = true,
  [constants.AMPHIBIOUS_PHASES.MINE_CLEARING]           = true,
  [constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT]            = true,
  [constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING]       = true,
  [constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING]         = true,
  [constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_UNLOADING] = true,
  [constants.AMPHIBIOUS_PHASES.COMPLETED]               = true,
}

---Zone missions started when the assault launches; boat (hovercraft) missions wait for the lanes
---@type string[]
local HELICOPTER_MISSION_CATEGORIES = { "transportHelicopter", "attackHelicopter" }

---Handle temporary Taoyuan-only loading and reconnaissance setup
---@param config SBJ__Config
---@param landingState SBJ__LandingOpsState
---@param zone SBJ__OperationalZoneDescriptor
local function processTaoyuanTemporarySetup(config, landingState, zone)
  if zone.name ~= "Taoyuan" then
    return
  end

  AmphibiousLogistics.transferAndAssignTransportAircraft(config.red.amphibOps.transportAircraft)
  StrikePlanner.addReconEntry(landingState.recon, config.red.recon.templates.GJ11_RECON)
end

---MOVING: sail to holding areas once the operation start time has passed
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

---WAITING_ARRIVAL: all ships settled in holding areas -> create cargo missions and load
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
    processTaoyuanTemporarySetup(tickCtx.config, tickCtx.landingState, zone)
  end
end

---WAITING_ASSAULT: launch when enemy contacts thin out, the wait times out, or fast-forward
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

  local ok = MineClearing.startMineClearing(amphibOps, zone, zoneState, tickCtx.filteredShips) and
      AmphibiousAssault.setLandingMissionStartTime(zone, zoneState, HELICOPTER_MISSION_CATEGORIES)
  if ok then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING
  end
end

---MINE_CLEARING: lanes cleared -> pair assault boats and move ships to launch stations
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
  end
end

---BOAT_ASSAULT: launch boats every tick; once they all arrive, start obstacle clearing
---@type SBJ__PhaseStep
local function stepBoatAssault(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  AssaultBoat.launchBoats(amphibOps, zone, zoneState)

  if AssaultBoat.updateBoats(amphibOps, zoneState) and
      ObstacleClearing.startObstacleClearing(amphibOps, zone, zoneState, tickCtx.currentTime) then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING
  end
end

---OBSTACLE_CLEARING: obstacles cleared -> assault landing
---@type SBJ__PhaseStep
local function stepObstacleClearing(tickCtx, _zone, zoneState)
  if ObstacleClearing.updateObstacleClearing(tickCtx.config.red.amphibOps, zoneState, tickCtx.currentTime) then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
  end
end

---ASSAULT_LANDING: a landed ZBD-05 in the zone counts as a beachhead
---@type SBJ__PhaseStep
local function stepAssaultLanding(tickCtx, zone, zoneState)
  -- TODO: 換成更嚴格的灘頭堡條件
  local result = AmphibiousAssault.countUnitsInEachArea(tickCtx.config.red.amphibOps.zones)
  local hasBeachhead = result[zone.name] and result[zone.name]["ZBD-05"] >= 1
  if hasBeachhead then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_UNLOADING
  end
end

---WAITING_ADMIN_UNLOADING: start admin unloading, then the zone is done
---@type SBJ__PhaseStep
local function stepWaitingAdminUnloading(tickCtx, zone, zoneState)
  -- TODO: 行政下卸的「絕對安全」條件；目前直接放行
  local ok = AdminUnloading.startAdminUnloading(zone, tickCtx.landingState.amphibOps.barges, tickCtx.filteredShips)
  if ok then
    zoneState.phase = constants.AMPHIBIOUS_PHASES.COMPLETED
  end
end

---Landing phases only: hovercraft sail after the first ACV wave is full (or the wait times out)
---Updating runs every tick; only launching is gated
---@type SBJ__PhaseStep
local function stepHovercraft(tickCtx, zone, zoneState)
  local amphibOps = tickCtx.config.red.amphibOps
  if AcvWave.isFirstWaveFull(zoneState, amphibOps.tuning.acvWave, tickCtx.currentTime) then
    Hovercraft.launchHovercraft(amphibOps, zone, zoneState, tickCtx.filteredShips)
  end
  Hovercraft.updateHovercraft(amphibOps, zoneState)
end

---Phase order, top to bottom. Steps are not exclusive: a step that advances the phase lets
---the next step run in the same tick, so a zone can cross several phases at once.
---@type { phase: string, step: SBJ__PhaseStep }[]
local PHASE_STEPS = {
  { phase = constants.AMPHIBIOUS_PHASES.MOVING,                  step = stepMoving },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL,         step = stepWaitingArrival },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,         step = stepWaitingAssault },
  { phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING,           step = stepMineClearing },
  { phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,            step = stepBoatAssault },
  { phase = constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING,       step = stepObstacleClearing },
  { phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING,         step = stepAssaultLanding },
  { phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_UNLOADING, step = stepWaitingAdminUnloading },
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

  if constants.AMPHIBIOUS_LANDING_PHASES[zoneState.phase] then
    stepHovercraft(tickCtx, zone, zoneState)
  end
end

---Handle periodic cargo retransfer for zones with active airlanding missions
---@param tickCtx SBJ__LandingTickContext
local function processCargoRetransfer(tickCtx)
  local config, landingState = tickCtx.config, tickCtx.landingState
  local currentTime, filteredShips = tickCtx.currentTime, tickCtx.filteredShips
  for _, zone in ipairs(config.red.amphibOps.zones) do
    local zoneState = landingState.amphibOps.zoneStates[zone.name]
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

---Check whether all configured operational zones have reached staging waters
---@param config SBJ__Config
---@param amphibOps SBJ__AmphibOpsContext
---@return boolean # True when every zone's phase is at WAITING_ASSAULT or beyond
local function hasAllZonesArrived(config, amphibOps)
  for _, zone in ipairs(config.red.amphibOps.zones) do
    local zoneState = amphibOps.zoneStates[zone.name]
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
---@param config SBJ__Config
---@param landingState SBJ__LandingOpsState
local function evaluateFireSupportGate(config, landingState)
  local amphib = landingState.amphibOps
  local arrived = hasAllZonesArrived(config, amphib)

  if amphib.fireSupportOnHold and arrived then
    amphib.fireSupportOnHold = false
    Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT,
      LogFormat.line("RESUME", { scope = "fireSupportGate", reason = "all_zones_at_staging_waters" }))
    return
  end

  if amphib.fireSupportOnHold or arrived then
    return
  end

  local report = landingState.ground and
      MissileSystem.getAmmoInventory(landingState.ground, constants.MISSILE_SYSTEM_TYPES.SRBM, constants.SIDES.RED)
  if not report then return end

  if report.total.percentage < config.red.amphibOps.fireSupportHoldThreshold then
    amphib.fireSupportOnHold = true
    Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT, LogFormat.line("HOLD", {
      scope = "fireSupportGate",
      reason = "srbm_low",
      total = report.total.percentage,
      threshold = config.red.amphibOps.fireSupportHoldThreshold,
      firing = report.firing.percentage,
      resupply = report.resupply.percentage,
      depot = report.ammo.percentage
    }))
  end
end

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

  processCargoRetransfer(tickCtx)
  evaluateFireSupportGate(config, landingState)
end

return Coordinator
