local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")
local AssaultBoat = {}

-- ============================================================================
-- Constants
-- ============================================================================

local STATUS = {
  PENDING  = "pending",
  LAUNCHED = "launched",
  ARRIVED  = "arrived",
}

---@type table<number, true>
local BOAT_CARRIER_DBIDS = {
  [constants.PLATFORMS.TYPE_072A]   = true,
  [constants.PLATFORMS.TYPE_072III] = true,
}

-- ============================================================================
-- Pairing
-- ============================================================================

---Find the boat carriers anchored in the zone with their assault boat GUIDs, from left to right
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param ships CMO__SideUnit[]
---@return SBJ__BoatCarrier[]
local function findCarriers(zone, frame, ships)
  local carriers = {}

  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)
    if ship and BOAT_CARRIER_DBIDS[ship.dbid] and ship:inArea(zone.movement.holdingAreas.deployLine) then
      local boats = {}
      local embarked = ship.embarkedUnits and ship.embarkedUnits[constants.PLATFORM_TYPES.BOATS] or {}
      for _, guid in ipairs(embarked) do
        local boat = GameApi.ScenEdit_GetUnit(guid)
        if boat and boat.dbid == constants.PLATFORMS.ASSAULT_BOAT then
          table.insert(boats, guid)
        end
      end

      if #boats > 0 then
        local _, lateral = LaneGeometry.projectPoint(frame, ship)
        table.insert(carriers, { guid = ship.guid, lateral = lateral, boats = boats })
      end
    end
  end

  table.sort(carriers, function(a, b) return a.lateral < b.lateral end)
  return carriers
end

---Select count items spread evenly across a list
---@generic T
---@param items T[]
---@param count integer
---@return T[]
local function selectEvenly(items, count)
  local selected = {}
  for j = 1, count do
    table.insert(selected, items[math.floor((j - 0.5) * #items / count) + 1])
  end
  return selected
end

---Select boats: first the first boat of every carrier, then the second boats, until the lanes are covered
---@param carriers SBJ__BoatCarrier[]
---@param laneCount integer
---@return SBJ__BoatPick[] # Ordered left to right
local function selectBoats(carriers, laneCount)
  local picks = {}
  local round = 1

  while #picks < laneCount do
    local roundBoats = {}
    for _, carrier in ipairs(carriers) do
      if carrier.boats[round] then
        table.insert(roundBoats, { boatGuid = carrier.boats[round], shipGuid = carrier.guid, lateral = carrier.lateral })
      end
    end
    if #roundBoats == 0 then break end

    local needed = laneCount - #picks
    for _, pick in ipairs(#roundBoats > needed and selectEvenly(roundBoats, needed) or roundBoats) do
      table.insert(picks, pick)
    end
    round = round + 1
  end

  table.sort(picks, function(a, b) return a.lateral < b.lateral end)
  return picks
end

---Calculate the sum of lateral gaps when the picks and lanes pair in order
---@param picks {lateral: number}[]
---@param lanes {lateral: number}[]
---@return number
local function calculatePairingCost(picks, lanes)
  local cost = 0
  for i, pick in ipairs(picks) do
    cost = cost + math.abs(pick.lateral - lanes[i].lateral)
  end
  return cost
end

---Select beach lanes from left to right. When boats are short, drop the outermost lanes on the cheaper side
---@param lanes SBJ__LanePlanState
---@param frame SBJ__LaneFrame
---@param picks {lateral: number}[]
---@return {id: string, lateral: number}[]
local function selectBeachLanes(lanes, frame, picks)
  local all = {}
  for _, waterLane in ipairs(lanes.waterLanes) do
    for _, beachLane in ipairs(waterLane.beachLanes) do
      local _, lateral = LaneGeometry.projectPoint(frame, beachLane.assaultPoint)
      table.insert(all, { id = beachLane.id, lateral = lateral })
    end
  end

  local drop = #all - #picks
  if drop <= 0 then
    return all
  end

  local keepLeft, keepRight = {}, {}
  for i = 1, #picks do
    keepLeft[i] = all[i]
    keepRight[i] = all[i + drop]
  end
  return calculatePairingCost(picks, keepLeft) <= calculatePairingCost(picks, keepRight) and keepLeft or keepRight
end

-- ============================================================================
-- Launch
-- ============================================================================

---Check if a carrier may launch its boats: it is in the ACV staging area
---@param zone SBJ__OperationalZoneDescriptor
---@param carrier CMO__Unit
---@return boolean
local function isCarrierAtLaunch(zone, carrier)
  return carrier:inArea(zone.landing.acv.area)
end

---Estimate the seconds until a carrier's boat reaches S_lane.
---A carrier at launch launches now. Any other carrier is assumed to sail to the outer edge of the station band first,
---since the shape of the staging area is not known here
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param carrier CMO__Unit
---@return number
local function estimateRunSec(amphibOps, zone, frame, carrier)
  local route = amphibOps.tuning.route
  local offshoreNm = -LaneGeometry.projectPoint(frame, carrier) / constants.METERS_PER_NM
  local launchNm = offshoreNm
  if not isCarrierAtLaunch(zone, carrier) then
    launchNm = math.min(offshoreNm, route.launchStationFarNm)
  end

  local sailHours = (offshoreNm - launchNm) / amphibOps.formation.shipSpeed
  local runHours = math.max(0, launchNm - route.shoreStandoffM / constants.METERS_PER_NM) / amphibOps.tuning.assaultBoat.speed

  return (sailHours + runHours) * constants.SECONDS_PER_HOUR
end

-- ============================================================================
-- Public API
-- ============================================================================

---Pair assault boats with beach lanes once, by lateral order. Store the pairing in zoneState.boats
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ships CMO__SideUnit[]
---@return boolean # Always true. A zone without boats has nothing to launch
function AssaultBoat.pairBoats(zone, zoneState, ships)
  local lanes = zoneState.lanes

  if not lanes then
    return false
  end

  local frame = LaneGeometry.buildFrame(lanes)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Pair assault boats")

  local laneCount = 0
  for _, waterLane in ipairs(lanes.waterLanes) do
    laneCount = laneCount + #waterLane.beachLanes
  end

  local picks = selectBoats(findCarriers(zone, frame, ships), laneCount)
  local beachLanes = selectBeachLanes(lanes, frame, picks)

  zoneState.boats = {}
  for i, pick in ipairs(picks) do
    zoneState.boats[pick.boatGuid] = { shipGuid = pick.shipGuid, beachLaneId = beachLanes[i].id, status = STATUS.PENDING }
    report.add("OK", { boat = pick.boatGuid, beachLane = beachLanes[i].id })
  end
  if #picks < laneCount then
    report.add("WARN", { reason = "boats_short", boats = #picks, beachLanes = laneCount })
  end

  report.emit()
  return true
end

---Launch paired boats whose carrier entered the ACV staging area. Set the course first, then launch
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
function AssaultBoat.launchBoats(amphibOps, zone, zoneState)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Launch assault boats")

  for boatGuid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING then
      local ship = GameApi.ScenEdit_GetUnit(entry.shipGuid)
      local boat = TrackedUnits.findUnit(zoneState, boatGuid)

      if ship and boat and boat.readytime_v == 0 and isCarrierAtLaunch(zone, ship) then
        local course = RoutePlanner.reserveBoatCourse(zoneState, entry.beachLaneId, {
          guid = boatGuid,
          launchPos = { latitude = ship.latitude, longitude = ship.longitude },
          routeConfig = amphibOps.tuning.route,
        })

        if course then
          boat.course = course
          boat.manualSpeed = amphibOps.tuning.assaultBoat.speed
          boat:Launch(true)
          entry.status = STATUS.LAUNCHED
          entry.finalPoint = course[#course]
          report.add("OK", { boat = boatGuid, beachLane = entry.beachLaneId })
        end
      end
    end
  end

  report.emit()
end

---Estimate when the last pending boat reaches S_lane, by the same launch rule as launchBoats
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param currentTime number
---@return number # Time of the arrival. currentTime when no boat is pending
function AssaultBoat.estimateShoreArrival(amphibOps, zone, zoneState, currentTime)
  local lanes = zoneState.lanes
  if not lanes then
    return currentTime
  end

  local frame = LaneGeometry.buildFrame(lanes)
  local arrivalAt = currentTime

  for _, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING then
      local carrier = GameApi.ScenEdit_GetUnit(entry.shipGuid)
      if carrier then
        arrivalAt = math.max(arrivalAt, currentTime + estimateRunSec(amphibOps, zone, frame, carrier))
      end
    end
  end

  return arrivalAt
end

---Update boats until each one reaches S_lane. A boat that is no longer found no longer holds the zone back
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@return boolean # True when no boat is still pending or under way
function AssaultBoat.updateBoats(amphibOps, zoneState)
  local arrivalNm = amphibOps.tuning.route.arrivalNm
  local isAllDone = true

  for guid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING or entry.status == STATUS.LAUNCHED then
      local boat = TrackedUnits.findUnit(zoneState, guid)

      if boat and DebugFlow.isFastForward(amphibOps, zoneState.phase) then
        boat.course = nil
        DebugFlow.teleport(guid, entry.finalPoint)
      end

      local range = boat and entry.finalPoint and GameApi.Tool_Range(guid, entry.finalPoint)

      if range and range < arrivalNm then
        entry.status = STATUS.ARRIVED
      elseif boat then
        isAllDone = false
      end
    end
  end

  return isAllDone
end

---Check if any paired boat is still waiting on its carrier
---@param zoneState SBJ__ZoneState
---@return boolean # True if a paired boat has not launched yet
function AssaultBoat.hasPendingBoats(zoneState)
  for _, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING then
      return true
    end
  end

  return false
end

---Find the beach lanes with a landed boat that is still alive
---@param zoneState SBJ__ZoneState
---@return table<string, true>
function AssaultBoat.findLandedLaneIdSet(zoneState)
  local laneIdSet = {}
  for boatGuid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.ARRIVED and TrackedUnits.findUnit(zoneState, boatGuid) then
      laneIdSet[entry.beachLaneId] = true
    end
  end
  return laneIdSet
end

return AssaultBoat
