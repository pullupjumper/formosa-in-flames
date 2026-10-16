local LaneGeometry = require("src.modules.landingOps.laneGeometry")

---Plans courses through the swept lanes for assault boats, ACVs and hovercraft.
---Pure apart from the state tables it is handed (queue counters and parking slots).
local RoutePlanner = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local METERS_PER_NM = 1852

-- ============================================================================
-- Lane Selection
-- ============================================================================

---Order water lanes by distance from the launch position; lanes within the tie band of the
---nearest come first, least-loaded first
---@param launchPos CMO__Location
---@param waterLanes SBJ__WaterLaneEntry[]
---@param loads table<string, integer> Units already routed per water lane id
---@param laneTieNm number
---@return SBJ__WaterLaneEntry[]
function RoutePlanner.sortWaterLanes(launchPos, waterLanes, loads, laneTieNm)
  local entries = {}
  local nearest = math.huge
  for _, waterLane in ipairs(waterLanes) do
    local distance = LaneGeometry.calculateDistanceM(launchPos, waterLane.launchPoint)
    nearest = math.min(nearest, distance)
    table.insert(entries, { waterLane = waterLane, distance = distance, load = loads[waterLane.id] or 0 })
  end

  local tieLimit = nearest + laneTieNm * METERS_PER_NM
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

---Pick the water lane for a launch position
---@param launchPos CMO__Location
---@param waterLanes SBJ__WaterLaneEntry[]
---@param loads table<string, integer>
---@param laneTieNm number
---@return SBJ__WaterLaneEntry|nil
function RoutePlanner.chooseWaterLane(launchPos, waterLanes, loads, laneTieNm)
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

---Take the next queue entry point for a water lane (line abreast → column)
---Each call moves the counter, so units released together enter the lane at staggered points.
---@param waterLane SBJ__WaterLaneEntry
---@param queueCounters table<string, integer>
---@param routeConfig SBJ__RouteConfig
---@return CMO__Location entryPoint
---@return integer k Counter value used for this unit
local function takeEntryPoint(waterLane, queueCounters, routeConfig)
  local k = queueCounters[waterLane.id] or 0
  queueCounters[waterLane.id] = k + 1

  local backoffM = (k % routeConfig.queueDepth) * routeConfig.columnSpacingM
  local laneLengthM = LaneGeometry.calculateDistanceM(waterLane.launchPoint, waterLane.deployPoint)
  local t = laneLengthM > 0 and math.min(backoffM / laneLengthM, 1) or 0
  return LaneGeometry.interpolate(waterLane.launchPoint, waterLane.deployPoint, t), k
end

---Number of parking slots between E_lane and A_lane
---@param beachLane SBJ__BeachLaneEntry
---@param routeConfig SBJ__RouteConfig
---@return integer
local function countSlots(beachLane, routeConfig)
  local lengthM = LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.assaultPoint)
  return math.floor(lengthM / routeConfig.queueSpacingM) + 1
end

---Position of a parking slot: slot 1 at E_lane, each next one queueSpacingM back toward A_lane
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

---Find the first free parking slot in a beach lane
---A slot is free when empty, held by this unit, or held by a unit that no longer exists.
---@param beachLane SBJ__BeachLaneEntry
---@param slots table<integer, string>|nil
---@param params SBJ__BuildRouteParams
---@return integer|nil
function RoutePlanner.findFreeSlot(beachLane, slots, params)
  slots = slots or {}
  for slot = 1, countSlots(beachLane, params.routeConfig) do
    local holder = slots[slot]
    if holder == nil or holder == params.guid or not params.isAlive(holder) then
      return slot
    end
  end
  return nil
end

-- ============================================================================
-- Course Building
-- ============================================================================

---Course to a parking slot: [entry, L_i, A_i, A_lane, (S_lane), slot]
---@param waterLane SBJ__WaterLaneEntry
---@param beachLane SBJ__BeachLaneEntry
---@param entryPoint CMO__Location
---@param slot {point: CMO__Location, backoffM: number}
---@return CMO__Location[]
local function buildSlotCourse(waterLane, beachLane, entryPoint, slot)
  local course = { entryPoint, waterLane.launchPoint, waterLane.assaultPoint, beachLane.assaultPoint }
  if slot.backoffM < LaneGeometry.calculateDistanceM(beachLane.endPoint, beachLane.shorePoint) then
    table.insert(course, beachLane.shorePoint)
  end
  table.insert(course, slot.point)
  return course
end

---Cleared beach lanes of a water lane, rotated so each new unit starts at the next one
---@param waterLane SBJ__WaterLaneEntry
---@param k integer
---@return SBJ__BeachLaneEntry[]
local function rotateClearedBeachLanes(waterLane, k)
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

---Whether a water lane has at least one cleared beach lane
---@param waterLane SBJ__WaterLaneEntry
---@return boolean
local function hasClearedBeachLane(waterLane)
  for _, beachLane in ipairs(waterLane.beachLanes) do
    if beachLane.isCleared then
      return true
    end
  end
  return false
end

---Try every cleared beach lane of one water lane; reserve the first slot whose course is clear
---@param waterLane SBJ__WaterLaneEntry
---@param params SBJ__BuildRouteParams
---@param opts SBJ__BuildRouteOpts|nil
---@return SBJ__RoutePlanResult|nil
local function planInWaterLane(waterLane, params, opts)
  local entryPoint, k = takeEntryPoint(waterLane, params.queueCounters, params.routeConfig)

  for _, beachLane in ipairs(rotateClearedBeachLanes(waterLane, k)) do
    local slots = params.laneSlots[beachLane.id] or {}
    local slot = RoutePlanner.findFreeSlot(beachLane, slots, params)

    if slot then
      local slotPoint, backoffM = buildSlotPoint(beachLane, slot, params.routeConfig)
      local course = buildSlotCourse(waterLane, beachLane, entryPoint, { point = slotPoint, backoffM = backoffM })
      if opts and opts.isFromDeployLine then
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

---Plan a course through cleared lanes to a parking slot and reserve that slot
---Water lanes are tried nearest first; full or blocked lanes fall through to the next.
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

  local sorted = RoutePlanner.sortWaterLanes(
    params.launchPos, candidates, params.queueCounters, params.routeConfig.laneTieNm)

  for _, waterLane in ipairs(sorted) do
    local plan = planInWaterLane(waterLane, params, opts)
    if plan then
      return plan
    end
  end

  return nil
end

---Course for an assault boat to its paired beach lane: [entry, L_i, A_i, A_lane, S_lane]
---Ignores obstacle state; the boat is the one going ashore to clear it.
---@param lanes SBJ__LanePlanState
---@param beachLaneId string
---@param queueCounters table<string, integer>
---@param routeConfig SBJ__RouteConfig
---@return CMO__Location[]|nil # nil when the beach lane id is unknown
function RoutePlanner.buildBoatRoute(lanes, beachLaneId, queueCounters, routeConfig)
  local waterLane, beachLane = RoutePlanner.findBeachLane(lanes, beachLaneId)
  if not waterLane or not beachLane then
    return nil
  end

  local entryPoint = takeEntryPoint(waterLane, queueCounters, routeConfig)
  return { entryPoint, waterLane.launchPoint, waterLane.assaultPoint, beachLane.assaultPoint, beachLane.shorePoint }
end

return RoutePlanner
