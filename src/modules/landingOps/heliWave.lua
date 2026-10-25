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

local ROLE = {
  TRANSPORT = "transport",
  ATTACK    = "attack",
}

local WING = {
  LEFT  = "left",
  RIGHT = "right",
}

---Lateral direction of each wing, facing the shore
---@type table<string, integer>
local WING_SIGN = {
  [WING.LEFT]  = -1,
  [WING.RIGHT] = 1,
}

local PHASE = {
  ENROUTE   = "enroute",
  UNLOADING = "unloading",
  LOITERING = "loitering",
  RETURNING = "returning",
}

---@type table<number, true>
local MOTHERSHIP_DBIDS = {
  [constants.PLATFORMS.TYPE_075] = true,
  [constants.PLATFORMS.TYPE_076] = true,
  [constants.PLATFORMS.TYPE_071] = true,
}

local METERS_PER_NM = 1852
local SECONDS_PER_HOUR = 3600

-- ============================================================================
-- Candidates
-- ============================================================================

---Check if a unit carries any cargo
---@param unit CMO__Unit
---@return boolean
local function hasCargo(unit)
  return unit.cargo ~= nil and unit.cargo[1] ~= nil and unit.cargo[1].cargo ~= nil and #unit.cargo[1].cargo > 0
end

---Find the motherships anchored in the zone
---@param zone SBJ__OperationalZoneDescriptor
---@param ships CMO__SideUnit[]
---@return CMO__Unit[]
local function findMotherships(zone, ships)
  local motherships = {}

  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)
    if ship and MOTHERSHIP_DBIDS[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) then
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
  local transportDbid, attackDbid = zone.air.transportHelicopter.dbid, zone.air.attackHelicopter.dbid

  for _, ship in ipairs(motherships) do
    local embarked = ship.embarkedUnits and ship.embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT] or {}

    for _, guid in ipairs(embarked) do
      local heli = GameApi.ScenEdit_GetUnit(guid)
      if heli and heli.readytime_v == 0 then
        if heli.dbid == transportDbid and hasCargo(heli) then
          table.insert(transports, heli)
        elseif heli.dbid == attackDbid then
          table.insert(attackers, heli)
        end
      end
    end
  end

  return transports, attackers
end

---Pick count items at random
---@generic T
---@param items T[]
---@param count integer
---@return T[]
local function pickRandom(items, count)
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
  for _, p in ipairs(points) do
    latSum = latSum + Utils.toNumber(p.latitude)
    lonSum = lonSum + Utils.toNumber(p.longitude)
  end
  return { latitude = latSum / #points, longitude = lonSum / #points }
end

---Build the course of one wing: sideways to the wing, along it past the shore, then to the wing's landing point
---@param plan SBJ__HeliFlightPlan
---@param startPos CMO__Location
---@param wing string
---@return CMO__Waypoint[] course
local function buildWingCourse(plan, startPos, wing)
  local frame, center, heliConfig = plan.frame, plan.center, plan.heliConfig
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
---@return SBJ__HeliFlightPlan|nil # nil when the lanes or the landing zone are missing
local function buildFlightPlan(zone, zoneState, heliConfig)
  local center = findLandingCenter(zone)
  if not (zoneState.lanes and center) then
    return nil
  end

  return {
    frame = { origin = zoneState.lanes.origin, bearing = zoneState.lanes.bearing },
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

---Estimate when the paired assault boats reach the shore line.
---The farthest carrier sails to the outer edge of the launch station band, then its boats run in to the shore.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@param currentTime number
---@return number # Time of the boat arrival
local function estimateBoatArrivalTime(amphibOps, zoneState, currentTime)
  local lanes = zoneState.lanes
  if not lanes then
    return currentTime
  end

  local frame = { origin = lanes.origin, bearing = lanes.bearing }
  local route = amphibOps.tuning.route
  local farthestNm = 0

  for _, entry in pairs(zoneState.boats or {}) do
    local carrier = GameApi.ScenEdit_GetUnit(entry.shipGuid)
    if carrier then
      local along = LaneGeometry.projectPoint(frame, carrier)
      farthestNm = math.max(farthestNm, -along / METERS_PER_NM)
    end
  end

  local sailHours = math.max(0, farthestNm - route.launchStationFarNm) / amphibOps.formation.shipSpeed
  local runInNm = route.launchStationFarNm - route.shoreStandoffM / METERS_PER_NM
  local runHours = runInNm / amphibOps.tuning.assaultBoat.speed

  return currentTime + (sailHours + runHours) * SECONDS_PER_HOUR
end

---Estimate the flight time of a wave from the first mothership along the longer wing
---@param plan SBJ__HeliFlightPlan|nil
---@param motherships CMO__Unit[]
---@return number # Seconds. 0 when the route cannot be built
local function estimateFlightSec(plan, motherships)
  local start = motherships[1]
  if not (plan and start) then
    return 0
  end

  local startPos = { latitude = start.latitude, longitude = start.longitude }
  local longestM = 0
  for _, wing in pairs(WING) do
    longestM = math.max(longestM, calculateCourseLengthM(startPos, buildWingCourse(plan, startPos, wing)))
  end

  return longestM / METERS_PER_NM / plan.heliConfig.cruiseSpeedKt * SECONDS_PER_HOUR
end

-- ============================================================================
-- Wave Launch
-- ============================================================================

---Launch one helicopter along its wing course
---@param heli CMO__Unit
---@param role string
---@param wing string
---@param plan SBJ__HeliFlightPlan
---@return SBJ__HeliState
local function launchHeli(heli, role, wing, plan)
  local course = buildWingCourse(plan, { latitude = heli.latitude, longitude = heli.longitude }, wing)
  course[1].desiredAltitude = 304
  heli:Launch(true)
  heli.course = course
  heli.throttle = "Military"
  GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.RED, guid = heli.guid }, { automatic_evasion = false })

  return { role = role, wing = wing, phase = PHASE.ENROUTE, landingPoint = course[#course] }
end

---Launch a group of helicopters, alternating left and right wing
---@param helis CMO__Unit[]
---@param role string
---@param units table<string, SBJ__HeliState> Wave units, filled in
---@param plan SBJ__HeliFlightPlan
local function launchGroup(helis, role, units, plan)
  for i, heli in ipairs(helis) do
    local wing = i % 2 == 1 and WING.LEFT or WING.RIGHT
    units[heli.guid] = launchHeli(heli, role, wing, plan)
  end
end

---Count the units of a wave by role
---@param units table<string, SBJ__HeliState>
---@param role string
---@return integer
local function countRole(units, role)
  local count = 0
  for _, entry in pairs(units) do
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
---@param plan SBJ__HeliFlightPlan
local function launchWave(tickCtx, zone, state, plan)
  local transports, attackers = findCandidates(zone, findMotherships(zone, tickCtx.filteredShips))
  if #transports == 0 then
    if not state.isWaitingLogged then
      state.isWaitingLogged = true
      Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT,
        LogFormat.line("WAIT", { scope = "heliWave", zone = zone.name, reason = "no_loaded_transport" }))
    end
    return
  end

  local units = {}
  launchGroup(pickRandom(transports, plan.heliConfig.waveSize), ROLE.TRANSPORT, units, plan)
  launchGroup(pickRandom(attackers, plan.heliConfig.escortSize), ROLE.ATTACK, units, plan)

  state.units = units
  state.waveIndex = state.waveIndex + 1
  state.waveLaunchedAt = tickCtx.currentTime
  state.isWaitingLogged = false

  Logger.log(constants.TAGS.AMPHIBIOUS_ASSAULT, LogFormat.line("OK", {
    scope = "heliWave",
    zone = zone.name,
    wave = state.waveIndex,
    transports = countRole(units, ROLE.TRANSPORT),
    attackers = countRole(units, ROLE.ATTACK),
  }))
end

-- ============================================================================
-- Wave Progress
-- ============================================================================

---Send a helicopter home
---@param heli CMO__Unit
---@param entry SBJ__HeliState
local function sendHome(heli, entry)
  heli:RTB(true)
  entry.phase = PHASE.RETURNING
end

---Check if every transport of the wave is done: back on its way home or destroyed
---@param units table<string, SBJ__HeliState>
---@return boolean
local function areTransportsDone(units)
  for guid, entry in pairs(units) do
    if entry.role == ROLE.TRANSPORT and entry.phase ~= PHASE.RETURNING and GameApi.ScenEdit_GetUnit(guid) then
      return false
    end
  end
  return true
end

---Move one transport through unloading
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param arrivalNm number
local function advanceTransport(heli, entry, arrivalNm)
  if entry.phase == PHASE.ENROUTE then
    local range = GameApi.Tool_Range(heli.guid, entry.landingPoint)
    if range and range < arrivalNm then
      GameApi.ScenEdit_UnloadCargo(heli.guid)
      entry.phase = PHASE.UNLOADING
    end
  elseif entry.phase == PHASE.UNLOADING and GameUtils.isCargoUnloaded(heli) then
    sendHome(heli, entry)
  end
end

---Move one attack helicopter to its loiter point
---@param heli CMO__Unit
---@param entry SBJ__HeliState
---@param arrivalNm number
local function advanceAttacker(heli, entry, arrivalNm)
  if entry.phase == PHASE.ENROUTE then
    local range = GameApi.Tool_Range(heli.guid, entry.landingPoint)
    if range and range < arrivalNm then
      entry.phase = PHASE.LOITERING
    end
  end
end

---Advance every helicopter of the wave. Escorts go home once the transports are done
---@param units table<string, SBJ__HeliState>
---@param arrivalNm number
local function advanceUnits(units, arrivalNm)
  for guid, entry in pairs(units) do
    local heli = GameApi.ScenEdit_GetUnit(guid)
    if heli and entry.role == ROLE.TRANSPORT then
      advanceTransport(heli, entry, arrivalNm)
    elseif heli then
      advanceAttacker(heli, entry, arrivalNm)
    end
  end

  if areTransportsDone(units) then
    for guid, entry in pairs(units) do
      local heli = entry.role == ROLE.ATTACK and entry.phase ~= PHASE.RETURNING and GameApi.ScenEdit_GetUnit(guid)
      if heli then
        sendHome(heli, entry)
      end
    end
  end
end

---Send home every helicopter of the wave still in the air
---@param units table<string, SBJ__HeliState>
local function recallWave(units)
  for guid, entry in pairs(units) do
    local heli = entry.phase ~= PHASE.RETURNING and GameApi.ScenEdit_GetUnit(guid)
    if heli then
      sendHome(heli, entry)
    end
  end
end

---Check if the wave is over: every helicopter is on its way home or destroyed
---@param units table<string, SBJ__HeliState>
---@return boolean
local function isWaveDone(units)
  for guid, entry in pairs(units) do
    if entry.phase ~= PHASE.RETURNING and GameApi.ScenEdit_GetUnit(guid) then
      return false
    end
  end
  return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Plan the first wave when the boat assault begins. It launches early enough to reach the landing
---points when the boats reach the shore.
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
function HeliWave.schedule(tickCtx, zone, zoneState)
  local amphibOps, currentTime = tickCtx.config.red.amphibOps, tickCtx.currentTime
  local plan = buildFlightPlan(zone, zoneState, amphibOps.tuning.heliWave)
  local boatArrivalAt = estimateBoatArrivalTime(amphibOps, zoneState, currentTime)
  local flightSec = estimateFlightSec(plan, findMotherships(zone, tickCtx.filteredShips))

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
end

---Run the helicopter waves of a zone for one tick. Do nothing before the wave plan exists
---@param tickCtx SBJ__LandingTickContext
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
function HeliWave.update(tickCtx, zone, zoneState)
  local state = zoneState.heliWave
  if not state or state.isFinished then
    return
  end

  local heliConfig = tickCtx.config.red.amphibOps.tuning.heliWave
  advanceUnits(state.units, heliConfig.arrivalNm)

  if state.waveLaunchedAt and tickCtx.currentTime - state.waveLaunchedAt >= heliConfig.waveTimeoutSec and
      not isWaveDone(state.units) then
    recallWave(state.units)
    Logger.warn(LogFormat.line("WARN",
      { scope = "heliWave", zone = zone.name, wave = state.waveIndex, reason = "wave_timeout" }))
  end

  if not isWaveDone(state.units) then
    return
  end

  if state.waveIndex >= #zone.air.transportHelicopter.missions then
    state.isFinished = true
    return
  end

  if state.waveIndex == 0 and not GameUtils.isAfterStartTime(state.launchAt) then
    return
  end

  local plan = buildFlightPlan(zone, zoneState, heliConfig)
  if not plan then
    Logger.error(LogFormat.line("ERROR", { scope = "heliWave", zone = zone.name, reason = "landing_geometry_missing" }))
    return
  end

  launchWave(tickCtx, zone, state, plan)
end

return HeliWave
