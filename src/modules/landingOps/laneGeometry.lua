local constants = require("src.core.constants")
local Utils = require("src.utils.utils")

---Provide pure lane geometry for the assault approach. Use a small-area flat-earth approximation:
---positions near the lane center convert to meters along and across the landing bearing.
local LaneGeometry = {}

-- ============================================================================
-- Coordinate Conversion
-- ============================================================================

---Convert a geographic position to meters east/north of the frame origin
---@param frame SBJ__LaneFrame
---@param pos CMO__Location
---@return number x Meters east
---@return number y Meters north
local function convertToLocalXY(frame, pos)
  local originLat, originLon = Utils.toNumber(frame.origin.latitude), Utils.toNumber(frame.origin.longitude)
  local cosLat = math.cos(math.rad(originLat))
  local x = (Utils.toNumber(pos.longitude) - originLon) * constants.METERS_PER_DEGREE * cosLat
  local y = (Utils.toNumber(pos.latitude) - originLat) * constants.METERS_PER_DEGREE
  return x, y
end

---Convert meters east/north of the frame origin back to a geographic position
---@param frame SBJ__LaneFrame
---@param x number
---@param y number
---@return CMO__Location
local function convertToGeo(frame, x, y)
  local originLat, originLon = Utils.toNumber(frame.origin.latitude), Utils.toNumber(frame.origin.longitude)
  local cosLat = math.cos(math.rad(originLat))
  return {
    latitude = originLat + y / constants.METERS_PER_DEGREE,
    longitude = originLon + x / (constants.METERS_PER_DEGREE * cosLat),
  }
end

---Build a position from lane coordinates
---@param frame SBJ__LaneFrame
---@param alongM number Meters toward shore from the origin (negative = seaward)
---@param lateralM number Meters to the right of the landing bearing
---@return CMO__Location
function LaneGeometry.buildPoint(frame, alongM, lateralM)
  local b = math.rad(frame.bearing)
  local x = alongM * math.sin(b) + lateralM * math.cos(b)
  local y = alongM * math.cos(b) - lateralM * math.sin(b)
  return convertToGeo(frame, x, y)
end

---Project a position onto lane coordinates
---@param frame SBJ__LaneFrame
---@param pos CMO__Location
---@return number alongM Meters toward shore from the origin
---@return number lateralM Meters to the right of the landing bearing
function LaneGeometry.projectPoint(frame, pos)
  local b = math.rad(frame.bearing)
  local x, y = convertToLocalXY(frame, pos)
  return x * math.sin(b) + y * math.cos(b), x * math.cos(b) - y * math.sin(b)
end

---Calculate the approximate distance between two nearby positions
---@param a CMO__Location
---@param b CMO__Location
---@return number # Meters
function LaneGeometry.calculateDistanceM(a, b)
  local x, y = convertToLocalXY({ origin = a, bearing = 0 }, b)
  return math.sqrt(x * x + y * y)
end

---Interpolate a point a fraction of the way from a to b
---@param a CMO__Location
---@param b CMO__Location
---@param fraction number 0 = a, 1 = b
---@return CMO__Location
function LaneGeometry.interpolate(a, b, fraction)
  local aLat, aLon = Utils.toNumber(a.latitude), Utils.toNumber(a.longitude)
  return {
    latitude = aLat + (Utils.toNumber(b.latitude) - aLat) * fraction,
    longitude = aLon + (Utils.toNumber(b.longitude) - aLon) * fraction,
  }
end

-- ============================================================================
-- Lane Layout
-- ============================================================================

---Build the Type 082 serpentine over the beach lanes: A→S, S→S, S→A, A→A, ...
---@param beachLanes SBJ__BeachLaneEntry[]
---@return CMO__Location[]
local function buildSerpentine(beachLanes)
  local course = {}
  for j, beachLane in ipairs(beachLanes) do
    if j % 2 == 1 then
      table.insert(course, beachLane.assaultPoint)
      table.insert(course, beachLane.shorePoint)
    else
      table.insert(course, beachLane.shorePoint)
      table.insert(course, beachLane.assaultPoint)
    end
  end
  return course
end

---Build one water lane and its beach lanes
---@param frame SBJ__LaneFrame
---@param params SBJ__BuildLanesParams
---@param index integer
---@param lateralM number
---@return SBJ__WaterLaneEntry
local function buildWaterLane(frame, params, index, lateralM)
  local route = params.routeConfig
  local deployAlong = -route.deployLineNm * constants.METERS_PER_NM
  local assaultAlong = -route.assaultLineNm * constants.METERS_PER_NM
  local shoreAlong = -route.shoreStandoffM
  local id = "W" .. index

  local waterLane = {
    id = id,
    deployPoint = LaneGeometry.buildPoint(frame, deployAlong, lateralM),
    launchPoint = LaneGeometry.buildPoint(frame, -route.launchLineNm * constants.METERS_PER_NM, lateralM),
    assaultPoint = LaneGeometry.buildPoint(frame, assaultAlong, lateralM),
    beachLanes = {},
  }

  local maxOffset = 0
  for j, offset in ipairs(route.beachLaneOffsetsM) do
    maxOffset = math.max(maxOffset, math.abs(offset))
    table.insert(waterLane.beachLanes, {
      id = id .. "-B" .. j,
      waterLaneId = id,
      assaultPoint = LaneGeometry.buildPoint(frame, assaultAlong, lateralM + offset),
      shorePoint = LaneGeometry.buildPoint(frame, shoreAlong, lateralM + offset),
      endPoint = LaneGeometry.buildPoint(frame, params.inlandDepthM, lateralM + offset),
      isCleared = false,
    })
  end

  local sweepCourse = { waterLane.deployPoint, waterLane.launchPoint, waterLane.assaultPoint }
  for _, point in ipairs(buildSerpentine(waterLane.beachLanes)) do
    table.insert(sweepCourse, point)
  end
  waterLane.sweepCourse = sweepCourse

  local halfWidth = maxOffset + params.areaMarginM
  waterLane.missionArea = {
    LaneGeometry.buildPoint(frame, deployAlong, lateralM - halfWidth),
    LaneGeometry.buildPoint(frame, deployAlong, lateralM + halfWidth),
    LaneGeometry.buildPoint(frame, shoreAlong, lateralM + halfWidth),
    LaneGeometry.buildPoint(frame, shoreAlong, lateralM - halfWidth),
  }

  return waterLane
end

---Check if every step between neighboring values is within [minM, maxM]
---@param values number[]
---@param params SBJ__IsStepRangeValidParams
---@return boolean # True if every step is within [minM, maxM]
local function isStepRangeValid(values, params)
  for i = params.first, params.last - 1 do
    local step = values[i + 1] - values[i]
    if step < params.minM or step > params.maxM then
      return false
    end
  end
  return true
end

---Build the lateral positions of water lanes in the gaps between ships, so no lane runs through a hull.
---Each gap at least waterLaneMinSpacingM wide gives a candidate at its midpoint.
---Choose consecutive candidates whose spacing stays within [waterLaneMinSpacingM, waterLaneMaxSpacingM].
---Among the valid runs, choose the run closest to the lane center.
---@param shipLaterals number[] Lateral positions of the ships, any order
---@param count integer Number of water lanes wanted
---@param routeConfig SBJ__RouteConfig
---@return number[]|nil # Ascending lateral per water lane; nil when no run of gaps qualifies
function LaneGeometry.buildWaterLaneLaterals(shipLaterals, count, routeConfig)
  if count < 1 then
    return nil
  end

  local minM, maxM = routeConfig.waterLaneMinSpacingM, routeConfig.waterLaneMaxSpacingM
  local sorted = { table.unpack(shipLaterals) }
  table.sort(sorted)

  local candidates = {}
  for i = 1, #sorted - 1 do
    if sorted[i + 1] - sorted[i] >= minM then
      table.insert(candidates, (sorted[i] + sorted[i + 1]) / 2)
    end
  end

  local bestFirst, bestOffset = nil, math.huge
  for first = 1, #candidates - count + 1 do
    local last = first + count - 1
    local offset = math.abs((candidates[first] + candidates[last]) / 2)
    if offset < bestOffset and isStepRangeValid(candidates, { first = first, last = last, minM = minM, maxM = maxM }) then
      bestFirst, bestOffset = first, offset
    end
  end

  if not bestFirst then
    return nil
  end
  return { table.unpack(candidates, bestFirst, bestFirst + count - 1) }
end

---Build water lanes (one per Type 082), ordered from left to right.
---Put the lanes at params.laterals when given. Otherwise space them evenly and symmetric about the lane center.
---@param params SBJ__BuildLanesParams
---@return SBJ__LanePlanState
function LaneGeometry.buildLanes(params)
  local frame = { origin = params.origin, bearing = params.bearing }
  local spacing = params.routeConfig.waterLaneSpacingM
  local waterLanes = {}

  for i = 1, params.count do
    local lateralM = params.laterals and params.laterals[i] or (i - (params.count + 1) / 2) * spacing
    table.insert(waterLanes, buildWaterLane(frame, params, i, lateralM))
  end

  return { origin = params.origin, bearing = params.bearing, waterLanes = waterLanes }
end

-- ============================================================================
-- Mine Cells
-- ============================================================================

---Build the corridor of square cells, one cell wide, along the strip from point a to point b
---@param frame SBJ__LaneFrame
---@param params SBJ__BuildMineCorridorParams
---@return SBJ__MineCorridor
local function buildMineCorridor(frame, params)
  local laneId, cellSizeM = params.laneId, params.cellSizeM
  local alongMin, lateralM = LaneGeometry.projectPoint(frame, params.a)
  local alongMax = LaneGeometry.projectPoint(frame, params.b)
  local halfM = cellSizeM / 2

  local cells = {}
  for along = alongMin, alongMax - 1e-6, cellSizeM do
    local nextAlong = math.min(along + cellSizeM, alongMax)
    table.insert(cells, {
      laneId = laneId,
      corners = {
        LaneGeometry.buildPoint(frame, along, lateralM - halfM),
        LaneGeometry.buildPoint(frame, along, lateralM + halfM),
        LaneGeometry.buildPoint(frame, nextAlong, lateralM + halfM),
        LaneGeometry.buildPoint(frame, nextAlong, lateralM - halfM),
      },
    })
  end

  return {
    laneId = laneId,
    alongMin = alongMin,
    alongMax = alongMax,
    lateralM = lateralM,
    halfWidthM = halfM,
    cellSizeM = cellSizeM,
    cells = cells,
  }
end

---Build the lane frame of a lane plan
---@param lanes SBJ__LanePlanState
---@return SBJ__LaneFrame
function LaneGeometry.buildFrame(lanes)
  return { origin = lanes.origin, bearing = lanes.bearing }
end

---Build the mine corridors: cut every water lane (deploy line to assault line) and beach lane (assault line to S_lane) into mine cells.
---The cells line up with the lane center line and are one cell wide, so neighboring lanes never overlap.
---@param lanes SBJ__LanePlanState
---@param cellSizeM number
---@return SBJ__MineCorridor[]
function LaneGeometry.buildMineCorridors(lanes, cellSizeM)
  local frame = LaneGeometry.buildFrame(lanes)
  local corridors = {}

  for _, waterLane in ipairs(lanes.waterLanes) do
    table.insert(corridors, buildMineCorridor(frame, {
      laneId = waterLane.id,
      a = waterLane.deployPoint,
      b = waterLane.assaultPoint,
      cellSizeM = cellSizeM,
    }))
    for _, beachLane in ipairs(waterLane.beachLanes) do
      table.insert(corridors, buildMineCorridor(frame, {
        laneId = beachLane.id,
        a = beachLane.assaultPoint,
        b = beachLane.shorePoint,
        cellSizeM = cellSizeM,
      }))
    end
  end

  return corridors
end

---Find the mine cell that contains a position.
---Check the bounds of each corridor in lane coordinates, then index straight into its cells.
---@param frame SBJ__LaneFrame
---@param corridors SBJ__MineCorridor[]
---@param pos CMO__Location
---@return SBJ__MineCell|nil
function LaneGeometry.findMineCell(frame, corridors, pos)
  local along, lateral = LaneGeometry.projectPoint(frame, pos)

  for _, corridor in ipairs(corridors) do
    if math.abs(lateral - corridor.lateralM) <= corridor.halfWidthM
        and along >= corridor.alongMin and along <= corridor.alongMax then
      local index = math.min(math.floor((along - corridor.alongMin) / corridor.cellSizeM) + 1, #corridor.cells)
      return corridor.cells[index]
    end
  end
  return nil
end

---Calculate the deepest inland reach of a polygon along the landing bearing
---@param frame SBJ__LaneFrame
---@param polygon CMO__Location[]
---@return number # Meters toward shore from the origin
function LaneGeometry.calculateInlandDepthM(frame, polygon)
  local depth = 0
  for _, pos in ipairs(polygon) do
    local along = LaneGeometry.projectPoint(frame, pos)
    depth = math.max(depth, along)
  end
  return depth
end

-- ============================================================================
-- Obstacle Cells
-- ============================================================================

---Calculate the orientation of the triangle p, q, r (positive = counter-clockwise)
---@param p CMO__Location
---@param q CMO__Location
---@param r CMO__Location
---@return number
local function calculateOrientation(p, q, r)
  local pLat, pLon = Utils.toNumber(p.latitude), Utils.toNumber(p.longitude)
  return (Utils.toNumber(q.longitude) - pLon) * (Utils.toNumber(r.latitude) - pLat)
      - (Utils.toNumber(q.latitude) - pLat) * (Utils.toNumber(r.longitude) - pLon)
end

---Check if r lies within the bounding box of segment p-q
---@param p CMO__Location
---@param q CMO__Location
---@param r CMO__Location
---@return boolean # True if r lies within the bounding box of p-q
local function isWithinBox(p, q, r)
  local pLat, pLon = Utils.toNumber(p.latitude), Utils.toNumber(p.longitude)
  local qLat, qLon = Utils.toNumber(q.latitude), Utils.toNumber(q.longitude)
  local rLat, rLon = Utils.toNumber(r.latitude), Utils.toNumber(r.longitude)
  return rLon >= math.min(pLon, qLon) and rLon <= math.max(pLon, qLon)
      and rLat >= math.min(pLat, qLat) and rLat <= math.max(pLat, qLat)
end

---Check if segments p1-p2 and q1-q2 intersect, touching included
---@param p1 CMO__Location
---@param p2 CMO__Location
---@param q1 CMO__Location
---@param q2 CMO__Location
---@return boolean # True if the segments intersect, touching included
function LaneGeometry.segmentsIntersect(p1, p2, q1, q2)
  local d1 = calculateOrientation(q1, q2, p1)
  local d2 = calculateOrientation(q1, q2, p2)
  local d3 = calculateOrientation(p1, p2, q1)
  local d4 = calculateOrientation(p1, p2, q2)

  if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)) then
    return true
  end

  return (d1 == 0 and isWithinBox(q1, q2, p1))
      or (d2 == 0 and isWithinBox(q1, q2, p2))
      or (d3 == 0 and isWithinBox(p1, p2, q1))
      or (d4 == 0 and isWithinBox(p1, p2, q2))
end

---Check if a segment touches any edge of a cell
---@param a CMO__Location
---@param b CMO__Location
---@param cell SBJ__ObstacleCellEntry
---@return boolean # True if the segment touches any edge of the cell
function LaneGeometry.isSegmentTouchingCell(a, b, cell)
  local corners = cell.corners
  for i = 1, #corners do
    if LaneGeometry.segmentsIntersect(a, b, corners[i], corners[i % #corners + 1]) then
      return true
    end
  end
  return false
end

---Build square cells aligned to the lane frame that tile a polygon. Keep the cells whose center is inside
---@param frame SBJ__LaneFrame
---@param polygon CMO__Location[]
---@param cellSizeM number
---@return SBJ__ObstacleCellEntry[]
function LaneGeometry.buildObstacleCells(frame, polygon, cellSizeM)
  local cells = {}
  if #polygon < 3 then
    return cells
  end

  local minAlong, maxAlong, minLateral, maxLateral = math.huge, -math.huge, math.huge, -math.huge
  for _, pos in ipairs(polygon) do
    local along, lateral = LaneGeometry.projectPoint(frame, pos)
    minAlong, maxAlong = math.min(minAlong, along), math.max(maxAlong, along)
    minLateral, maxLateral = math.min(minLateral, lateral), math.max(maxLateral, lateral)
  end

  local startAlong = math.floor(minAlong / cellSizeM) * cellSizeM
  local startLateral = math.floor(minLateral / cellSizeM) * cellSizeM

  for along = startAlong, maxAlong, cellSizeM do
    for lateral = startLateral, maxLateral, cellSizeM do
      local center = LaneGeometry.buildPoint(frame, along + cellSizeM / 2, lateral + cellSizeM / 2)
      if Utils.isPointInPolygon(center, polygon) then
        table.insert(cells, {
          corners = {
            LaneGeometry.buildPoint(frame, along, lateral),
            LaneGeometry.buildPoint(frame, along, lateral + cellSizeM),
            LaneGeometry.buildPoint(frame, along + cellSizeM, lateral + cellSizeM),
            LaneGeometry.buildPoint(frame, along + cellSizeM, lateral),
          },
          state = constants.OBSTACLE_CELL_STATES.INTACT,
        })
      end
    end
  end

  return cells
end

---Check if every cell that a route touches is cleared
---@param route CMO__Location[]
---@param cells SBJ__ObstacleCellEntry[]|nil
---@return boolean # True if every cell the route touches is cleared
function LaneGeometry.isRouteClear(route, cells)
  for _, cell in ipairs(cells or {}) do
    if cell.state ~= constants.OBSTACLE_CELL_STATES.CLEARED then
      for i = 1, #route - 1 do
        if LaneGeometry.isSegmentTouchingCell(route[i], route[i + 1], cell) then
          return false
        end
      end
    end
  end
  return true
end

return LaneGeometry
