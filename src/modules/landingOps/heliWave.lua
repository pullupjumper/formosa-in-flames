local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")

---Fly the zone's helicopters in waves. A wave is a group of transport helicopters with attack helicopter escorts.
---It launches from the motherships, flies out along the left and right wings, and goes inland to its landing points.
---Transports unload and return. Escorts loiter until every transport of the wave is done.
---The next wave launches only after the wave in the air has finished or timed out.
local HeliWave = {}

-- ============================================================================
-- Constants
-- ============================================================================

---@enum SBJ__HeliRoleType
local ROLE = {
  TRANSPORT = "transport",
  ATTACK    = "attack",
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
  LOITERING = "loitering",
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
  local points = GameUtils.findAreaLocations(constants.SIDES.RED, zone.air.landingZone)
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

---Build the course of one wing: sideways to the wing, along it past the shore, then to the wing's landing point
---@param flightCtx SBJ__HeliFlightContext
---@param startPos CMO__Location
---@param wing SBJ__HeliWingType
---@return CMO__Waypoint[] course
local function buildWingCourse(flightCtx, startPos, wing)
  local frame, center, heliConfig = flightCtx.frame, flightCtx.center, flightCtx.heliConfig
  local sign = WING_SIGN[wing]
  local startAlong = LaneGeometry.projectPoint(frame, startPos)
  local centerAlong, centerLateral = LaneGeometry.projectPoint(frame, center)
  local wingLateral = sign * heliConfig.wingOffsetM

  return {
    LaneGeometry.buildPoint(frame, startAlong, wingLateral),
    LaneGeometry.buildPoint(frame, heliConfig.inlandEntryM, wingLateral),
    LaneGeometry.buildPoint(frame, centerAlong, centerLateral + sign * heliConfig.landingSpreadM),
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

-- ============================================================================
-- Wave Launch
-- ============================================================================

---Launch one helicopter along its wing course
---@param heli CMO__Unit
---@param role SBJ__HeliRoleType
---@param wing SBJ__HeliWingType
---@param flightCtx SBJ__HeliFlightContext
---@return SBJ__HeliState
local function launchHeli(heli, role, wing, flightCtx)
  local course = buildWingCourse(flightCtx, { latitude = heli.latitude, longitude = heli.longitude }, wing)
  course[1].desiredAltitude = flightCtx.heliConfig.cruiseAltitudeM
  heli:Launch(true)
  heli.course = course
  heli.throttle = constants.THROTTLES.MILITARY
  GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.RED, guid = heli.guid }, { automatic_evasion = false })

  return { role = role, wing = wing, phase = PHASE.ENROUTE, landingPoint = course[#course] }
end

---Launch a group of helicopters, alternating left and right wing
---@param helis CMO__Unit[]
---@param role SBJ__HeliRoleType
---@param unitMap table<string, SBJ__HeliState> Wave units, filled in
---@param flightCtx SBJ__HeliFlightContext
local function launchGroup(helis, role, unitMap, flightCtx)
  for i, heli in ipairs(helis) do
    local wing = i % 2 == 1 and WING.LEFT or WING.RIGHT
    unitMap[heli.guid] = launchHeli(heli, role, wing, flightCtx)
  end
end

---Count the units of a wave by role
---@param unitMap table<string, SBJ__HeliState>
---@param role SBJ__HeliRoleType
---@return integer
local function countRole(unitMap, role)
  local count = 0
  for _, entry in pairs(unitMap) do
    if entry.role == role then
      count = count + 1
    end
  end
  return count
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
  launchGroup(selectRandom(transports, flightCtx.heliConfig.waveSize), ROLE.TRANSPORT, unitMap, flightCtx)
  launchGroup(selectRandom(attackers, flightCtx.heliConfig.escortSize), ROLE.ATTACK, unitMap, flightCtx)

  state.units = unitMap
  state.waveIndex = state.waveIndex + 1
  state.waveLaunchedAt = tickCtx.currentTime
  state.isWaitingLogged = false

  return {
    tag = "OK",
    fields = {
      zone = zone.name,
      wave = state.waveIndex,
      transports = countRole(unitMap, ROLE.TRANSPORT),
      attackers = countRole(unitMap, ROLE.ATTACK),
    },
  }
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

---Find the helicopters of the wave that are alive and not yet on their way home
---@param unitMap table<string, SBJ__HeliState>
---@return table<string, CMO__Unit> # Alive helicopters indexed by GUID
local function findFlyingHelis(unitMap)
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

---Check if every transport of the wave is done: back on its way home or destroyed
---@param unitMap table<string, SBJ__HeliState>
---@return boolean # True if no transport is still in the air
local function isTransportsDone(unitMap)
  for guid in pairs(findFlyingHelis(unitMap)) do
    if unitMap[guid].role == ROLE.TRANSPORT then
      return false
    end
  end
  return true
end

---Check if the wave is over: every helicopter is on its way home or destroyed
---@param unitMap table<string, SBJ__HeliState>
---@return boolean # True if no helicopter of the wave is still in the air
local function isWaveDone(unitMap)
  return next(findFlyingHelis(unitMap)) == nil
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

---Update one attack helicopter on its way to the loiter point
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param arrivalNm number
local function updateAttacker(heli, entry, arrivalNm)
  if entry.phase == PHASE.ENROUTE and hasArrived(heli, entry, arrivalNm) then
    entry.phase = PHASE.LOITERING
  end
end

---Move home every helicopter of the wave still in the air, or only the escorts
---@param unitMap table<string, SBJ__HeliState>
---@param role? SBJ__HeliRoleType Only move helicopters of this role; nil moves them all
local function moveHomeWave(unitMap, role)
  for guid, heli in pairs(findFlyingHelis(unitMap)) do
    if not role or unitMap[guid].role == role then
      moveHome(heli, unitMap[guid])
    end
  end
end

---Update every helicopter of the wave. Escorts go home once the transports are done
---@param unitMap table<string, SBJ__HeliState>
---@param arrivalNm number
local function updateUnits(unitMap, arrivalNm)
  for guid, entry in pairs(unitMap) do
    local heli = GameApi.ScenEdit_GetUnit(guid)
    if heli and entry.role == ROLE.TRANSPORT then
      updateTransport(heli, entry, arrivalNm)
    elseif heli then
      updateAttacker(heli, entry, arrivalNm)
    end
  end

  if isTransportsDone(unitMap) then
    moveHomeWave(unitMap, ROLE.ATTACK)
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Schedule the first wave when the boat assault begins. It launches early enough to reach the landing
---points when the boats reach the shore.
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
    isFinished = false,
  }

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
  if not state or state.isFinished then
    return true
  end

  local heliConfig = getHeliConfig(tickCtx)
  updateUnits(state.units, heliConfig.arrivalNm)

  -- A transport stuck unloading is moved home too, so it cannot block the next wave
  if state.waveLaunchedAt and tickCtx.currentTime - state.waveLaunchedAt >= heliConfig.waveTimeoutSec and
      not isWaveDone(state.units) then
    moveHomeWave(state.units)
    Logger.warn(LogFormat.line("WARN",
      { scope = "heliWave", zone = zone.name, wave = state.waveIndex, reason = "wave_timeout" }))
  end

  if not isWaveDone(state.units) then
    return true
  end

  if state.waveIndex >= #zone.air.transportHelicopter.missions then
    state.isFinished = true
    return true
  end

  if state.waveIndex == 0 and not GameUtils.isAfterStartTime(state.launchAt) then
    return true
  end

  local flightCtx = buildFlightContext(zone, zoneState, heliConfig)
  if not flightCtx then
    Logger.error(LogFormat.line("ERROR", { scope = "heliWave", zone = zone.name, reason = "landing_geometry_missing" }))
    return false
  end

  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "heliWave", "launchWave")
  report.addAll({ launchWave(tickCtx, zone, state, flightCtx) })
  report.emit()

  return true
end

return HeliWave
