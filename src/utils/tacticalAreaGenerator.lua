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

---Calculate U-shape outline corner points with offset (both outer and inner corners)
---@param uShapeCenterLat number U-shape center latitude
---@param uShapeCenterLon number U-shape center longitude
---@param width number U-shape width in nautical miles
---@param height number U-shape height in nautical miles
---@param thickness number U-shape wall thickness in nautical miles
---@param openingAngle number U-shape opening direction in degrees
---@param offset number Offset distance from U-shape edges in nautical miles
---@return {topLeft:CMO__Location, topRight:CMO__Location, bottomRight:CMO__Location, bottomLeft:CMO__Location, innerTopLeft:CMO__Location, innerTopRight:CMO__Location} # Corner points
local function calculateOutlineCorners(uShapeCenterLat, uShapeCenterLon, width, height, thickness, openingAngle, offset)
  local corners = {}

  -- Calculate outer rectangle corners
  local halfWidth = width / 2
  local halfHeight = height / 2
  local outerDiagonalDist = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
  local outerBaseAngle = math.deg(Utils.atan2(halfWidth, halfHeight))

  -- Outer corners without offset (base points)
  local outerTopRight = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle + outerBaseAngle) % 360,
    distance = outerDiagonalDist
  })

  local outerTopLeft = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle - outerBaseAngle + 360) % 360,
    distance = outerDiagonalDist
  })

  -- Outer corners with offset
  local outerHalfWidthOffset = halfWidth + offset
  local outerHalfHeightOffset = halfHeight + offset
  local outerDiagonalDistOffset = math.sqrt(outerHalfWidthOffset * outerHalfWidthOffset +
    outerHalfHeightOffset * outerHalfHeightOffset)
  local outerBaseAngleOffset = math.deg(Utils.atan2(outerHalfWidthOffset, outerHalfHeightOffset))

  corners.topRight = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle + outerBaseAngleOffset) % 360,
    distance = outerDiagonalDistOffset
  })

  corners.topLeft = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle - outerBaseAngleOffset + 360) % 360,
    distance = outerDiagonalDistOffset
  })

  corners.bottomRight = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle + 180 - outerBaseAngleOffset) % 360,
    distance = outerDiagonalDistOffset
  })

  corners.bottomLeft = GameApi.World_GetPointFromBearing({
    latitude = uShapeCenterLat,
    longitude = uShapeCenterLon,
    bearing = (openingAngle + 180 + outerBaseAngleOffset) % 360,
    distance = outerDiagonalDistOffset
  })

  -- Calculate inner rectangle corners
  -- Find base points of inner rectangle (without offset)
  -- Inner top-right base: from outer top-right, move inward by thickness
  local innerTopRightBase = GameApi.World_GetPointFromBearing({
    latitude = outerTopRight.latitude,
    longitude = outerTopRight.longitude,
    bearing = (270 + openingAngle) % 360, -- Move left (toward center)
    distance = thickness
  })

  -- Inner top-left base: from outer top-left, move inward by thickness
  local innerTopLeftBase = GameApi.World_GetPointFromBearing({
    latitude = outerTopLeft.latitude,
    longitude = outerTopLeft.longitude,
    bearing = (90 + openingAngle) % 360, -- Move right (toward center)
    distance = thickness
  })

  -- Apply diagonal offset from base points (toward interior)
  local offsetDiagonal = offset * math.sqrt(2)

  -- Inner top-right: diagonal toward bottom-left (away from right wall and opening edge)
  corners.innerTopRight = GameApi.World_GetPointFromBearing({
    latitude = innerTopRightBase.latitude,
    longitude = innerTopRightBase.longitude,
    bearing = (openingAngle - 45 + 360) % 360, -- Bottom-left diagonal
    distance = offsetDiagonal
  })

  -- Inner top-left: diagonal toward bottom-right (away from left wall and opening edge)
  corners.innerTopLeft = GameApi.World_GetPointFromBearing({
    latitude = innerTopLeftBase.latitude,
    longitude = innerTopLeftBase.longitude,
    bearing = (openingAngle + 45) % 360, -- Bottom-right diagonal
    distance = offsetDiagonal
  })

  return corners
end

---Generate path with U-shape avoidance by following rectangular perimeter
---Creates a waypoint array from start to end, routing around U-shape rectangular outline
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
---@param width number U-shape width in nautical miles
---@param height number U-shape height in nautical miles
---@param thickness number U-shape wall thickness in nautical miles
---@return SBJ__PathWaypoint[] # Array of waypoints forming the path
local function generatePathWithAvoidance(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                         uShapeMaxDist, uShapeInnerDist, openingAngle, avoidanceMargin,
                                         avoidanceDistance, width, height, thickness)
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
    -- Calculate U-shape outline corners (both outer and inner)
    local corners = calculateOutlineCorners(
      uShapeCenterLat, uShapeCenterLon, width, height, thickness,
      openingAngle, avoidanceMargin
    )

    -- Calculate bearing from U-shape center to destination
    local bearingToEnd = GameApi.Tool_Bearing(
      { latitude = uShapeCenterLat, longitude = uShapeCenterLon },
      { latitude = endLat, longitude = endLon }
    )

    -- Calculate angular difference from opening to destination
    local normalizedOpening = openingAngle % 360
    local normalizedEnd = bearingToEnd % 360
    local angleDiff = (normalizedEnd - normalizedOpening + 180) % 360 - 180

    -- Determine which inner corner to use for exit
    local useRightPath = angleDiff > 0

    -- Step 1: Exit through inner corner (inside the opening)
    if useRightPath then
      table.insert(waypoints, {
        latitude = corners.innerTopRight.latitude,
        longitude = corners.innerTopRight.longitude
      })
    else
      table.insert(waypoints, {
        latitude = corners.innerTopLeft.latitude,
        longitude = corners.innerTopLeft.longitude
      })
    end

    -- Step 2: Add outer corners based on destination direction
    -- Only add corners if necessary to reach destination
    if angleDiff > 90 and angleDiff <= 135 then
      -- Right side: need outer topRight corner
      table.insert(waypoints, {
        latitude = corners.topRight.latitude,
        longitude = corners.topRight.longitude
      })
    elseif angleDiff > 135 then
      -- Back-right side: topRight → bottomRight
      table.insert(waypoints, {
        latitude = corners.topRight.latitude,
        longitude = corners.topRight.longitude
      })
      table.insert(waypoints, {
        latitude = corners.bottomRight.latitude,
        longitude = corners.bottomRight.longitude
      })
      -- Only add bottomLeft if very close to opposite side
      if angleDiff > 170 then
        table.insert(waypoints, {
          latitude = corners.bottomLeft.latitude,
          longitude = corners.bottomLeft.longitude
        })
      end
    elseif angleDiff < -135 then
      -- Back-left side: topLeft → bottomLeft
      table.insert(waypoints, {
        latitude = corners.topLeft.latitude,
        longitude = corners.topLeft.longitude
      })
      table.insert(waypoints, {
        latitude = corners.bottomLeft.latitude,
        longitude = corners.bottomLeft.longitude
      })
      -- Only add bottomRight if very close to opposite side
      if angleDiff < -170 then
        table.insert(waypoints, {
          latitude = corners.bottomRight.latitude,
          longitude = corners.bottomRight.longitude
        })
      end
    elseif angleDiff < -90 and angleDiff >= -135 then
      -- Left side: need outer topLeft corner
      table.insert(waypoints, {
        latitude = corners.topLeft.latitude,
        longitude = corners.topLeft.longitude
      })
    end
    -- If -90 <= angleDiff <= 90: destination roughly forward, inner corner to destination is sufficient
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
  local startAngle = openingAngle + 180 - (angleRange / 2)

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
    avoidanceMargin, avoidanceDistance,
    pathConfig.width, pathConfig.height, pathConfig.thickness
  )

  -- Generate AHA path: Reload Area -> Ammo Holding Area
  paths.AHA.waypoints = generatePathWithAvoidance(
    tonumber(reloadCtr.latitude) or 0, tonumber(reloadCtr.longitude) or 0,
    tonumber(ammoCtr.latitude) or 0, tonumber(ammoCtr.longitude) or 0,
    pathConfig.centerLat, pathConfig.centerLon,
    uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
    avoidanceMargin, avoidanceDistance,
    pathConfig.width, pathConfig.height, pathConfig.thickness
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
          avoidanceMargin, avoidanceDistance,
          pathConfig.width, pathConfig.height, pathConfig.thickness
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
          avoidanceMargin, avoidanceDistance,
          pathConfig.width, pathConfig.height, pathConfig.thickness
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
--   -- U-shape basic configuration (required)
--   centerLat = u.latitude,
--   centerLon = u.longitude,
--   thickness = 0.5,       -- U-shape wall thickness (nautical miles)
--   width = 2.5,           -- U-shape width (nautical miles)
--   height = 2,          -- U-shape height (nautical miles)
--   openingAngle = 30,     -- Opening direction angle (0=North, 90=East, 180=South, 270=West)

--   -- Internal three functional zones configuration (optional)
--   internalSquares = {
--     size = 0.2,                    -- Square side length (nautical miles)
--     marginToWall = 0.1,            -- Distance to U-shape inner wall (nautical miles)
--     marginBetweenSquares = 0.5    -- Distance between squares (nautical miles)
--   },

--   -- Outer fire points configuration (optional)
--   firePoints = {
--     radius = 4,          -- Fire point circle radius (nautical miles)
--     squareSize = 0.3,    -- Fire point square side length (nautical miles)
--     count = 2,           -- Number of fire points
--     angleRange = 90,    -- Angular range (degrees), 360=full circle, 180=semicircle
--     margin = 0.2         -- Safety margin between fire points (nautical miles)
--   }
-- })

-- -- Create reference areas
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

-- -- Calculate movement paths
-- if result.ammoArea and result.hideArea and result.reloadArea then
--   local paths = TacticalAreaGenerator.calculateMovementPaths({
--     centerLat = u.latitude,
--     centerLon = u.longitude,
--     width = 2.5,
--     height = 2,
--     thickness = 0.5,
--     openingAngle = 30,
--     ammoArea = result.ammoArea,
--     hideArea = result.hideArea,
--     reloadArea = result.reloadArea,
--     firePoints = result.firePoints,
--     avoidanceMargin = 0.3  -- Safety distance to avoid U-shape (nautical miles)
--   })

--   -- Path usage example: Hide Area -> Fire Point
--   for i, path in ipairs(paths.FP) do
--     print("Path from Hide Area to Fire Point " .. i .. ":")
--     for j, waypoint in ipairs(path.waypoints) do
--       print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--     end
--   end

--   -- Path usage example: Reload Area -> Hide Area
--   print("Path from Reload Area to Hide Area:")
--   for j, waypoint in ipairs(paths.HA.waypoints) do
--     print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--   end

--   -- Path usage example: Fire Point -> Reload Area
--   for i, path in ipairs(paths.RL) do
--     print("Path from Fire Point " .. i .. " to Reload Area:")
--     for j, waypoint in ipairs(path.waypoints) do
--       print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--     end
--   end

--   -- Path usage example: Reload Area -> Ammo Holding Area
--   print("Path from Reload Area to Ammo Holding Area:")
--   for j, waypoint in ipairs(paths.AHA.waypoints) do
--     print(string.format("  Waypoint %d: lat=%.6f, lon=%.6f", j, waypoint.latitude, waypoint.longitude))
--   end
-- --u.course=paths.AHA.waypoints
-- --u.course=paths.HA.waypoints
-- --u.course=paths.FP[1].waypoints
-- --u.course=paths.FP[2].waypoints
-- --u.course=paths.AHA.waypoints
-- end

return TacticalAreaGenerator
