local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local constants = require("src.core.constants")
local DebugFlow = require("src.modules.landingOps.debugFlow")

local AssaultBoat = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local STATUS = {
  PENDING  = "pending",
  LAUNCHED = "launched",
  ARRIVED  = "arrived",
  LOST     = "lost",
}

---@type table<number, true>
local BOAT_CARRIER_DBIDS = {
  [constants.PLATFORMS.TYPE_072A]   = true,
  [constants.PLATFORMS.TYPE_072III] = true,
}

-- ============================================================================
-- Pairing
-- ============================================================================

---Find boat carriers anchored in the zone with their assault boat GUIDs, left to right
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param ships CMO__SideUnit[]
---@return {guid: string, lateral: number, boats: string[]}[]
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

---Pick count items spread evenly across a list
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

---Pick boats: every carrier's first boat, then second boats, ... until lanes are covered
---@param carriers {guid: string, lateral: number, boats: string[]}[]
---@param laneCount integer
---@return {boatGuid: string, shipGuid: string, lateral: number}[] # Ordered left to right
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

---Sum of lateral gaps when pairing picks and lanes in order
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

---Beach lanes left to right; when boats are short, drop the outermost lanes on the cheaper side
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
-- Public API
-- ============================================================================

---Pair assault boats with beach lanes once, by lateral order, and store the pairing in zoneState.boats
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ships CMO__SideUnit[]
---@return boolean # Always true; a zone without boats just has nothing to launch
function AssaultBoat.pairBoats(zone, zoneState, ships)
  local lanes = zoneState.lanes

  if not lanes then
    return false
  end

  local frame = { origin = lanes.origin, bearing = lanes.bearing }
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

---Launch paired boats whose carrier has entered the ACV staging area: course first, then Launch
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
function AssaultBoat.launchBoats(amphibOps, zone, zoneState)
  zoneState.queueCounters = zoneState.queueCounters or {}
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Launch assault boats")

  for boatGuid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING then
      local ship = GameApi.ScenEdit_GetUnit(entry.shipGuid)
      local boat = GameApi.ScenEdit_GetUnit(boatGuid)

      if ship and boat and boat.readytime_v == 0 and ship:inArea(zone.landing.acv.area) then
        local course = RoutePlanner.buildBoatRoute(
          zoneState.lanes,
          entry.beachLaneId,
          { latitude = ship.latitude, longitude = ship.longitude },
          zoneState.queueCounters,
          amphibOps.tuning.route
        )

        if course then
          boat.course = course
          boat.manualSpeed = amphibOps.tuning.assaultBoat.speed
          boat:Launch(true)
          entry.status = STATUS.LAUNCHED
          entry.finalPoint = course[#course]
          if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT) then
            DebugFlow.teleport(boatGuid, entry.finalPoint)
          end
          report.add("OK", { boat = boatGuid, beachLane = entry.beachLaneId })
        end
      end
    end
  end

  report.emit()
end

---Track boats until each reaches S_lane or is lost
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@return boolean # True when no boat is still pending or under way
function AssaultBoat.updateBoats(amphibOps, zoneState)
  local arrivalNm = amphibOps.tuning.route.arrivalNm
  local isAllDone = true

  for boatGuid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.PENDING or entry.status == STATUS.LAUNCHED then
      local boat = GameApi.ScenEdit_GetUnit(boatGuid)
      local range = boat and entry.finalPoint and GameApi.Tool_Range(boatGuid, entry.finalPoint)

      if not boat then
        entry.status = STATUS.LOST
      elseif range and range < arrivalNm then
        entry.status = STATUS.ARRIVED
      else
        isAllDone = false
      end
    end
  end

  return isAllDone
end

---Beach lanes with a landed boat that is still alive
---@param zoneState SBJ__ZoneState
---@return table<string, true>
function AssaultBoat.findLandedLaneIdSet(zoneState)
  local laneIdSet = {}
  for boatGuid, entry in pairs(zoneState.boats or {}) do
    if entry.status == STATUS.ARRIVED and GameApi.ScenEdit_GetUnit(boatGuid) then
      laneIdSet[entry.beachLaneId] = true
    end
  end
  return laneIdSet
end

return AssaultBoat
