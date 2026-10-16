local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

---Pure lane geometry for the assault approach. Small-area flat-earth approximation:
---positions near the lane center are converted to meters along/across the landing bearing.
local LaneGeometry = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local METERS_PER_DEGREE = 111320
local METERS_PER_NM = 1852

-- ============================================================================
-- Coordinate Conversion
-- ============================================================================

---Convert a geographic position to meters east/north of the frame origin
---@param frame SBJ__LaneFrame
---@param pos CMO__Location
---@return number x Meters east
---@return number y Meters north
local function toLocalXY(frame, pos)
  local originLat, originLon = Utils.toNumber(frame.origin.latitude), Utils.toNumber(frame.origin.longitude)
  local cosLat = math.cos(math.rad(originLat))
  local x = (Utils.toNumber(pos.longitude) - originLon) * METERS_PER_DEGREE * cosLat
  local y = (Utils.toNumber(pos.latitude) - originLat) * METERS_PER_DEGREE
  return x, y
end

---Convert meters east/north of the frame origin back to a geographic position
---@param frame SBJ__LaneFrame
---@param x number
---@param y number
---@return CMO__Location
local function toGeo(frame, x, y)
  local originLat, originLon = Utils.toNumber(frame.origin.latitude), Utils.toNumber(frame.origin.longitude)
  local cosLat = math.cos(math.rad(originLat))
  return {
    latitude = originLat + y / METERS_PER_DEGREE,
    longitude = originLon + x / (METERS_PER_DEGREE * cosLat),
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
  return toGeo(frame, x, y)
end

---Project a position onto lane coordinates
---@param frame SBJ__LaneFrame
---@param pos CMO__Location
---@return number alongM Meters toward shore from the origin
---@return number lateralM Meters to the right of the landing bearing
function LaneGeometry.projectPoint(frame, pos)
  local b = math.rad(frame.bearing)
  local x, y = toLocalXY(frame, pos)
  return x * math.sin(b) + y * math.cos(b), x * math.cos(b) - y * math.sin(b)
end

---Approximate distance between two nearby positions
---@param a CMO__Location
---@param b CMO__Location
---@return number # Meters
function LaneGeometry.calculateDistanceM(a, b)
  local x, y = toLocalXY({ origin = a, bearing = 0 }, b)
  return math.sqrt(x * x + y * y)
end

---Point a fraction of the way from a to b
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

---Build the Type 529 serpentine over the beach lanes: A→S, S→S, S→A, A→A, ...
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
  local deployAlong = -route.deployLineNm * METERS_PER_NM
  local assaultAlong = -route.assaultLineNm * METERS_PER_NM
  local shoreAlong = -route.shoreStandoffM
  local id = "W" .. index

  local waterLane = {
    id = id,
    deployPoint = LaneGeometry.buildPoint(frame, deployAlong, lateralM),
    launchPoint = LaneGeometry.buildPoint(frame, -route.launchLineNm * METERS_PER_NM, lateralM),
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

---Build water lanes (one per Type 529), symmetric about the lane center, ordered left to right
---@param params SBJ__BuildLanesParams
---@return SBJ__LanePlanState
function LaneGeometry.buildLanes(params)
  local frame = { origin = params.origin, bearing = params.bearing }
  local spacing = params.routeConfig.waterLaneSpacingM
  local waterLanes = {}

  for i = 1, params.count do
    local lateralM = (i - (params.count + 1) / 2) * spacing
    table.insert(waterLanes, buildWaterLane(frame, params, i, lateralM))
  end

  return { origin = params.origin, bearing = params.bearing, waterLanes = waterLanes }
end

---Deepest inland reach of a polygon along the landing bearing
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

---Orientation of the triangle p, q, r (positive = counter-clockwise)
---@param p CMO__Location
---@param q CMO__Location
---@param r CMO__Location
---@return number
local function calculateOrientation(p, q, r)
  local pLat, pLon = Utils.toNumber(p.latitude), Utils.toNumber(p.longitude)
  return (Utils.toNumber(q.longitude) - pLon) * (Utils.toNumber(r.latitude) - pLat)
      - (Utils.toNumber(q.latitude) - pLat) * (Utils.toNumber(r.longitude) - pLon)
end

---Whether r lies within the bounding box of segment p-q
---@param p CMO__Location
---@param q CMO__Location
---@param r CMO__Location
---@return boolean
local function isWithinBox(p, q, r)
  local pLat, pLon = Utils.toNumber(p.latitude), Utils.toNumber(p.longitude)
  local qLat, qLon = Utils.toNumber(q.latitude), Utils.toNumber(q.longitude)
  local rLat, rLon = Utils.toNumber(r.latitude), Utils.toNumber(r.longitude)
  return rLon >= math.min(pLon, qLon) and rLon <= math.max(pLon, qLon)
      and rLat >= math.min(pLat, qLat) and rLat <= math.max(pLat, qLat)
end

---Whether segments p1-p2 and q1-q2 intersect, touching included
---@param p1 CMO__Location
---@param p2 CMO__Location
---@param q1 CMO__Location
---@param q2 CMO__Location
---@return boolean
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

---Whether a segment touches any edge of a cell
---@param a CMO__Location
---@param b CMO__Location
---@param cell SBJ__ObstacleCellEntry
---@return boolean
function LaneGeometry.isSegmentTouchingCell(a, b, cell)
  local corners = cell.corners
  for i = 1, #corners do
    if LaneGeometry.segmentsIntersect(a, b, corners[i], corners[i % #corners + 1]) then
      return true
    end
  end
  return false
end

---Tile a polygon with square cells aligned to the lane frame; keeps cells whose center is inside
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

---Whether every cell a route touches is cleared
---@param route CMO__Location[]
---@param cells SBJ__ObstacleCellEntry[]|nil
---@return boolean
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
