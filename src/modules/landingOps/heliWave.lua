local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local CargoRun = require("src.modules.landingOps.cargoRun")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")

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
  ENROUTE   = CargoRun.PHASE.ENROUTE,
  UNLOADING = CargoRun.PHASE.UNLOADING,
  CAS       = "cas",
  RETURNING = CargoRun.PHASE.RETURNING,
}

-- ============================================================================
-- Candidates
-- ============================================================================

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
---@return CMO__Unit[] transportHelis
---@return CMO__Unit[] attackHelis
local function findReadyHelis(zone, motherships)
  local transportHelis, attackHelis = {}, {}
  local air = zone.air
  local transportDBID, attackDBID = air.transportHelicopter.dbid, air.attackHelicopter.dbid

  for _, ship in ipairs(motherships) do
    for _, heli in ipairs(CargoRun.findReady(ship, constants.PLATFORM_TYPES.AIRCRAFT, transportDBID)) do
      table.insert(transportHelis, heli)
    end

    local embarked = ship.embarkedUnits and ship.embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT] or {}
    for _, guid in ipairs(embarked) do
      local heli = GameApi.ScenEdit_GetUnit(guid)
      if heli and heli.readytime_v == 0 and heli.dbid == attackDBID then
        table.insert(attackHelis, heli)
      end
    end
  end

  return transportHelis, attackHelis
end

---Find the ready, loaded transport aircraft aboard the zone's airfield
---@param transportAircraft SBJ__TransportAircraftDescriptor
---@return CMO__Unit[]
local function findReadyAirlifters(transportAircraft)
  local airfield = GameApi.ScenEdit_GetUnit(transportAircraft.guid)
  if not airfield then
    return {}
  end
  return CargoRun.findReady(airfield, constants.PLATFORM_TYPES.AIRCRAFT, transportAircraft.dbid)
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
---@param flightCtx SBJ__AirWaveFlightContext
---@param wing SBJ__HeliWingType
---@return CMO__Waypoint[] course
local function buildInlandCourse(flightCtx, wing)
  local frame, center, flightPath = flightCtx.frame, flightCtx.center, flightCtx.heliConfig.flightPath
  local sign = WING_SIGN[wing]
  local centerAlong, centerLateral = LaneGeometry.projectPoint(frame, center)
  local wingLateral = sign * flightPath.wingOffsetM

  return {
    LaneGeometry.buildPoint(frame, flightPath.inlandEntryM, wingLateral),
    LaneGeometry.buildPoint(frame, centerAlong, centerLateral + sign * flightPath.landingSpreadM),
  }
end

---Build the course of one wing: sideways to the wing, then the inland part
---@param flightCtx SBJ__AirWaveFlightContext
---@param startPos CMO__Location
---@param wing SBJ__HeliWingType
---@return CMO__Waypoint[] course
local function buildWingCourse(flightCtx, startPos, wing)
  local startAlong = LaneGeometry.projectPoint(flightCtx.frame, startPos)
  local inland = buildInlandCourse(flightCtx, wing)
  local wingLateral = WING_SIGN[wing] * flightCtx.heliConfig.flightPath.wingOffsetM

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
---@return SBJ__AirWaveFlightContext|nil # nil when the lanes or the landing zone are missing
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

---Calculate the flight time of a wave from the first mothership along the longer wing
---@param flightCtx SBJ__AirWaveFlightContext|nil
---@param motherships CMO__Unit[]
---@return number # Seconds. 0 when the route cannot be built
local function calculateHeliFlightSec(flightCtx, motherships)
  local start = motherships[1]
  if not (flightCtx and start) then
    return 0
  end

  local startPos = { latitude = start.latitude, longitude = start.longitude }
  local longestM = 0
  for _, wing in pairs(WING) do
    longestM = math.max(longestM, calculateCourseLengthM(startPos, buildWingCourse(flightCtx, startPos, wing)))
  end

  return longestM / constants.METERS_PER_NM / flightCtx.heliConfig.transport.cruiseSpeedKt * constants.SECONDS_PER_HOUR
end

---Calculate the flight time of an airlift batch from the airfield along the longer wing
---@param flightCtx SBJ__AirWaveFlightContext|nil
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
---@param aircraft CMO__Unit
---@param role SBJ__HeliRoleType
---@param wing SBJ__HeliWingType
---@param course CMO__Waypoint[]
---@return SBJ__WaveAircraftState
local function launchAircraft(aircraft, role, wing, course)
  aircraft:Launch(true)
  aircraft.course = course
  aircraft.throttle = constants.THROTTLES.MILITARY
  GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.RED, guid = aircraft.guid }, { automatic_evasion = false })

  return { role = role, wing = wing, phase = PHASE.ENROUTE, landingPoint = course[#course] }
end

---Launch a group of aircraft, alternating left and right wing
---@param group CMO__Unit[]
---@param role SBJ__HeliRoleType
---@param unitMap table<string, SBJ__WaveAircraftState> Wave units, filled in
---@param courseOf fun(aircraft: CMO__Unit, wing: SBJ__HeliWingType): CMO__Waypoint[]
local function launchGroup(group, role, unitMap, courseOf)
  for i, aircraft in ipairs(group) do
    local wing = i % 2 == 1 and WING.LEFT or WING.RIGHT
    unitMap[aircraft.guid] = launchAircraft(aircraft, role, wing, courseOf(aircraft, wing))
  end
end

---Launch the next helicopter wave when loaded transport helicopters are aboard
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param heliWave SBJ__HeliWaveState
---@param flightCtx SBJ__AirWaveFlightContext
---@return SBJ__LogResult|nil # nil when there is nothing new to report
local function launchHeliWave(tickCtx, zone, heliWave, flightCtx)
  local transport = heliWave.transport
  local transportHelis, attackHelis = findReadyHelis(zone, findMotherships(zone, tickCtx.filteredShips))
  if #transportHelis == 0 then
    if transport.isWaitingLogged then
      return nil
    end

    transport.isWaitingLogged = true
    return { tag = "HOLD", fields = { zone = zone.name, reason = "no_loaded_transport" } }
  end

  local unitMap = {}
  local attackHeliNeed = math.max(0, flightCtx.heliConfig.attack.count - Utils.getCount(heliWave.attackHelis))
  local launchedBefore = Utils.getCount(heliWave.attackHelis)
  local heliConfig = flightCtx.heliConfig
  local function courseOf(aircraft, wing)
    local course = buildWingCourse(flightCtx, { latitude = aircraft.latitude, longitude = aircraft.longitude }, wing)
    course[1].desiredAltitude = heliConfig.transport.cruiseAltitudeM
    return course
  end
  launchGroup(selectRandom(transportHelis, heliConfig.transport.waveSize), ROLE.TRANSPORT, unitMap, courseOf)
  launchGroup(selectRandom(attackHelis, attackHeliNeed), ROLE.ATTACK, heliWave.attackHelis, courseOf)

  transport.currentWave = unitMap
  transport.waveIndex = transport.waveIndex + 1
  transport.waveLaunchedAt = tickCtx.currentTime
  transport.isWaitingLogged = false

  return {
    tag = "OK",
    fields = {
      zone = zone.name,
      wave = transport.waveIndex,
      transports = Utils.getCount(unitMap),
      attackHelis = Utils.getCount(heliWave.attackHelis) - launchedBefore,
    },
  }
end

---Launch the next airlift wave when loaded transport aircraft are on the airfield
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param airlift SBJ__AirWaveState
---@param flightCtx SBJ__AirWaveFlightContext
---@return SBJ__LogResult|nil # nil when there is nothing new to report
local function launchAirliftWave(tickCtx, zone, airlift, flightCtx)
  local airlifters = findReadyAirlifters(zone.air.transportAircraft)
  if #airlifters == 0 then
    if airlift.isWaitingLogged then
      return nil
    end

    airlift.isWaitingLogged = true
    return { tag = "HOLD", fields = { zone = zone.name, reason = "no_loaded_airlifter" } }
  end

  local airliftConfig = flightCtx.heliConfig.airlift
  local unitMap = {}
  local function courseOf(aircraft, wing)
    local course = buildInlandCourse(flightCtx, wing)
    course[1].desiredAltitude = airliftConfig.cruiseAltitudeM
    return course
  end
  launchGroup(selectRandom(airlifters, airliftConfig.batchSize), ROLE.AIRLIFT, unitMap, courseOf)

  airlift.currentWave = unitMap
  airlift.waveIndex = airlift.waveIndex + 1
  airlift.waveLaunchedAt = tickCtx.currentTime
  airlift.isWaitingLogged = false

  return { tag = "OK", fields = { zone = zone.name, wave = airlift.waveIndex, aircraft = Utils.getCount(unitMap) } }
end

-- ============================================================================
-- Wave Progress
-- ============================================================================

---Find the transports of the wave that are alive and not yet on their way home
---@param zoneState SBJ__ZoneState
---@param unitMap table<string, SBJ__WaveAircraftState>
---@return table<string, CMO__Unit> # Alive transports indexed by GUID
local function findFlyingTransports(zoneState, unitMap)
  local helis = {}
  for guid, entry in pairs(unitMap) do
    local heli = entry.phase ~= PHASE.RETURNING and TrackedUnits.findUnit(zoneState, guid)
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
  return tickCtx.config.red.amphibOps.heliWave
end

---Check if the wave is over: every transport is on its way home or destroyed
---@param zoneState SBJ__ZoneState
---@param unitMap table<string, SBJ__WaveAircraftState>
---@return boolean # True if no transport of the wave is still in the air
local function isWaveDone(zoneState, unitMap)
  return next(findFlyingTransports(zoneState, unitMap)) == nil
end

---Check if a helicopter is close enough to its landing point
---@param heli CMO__Unit
---@param entry SBJ__WaveAircraftState
---@param arrivalNm number
---@return boolean # True if the helicopter is within arrivalNm of its landing point
local function hasArrived(heli, entry, arrivalNm)
  local range = GameApi.Tool_Range(heli.guid, entry.landingPoint)
  return range ~= nil and range < arrivalNm
end

---Update one attack helicopter on its way. Near its landing point it joins the CAS mission, which takes over
---@param heli CMO__Unit
---@param entry SBJ__WaveAircraftState
---@param casAssignNm number
---@param missionName string
local function updateAttackHeli(heli, entry, casAssignNm, missionName)
  if entry.phase == PHASE.ENROUTE and hasArrived(heli, entry, casAssignNm) then
    heli.course = nil
    GameApi.ScenEdit_AssignUnitToMission(heli.guid, missionName)
    entry.phase = PHASE.CAS
  end
end

---Recall to base every transport of the wave still in the air
---@param zoneState SBJ__ZoneState
---@param unitMap table<string, SBJ__WaveAircraftState>
local function recallTransports(zoneState, unitMap)
  for guid, heli in pairs(findFlyingTransports(zoneState, unitMap)) do
    CargoRun.recallToBase(heli, unitMap[guid])
  end
end

---Update every transport of the wave
---@param zoneState SBJ__ZoneState
---@param unitMap table<string, SBJ__WaveAircraftState>
---@param arrivalNm number
local function updateTransports(zoneState, unitMap, arrivalNm)
  for guid, entry in pairs(unitMap) do
    local heli = TrackedUnits.findUnit(zoneState, guid)
    if heli then
      CargoRun.step(heli, entry, entry.landingPoint, arrivalNm)
    end
  end
end

---Update every attack helicopter that has not yet joined the CAS mission
---@param zoneState SBJ__ZoneState
---@param attackHeliMap table<string, SBJ__WaveAircraftState>
---@param casAssignNm number
---@param missionName string
local function updateAttackHelis(zoneState, attackHeliMap, casAssignNm, missionName)
  for guid, entry in pairs(attackHeliMap) do
    local heli = entry.phase == PHASE.ENROUTE and TrackedUnits.findUnit(zoneState, guid)
    if heli then
      updateAttackHeli(heli, entry, casAssignNm, missionName)
    end
  end
end

---Recall to base the transports of an air wave that stayed out past the timeout
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param airWaveKey "transport"|"airlift"
---@return SBJ__LogResult|nil # nil when nothing timed out
local function recallTimedOutWave(tickCtx, zone, zoneState, airWaveKey)
  local airWave = zoneState.heliWave[airWaveKey]
  local isTimedOut = airWave.waveLaunchedAt ~= nil
      and tickCtx.currentTime - airWave.waveLaunchedAt >= getHeliConfig(tickCtx).waveTimeoutSec
  -- A transport stuck unloading is recalled too, so it cannot block the next wave
  if not isTimedOut or isWaveDone(zoneState, airWave.currentWave) then
    return nil
  end

  recallTransports(zoneState, airWave.currentWave)
  return { tag = "WARN", fields = { zone = zone.name, airWave = airWaveKey, wave = airWave.waveIndex, reason = "wave_timeout" } }
end

---Move the transports of an air wave and send them home if the wave timed out. Do nothing if the zone has no such air wave
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param airWaveKey "transport"|"airlift"
---@return SBJ__LogResult|nil # nil when nothing timed out
local function advanceAirWave(tickCtx, zone, zoneState, airWaveKey)
  local airWave = zoneState.heliWave[airWaveKey]
  if not airWave then
    return nil
  end

  updateTransports(zoneState, airWave.currentWave, getHeliConfig(tickCtx)[airWaveKey].arrivalNm)
  return recallTimedOutWave(tickCtx, zone, zoneState, airWaveKey)
end

---Check if an air wave is done and its next launch time has come
---@param zoneState SBJ__ZoneState
---@param airWave SBJ__AirWaveState|nil
---@return boolean # False if the zone has no such air wave
local function canLaunchNextWave(zoneState, airWave)
  return airWave ~= nil and isWaveDone(zoneState, airWave.currentWave)
      and (airWave.waveIndex > 0 or GameUtils.isAfterStartTime(airWave.launchAt))
end

---Launch the next helicopter wave and the next airlift wave if they can launch
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param heliWave SBJ__HeliWaveState
---@return SBJ__LogResult[]|nil # nil when the lanes or the landing zone are missing
local function launchNextWaves(tickCtx, zone, zoneState, heliWave)
  local canLaunchHeli = canLaunchNextWave(zoneState, heliWave.transport)
  local canLaunchAirlift = canLaunchNextWave(zoneState, heliWave.airlift)
  if not (canLaunchHeli or canLaunchAirlift) then
    return {}
  end

  local flightCtx = buildFlightContext(zone, zoneState, getHeliConfig(tickCtx))
  if not flightCtx then
    return nil
  end

  local results = {}
  if canLaunchHeli then
    results[#results + 1] = launchHeliWave(tickCtx, zone, heliWave, flightCtx)
  end

  if canLaunchAirlift then
    results[#results + 1] = launchAirliftWave(tickCtx, zone, heliWave.airlift, flightCtx)
  end
  return results
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
  local boatArrivalAt = AssaultBoat.estimateShoreArrival(amphibOps, zone, zoneState, currentTime)
  local flightSec = calculateHeliFlightSec(flightCtx, findMotherships(zone, tickCtx.filteredShips))

  zoneState.heliWave = {
    transport = {
      waveIndex = 0,
      launchAt = math.max(currentTime, boatArrivalAt - flightSec),
      currentWave = {},
    },
    attackHelis = {},
  }

  if zone.air.transportAircraft then
    local airliftConfig = getHeliConfig(tickCtx).airlift
    local airfield = GameApi.ScenEdit_GetUnit(zone.air.transportAircraft.guid)
    local airliftFlightSec = calculateAirliftFlightSec(flightCtx, airfield)
    zoneState.heliWave.airlift = {
      waveIndex = 0,
      launchAt = math.max(currentTime, boatArrivalAt + airliftConfig.delaySec - airliftFlightSec),
      currentWave = {},
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
    launchIn = zoneState.heliWave.transport.launchAt - currentTime,
  }))

  return true
end

---Run the helicopter waves of a zone for one tick. Do nothing before the wave plan exists
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return boolean # False if the wave could not launch because the lanes or the landing zone are missing
function HeliWave.update(tickCtx, zone, zoneState)
  local heliWave = zoneState.heliWave
  if not heliWave then
    return true
  end

  local heliConfig = getHeliConfig(tickCtx)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "heliWave", "launchWave")

  -- Move the aircraft in the air
  updateAttackHelis(zoneState, heliWave.attackHelis, heliConfig.attack.casAssignNm, getCasMissionName(zone))
  report.addAll({ advanceAirWave(tickCtx, zone, zoneState, "transport") })
  report.addAll({ advanceAirWave(tickCtx, zone, zoneState, "airlift") })

  -- Launch the next waves
  local launchResults = launchNextWaves(tickCtx, zone, zoneState, heliWave)
  if not launchResults then
    report.emit()
    Logger.error(LogFormat.line("ERROR", { scope = "heliWave", zone = zone.name, reason = "landing_geometry_missing" }))
    return false
  end

  report.addAll(launchResults)
  report.emit()
  return true
end

return HeliWave
