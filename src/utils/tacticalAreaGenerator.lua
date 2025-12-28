local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local TacticalAreaGenerator = {}

-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---Generate a random square center within valid bounds of internal rectangle
---@param centerLat number Center latitude of internal rectangle
---@param centerLon number Center longitude of internal rectangle
---@param maxOffsetX number Maximum offset in X direction (perpendicular to opening)
---@param maxOffsetY number Maximum offset in Y direction (parallel to opening)
---@param openingAngle number Opening direction in degrees
---@return CMO__Location # Random center point
local function generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle)
  -- Random offset in X direction (perpendicular to opening)
  local offsetX = (math.random() * 2 - 1) * maxOffsetX
  -- Random offset in Y direction (parallel to opening, negative = away from opening)
  local offsetY = (math.random() * 2 - 1) * maxOffsetY

  -- Move from center by offsetX perpendicular to opening direction
  local tempPos = GameApi.World_GetPointFromBearing({
    latitude = centerLat,
    longitude = centerLon,
    bearing = (90 + openingAngle) % 360,
    distance = offsetX
  })

  -- Then move by offsetY parallel to opening direction
  return GameApi.World_GetPointFromBearing({
    latitude = tempPos.latitude,
    longitude = tempPos.longitude,
    bearing = (180 + openingAngle) % 360,
    distance = offsetY
  })
end

---Check if a fire point square overlaps with U-shape bounding box
---@param squareLat number Fire point center latitude
---@param squareLon number Fire point center longitude
---@param centerLat number U-shape center latitude
---@param centerLon number U-shape center longitude
---@param uShapeMaxDist number U-shape maximum distance from center
---@param squareSize number Fire point square size
---@param margin number Safety margin
---@return boolean # True if overlaps with U-shape
local function checkFirePointOverlapsWithUShape(squareLat, squareLon, centerLat, centerLon, uShapeMaxDist, squareSize,
                                                margin)
  local distanceToCenter = GameUtils.calculateDistance(centerLat, centerLon, squareLat, squareLon)

  -- Check if square is too close to U-shape
  -- Square should be outside U-shape bounding box plus its own half diagonal
  local halfSquare = squareSize / 2
  local squareDiagonal = math.sqrt(2) * halfSquare
  local minSafeDistance = uShapeMaxDist + squareDiagonal + margin

  return distanceToCenter < minSafeDistance
end

---Calculate center point of square from four vertices
---@param vertices CMO__Location[] Four vertices of the square
---@return CMO__Location # Center point coordinates
local function calculateSquareCenter(vertices)
  assert(#vertices == 4, "Square must have exactly 4 vertices")

  local sumLat = 0
  local sumLon = 0
  for _, vertex in ipairs(vertices) do
    sumLat = sumLat + vertex.latitude
    sumLon = sumLon + vertex.longitude
  end

  return {
    latitude = sumLat / 4,
    longitude = sumLon / 4
  }
end

---Check if a point is inside a square area defined by vertices
---Uses distance-based approximation suitable for geographic coordinates
---@param pointLat number Point latitude
---@param pointLon number Point longitude
---@param squareVertices CMO__Location[] Four vertices of the square
---@return boolean # True if point is inside the square
local function isPointInSquare(pointLat, pointLon, squareVertices)
  assert(#squareVertices == 4, "Square must have exactly 4 vertices")

  local squareCenter = calculateSquareCenter(squareVertices)
  local centerLat = squareCenter.latitude
  local centerLon = squareCenter.longitude

  -- Calculate distance from point to square center
  local distToCenter = GameUtils.calculateDistance(centerLat, centerLon, pointLat, pointLon)

  -- Calculate square's half-diagonal (approximate radius)
  local squareSize = GameUtils.calculateDistance(
    squareVertices[1].latitude, squareVertices[1].longitude,
    squareVertices[2].latitude, squareVertices[2].longitude
  )
  local squareRadius = math.sqrt(2) * squareSize / 2

  -- Point is inside if distance to center is less than half-diagonal
  -- This treats the square as a circle (conservative approximation)
  return distToCenter < (squareRadius * 0.85) -- 0.85 factor to approximate square inscribed circle
end

---Check if a line segment intersects with a square area
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param squareVertices CMO__Location[] Four vertices of the square
---@param margin number Safety margin in nautical miles
---@return boolean # True if path intersects the square
local function checkPathIntersectsSquare(startLat, startLon, endLat, endLon, squareVertices, margin)
  local squareCenter = calculateSquareCenter(squareVertices)
  local centerLat = squareCenter.latitude
  local centerLon = squareCenter.longitude

  -- Calculate square size and effective radius with margin
  local squareSize = GameUtils.calculateDistance(
    squareVertices[1].latitude, squareVertices[1].longitude,
    squareVertices[2].latitude, squareVertices[2].longitude
  )
  local squareRadius = (math.sqrt(2) * squareSize / 2) + margin

  -- Calculate distances from endpoints to square center
  local startDist = GameUtils.calculateDistance(centerLat, centerLon, startLat, startLon)
  local endDist = GameUtils.calculateDistance(centerLat, centerLon, endLat, endLon)

  -- Quick rejection: if both endpoints are far from square
  if startDist > (squareRadius * 2) and endDist > (squareRadius * 2) then
    return false
  end

  -- Calculate minimum distance from square center to the line segment
  -- Using parametric line representation: P(t) = start + t * (end - start), t ∈ [0,1]

  -- Vector from start to end
  local dx = endLat - startLat
  local dy = endLon - startLon

  -- Vector from start to center
  local fx = centerLat - startLat
  local fy = centerLon - startLon

  -- Project center onto line segment
  local segmentLengthSq = dx * dx + dy * dy

  if segmentLengthSq < 0.0000001 then
    -- Start and end are essentially the same point
    return startDist < squareRadius
  end

  local t = (fx * dx + fy * dy) / segmentLengthSq
  t = math.max(0, math.min(1, t)) -- Clamp to [0,1]

  -- Closest point on segment to center
  local closestLat = startLat + t * dx
  local closestLon = startLon + t * dy

  -- Distance from center to closest point on segment
  local minDist = GameUtils.calculateDistance(centerLat, centerLon, closestLat, closestLon)

  -- Path intersects if minimum distance is less than square radius
  return minDist < squareRadius
end

---Generate avoidance waypoint to bypass a square obstacle
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param squareVertices CMO__Location[] Four vertices of the obstacle square
---@param avoidanceDistance number Distance to detour around obstacle in nautical miles
---@return CMO__Location # Avoidance waypoint coordinates
local function generateSquareAvoidanceWaypoint(startLat, startLon, endLat, endLon, squareVertices, avoidanceDistance)
  local squareCenter = calculateSquareCenter(squareVertices)
  local centerLat = squareCenter.latitude
  local centerLon = squareCenter.longitude

  -- Calculate path midpoint
  local midLat = (startLat + endLat) / 2
  local midLon = (startLon + endLon) / 2

  -- Calculate bearing from path midpoint to obstacle center
  local bearingToObstacle = GameApi.Tool_Bearing(
    { latitude = midLat, longitude = midLon },
    { latitude = centerLat, longitude = centerLon }
  )

  -- Calculate two candidate avoidance points (perpendicular to the obstacle direction)
  local leftBearing = (bearingToObstacle + 90) % 360
  local rightBearing = (bearingToObstacle - 90 + 360) % 360

  local leftWaypoint = GameApi.World_GetPointFromBearing({
    latitude = centerLat,
    longitude = centerLon,
    bearing = leftBearing,
    distance = avoidanceDistance
  })

  local rightWaypoint = GameApi.World_GetPointFromBearing({
    latitude = centerLat,
    longitude = centerLon,
    bearing = rightBearing,
    distance = avoidanceDistance
  })

  -- Choose the waypoint that results in shorter total path length
  local leftPathLength = GameUtils.calculateDistance(startLat, startLon, leftWaypoint.latitude, leftWaypoint.longitude) +
      GameUtils.calculateDistance(leftWaypoint.latitude, leftWaypoint.longitude, endLat, endLon)

  local rightPathLength = GameUtils.calculateDistance(startLat, startLon, rightWaypoint.latitude,
        rightWaypoint.longitude) +
      GameUtils.calculateDistance(rightWaypoint.latitude, rightWaypoint.longitude, endLat, endLon)

  if leftPathLength < rightPathLength then
    return leftWaypoint
  else
    return rightWaypoint
  end
end

---Check if a line segment intersects with U-shape wall area
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param uShapeCenterLat number U-shape center latitude
---@param uShapeCenterLon number U-shape center longitude
---@param uShapeMaxDist number U-shape maximum distance from center (outer radius)
---@param uShapeInnerDist number U-shape inner rectangle approximate radius
---@param margin number Safety margin in nautical miles
---@return boolean # True if path intersects U-shape wall
local function checkPathIntersectsUShape(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                         uShapeMaxDist, uShapeInnerDist, margin)
  -- Calculate distances from start and end points to U-shape center
  local startDist = GameUtils.calculateDistance(uShapeCenterLat, uShapeCenterLon, startLat, startLon)
  local endDist = GameUtils.calculateDistance(uShapeCenterLat, uShapeCenterLon, endLat, endLon)

  -- If both points are inside the inner area, no avoidance needed
  -- (path stays within U-shape interior)
  if startDist < uShapeInnerDist and endDist < uShapeInnerDist then
    return false
  end

  -- If both points are far outside, check path midpoint
  if startDist > (uShapeMaxDist + margin) and endDist > (uShapeMaxDist + margin) then
    return false
  end

  -- Otherwise, check multiple sample points along the path
  -- This catches paths that are tangent to or cross through U-shape
  local numSamples = 5
  for i = 0, numSamples do
    local t = i / numSamples
    local sampleLat = startLat + t * (endLat - startLat)
    local sampleLon = startLon + t * (endLon - startLon)
    local sampleDist = GameUtils.calculateDistance(uShapeCenterLat, uShapeCenterLon, sampleLat, sampleLon)

    -- Check if sample point is in the wall area (between inner and outer boundaries)
    if sampleDist > uShapeInnerDist and sampleDist < (uShapeMaxDist + margin) then
      return true
    end
  end

  return false
end

---Generate avoidance waypoint to bypass U-shape
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param uShapeCenterLat number U-shape center latitude
---@param uShapeCenterLon number U-shape center longitude
---@param openingAngle number U-shape opening direction in degrees
---@param avoidanceDistance number Distance to detour around U-shape in nautical miles
---@return CMO__Location # Avoidance waypoint coordinates
local function generateAvoidanceWaypoint(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                         openingAngle, avoidanceDistance)
  -- Calculate bearing from U-shape center to path midpoint
  local midLat = (startLat + endLat) / 2
  local midLon = (startLon + endLon) / 2

  local bearingToMid = GameApi.Tool_Bearing(
    { latitude = uShapeCenterLat, longitude = uShapeCenterLon },
    { latitude = midLat, longitude = midLon }
  )

  -- Determine if we should route through the opening or around the sides
  -- Calculate angle difference between path and opening
  local angleDiff = math.abs((bearingToMid - openingAngle + 180) % 360 - 180)

  -- If path crosses through opening area (within 90 degrees of opening direction), use opening
  -- Otherwise, route around the opposite side
  local avoidanceBearing
  if angleDiff < 90 then
    -- Route through opening
    avoidanceBearing = openingAngle
  else
    -- Route around the side opposite to the opening
    avoidanceBearing = (openingAngle + 180) % 360
  end

  -- Generate waypoint at avoidance distance from U-shape center
  return GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = avoidanceBearing,
    distance = avoidanceDistance
  })
end

---Generate path with optional U-shape avoidance waypoint
---Creates a waypoint array from start to end, inserting avoidance waypoint if needed
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param uShapeCenterLat number U-shape center latitude
---@param uShapeCenterLon number U-shape center longitude
---@param uShapeMaxDist number U-shape maximum distance from center
---@param uShapeInnerDist number U-shape inner rectangle approximate radius
---@param openingAngle number U-shape opening direction in degrees
---@param avoidanceMargin number Safety margin for intersection check
---@param avoidanceDistance number Distance for avoidance waypoint
---@return SBJ__PathWaypoint[] # Array of waypoints forming the path
local function generatePathWithAvoidance(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                         uShapeMaxDist, uShapeInnerDist, openingAngle, avoidanceMargin,
                                         avoidanceDistance)
  local waypoints = {}

  -- Add start waypoint
  table.insert(waypoints, {
    latitude = startLat,
    longitude = startLon
  })

  -- Check if direct path intersects U-shape
  local intersectsUShape = checkPathIntersectsUShape(
    startLat, startLon, endLat, endLon,
    uShapeCenterLat, uShapeCenterLon,
    uShapeMaxDist, uShapeInnerDist, avoidanceMargin
  )

  if intersectsUShape then
    local avoidanceWp = generateAvoidanceWaypoint(
      startLat, startLon, endLat, endLon,
      uShapeCenterLat, uShapeCenterLon,
      openingAngle, avoidanceDistance
    )
    table.insert(waypoints, {
      latitude = avoidanceWp.latitude,
      longitude = avoidanceWp.longitude
    })
  end

  -- Add end waypoint
  table.insert(waypoints, {
    latitude = endLat,
    longitude = endLon
  })

  return waypoints
end

-- ============================================================================
-- Public API Functions
-- ============================================================================

---Generate square vertices from center point
---@param centerLat number Center latitude in degrees
---@param centerLon number Center longitude in degrees
---@param size number Square size in nautical miles
---@param rotationAngle number Rotation angle in degrees
---@return CMO__Location[] # Array of 4 vertices forming a square
function TacticalAreaGenerator.generateSquareVertices(centerLat, centerLon, size, rotationAngle)
  local halfSize = size / 2
  local diagonalDist = math.sqrt(2) * halfSize
  local vertices = {}

  -- Four corners at 45, 135, 225, 315 degrees relative to rotation
  local cornerAngles = { 45, 135, 225, 315 }
  for _, cornerAngle in ipairs(cornerAngles) do
    local vertex = GameApi.World_GetPointFromBearing({
      latitude = centerLat,
      longitude = centerLon,
      bearing = (cornerAngle + rotationAngle) % 360,
      distance = diagonalDist
    })
    table.insert(vertices, vertex)
  end

  return vertices
end

---Check if two squares overlap based on center distance and size
---@param center1Lat number First square center latitude
---@param center1Lon number First square center longitude
---@param center2Lat number Second square center latitude
---@param center2Lon number Second square center longitude
---@param squareSize number Square size in nautical miles
---@param margin number Safety margin in nautical miles
---@return boolean # True if squares overlap (including margin)
function TacticalAreaGenerator.checkSquaresOverlap(center1Lat, center1Lon, center2Lat, center2Lon, squareSize, margin)
  local distance = GameUtils.calculateDistance(center1Lat, center1Lon, center2Lat, center2Lon)
  return distance < (squareSize + margin)
end

---Generate U-shaped area vertices with specified configuration
---Returns ordered vertices forming a U-shape (3 sides closed, 1 side open), and optionally generates internal squares and fire points
---@param areaConfig SBJ__UShapeAreaConfig Configuration object for U-shaped area generation
---@return SBJ__UShapeAreaResult result Contains uShapeVertices and optionally ammoArea, hideArea, reloadArea, firePoints with vertices
function TacticalAreaGenerator.generateUShapeVertices(areaConfig)
  -- Validate required fields
  assert(areaConfig.centerLat, "config.centerLat is required")
  assert(areaConfig.centerLon, "config.centerLon is required")
  assert(areaConfig.thickness, "config.thickness is required")
  assert(areaConfig.width, "config.width is required")
  assert(areaConfig.height, "config.height is required")
  assert(areaConfig.openingAngle, "config.openingAngle is required")

  local result = {}
  local vertices = {}

  -- Extract config values
  local centerLat = areaConfig.centerLat
  local centerLon = areaConfig.centerLon
  local thickness = areaConfig.thickness
  local width = areaConfig.width
  local height = areaConfig.height
  local openingAngle = areaConfig.openingAngle

  -- Calculate half dimensions for positioning from center
  local halfWidth = width / 2
  local halfHeight = height / 2

  -- Calculate diagonal distance and angle for outer rectangle corners
  local outerDiagonalDist = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
  local baseAngle = math.deg(Utils.atan2(halfWidth, halfHeight))

  -- Calculate 4 corners of outer rectangle (relative to north, will rotate later)
  -- Top-left, top-right, bottom-right, bottom-left
  local outerAngles = {
    360 - baseAngle, -- Top-left
    baseAngle,       -- Top-right
    180 - baseAngle, -- Bottom-right
    180 + baseAngle  -- Bottom-left
  }

  -- Generate outer corners (rotated by openingAngle)
  local outerCorners = {}
  for i = 1, 4 do
    outerCorners[i] = GameApi.World_GetPointFromBearing({
      latitude = centerLat,
      longitude = centerLon,
      bearing = (outerAngles[i] + openingAngle) % 360,
      distance = outerDiagonalDist
    })
  end

  -- Generate inner corners by offsetting from outer corners
  -- Top corners (opening edge): only offset horizontally inward by thickness
  -- Bottom corners: offset both horizontally and vertically by thickness
  local innerCorners = {}

  -- Inner top-left: from outer top-left, move right (90° from opening direction)
  innerCorners[1] = GameApi.World_GetPointFromBearing({
    latitude = outerCorners[1].latitude,
    longitude = outerCorners[1].longitude,
    bearing = (90 + openingAngle) % 360,
    distance = thickness
  })

  -- Inner top-right: from outer top-right, move left (270° from opening direction)
  innerCorners[2] = GameApi.World_GetPointFromBearing({
    latitude = outerCorners[2].latitude,
    longitude = outerCorners[2].longitude,
    bearing = (270 + openingAngle) % 360,
    distance = thickness
  })

  -- Inner bottom-right: from inner top-right, move down (180° from opening direction)
  innerCorners[3] = GameApi.World_GetPointFromBearing({
    latitude = innerCorners[2].latitude,
    longitude = innerCorners[2].longitude,
    bearing = (180 + openingAngle) % 360,
    distance = height - thickness
  })

  -- Inner bottom-left: from inner top-left, move down (180° from opening direction)
  innerCorners[4] = GameApi.World_GetPointFromBearing({
    latitude = innerCorners[1].latitude,
    longitude = innerCorners[1].longitude,
    bearing = (180 + openingAngle) % 360,
    distance = height - thickness
  })

  -- Build U-shape vertices in order (counter-clockwise)
  -- Opening is at the top (after rotation)
  -- Outer bottom-left → outer bottom-right → outer top-right →
  -- inner top-right → inner bottom-right → inner bottom-left →
  -- inner top-left → outer top-left
  table.insert(vertices, outerCorners[4]) -- Outer bottom-left
  table.insert(vertices, outerCorners[3]) -- Outer bottom-right
  table.insert(vertices, outerCorners[2]) -- Outer top-right
  table.insert(vertices, innerCorners[2]) -- Inner top-right
  table.insert(vertices, innerCorners[3]) -- Inner bottom-right
  table.insert(vertices, innerCorners[4]) -- Inner bottom-left
  table.insert(vertices, innerCorners[1]) -- Inner top-left
  table.insert(vertices, outerCorners[1]) -- Outer top-left

  result.uShapeVertices = vertices

  -- Generate three non-overlapping squares inside if internalSquares config is specified
  if areaConfig.internalSquares then
    local internalSquares = TacticalAreaGenerator.generateInternalSquares(
      innerCorners,
      openingAngle,
      areaConfig.internalSquares.size,
      width - 2 * thickness,
      height - thickness,
      areaConfig.internalSquares.marginToWall,
      areaConfig.internalSquares.marginBetweenSquares
    )

    result.ammoArea = internalSquares.ammoArea
    result.hideArea = internalSquares.hideArea
    result.reloadArea = internalSquares.reloadArea
  end

  -- Generate fire points on circle perimeter if firePoints config is specified
  if areaConfig.firePoints then
    result.firePoints = TacticalAreaGenerator.generateFirePoints(
      centerLat,
      centerLon,
      areaConfig.firePoints.radius,
      areaConfig.firePoints.squareSize,
      areaConfig.firePoints.count,
      areaConfig.firePoints.angleRange or 360,
      openingAngle,
      areaConfig.firePoints.margin or 0.1,
      vertices,
      width,
      height
    )
  end

  return result
end

---Generate three non-overlapping squares inside the U-shape's internal rectangle
---@param innerCorners CMO__Location[] Four corners of internal rectangle
---@param openingAngle number Opening direction in degrees
---@param squareSize number Size of squares in nautical miles
---@param innerWidth number Width of internal rectangle in nautical miles
---@param innerHeight number Height of internal rectangle in nautical miles
---@param marginToWall? number Safety margin between squares and U-shape walls in nm (default: 0.1)
---@param marginBetweenSquares? number Safety margin between squares in nm (default: 0.1)
---@return {ammoArea: CMO__Location[], hideArea: CMO__Location[], reloadArea: CMO__Location[]} # Contains ammoArea, hideArea, reloadArea with vertices arrays
function TacticalAreaGenerator.generateInternalSquares(innerCorners, openingAngle, squareSize, innerWidth, innerHeight,
                                                       marginToWall, marginBetweenSquares)
  local areas = {}
  -- Default values for margins
  local wallMargin = marginToWall or 0.1
  local squareMargin = marginBetweenSquares or 0.1
  local maxAttempts = 100
  local halfSquare = squareSize / 2

  -- Calculate the center of internal rectangle
  local centerLat = (innerCorners[1].latitude + innerCorners[2].latitude +
    innerCorners[3].latitude + innerCorners[4].latitude) / 4
  local centerLon = (innerCorners[1].longitude + innerCorners[2].longitude +
    innerCorners[3].longitude + innerCorners[4].longitude) / 4

  -- Calculate valid range for square centers (must be within safe bounds)
  local maxOffsetX = (innerWidth / 2) - halfSquare - wallMargin
  local maxOffsetY = (innerHeight / 2) - halfSquare - wallMargin

  if maxOffsetX <= 0 or maxOffsetY <= 0 then
    error(string.format(
      "Square size (%.2f nm) too large for internal area (%.2f x %.2f nm) with wall margin %.2f nm",
      squareSize, innerWidth, innerHeight, wallMargin
    ))
  end

  -- Generate three square centers
  ---@type CMO__Location[]
  local centers = {}
  local areaNames = { "ammoArea", "hideArea", "reloadArea" }

  for i = 1, 3 do
    local validCenter = false
    local attempts = 0

    while not validCenter and attempts < maxAttempts do
      attempts = attempts + 1
      local candidate = generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle)

      -- Check if this center doesn't overlap with existing squares
      local overlap = false
      for _, existingCenter in ipairs(centers) do
        if TacticalAreaGenerator.checkSquaresOverlap(
              tonumber(candidate.latitude) or 0, tonumber(candidate.longitude) or 0,
              tonumber(existingCenter.latitude) or 0, tonumber(existingCenter.longitude) or 0,
              squareSize, squareMargin
            ) then
          overlap = true
          break
        end
      end

      if not overlap then
        table.insert(centers, candidate)
        validCenter = true
      end
    end

    if not validCenter then
      error(string.format("Failed to place %s after %d attempts", areaNames[i], maxAttempts))
    end
  end

  -- Generate vertices for each square
  areas.ammoArea = TacticalAreaGenerator.generateSquareVertices(
    tonumber(centers[1].latitude) or 0,
    tonumber(centers[1].longitude) or 0,
    squareSize,
    openingAngle
  )
  areas.hideArea = TacticalAreaGenerator.generateSquareVertices(
    tonumber(centers[2].latitude) or 0,
    tonumber(centers[2].longitude) or 0,
    squareSize,
    openingAngle
  )
  areas.reloadArea = TacticalAreaGenerator.generateSquareVertices(
    tonumber(centers[3].latitude) or 0,
    tonumber(centers[3].longitude) or 0,
    squareSize,
    openingAngle
  )

  return areas
end

---Generate fire point squares on circle perimeter around U-shape
---@param centerLat number Center latitude in degrees
---@param centerLon number Center longitude in degrees
---@param radius number Radius of circle in nautical miles
---@param squareSize number Size of fire point squares in nautical miles
---@param count number Number of fire points to generate
---@param angleRange number Angular range for placement in degrees (360 = full circle)
---@param openingAngle number U-shape opening direction in degrees
---@param margin number Safety margin between fire points in nautical miles
---@param uShapeVertices table<CMO__Location> U-shape vertices for collision detection
---@param uShapeWidth number U-shape width in nautical miles
---@param uShapeHeight number U-shape height in nautical miles
---@return table<integer, CMO__Location[]> # Array of fire point areas, each with 4 vertices
function TacticalAreaGenerator.generateFirePoints(centerLat, centerLon, radius, squareSize, count, angleRange,
                                                  openingAngle, margin, uShapeVertices, uShapeWidth, uShapeHeight)
  ---@type {center:CMO__Location, vertices:CMO__Location[]}[]
  local firePoints = {}
  local maxAttempts = 200

  -- Calculate U-shape bounding box for collision detection
  local uShapeMaxDist = math.sqrt((uShapeWidth / 2) ^ 2 + (uShapeHeight / 2) ^ 2)

  -- Calculate angle range boundaries
  -- Opening angle points to the opening direction
  -- We want to avoid placing fire points directly in the opening
  local startAngle = openingAngle - (angleRange / 2)

  -- Generate fire points
  for i = 1, count do
    local validPosition = false
    local attempts = 0

    while not validPosition and attempts < maxAttempts do
      attempts = attempts + 1

      -- Generate random angle within range
      local randomAngle = startAngle + (math.random() * angleRange)
      randomAngle = randomAngle % 360

      -- Calculate position on circle perimeter
      local candidate = GameApi.World_GetPointFromBearing({
        latitude = centerLat,
        longitude = centerLon,
        bearing = randomAngle,
        distance = radius
      })

      -- Check if position is valid
      local valid = true

      -- Check overlap with U-shape
      if checkFirePointOverlapsWithUShape(tonumber(candidate.latitude) or 0, tonumber(candidate.longitude) or 0, centerLat, centerLon,
            uShapeMaxDist, squareSize, margin) then
        valid = false
      end

      -- Check overlap with existing fire points
      if valid then
        for _, existingFirePoint in ipairs(firePoints) do
          if TacticalAreaGenerator.checkSquaresOverlap(
                tonumber(candidate.latitude) or 0, tonumber(candidate.longitude) or 0,
                tonumber(existingFirePoint.center.latitude) or 0, tonumber(existingFirePoint.center.longitude) or 0,
                squareSize, margin
              ) then
            valid = false
            break
          end
        end
      end

      if valid then
        -- Calculate square rotation to face toward U-shape center
        local bearingToCenter = GameApi.Tool_Bearing(
          { latitude = candidate.latitude, longitude = candidate.longitude },
          { latitude = centerLat, longitude = centerLon }
        )

        local vertices = TacticalAreaGenerator.generateSquareVertices(
          tonumber(candidate.latitude) or 0, tonumber(candidate.longitude) or 0,
          squareSize, bearingToCenter
        )

        table.insert(firePoints, {
          center = candidate,
          vertices = vertices
        })
        validPosition = true
      end
    end

    if not validPosition then
      error(string.format(
        "Failed to place fire point %d/%d after %d attempts. Try: larger radius, smaller squares, fewer count, or larger angleRange",
        i, count, maxAttempts
      ))
    end
  end

  -- Return only vertices arrays for compatibility
  local firePointVertices = {}
  for i, fp in ipairs(firePoints) do
    firePointVertices[i] = fp.vertices
  end

  return firePointVertices
end

---Calculate movement paths between tactical positions with U-shape avoidance
---Generates optimized paths for TEL movement between different tactical zones
---@param pathConfig SBJ__MovementPathsConfig Configuration for path calculation
---@return SBJ__MovementPaths # Movement paths organized by type (FP, HA, RL, AHA)
function TacticalAreaGenerator.calculateMovementPaths(pathConfig)
  -- Validate required fields
  assert(pathConfig.centerLat, "config.centerLat is required")
  assert(pathConfig.centerLon, "config.centerLon is required")
  assert(pathConfig.width, "config.width is required")
  assert(pathConfig.height, "config.height is required")
  assert(pathConfig.thickness, "config.thickness is required")
  assert(pathConfig.openingAngle, "config.openingAngle is required")
  assert(pathConfig.ammoArea, "config.ammoArea is required")
  assert(pathConfig.hideArea, "config.hideArea is required")
  assert(pathConfig.reloadArea, "config.reloadArea is required")

  local avoidanceMargin = pathConfig.avoidanceMargin or 0.3
  local paths = {
    FP = {},
    HA = { waypoints = {} },
    RL = {},
    AHA = { waypoints = {} }
  }

  -- Calculate U-shape bounding parameters
  local uShapeMaxDist = math.sqrt((pathConfig.width / 2) ^ 2 + (pathConfig.height / 2) ^ 2)
  local avoidanceDistance = uShapeMaxDist + avoidanceMargin + 0.5 -- Extra buffer for detour

  -- Calculate inner rectangle dimensions for collision detection
  local innerWidth = pathConfig.width - 2 * pathConfig.thickness
  local innerHeight = pathConfig.height - pathConfig.thickness
  local uShapeInnerDist = math.sqrt((innerWidth / 2) ^ 2 + (innerHeight / 2) ^ 2)

  -- Calculate center points of tactical zones
  local ammoCtr = calculateSquareCenter(pathConfig.ammoArea)
  local hideCtr = calculateSquareCenter(pathConfig.hideArea)
  local reloadCtr = calculateSquareCenter(pathConfig.reloadArea)

  -- Generate HA path: Reload Area -> Hide Area
  paths.HA.waypoints = generatePathWithAvoidance(
    tonumber(reloadCtr.latitude) or 0, tonumber(reloadCtr.longitude) or 0,
    tonumber(hideCtr.latitude) or 0, tonumber(hideCtr.longitude) or 0,
    pathConfig.centerLat, pathConfig.centerLon,
    uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
    avoidanceMargin, avoidanceDistance
  )

  -- Generate AHA path: Reload Area -> Ammo Holding Area
  paths.AHA.waypoints = generatePathWithAvoidance(
    tonumber(reloadCtr.latitude) or 0, tonumber(reloadCtr.longitude) or 0,
    tonumber(ammoCtr.latitude) or 0, tonumber(ammoCtr.longitude) or 0,
    pathConfig.centerLat, pathConfig.centerLon,
    uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
    avoidanceMargin, avoidanceDistance
  )

  -- Generate FP paths: Hide Area -> each Fire Point
  if pathConfig.firePoints then
    for i, firePoint in ipairs(pathConfig.firePoints) do
      local fpCtr = calculateSquareCenter(firePoint)
      paths.FP[i] = {
        waypoints = generatePathWithAvoidance(
          tonumber(hideCtr.latitude) or 0, tonumber(hideCtr.longitude) or 0,
          tonumber(fpCtr.latitude) or 0, tonumber(fpCtr.longitude) or 0,
          pathConfig.centerLat, pathConfig.centerLon,
          uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
          avoidanceMargin, avoidanceDistance
        )
      }
    end
  end

  -- Generate RL paths: each Fire Point -> Reload Area
  if pathConfig.firePoints then
    for i, firePoint in ipairs(pathConfig.firePoints) do
      local fpCtr = calculateSquareCenter(firePoint)
      paths.RL[i] = {
        waypoints = generatePathWithAvoidance(
          tonumber(fpCtr.latitude) or 0, tonumber(fpCtr.longitude) or 0,
          tonumber(reloadCtr.latitude) or 0, tonumber(reloadCtr.longitude) or 0,
          pathConfig.centerLat, pathConfig.centerLon,
          uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
          avoidanceMargin, avoidanceDistance
        )
      }
    end
  end

  return paths
end

-- ============================================================================
-- Usage Example
-- ============================================================================
-- local TacticalAreaGenerator = require("src.utils.tacticalAreaGenerator")
-- local u = ScenEdit_GetUnit({name='3MN-1 Bison B [Bomber]', guid='L13OAU-0HNI52ARQHQNF'})

-- local result = TacticalAreaGenerator.generateUShapeVertices({
--   -- U 型基本配置（必填）
--   centerLat = u.latitude,
--   centerLon = u.longitude,
--   thickness = 0.5,       -- U型厚度 (海里)
--   width = 2.5,           -- U型寬度 (海里)
--   height = 2.5,          -- U型高度 (海里)
--   openingAngle = 30,     -- 開口方向角度 (0=北, 90=東, 180=南, 270=西)

--   -- 內部三個功能區配置（可選）
--   internalSquares = {
--     size = 0.2,                    -- 正方形邊長 (海里)
--     marginToWall = 0.1,            -- 與U型內壁的間距 (海里)
--     marginBetweenSquares = 0.15    -- 正方形之間的間距 (海里)
--   },

--   -- 外圍火力點配置（可選）
--   firePoints = {
--     radius = 5,          -- 火力點圓周半徑 (海里)
--     squareSize = 0.3,    -- 火力點正方形邊長 (海里)
--     count = 3,           -- 火力點數量
--     angleRange = 270,    -- 角度範圍 (度)，360=整圈，180=半圈
--     margin = 0.2         -- 火力點之間的安全間距 (海里)
--   }
-- })

-- -- 創建參考區域
-- ScenEdit_AddReferencePoint({side="Taiwan", name="U-Shape Area", area = result.uShapeVertices})

-- if result.ammoArea then
--   ScenEdit_AddReferencePoint({side="Taiwan", name="Ammo Holding Area", area = result.ammoArea})
--   ScenEdit_AddReferencePoint({side="Taiwan", name="Hide Area", area = result.hideArea})
--   ScenEdit_AddReferencePoint({side="Taiwan", name="Reload Area", area = result.reloadArea})
-- end

-- if result.firePoints then
--   for i, firePoint in ipairs(result.firePoints) do
--     ScenEdit_AddReferencePoint({
--       side = "Taiwan",
--       name = "Fire Point " .. i,
--       area = firePoint
--     })
--   end
-- end

-- -- 計算移動路徑
-- if result.ammoArea and result.hideArea and result.reloadArea then
--   local paths = TacticalAreaGenerator.calculateMovementPaths({
--     centerLat = u.latitude,
--     centerLon = u.longitude,
--     width = 2.5,
--     height = 2.5,
--     thickness = 0.5,
--     openingAngle = 30,
--     ammoArea = result.ammoArea,
--     hideArea = result.hideArea,
--     reloadArea = result.reloadArea,
--     firePoints = result.firePoints,
--     avoidanceMargin = 0.3  -- 迴避U型的安全距離 (海里)
--   })

--   -- 使用路徑範例: Hide Area -> Fire Point
--   for i, path in ipairs(paths.FP) do
--     print("Path from Hide Area to Fire Point " .. i .. ":")
--     for j, waypoint in ipairs(path.waypoints) do
--       print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--     end
--   end

--   -- 使用路徑範例: Reload Area -> Hide Area
--   print("Path from Reload Area to Hide Area:")
--   for j, waypoint in ipairs(paths.HA.waypoints) do
--     print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--   end

--   -- 使用路徑範例: Fire Point -> Reload Area
--   for i, path in ipairs(paths.RL) do
--     print("Path from Fire Point " .. i .. " to Reload Area:")
--     for j, waypoint in ipairs(path.waypoints) do
--       print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--     end
--   end

--   -- 使用路徑範例: Reload Area -> Ammo Holding Area
--   print("Path from Reload Area to Ammo Holding Area:")
--   for j, waypoint in ipairs(paths.AHA.waypoints) do
--     print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--   end
----u.course=paths.AHA.waypoints
----u.course=paths.HA.waypoints
----u.course=paths.FP[1].waypoints
----u.course=paths.FP[2].waypoints
----u.course=paths.AHA.waypoints
-- end

return TacticalAreaGenerator
