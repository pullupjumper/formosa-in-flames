local constants = require("src.core.constants")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")

---Build courses through the swept lanes for assault boats, ACVs and hovercraft.
---This module is pure apart from the state tables it receives (queue counters and parking slots).
local RoutePlanner = {}

-- ============================================================================
-- Constants
-- ============================================================================

local SAME_POINT_M = 1 -- lane points closer than this to the entry are the entry

-- ============================================================================
-- Lane Selection
-- ============================================================================

---Sort water lanes by a distance measure. The lanes within the tie band of the nearest lane come first,
---least-loaded first
---@param waterLanes SBJ__WaterLaneEntry[]
---@param loads table<string, integer> Units already routed per water lane id
---@param tieM number
---@param measure fun(waterLane: SBJ__WaterLaneEntry): number
---@return SBJ__WaterLaneEntry[]
local function sortByMeasure(waterLanes, loads, tieM, measure)
  local entries = {}
  local nearest = math.huge
  for _, waterLane in ipairs(waterLanes) do
    local distance = measure(waterLane)
    nearest = math.min(nearest, distance)
    table.insert(entries, { waterLane = waterLane, distance = distance, load = loads[waterLane.id] or 0 })
  end

  local tieLimit = nearest + tieM
  table.sort(entries, function(a, b)
    local aTied, bTied = a.distance <= tieLimit, b.distance <= tieLimit
    if aTied ~= bTied then return aTied end
    if aTied and a.load ~= b.load then return a.load < b.load end
    return a.distance < b.distance
  end)

  local sorted = {}
  for _, entry in ipairs(entries) do
    table.insert(sorted, entry.waterLane)
  end
  return sorted
end

---Create the per-zone lane load tables when missing
---@param zoneState SBJ__ZoneState
function RoutePlanner.ensureLaneState(zoneState)
  zoneState.queueCounters = zoneState.queueCounters or {}
  zoneState.laneSlots = zoneState.laneSlots or {}
end

---Sort water lanes by distance from the launch position. The lanes within the tie band of the
---nearest lane come first, least-loaded first
---@param launchPos CMO__Location
---@param waterLanes SBJ__WaterLaneEntry[]
---@param loads table<string, integer> Units already routed per water lane id
---@param laneTieNm number
---@return SBJ__WaterLaneEntry[]
function RoutePlanner.sortWaterLanes(launchPos, waterLanes, loads, laneTieNm)
  return sortByMeasure(waterLanes, loads, laneTieNm * constants.METERS_PER_NM, function(waterLane)
    return LaneGeometry.calculateDistanceM(launchPos, waterLane.launchPoint)
  end)
end

---Sort water lanes by sideways distance from the launch position. A unit released beside the
---lane field then takes an adjacent lane and never crosses the gap of another ship
---@param waterLanes SBJ__WaterLaneEntry[]
---@param params SBJ__SideApproachParams
---@return SBJ__WaterLaneEntry[]
function RoutePlanner.sortWaterLanesByLateral(waterLanes, params)
  local frame = LaneGeometry.buildFrame(params.lanes)
  local _, launchLateral = LaneGeometry.projectPoint(frame, params.launchPos)
  return sortByMeasure(waterLanes, params.queueCounters, params.routeConfig.laneTieM, function(waterLane)
    local _, lateral = LaneGeometry.projectPoint(frame, waterLane.launchPoint)
    return math.abs(lateral - launchLateral)
  end)
end

---Select the water lane for a launch position
---@param launchPos CMO__Location
---@param waterLanes SBJ__WaterLaneEntry[]
---@param loads table<string, integer>
---@param laneTieNm number
---@return SBJ__WaterLaneEntry|nil
function RoutePlanner.selectWaterLane(launchPos, waterLanes, loads, laneTieNm)
  return RoutePlanner.sortWaterLanes(launchPos, waterLanes, loads, laneTieNm)[1]
end

---Find a beach lane by id
---@param lanes SBJ__LanePlanState
---@param beachLaneId string
---@return SBJ__WaterLaneEntry|nil waterLane
---@return SBJ__BeachLaneEntry|nil beachLane
function RoutePlanner.findBeachLane(lanes, beachLaneId)
  for _, waterLane in ipairs(lanes.waterLanes) do
    for _, beachLane in ipairs(waterLane.beachLanes) do
      if beachLane.id == beachLaneId then
        return waterLane, beachLane
      end
    end
  end
  return nil, nil
end

-- ============================================================================
-- Queueing
-- ============================================================================

---Update the queue counter of a water lane and return its previous value
---Each call moves the counter, so units released together get staggered entry points.
---@param waterLane SBJ__WaterLaneEntry
---@param queueCounters table<string, integer>
---@return integer # Queue index of the unit, counted from 0
local function updateQueueIndex(waterLane, queueCounters)
  local k = queueCounters[waterLane.id] or 0
  queueCounters[waterLane.id] = k + 1
  return k
end

---Calculate the distance that a queued unit backs off toward open sea
---@param k integer
---@param routeConfig SBJ__RouteConfig
---@return number
local function calculateBackoffM(k, routeConfig)
  return (k % routeConfig.queueDepth) * routeConfig.columnSpacingM
end

---Build the approach for units released far offshore: entry on the launch→deploy stretch, then L_i and A_i
---@param waterLane SBJ__WaterLaneEntry
---@param k integer
---@param routeConfig SBJ__RouteConfig
---@return CMO__Location[]
local function buildDeployApproach(waterLane, k, routeConfig)
  local laneLengthM = LaneGeometry.calculateDistanceM(waterLane.launchPoint, waterLane.deployPoint)
  local t = laneLengthM > 0 and math.min(calculateBackoffM(k, routeConfig) / laneLengthM, 1) or 0
  local entryPoint = LaneGeometry.interpolate(waterLane.launchPoint, waterLane.deployPoint, t)
  return { entryPoint, waterLane.launchPoint, waterLane.assaultPoint }
end

---Build the approach for units released beside the lane: enter the lane abeam of the launch position,
---then use only the lane points still ahead (toward shore). Only the queue stagger sends the unit
---back out to sea, and the entry never goes seaward of the deploy line.
---@param waterLane SBJ__WaterLaneEntry
---@param k integer
---@param params SBJ__SideApproachParams
---@return CMO__Location[]
local function buildSideApproach(waterLane, k, params)
  local frame = LaneGeometry.buildFrame(params.lanes)
  local launchAlong, laneLateral = LaneGeometry.projectPoint(frame, waterLane.launchPoint)
  local deployAlong = LaneGeometry.projectPoint(frame, waterLane.deployPoint)
  local assaultAlong = LaneGeometry.projectPoint(frame, waterLane.assaultPoint)
  local shipAlong = LaneGeometry.projectPoint(frame, params.launchPos)

  local entryAlong = shipAlong - calculateBackoffM(k, params.routeConfig)
  entryAlong = math.max(deployAlong, math.min(entryAlong, assaultAlong))

  local approach = { LaneGeometry.buildPoint(frame, entryAlong, laneLateral) }
  if launchAlong > entryAlong + SAME_POINT_M then
    table.insert(approach, waterLane.launchPoint)
  end
  if assaultAlong > entryAlong + SAME_POINT_M then
    table.insert(approach, waterLane.assaultPoint)
  end
  return approach
end

---Count the parking slots between E_lane and A_lane
---@param beachLane SBJ__BeachLaneEntry
---@param routeConfig SBJ__RouteConfig
---@return integer
local function countSlots(beachLane, routeConfig)
  local lengthM = LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.assaultPoint)
  return math.floor(lengthM / routeConfig.queueSpacingM) + 1
end

---Build the position of a parking slot: slot 1 at E_lane, each next slot queueSpacingM further back toward A_lane
---@param beachLane SBJ__BeachLaneEntry
---@param slot integer
---@param routeConfig SBJ__RouteConfig
---@return CMO__Location pos
---@return number backoffM Distance from E_lane
local function buildSlotPoint(beachLane, slot, routeConfig)
  local lengthM = LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.assaultPoint)
  local backoffM = (slot - 1) * routeConfig.queueSpacingM
  local t = lengthM > 0 and backoffM / lengthM or 0
  return LaneGeometry.interpolate(beachLane.endPoint, beachLane.assaultPoint, t), backoffM
end

---Find the first free parking slot in a beach lane.
---A slot is free when it is empty, held by this unit, or held by a unit that no longer exists.
---@param beachLane SBJ__BeachLaneEntry
---@param slots table<integer, string|false>|nil
---@param params SBJ__BuildRouteParams
---@return integer|nil
function RoutePlanner.findFreeSlot(beachLane, slots, params)
  slots = slots or {}
  for slot = 1, countSlots(beachLane, params.routeConfig) do
    local holder = slots[slot]
    if not holder or holder == params.guid or not params.isAlive(holder) then
      return slot
    end
  end
  return nil
end

---Assign the parking slot that lies on S_lane to an assault boat.
---The boat stays at S_lane after it lands, so the slot nearest to it is not free for other units.
---@param beachLaneId string
---@param params SBJ__AssignShoreSlotParams
---@return boolean # True if the slot was assigned, false when the beach lane id is unknown
function RoutePlanner.assignShoreSlot(beachLaneId, params)
  local _, beachLane = RoutePlanner.findBeachLane(params.lanes, beachLaneId)
  if not beachLane then
    return false
  end

  local shoreToEndM = LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.shorePoint)
  local slot = math.min(
    math.floor(shoreToEndM / params.routeConfig.queueSpacingM + 0.5) + 1,
    countSlots(beachLane, params.routeConfig))
  local slots = params.laneSlots[beachLaneId] or {}
  -- Fill the gap below with false. A sparse table saves as a JSON object, and its integer keys load back as strings
  for i = #slots + 1, slot - 1 do
    slots[i] = false
  end
  slots[slot] = params.guid
  params.laneSlots[beachLaneId] = slots
  return true
end

-- ============================================================================
-- Course Building
-- ============================================================================

---Build the course to a parking slot: [approach..., A_lane, (S_lane), slot]
---@param approach CMO__Location[]
---@param beachLane SBJ__BeachLaneEntry
---@param slot {point: CMO__Location, backoffM: number}
---@return CMO__Location[]
local function buildSlotCourse(approach, beachLane, slot)
  local course = { table.unpack(approach) }
  table.insert(course, beachLane.assaultPoint)
  if slot.backoffM < LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.shorePoint) then
    table.insert(course, beachLane.shorePoint)
  end
  table.insert(course, slot.point)
  return course
end

---Build the cleared beach lanes of a water lane, rotated so that each new unit starts at the next lane
---@param waterLane SBJ__WaterLaneEntry
---@param k integer
---@return SBJ__BeachLaneEntry[]
local function buildRotatedClearedBeachLanes(waterLane, k)
  local cleared = {}
  for _, beachLane in ipairs(waterLane.beachLanes) do
    if beachLane.isCleared then
      table.insert(cleared, beachLane)
    end
  end

  local rotated = {}
  for i = 1, #cleared do
    table.insert(rotated, cleared[(k + i - 1) % #cleared + 1])
  end
  return rotated
end

---Check if a water lane has at least one cleared beach lane
---@param waterLane SBJ__WaterLaneEntry
---@return boolean # True if the water lane has at least one cleared beach lane
local function hasClearedBeachLane(waterLane)
  for _, beachLane in ipairs(waterLane.beachLanes) do
    if beachLane.isCleared then
      return true
    end
  end
  return false
end

---Build a route in one water lane: try every cleared beach lane and reserve the first slot whose course is clear
---@param waterLane SBJ__WaterLaneEntry
---@param params SBJ__BuildRouteParams
---@param opts SBJ__BuildRouteOpts|nil
---@return SBJ__RoutePlanResult|nil
local function buildInWaterLane(waterLane, params, opts)
  local k = updateQueueIndex(waterLane, params.queueCounters)
  local isFromDeployLine = opts and opts.isFromDeployLine
  local approach
  if isFromDeployLine then
    approach = buildDeployApproach(waterLane, k, params.routeConfig)
  else
    approach = buildSideApproach(waterLane, k, params)
  end

  for _, beachLane in ipairs(buildRotatedClearedBeachLanes(waterLane, k)) do
    local slots = params.laneSlots[beachLane.id] or {}
    local slot = RoutePlanner.findFreeSlot(beachLane, slots, params)

    if slot then
      local slotPoint, backoffM = buildSlotPoint(beachLane, slot, params.routeConfig)
      local course = buildSlotCourse(approach, beachLane, { point = slotPoint, backoffM = backoffM })
      if isFromDeployLine then
        table.insert(course, 1, waterLane.deployPoint)
      end

      if LaneGeometry.isRouteClear(course, params.cells) then
        slots[slot] = params.guid
        params.laneSlots[beachLane.id] = slots
        return { course = course, waterLaneId = waterLane.id, beachLaneId = beachLane.id, slot = slot }
      end
    end
  end

  return nil
end

---Build a course through the cleared lanes to a parking slot and reserve that slot.
---Try the water lanes nearest first. Full or blocked lanes fall through to the next lane.
---@param params SBJ__BuildRouteParams
---@param opts? SBJ__BuildRouteOpts
---@return SBJ__RoutePlanResult|nil # nil when no cleared lane has a free slot
function RoutePlanner.buildRoute(params, opts)
  local candidates = {}
  for _, waterLane in ipairs(params.lanes.waterLanes) do
    if hasClearedBeachLane(waterLane) then
      table.insert(candidates, waterLane)
    end
  end

  local sorted
  if opts and opts.isFromDeployLine then
    sorted = RoutePlanner.sortWaterLanes(
      params.launchPos, candidates, params.queueCounters, params.routeConfig.laneTieNm)
  else
    sorted = RoutePlanner.sortWaterLanesByLateral(candidates, params)
  end

  for _, waterLane in ipairs(sorted) do
    local plan = buildInWaterLane(waterLane, params, opts)
    if plan then
      return plan
    end
  end

  return nil
end

---Build the course for an assault boat to its paired beach lane: [entry, (L_i), (A_i), A_lane, S_lane].
---Ignore the obstacle state. The boat is the unit that goes ashore to clear it.
---@param beachLaneId string
---@param params SBJ__SideApproachParams launchPos is where the boat is released
---@return CMO__Location[]|nil # nil when the beach lane id is unknown
function RoutePlanner.buildBoatRoute(beachLaneId, params)
  local waterLane, beachLane = RoutePlanner.findBeachLane(params.lanes, beachLaneId)
  if not waterLane or not beachLane then
    return nil
  end

  local k = updateQueueIndex(waterLane, params.queueCounters)
  local course = buildSideApproach(waterLane, k, params)
  table.insert(course, beachLane.assaultPoint)
  table.insert(course, beachLane.shorePoint)
  return course
end

return RoutePlanner
