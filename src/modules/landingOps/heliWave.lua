local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")

---Fly the zone's helicopters in waves. A wave is a group of transport helicopters plus attack helicopters topping up the zone's CAS force.
---It launches from the motherships, flies out along the left and right wings, and goes inland to its landing points.
---Transports unload and return. An attack helicopter is assigned to the zone's CAS mission near its landing point,
---and from then on the mission alone decides what it does.
---The next wave launches only after the transports of the wave in the air have finished or timed out.
---Fixed-wing transports (airlift) fly the same inland course from their airfield, in batches that reach the landing points
---a fixed delay after the wave. Their batches are tracked apart from the helicopter waves.
local HeliWave = {}

-- ============================================================================
-- Constants
-- ============================================================================

---@enum SBJ__HeliRoleType
local ROLE = {
  TRANSPORT = "transport",
  ATTACK    = "attack",
  AIRLIFT   = "airlift",
}

---@enum SBJ__HeliWingType
local WING = {
  LEFT  = "left",
  RIGHT = "right",
}

---Lateral direction of each wing, facing the shore
---@type table<SBJ__HeliWingType, integer>
local WING_SIGN = {
  [WING.LEFT]  = -1,
  [WING.RIGHT] = 1,
}

---@enum SBJ__HeliPhaseType
local PHASE = {
  ENROUTE   = "enroute",
  UNLOADING = "unloading",
  CAS       = "cas",
  RETURNING = "returning",
}

-- ============================================================================
-- Candidates
-- ============================================================================

---Check if a unit carries any cargo
---@param unit CMO__Unit
---@return boolean # True if the unit carries at least one cargo item
local function hasCargo(unit)
  return unit.cargo ~= nil and unit.cargo[1] ~= nil and unit.cargo[1].cargo ~= nil and #unit.cargo[1].cargo > 0
end

---Find the motherships anchored in the zone
---@param zone SBJ__OperationalZoneDescriptor
---@param ships CMO__SideUnit[]
---@return CMO__Unit[]
local function findMotherships(zone, ships)
  local motherships = {}

  for _, sideUnit in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(sideUnit.guid)
    if ship and constants.MOTHERSHIP_DBID_SET[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) then
      table.insert(motherships, ship)
    end
  end

  return motherships
end

---Find the ready helicopters aboard the motherships: loaded transports and unloaded attack helicopters
---@param zone SBJ__OperationalZoneDescriptor
---@param motherships CMO__Unit[]
---@return CMO__Unit[] transports
---@return CMO__Unit[] attackers
local function findCandidates(zone, motherships)
  local transports, attackers = {}, {}
  local air = zone.air
  local transportDBID, attackDBID = air.transportHelicopter.dbid, air.attackHelicopter.dbid

  for _, ship in ipairs(motherships) do
    local embarked = ship.embarkedUnits and ship.embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT] or {}

    for _, guid in ipairs(embarked) do
      local heli = GameApi.ScenEdit_GetUnit(guid)
      if heli and heli.readytime_v == 0 then
        if heli.dbid == transportDBID and hasCargo(heli) then
          table.insert(transports, heli)
        elseif heli.dbid == attackDBID then
          table.insert(attackers, heli)
        end
      end
    end
  end

  return transports, attackers
end

---Find the ready, loaded transport aircraft aboard the zone's airfield
---@param transportAircraft SBJ__TransportAircraftDescriptor
---@return CMO__Unit[]
local function findAirliftCandidates(transportAircraft)
  local airfield = GameApi.ScenEdit_GetUnit(transportAircraft.guid)
  local embarked = airfield and airfield.embarkedUnits and airfield.embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT] or {}
  local candidates = {}

  for _, guid in ipairs(embarked) do
    local aircraft = GameApi.ScenEdit_GetUnit(guid)
    if aircraft and aircraft.dbid == transportAircraft.dbid and aircraft.readytime_v == 0 and hasCargo(aircraft) then
      table.insert(candidates, aircraft)
    end
  end

  return candidates
end

---Get the name of the zone's CAS mission
---@param zone SBJ__OperationalZoneDescriptor
---@return string
local function getCasMissionName(zone)
  return "CAS/HELI/" .. string.upper(zone.name)
end

---Select count items at random
---@generic T
---@param items T[]
---@param count integer
---@return T[]
local function selectRandom(items, count)
  local pool = {}
  for i, item in ipairs(items) do
    pool[i] = item
  end

  local picks = {}
  while #picks < count and #pool > 0 do
    table.insert(picks, table.remove(pool, math.random(#pool)))
  end
  return picks
end

-- ============================================================================
-- Routes
-- ============================================================================

---Find the center of the air landing zone
---@param zone SBJ__OperationalZoneDescriptor
---@return CMO__Location|nil # nil when the zone points cannot be resolved
local function findLandingCenter(zone)
  local points = GameUtils.findAreaLocations(constants.SIDES.RED, zone.air.transportHelicopter.zone)
  if #points == 0 then
    return nil
  end

  local latSum, lonSum = 0, 0
  for _, point in ipairs(points) do
    latSum = latSum + Utils.toNumber(point.latitude)
    lonSum = lonSum + Utils.toNumber(point.longitude)
  end
  return { latitude = latSum / #points, longitude = lonSum / #points }
end

---Build the inland part of a wing course: along the wing past the shore, then to the wing's landing point
---@param flightCtx SBJ__HeliFlightContext
---@param wing SBJ__HeliWingType
---@return CMO__Waypoint[] course
local function buildInlandCourse(flightCtx, wing)
  local frame, center, heliConfig = flightCtx.frame, flightCtx.center, flightCtx.heliConfig
  local sign = WING_SIGN[wing]
  local centerAlong, centerLateral = LaneGeometry.projectPoint(frame, center)
  local wingLateral = sign * heliConfig.wingOffsetM

  return {
    LaneGeometry.buildPoint(frame, heliConfig.inlandEntryM, wingLateral),
    LaneGeometry.buildPoint(frame, centerAlong, centerLateral + sign * heliConfig.landingSpreadM),
  }
end

---Build the course of one wing: sideways to the wing, then the inland part
---@param flightCtx SBJ__HeliFlightContext
---@param startPos CMO__Location
---@param wing SBJ__HeliWingType
---@return CMO__Waypoint[] course
local function buildWingCourse(flightCtx, startPos, wing)
  local startAlong = LaneGeometry.projectPoint(flightCtx.frame, startPos)
  local inland = buildInlandCourse(flightCtx, wing)
  local wingLateral = WING_SIGN[wing] * flightCtx.heliConfig.wingOffsetM

  return {
    LaneGeometry.buildPoint(flightCtx.frame, startAlong, wingLateral),
    inland[1],
    inland[2],
  }
end

---Build the geometry shared by every course of a wave
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param heliConfig SBJ__HeliWaveConfig
---@return SBJ__HeliFlightContext|nil # nil when the lanes or the landing zone are missing
local function buildFlightContext(zone, zoneState, heliConfig)
  local center = findLandingCenter(zone)
  if not (zoneState.lanes and center) then
    return nil
  end

  return {
    frame = LaneGeometry.buildFrame(zoneState.lanes),
    center = center,
    heliConfig = heliConfig,
  }
end

---Calculate the length of a course
---@param startPos CMO__Location
---@param course CMO__Location[]
---@return number # Meters
local function calculateCourseLengthM(startPos, course)
  local length, previous = 0, startPos
  for _, point in ipairs(course) do
    length = length + LaneGeometry.calculateDistanceM(previous, point)
    previous = point
  end
  return length
end

---Calculate when the paired assault boats reach the shore line.
---The farthest carrier sails to the outer edge of the launch station band, then its boats run in to the shore.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@param currentTime number
---@return number # Time of the boat arrival
local function calculateBoatArrivalTime(amphibOps, zoneState, currentTime)
  local lanes = zoneState.lanes
  if not lanes then
    return currentTime
  end

  local frame = LaneGeometry.buildFrame(lanes)
  local route = amphibOps.tuning.route
  local farthestNm = 0

  for _, entry in pairs(zoneState.boats or {}) do
    local carrier = GameApi.ScenEdit_GetUnit(entry.shipGuid)
    if carrier then
      local along = LaneGeometry.projectPoint(frame, carrier)
      farthestNm = math.max(farthestNm, -along / constants.METERS_PER_NM)
    end
  end

  local sailHours = math.max(0, farthestNm - route.launchStationFarNm) / amphibOps.formation.shipSpeed
  local runInNm = route.launchStationFarNm - route.shoreStandoffM / constants.METERS_PER_NM
  local runHours = runInNm / amphibOps.tuning.assaultBoat.speed

  return currentTime + (sailHours + runHours) * constants.SECONDS_PER_HOUR
end

---Calculate the flight time of a wave from the first mothership along the longer wing
---@param flightCtx SBJ__HeliFlightContext|nil
---@param motherships CMO__Unit[]
---@return number # Seconds. 0 when the route cannot be built
local function calculateFlightSec(flightCtx, motherships)
  local start = motherships[1]
  if not (flightCtx and start) then
    return 0
  end

  local startPos = { latitude = start.latitude, longitude = start.longitude }
  local longestM = 0
  for _, wing in pairs(WING) do
    longestM = math.max(longestM, calculateCourseLengthM(startPos, buildWingCourse(flightCtx, startPos, wing)))
  end

  return longestM / constants.METERS_PER_NM / flightCtx.heliConfig.cruiseSpeedKt * constants.SECONDS_PER_HOUR
end

---Calculate the flight time of an airlift batch from the airfield along the longer wing
---@param flightCtx SBJ__HeliFlightContext|nil
---@param airfield CMO__Unit|nil
---@return number # Seconds. 0 when the route cannot be built
local function calculateAirliftFlightSec(flightCtx, airfield)
  if not (flightCtx and airfield) then
    return 0
  end

  local startPos = { latitude = airfield.latitude, longitude = airfield.longitude }
  local longestM = 0
  for _, wing in pairs(WING) do
    longestM = math.max(longestM, calculateCourseLengthM(startPos, buildInlandCourse(flightCtx, wing)))
  end

  return longestM / constants.METERS_PER_NM / flightCtx.heliConfig.airlift.cruiseSpeedKt * constants.SECONDS_PER_HOUR
end

-- ============================================================================
-- Wave Launch
-- ============================================================================

---Launch one aircraft along a course
---@param heli CMO__Unit
---@param role SBJ__HeliRoleType
---@param wing SBJ__HeliWingType
---@param course CMO__Waypoint[]
---@return SBJ__HeliState
local function launchHeli(heli, role, wing, course)
  heli:Launch(true)
  heli.course = course
  heli.throttle = constants.THROTTLES.MILITARY
  GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.RED, guid = heli.guid }, { automatic_evasion = false })

  return { role = role, wing = wing, phase = PHASE.ENROUTE, landingPoint = course[#course] }
end

---Launch a group of aircraft, alternating left and right wing
---@param helis CMO__Unit[]
---@param role SBJ__HeliRoleType
---@param unitMap table<string, SBJ__HeliState> Wave units, filled in
---@param courseOf fun(heli: CMO__Unit, wing: SBJ__HeliWingType): CMO__Waypoint[]
local function launchGroup(helis, role, unitMap, courseOf)
  for i, heli in ipairs(helis) do
    local wing = i % 2 == 1 and WING.LEFT or WING.RIGHT
    unitMap[heli.guid] = launchHeli(heli, role, wing, courseOf(heli, wing))
  end
end

---Launch the next wave when loaded transports are aboard
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param state SBJ__HeliWaveState
---@param flightCtx SBJ__HeliFlightContext
---@return SBJ__LogResult|nil # nil when there is nothing new to report
local function launchWave(tickCtx, zone, state, flightCtx)
  local transports, attackers = findCandidates(zone, findMotherships(zone, tickCtx.filteredShips))
  if #transports == 0 then
    if state.isWaitingLogged then
      return nil
    end

    state.isWaitingLogged = true
    return { tag = "HOLD", fields = { zone = zone.name, reason = "no_loaded_transport" } }
  end

  local unitMap = {}
  local attackerNeed = math.max(0, flightCtx.heliConfig.escortSize - Utils.getCount(state.attackers))
  local launchedBefore = Utils.getCount(state.attackers)
  local heliConfig = flightCtx.heliConfig
  local function courseOf(heli, wing)
    local course = buildWingCourse(flightCtx, { latitude = heli.latitude, longitude = heli.longitude }, wing)
    course[1].desiredAltitude = heliConfig.cruiseAltitudeM
    return course
  end
  launchGroup(selectRandom(transports, heliConfig.waveSize), ROLE.TRANSPORT, unitMap, courseOf)
  launchGroup(selectRandom(attackers, attackerNeed), ROLE.ATTACK, state.attackers, courseOf)

  state.units = unitMap
  state.waveIndex = state.waveIndex + 1
  state.waveLaunchedAt = tickCtx.currentTime
  state.isWaitingLogged = false

  return {
    tag = "OK",
    fields = {
      zone = zone.name,
      wave = state.waveIndex,
      transports = Utils.getCount(unitMap),
      attackers = Utils.getCount(state.attackers) - launchedBefore,
    },
  }
end

---Launch the next airlift batch when loaded transport aircraft are on the airfield
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param airlift SBJ__AirliftState
---@param flightCtx SBJ__HeliFlightContext
---@return SBJ__LogResult|nil # nil when there is nothing new to report
local function launchAirliftBatch(tickCtx, zone, airlift, flightCtx)
  local candidates = findAirliftCandidates(zone.air.transportAircraft)
  if #candidates == 0 then
    if airlift.isWaitingLogged then
      return nil
    end

    airlift.isWaitingLogged = true
    return { tag = "HOLD", fields = { zone = zone.name, reason = "no_loaded_airlifter" } }
  end

  local airliftConfig = flightCtx.heliConfig.airlift
  local unitMap = {}
  local function courseOf(heli, wing)
    local course = buildInlandCourse(flightCtx, wing)
    course[1].desiredAltitude = airliftConfig.cruiseAltitudeM
    return course
  end
  launchGroup(selectRandom(candidates, airliftConfig.size), ROLE.AIRLIFT, unitMap, courseOf)

  airlift.units = unitMap
  airlift.waveIndex = airlift.waveIndex + 1
  airlift.waveLaunchedAt = tickCtx.currentTime
  airlift.isWaitingLogged = false

  return { tag = "OK", fields = { zone = zone.name, batch = airlift.waveIndex, aircraft = Utils.getCount(unitMap) } }
end

-- ============================================================================
-- Wave Progress
-- ============================================================================

---Move a helicopter home
---@param heli CMO__Unit
---@param entry SBJ__HeliState
local function moveHome(heli, entry)
  heli:RTB(true)
  entry.phase = PHASE.RETURNING
end

---Find the transports of the wave that are alive and not yet on their way home
---@param unitMap table<string, SBJ__HeliState>
---@return table<string, CMO__Unit> # Alive transports indexed by GUID
local function findFlyingTransports(unitMap)
  local helis = {}
  for guid, entry in pairs(unitMap) do
    local heli = entry.phase ~= PHASE.RETURNING and GameApi.ScenEdit_GetUnit(guid)
    if heli then
      helis[guid] = heli
    end
  end
  return helis
end

---Get the helicopter wave settings
---@param tickCtx SBJ__LandingTickContext
---@return SBJ__HeliWaveConfig
local function getHeliConfig(tickCtx)
  return tickCtx.config.red.amphibOps.tuning.heliWave
end

---Check if the wave is over: every transport is on its way home or destroyed
---@param unitMap table<string, SBJ__HeliState>
---@return boolean # True if no transport of the wave is still in the air
local function isWaveDone(unitMap)
  return next(findFlyingTransports(unitMap)) == nil
end

---Check if a helicopter is close enough to its landing point
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param arrivalNm number
---@return boolean # True if the helicopter is within arrivalNm of its landing point
local function hasArrived(heli, entry, arrivalNm)
  local range = GameApi.Tool_Range(heli.guid, entry.landingPoint)
  return range ~= nil and range < arrivalNm
end

---Update one transport through unloading
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param arrivalNm number
local function updateTransport(heli, entry, arrivalNm)
  if entry.phase == PHASE.ENROUTE then
    if hasArrived(heli, entry, arrivalNm) then
      GameApi.ScenEdit_UnloadCargo(heli.guid)
      entry.phase = PHASE.UNLOADING
    end
  elseif entry.phase == PHASE.UNLOADING and GameUtils.isCargoUnloaded(heli) then
    moveHome(heli, entry)
  end
end

---Update one attack helicopter on its way. Near its landing point it joins the CAS mission, which takes over
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param casAssignNm number
---@param missionName string
local function updateAttacker(heli, entry, casAssignNm, missionName)
  if entry.phase == PHASE.ENROUTE and hasArrived(heli, entry, casAssignNm) then
    heli.course = nil
    GameApi.ScenEdit_AssignUnitToMission(heli.guid, missionName)
    entry.phase = PHASE.CAS
  end
end

---Move home every transport of the wave still in the air
---@param unitMap table<string, SBJ__HeliState>
local function moveHomeTransports(unitMap)
  for guid, heli in pairs(findFlyingTransports(unitMap)) do
    moveHome(heli, unitMap[guid])
  end
end

---Update every transport of the wave
---@param zoneState SBJ__ZoneState
---@param unitMap table<string, SBJ__HeliState>
---@param arrivalNm number
local function updateTransports(zoneState, unitMap, arrivalNm)
  for guid, entry in pairs(unitMap) do
    local heli = TrackedUnits.findUnit(zoneState, guid)
    if heli then
      updateTransport(heli, entry, arrivalNm)
    end
  end
end

---Update every attack helicopter that has not yet joined the CAS mission
---@param zoneState SBJ__ZoneState
---@param attackerMap table<string, SBJ__HeliState>
---@param casAssignNm number
---@param missionName string
local function updateAttackers(zoneState, attackerMap, casAssignNm, missionName)
  for guid, entry in pairs(attackerMap) do
    local heli = entry.phase == PHASE.ENROUTE and TrackedUnits.findUnit(zoneState, guid)
    if heli then
      updateAttacker(heli, entry, casAssignNm, missionName)
    end
  end
end

---Recall the transports of a fleet (helicopter wave or airlift batch) that stayed out past the timeout
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param fleet SBJ__HeliWaveState|SBJ__AirliftState
---@param fleetName string Which fleet, for the log
---@return SBJ__LogResult|nil # nil when nothing timed out
local function recallOnTimeout(tickCtx, zone, fleet, fleetName)
  -- A transport stuck unloading is moved home too, so it cannot block the next wave
  if not (fleet.waveLaunchedAt and tickCtx.currentTime - fleet.waveLaunchedAt >= getHeliConfig(tickCtx).waveTimeoutSec and
        not isWaveDone(fleet.units)) then
    return nil
  end

  moveHomeTransports(fleet.units)
  return { tag = "WARN", fields = { zone = zone.name, fleet = fleetName, wave = fleet.waveIndex, reason = "wave_timeout" } }
end

---Check if a fleet is done and its next launch time has come
---@param fleet SBJ__HeliWaveState|SBJ__AirliftState
---@return boolean
local function isFleetDue(fleet)
  return isWaveDone(fleet.units) and (fleet.waveIndex > 0 or GameUtils.isAfterStartTime(fleet.launchAt))
end

-- ============================================================================
-- Public API
-- ============================================================================

---Schedule the first wave when the boat assault begins, and create the zone's CAS mission.
---The wave launches early enough to reach the landing points when the boats reach the shore.
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return boolean # True if the wave plan is set
function HeliWave.schedule(tickCtx, zone, zoneState)
  local amphibOps, currentTime = tickCtx.config.red.amphibOps, tickCtx.currentTime
  local flightCtx = buildFlightContext(zone, zoneState, getHeliConfig(tickCtx))
  local boatArrivalAt = calculateBoatArrivalTime(amphibOps, zoneState, currentTime)
  local flightSec = calculateFlightSec(flightCtx, findMotherships(zone, tickCtx.filteredShips))

  zoneState.heliWave = {
    waveIndex = 0,
    launchAt = math.max(currentTime, boatArrivalAt - flightSec),
    units = {},
    attackers = {},
  }

  if zone.air.transportAircraft then
    local airliftConfig = getHeliConfig(tickCtx).airlift
    local airfield = GameApi.ScenEdit_GetUnit(zone.air.transportAircraft.guid)
    local airliftFlightSec = calculateAirliftFlightSec(flightCtx, airfield)
    zoneState.heliWave.airlift = {
      waveIndex = 0,
      launchAt = math.max(currentTime, boatArrivalAt + airliftConfig.delaySec - airliftFlightSec),
      units = {},
    }
  end

  GameApi.ScenEdit_AddMission(
    constants.SIDES.RED,
    getCasMissionName(zone),
    "patrol",
    { type = "land", zone = zone.air.attackHelicopter.zone }
  )

  Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT, LogFormat.line("OK", {
    scope = "heliWave",
    zone = zone.name,
    boatArrivalIn = boatArrivalAt - currentTime,
    flightSec = flightSec,
    launchIn = zoneState.heliWave.launchAt - currentTime,
  }))

  return true
end

---Run the helicopter waves of a zone for one tick. Do nothing before the wave plan exists
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return boolean # False if the wave could not launch because the lanes or the landing zone are missing
function HeliWave.update(tickCtx, zone, zoneState)
  local state = zoneState.heliWave
  if not state then
    return true
  end

  local heliConfig = getHeliConfig(tickCtx)
  updateAttackers(zoneState, state.attackers, heliConfig.casAssignNm, getCasMissionName(zone))

  local airlift = state.airlift
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "heliWave", "launchWave")
  updateTransports(zoneState, state.units, heliConfig.arrivalNm)
  report.addAll({ recallOnTimeout(tickCtx, zone, state, "heli") })
  local isHeliReady = isFleetDue(state)
  local isAirliftReady = false
  if airlift then
    updateTransports(zoneState, airlift.units, heliConfig.airlift.arrivalNm)
    report.addAll({ recallOnTimeout(tickCtx, zone, airlift, "airlift") })
    isAirliftReady = isFleetDue(airlift)
  end
  if not (isHeliReady or isAirliftReady) then
    report.emit()
    return true
  end

  local flightCtx = buildFlightContext(zone, zoneState, heliConfig)
  if not flightCtx then
    Logger.error(LogFormat.line("ERROR", { scope = "heliWave", zone = zone.name, reason = "landing_geometry_missing" }))
    return false
  end

  if isHeliReady then
    report.addAll({ launchWave(tickCtx, zone, state, flightCtx) })
  end
  if airlift and isAirliftReady then
    report.addAll({ launchAirliftBatch(tickCtx, zone, airlift, flightCtx) })
  end
  report.emit()

  return true
end

return HeliWave
