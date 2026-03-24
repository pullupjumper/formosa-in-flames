local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")

local TacticalAreaGenerator = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Generate a random square center within valid bounds of boundary rectangle
---@param centerLat number Center latitude of boundary rectangle
---@param centerLon number Center longitude of boundary rectangle
---@param maxOffsetX number Maximum offset in X direction (perpendicular to opening)
---@param maxOffsetY number Maximum offset in Y direction (parallel to opening)
---@param openingAngle number Opening direction in degrees
---@return CMO__Location # Random center point
local function generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle)
  local offsetX = (math.random() * 2 - 1) * maxOffsetX
  local offsetY = (math.random() * 2 - 1) * maxOffsetY

  local tempPos = GameApi.World_GetPointFromBearing({
    latitude = centerLat,
    longitude = centerLon,
    bearing = (90 + openingAngle) % 360,
    distance = offsetX
  })

  return GameApi.World_GetPointFromBearing({
    latitude = tempPos.latitude,
    longitude = tempPos.longitude,
    bearing = (180 + openingAngle) % 360,
    distance = offsetY
  })
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

---Check if two squares overlap based on center distance and size
---@param center1Lat number|string First square center latitude
---@param center1Lon number|string First square center longitude
---@param center2Lat number|string Second square center latitude
---@param center2Lon number|string Second square center longitude
---@param squareSize number|string Square size in nautical miles
---@param margin number Safety margin in nautical miles
---@return boolean # True if squares overlap (including margin)
local function checkSquaresOverlap(center1Lat, center1Lon, center2Lat, center2Lon, squareSize, margin)
  local distance = GameUtils.calculateDistance(center1Lat, center1Lon, center2Lat, center2Lon)
  return distance < (squareSize + margin)
end

---Check if a point is inside a square defined by vertices
---@param pointLat number|string Point latitude
---@param pointLon number|string Point longitude
---@param squareCenter CMO__Location Square center point
---@param squareSize number Square size in nautical miles
---@param margin number Safety margin in nautical miles
---@return boolean # True if point is inside square (including margin)
local function checkPointInSquare(pointLat, pointLon, squareCenter, squareSize, margin)
  local distance = GameUtils.calculateDistance(squareCenter.latitude, squareCenter.longitude, pointLat, pointLon)
  local halfSize = squareSize / 2 + margin
  return distance < halfSize
end

---Generate square vertices from center point
---@param centerLat number|string Center latitude in degrees
---@param centerLon number|string Center longitude in degrees
---@param size number Square size in nautical miles
---@param rotationAngle number Rotation angle in degrees
---@return CMO__Location[] # Array of 4 vertices forming a square
local function generateSquareVertices(centerLat, centerLon, size, rotationAngle)
  local halfSize = size / 2
  local diagonalDist = math.sqrt(2) * halfSize
  local vertices = {}

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

---Check if a line segment intersects with a square area
---@param startLat number|string Start point latitude
---@param startLon number|string Start point longitude
---@param endLat number|string End point latitude
---@param endLon number|string End point longitude
---@param squareVertices CMO__Location[] Four vertices of the square
---@param margin number Safety margin in nautical miles
---@return boolean # True if path intersects square
local function checkPathIntersectsSquare(startLat, startLon, endLat, endLon, squareVertices, margin)
  local squareCenter = calculateSquareCenter(squareVertices)

  local dist1 = GameUtils.calculateDistance(squareVertices[1].latitude, squareVertices[1].longitude,
    squareVertices[2].latitude, squareVertices[2].longitude)
  local dist2 = GameUtils.calculateDistance(squareVertices[2].latitude, squareVertices[2].longitude,
    squareVertices[3].latitude, squareVertices[3].longitude)
  local squareSize = (dist1 + dist2) / 2

  local numSamples = 10
  for i = 0, numSamples do
    local t = i / numSamples
    local sampleLat = startLat + t * (endLat - startLat)
    local sampleLon = startLon + t * (endLon - startLon)

    if checkPointInSquare(sampleLat, sampleLon, squareCenter, squareSize, margin) then
      return true
    end
  end

  return false
end

---Calculate four external offset corners of a square
---@param squareVertices CMO__Location[] Four vertices of the square
---@param offset number Offset distance from square edges in nautical miles
---@return CMO__Location[] # Four offset corner points (outside the square)
local function calculateSquareOffsetCorners(squareVertices, offset)
  local squareCenter = calculateSquareCenter(squareVertices)
  local offsetCorners = {}

  for _, vertex in ipairs(squareVertices) do
    local bearing = GameApi.Tool_Bearing(
      { latitude = squareCenter.latitude, longitude = squareCenter.longitude },
      { latitude = vertex.latitude, longitude = vertex.longitude }
    )

    local offsetDist = offset * 1.2
    local offsetCorner = GameApi.World_GetPointFromBearing({
      latitude = vertex.latitude,
      longitude = vertex.longitude,
      bearing = bearing,
      distance = offsetDist
    })

    table.insert(offsetCorners, offsetCorner)
  end

  return offsetCorners
end

---Select best pair of adjacent avoidance corners from offset corners
---@param startLat number Start point latitude
---@param startLon number Start point longitude
---@param endLat number End point latitude
---@param endLon number End point longitude
---@param offsetCorners CMO__Location[] Four offset corner points
---@param allSquares CMO__Location[][] All square areas to check for collisions
---@param margin number Safety margin in nautical miles
---@return CMO__Location|nil corner1 First corner point, or nil if none found
---@return CMO__Location|nil corner2 Second corner point, or nil if none found
local function selectBestAvoidanceCornerPair(startLat, startLon, endLat, endLon, offsetCorners, allSquares, margin)
  if #offsetCorners ~= 4 then
    return nil, nil
  end

  local bestPair = nil
  local minDistance = math.huge

  for i = 1, 4 do
    local pairs = {
      { offsetCorners[i],           offsetCorners[(i % 4) + 1] },
      { offsetCorners[(i % 4) + 1], offsetCorners[i] }
    }

    for _, pair in ipairs(pairs) do
      local corner1 = pair[1]
      local corner2 = pair[2]
      local hasCollision = false

      -- Check path segment: start -> corner1
      for _, squareVertices in ipairs(allSquares) do
        local squareCenter = calculateSquareCenter(squareVertices)
        local d1 = GameUtils.calculateDistance(squareVertices[1].latitude, squareVertices[1].longitude,
          squareVertices[2].latitude, squareVertices[2].longitude)
        local d2 = GameUtils.calculateDistance(squareVertices[2].latitude, squareVertices[2].longitude,
          squareVertices[3].latitude, squareVertices[3].longitude)
        local squareSize = (d1 + d2) / 2

        local startInSquare = checkPointInSquare(startLat, startLon, squareCenter, squareSize, 0)
        local corner1InSquare = checkPointInSquare(corner1.latitude, corner1.longitude, squareCenter, squareSize, 0)

        if not (startInSquare or corner1InSquare) and checkPathIntersectsSquare(
              startLat, startLon, corner1.latitude, corner1.longitude, squareVertices, margin
            ) then
          hasCollision = true
          break
        end
      end

      -- Check path segment: corner1 -> corner2
      if not hasCollision then
        for _, squareVertices in ipairs(allSquares) do
          local squareCenter = calculateSquareCenter(squareVertices)
          local d1 = GameUtils.calculateDistance(squareVertices[1].latitude, squareVertices[1].longitude,
            squareVertices[2].latitude, squareVertices[2].longitude)
          local d2 = GameUtils.calculateDistance(squareVertices[2].latitude, squareVertices[2].longitude,
            squareVertices[3].latitude, squareVertices[3].longitude)
          local squareSize = (d1 + d2) / 2

          local corner1InSquare = checkPointInSquare(corner1.latitude, corner1.longitude, squareCenter, squareSize, 0)
          local corner2InSquare = checkPointInSquare(corner2.latitude, corner2.longitude, squareCenter, squareSize, 0)

          if not (corner1InSquare or corner2InSquare) and checkPathIntersectsSquare(
                corner1.latitude, corner1.longitude, corner2.latitude, corner2.longitude, squareVertices, margin
              ) then
            hasCollision = true
            break
          end
        end
      end

      -- Check path segment: corner2 -> end
      if not hasCollision then
        for _, squareVertices in ipairs(allSquares) do
          local squareCenter = calculateSquareCenter(squareVertices)
          local d1 = GameUtils.calculateDistance(squareVertices[1].latitude, squareVertices[1].longitude,
            squareVertices[2].latitude, squareVertices[2].longitude)
          local d2 = GameUtils.calculateDistance(squareVertices[2].latitude, squareVertices[2].longitude,
            squareVertices[3].latitude, squareVertices[3].longitude)
          local squareSize = (d1 + d2) / 2

          local corner2InSquare = checkPointInSquare(corner2.latitude, corner2.longitude, squareCenter, squareSize, 0)
          local endInSquare = checkPointInSquare(endLat, endLon, squareCenter, squareSize, 0)

          if not (corner2InSquare or endInSquare) and checkPathIntersectsSquare(
                corner2.latitude, corner2.longitude, endLat, endLon, squareVertices, margin
              ) then
            hasCollision = true
            break
          end
        end
      end

      if not hasCollision then
        local d1 = GameUtils.calculateDistance(startLat, startLon, corner1.latitude, corner1.longitude)
        local d2 = GameUtils.calculateDistance(corner1.latitude, corner1.longitude, corner2.latitude, corner2.longitude)
        local d3 = GameUtils.calculateDistance(corner2.latitude, corner2.longitude, endLat, endLon)
        local totalDist = d1 + d2 + d3

        if totalDist < minDistance then
          minDistance = totalDist
          bestPair = { corner1, corner2 }
        end
      end
    end
  end

  if bestPair then
    return bestPair[1], bestPair[2]
  else
    return nil, nil
  end
end

-- ============================================================================
-- Path Generation (avoid other position squares only)
-- ============================================================================

---Generate path with avoidance of position squares
---@param startLat number|string Start point latitude
---@param startLon number|string Start point longitude
---@param endLat number|string End point latitude
---@param endLon number|string End point longitude
---@param avoidanceMargin number Safety margin for intersection check
---@param avoidSquares CMO__Location[][] Array of square areas to avoid
---@return SBJ__PathWaypoint[] # Array of waypoints forming the path
local function generatePathWithAvoidance(startLat, startLon, endLat, endLon, avoidanceMargin, avoidSquares)
  local waypoints = {
    { latitude = startLat, longitude = startLon },
    { latitude = endLat, longitude = endLon },
  }

  if #avoidSquares == 0 then return waypoints end

  local maxIterations = 20
  local modified = true
  local iteration = 0

  while modified and iteration < maxIterations do
    modified = false
    iteration = iteration + 1

    for i = 1, #waypoints - 1 do
      local segStart = waypoints[i]
      local segEnd = waypoints[i + 1]

      for squareIdx, squareVertices in ipairs(avoidSquares) do
        local squareCenter = calculateSquareCenter(squareVertices)
        local d1 = GameUtils.calculateDistance(squareVertices[1].latitude, squareVertices[1].longitude,
          squareVertices[2].latitude, squareVertices[2].longitude)
        local d2 = GameUtils.calculateDistance(squareVertices[2].latitude, squareVertices[2].longitude,
          squareVertices[3].latitude, squareVertices[3].longitude)
        local squareSize = (d1 + d2) / 2

        local startInSquare = checkPointInSquare(segStart.latitude, segStart.longitude, squareCenter, squareSize, 0)
        local endInSquare = checkPointInSquare(segEnd.latitude, segEnd.longitude, squareCenter, squareSize, 0)

        if not (startInSquare or endInSquare) and checkPathIntersectsSquare(
              segStart.latitude, segStart.longitude,
              segEnd.latitude, segEnd.longitude,
              squareVertices, avoidanceMargin
            ) then
          local corner1, corner2 = nil, nil
          local offsetMultipliers = { 2.0, 2.5, 3.0, 3.5, 4.0, 5.0 }

          local otherSquares = {}
          for idx, sq in ipairs(avoidSquares) do
            if idx ~= squareIdx then
              table.insert(otherSquares, sq)
            end
          end

          for _, multiplier in ipairs(offsetMultipliers) do
            local offsetDist = avoidanceMargin * multiplier
            local offsetCorners = calculateSquareOffsetCorners(squareVertices, offsetDist)

            corner1, corner2 = selectBestAvoidanceCornerPair(
              segStart.latitude, segStart.longitude,
              segEnd.latitude, segEnd.longitude,
              offsetCorners,
              otherSquares,
              avoidanceMargin
            )

            if corner1 and corner2 then
              break
            end
          end

          if corner1 and corner2 then
            table.insert(waypoints, i + 1, {
              latitude = corner1.latitude,
              longitude = corner1.longitude
            })
            table.insert(waypoints, i + 2, {
              latitude = corner2.latitude,
              longitude = corner2.longitude
            })

            modified = true
            break
          else
            Logger.error(string.format(
              "Cannot find valid avoidance path at segment %d->%d.", i, i + 1
            ))
          end
        end
      end

      if modified then
        break
      end
    end
  end

  if iteration >= maxIterations then
    Logger.error("Failed to generate collision-free path after " .. maxIterations .. " iterations")
  end

  return waypoints
end

-- ============================================================================
-- Internal Area Generation
-- ============================================================================

---Generate two non-overlapping squares inside the boundary rectangle
---@param boundaryCorners CMO__Location[] Four corners of boundary rectangle
---@param openingAngle number Opening direction in degrees
---@param squareSize number Size of squares in nautical miles
---@param areaWidth number Width of boundary rectangle in nautical miles
---@param areaHeight number Height of boundary rectangle in nautical miles
---@param marginToWall? number Safety margin between squares and boundary walls in nm (default: 0.1)
---@param marginBetweenSquares? number Safety margin between squares in nm (default: 0.1)
---@return {hideArea: CMO__Location[], reloadArea: CMO__Location[]}
local function generateInternalSquares(boundaryCorners, openingAngle, squareSize, areaWidth, areaHeight,
                                       marginToWall, marginBetweenSquares)
  local areas = {}
  local wallMargin = marginToWall or 0.1
  local squareMargin = marginBetweenSquares or 0.1
  local maxAttempts = 100
  local halfSquare = squareSize / 2

  local centerLat = (boundaryCorners[1].latitude + boundaryCorners[2].latitude +
    boundaryCorners[3].latitude + boundaryCorners[4].latitude) / 4
  local centerLon = (boundaryCorners[1].longitude + boundaryCorners[2].longitude +
    boundaryCorners[3].longitude + boundaryCorners[4].longitude) / 4

  local maxOffsetX = areaWidth / 2 - halfSquare - wallMargin
  local maxOffsetY = areaHeight / 2 - halfSquare - wallMargin

  if maxOffsetX <= 0 or maxOffsetY <= 0 then
    Logger.error(string.format(
      "Square size (%.2f nm) too large for boundary area (%.2f x %.2f nm) with wall margin %.2f nm",
      squareSize, areaWidth, areaHeight, wallMargin
    ))
  end

  ---@type CMO__Location[]
  local centers = {}
  local areaNames = { "hideArea", "reloadArea" }

  for i = 1, 2 do
    local validCenter = false
    local attempts = 0

    while not validCenter and attempts < maxAttempts do
      attempts = attempts + 1
      local candidate = generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle)

      local overlap = false
      for _, existingCenter in ipairs(centers) do
        if checkSquaresOverlap(
              candidate.latitude, candidate.longitude,
              existingCenter.latitude, existingCenter.longitude,
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
      Logger.error(string.format("Failed to place %s after %d attempts", areaNames[i], maxAttempts))
    end
  end

  areas.hideArea = generateSquareVertices(centers[1].latitude, centers[1].longitude, squareSize, openingAngle)
  areas.reloadArea = generateSquareVertices(centers[2].latitude, centers[2].longitude, squareSize, openingAngle)

  return areas
end

---Generate fire point squares on circle perimeter around boundary
---@param centerLat number Center latitude in degrees
---@param centerLon number Center longitude in degrees
---@param radius number Radius of circle in nautical miles
---@param squareSize number Size of fire point squares in nautical miles
---@param count number Number of fire points to generate
---@param angleRange number Angular range for placement in degrees
---@param openingAngle number Opening direction in degrees
---@param margin number Safety margin between fire points in nautical miles
---@param boundaryWidth number Boundary width in nautical miles
---@param boundaryHeight number Boundary height in nautical miles
---@return table<integer, CMO__Location[]> # Array of fire point areas, each with 4 vertices
local function generateFirePoints(centerLat, centerLon, radius, squareSize, count, angleRange,
                                   openingAngle, margin, boundaryWidth, boundaryHeight)
  ---@type {center:CMO__Location, vertices:CMO__Location[]}[]
  local firePoints = {}
  local maxAttempts = 200

  local boundaryMaxDist = math.sqrt((boundaryWidth / 2) ^ 2 + (boundaryHeight / 2) ^ 2)
  local startAngle = openingAngle + 180 - (angleRange / 2)

  for i = 1, count do
    local validPosition = false
    local attempts = 0

    while not validPosition and attempts < maxAttempts do
      attempts = attempts + 1

      local randomAngle = startAngle + (math.random() * angleRange)
      randomAngle = randomAngle % 360

      local candidate = GameApi.World_GetPointFromBearing({
        latitude = centerLat,
        longitude = centerLon,
        bearing = randomAngle,
        distance = radius
      })

      local valid = true

      -- Ensure fire point is outside the boundary rectangle
      local distanceToCenter = GameUtils.calculateDistance(centerLat, centerLon, candidate.latitude, candidate.longitude)
      local halfSquare = squareSize / 2
      local squareDiagonal = math.sqrt(2) * halfSquare
      local minSafeDistance = boundaryMaxDist + squareDiagonal + margin

      if distanceToCenter < minSafeDistance then
        valid = false
      end

      -- Check overlap with existing fire points
      if valid then
        for _, existingFirePoint in ipairs(firePoints) do
          if checkSquaresOverlap(
                candidate.latitude, candidate.longitude,
                existingFirePoint.center.latitude, existingFirePoint.center.longitude,
                squareSize, margin
              ) then
            valid = false
            break
          end
        end
      end

      if valid then
        local bearingToCenter = GameApi.Tool_Bearing(
          { latitude = candidate.latitude, longitude = candidate.longitude },
          { latitude = centerLat, longitude = centerLon }
        )

        local vertices = generateSquareVertices(
          candidate.latitude, candidate.longitude,
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
      Logger.error(string.format(
        "Failed to place fire point %d/%d after %d attempts.",
        i, count, maxAttempts
      ))
    end
  end

  local firePointVertices = {}
  for idx, fp in ipairs(firePoints) do
    firePointVertices[idx] = fp.vertices
  end

  return firePointVertices
end

---Generate AHA (Ammo Holding Area) position outside the boundary, along openingAngle direction
---@param centerLat number Center latitude in degrees
---@param centerLon number Center longitude in degrees
---@param radius number Distance from center in nautical miles
---@param squareSize number AHA square size in nautical miles
---@param openingAngle number Opening direction in degrees
---@return CMO__Location[] # Array of 4 vertices forming the AHA square
local function generateAhaPosition(centerLat, centerLon, radius, squareSize, openingAngle)
  local ahaCenter = GameApi.World_GetPointFromBearing({
    latitude = centerLat,
    longitude = centerLon,
    bearing = openingAngle,
    distance = radius
  })
  return generateSquareVertices(ahaCenter.latitude, ahaCenter.longitude, squareSize, openingAngle)
end

-- ============================================================================
-- Public API Functions
-- ============================================================================

---Generate rectangular boundary area vertices with specified configuration
---Returns ordered vertices forming a quadrilateral, and optionally generates internal squares and fire points
---@param areaConfig SBJ__UShapeAreaConfig Configuration object for area generation
---@return SBJ__UShapeAreaResult result Contains uShapeVertices and optionally ammoArea, hideArea, reloadArea, firePoints
function TacticalAreaGenerator.generateUShapeVertices(areaConfig)
  assert(areaConfig.centerLat, "config.centerLat is required")
  assert(areaConfig.centerLon, "config.centerLon is required")
  assert(areaConfig.width, "config.width is required")
  assert(areaConfig.height, "config.height is required")
  assert(areaConfig.openingAngle, "config.openingAngle is required")

  local result = {}

  local centerLat = areaConfig.centerLat
  local centerLon = areaConfig.centerLon
  local width = areaConfig.width
  local height = areaConfig.height
  local openingAngle = areaConfig.openingAngle

  local halfWidth = width / 2
  local halfHeight = height / 2

  local outerDiagonalDist = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
  local baseAngle = math.deg(Utils.atan2(halfWidth, halfHeight))

  local outerAngles = {
    360 - baseAngle, -- Top-left
    baseAngle,       -- Top-right
    180 - baseAngle, -- Bottom-right
    180 + baseAngle  -- Bottom-left
  }

  local outerCorners = {}
  for i = 1, 4 do
    outerCorners[i] = GameApi.World_GetPointFromBearing({
      latitude = centerLat,
      longitude = centerLon,
      bearing = (outerAngles[i] + openingAngle) % 360,
      distance = outerDiagonalDist
    })
  end

  -- Boundary is a simple quadrilateral (4 vertices)
  result.uShapeVertices = { outerCorners[1], outerCorners[2], outerCorners[3], outerCorners[4] }

  if areaConfig.internalSquares then
    local internalSquares = generateInternalSquares(
      outerCorners,
      openingAngle,
      areaConfig.internalSquares.size,
      width,
      height,
      areaConfig.internalSquares.marginToWall,
      areaConfig.internalSquares.marginBetweenSquares
    )

    result.hideArea = internalSquares.hideArea
    result.reloadArea = internalSquares.reloadArea
  end

  if areaConfig.ahaPoint then
    result.ammoArea = generateAhaPosition(
      centerLat,
      centerLon,
      areaConfig.ahaPoint.radius,
      areaConfig.ahaPoint.squareSize,
      openingAngle
    )
  end

  if areaConfig.firePoints then
    result.firePoints = generateFirePoints(
      centerLat,
      centerLon,
      areaConfig.firePoints.radius,
      areaConfig.firePoints.squareSize,
      areaConfig.firePoints.count,
      areaConfig.firePoints.angleRange or 360,
      openingAngle,
      areaConfig.firePoints.margin or 0.1,
      width,
      height
    )
  end

  return result
end

---Calculate movement paths between tactical positions (avoid other position squares only)
---@param pathConfig SBJ__MovementPathsConfig Configuration for path calculation
---@return SBJ__MovementPaths # Movement paths organized by type (FP, HA, RL, AHA)
function TacticalAreaGenerator.calculateMovementPaths(pathConfig)
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

  local ammoCtr = calculateSquareCenter(pathConfig.ammoArea)
  local hideCtr = calculateSquareCenter(pathConfig.hideArea)
  local reloadCtr = calculateSquareCenter(pathConfig.reloadArea)

  -- HA: reload -> hide, avoid ammo
  paths.HA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude, reloadCtr.longitude,
    hideCtr.latitude, hideCtr.longitude,
    avoidanceMargin,
    { pathConfig.ammoArea }
  )

  -- AHA: reload -> ammo, avoid hide
  paths.AHA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude, reloadCtr.longitude,
    ammoCtr.latitude, ammoCtr.longitude,
    avoidanceMargin,
    { pathConfig.hideArea }
  )

  -- FP: hide -> fire points, avoid ammo & reload
  if pathConfig.firePoints then
    for i, firePoint in ipairs(pathConfig.firePoints) do
      local fpCtr = calculateSquareCenter(firePoint)
      paths.FP[i] = {
        waypoints = generatePathWithAvoidance(
          hideCtr.latitude, hideCtr.longitude,
          fpCtr.latitude, fpCtr.longitude,
          avoidanceMargin,
          { pathConfig.ammoArea, pathConfig.reloadArea }
        )
      }
    end
  end

  -- RL: fire points -> reload, avoid ammo & hide
  if pathConfig.firePoints then
    for i, firePoint in ipairs(pathConfig.firePoints) do
      local fpCtr = calculateSquareCenter(firePoint)
      paths.RL[i] = {
        waypoints = generatePathWithAvoidance(
          fpCtr.latitude, fpCtr.longitude,
          reloadCtr.latitude, reloadCtr.longitude,
          avoidanceMargin,
          { pathConfig.ammoArea, pathConfig.hideArea }
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
--   -- Boundary basic configuration (required)
--   centerLat = u.latitude,
--   centerLon = u.longitude,
--   width = 1.5,            -- Boundary width (nautical miles)
--   height = 1.5,           -- Boundary height (nautical miles)
--   openingAngle = 30,      -- Opening direction angle (0=North, 90=East, 180=South, 270=West)

--   -- Internal two functional zones configuration (optional)
--   internalSquares = {
--     size = 0.2,                    -- Square side length (nautical miles)
--     marginToWall = 0.1,            -- Distance to boundary wall (nautical miles)
--     marginBetweenSquares = 0.5     -- Distance between squares (nautical miles)
--   },

--   -- Outer fire points configuration (optional)
--   firePoints = {
--     radius = 3,            -- Fire point circle radius (nautical miles)
--     squareSize = 0.3,      -- Fire point square side length (nautical miles)
--     count = 2,             -- Number of fire points
--     angleRange = 90,       -- Angular range (degrees), 360=full circle, 180=semicircle
--     margin = 0.2           -- Safety margin between fire points (nautical miles)
--   },

--   -- External AHA (Ammo Holding Area) configuration (optional)
--   ahaPoint = {
--     radius = 15,           -- Distance from center along openingAngle direction (nautical miles)
--     squareSize = 0.3       -- AHA square side length (nautical miles)
--   }
-- })

-- -- Create reference areas
-- ScenEdit_AddReferencePoint({side="Taiwan", name="Boundary Area", area = result.uShapeVertices})

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
--     ammoArea = result.ammoArea,
--     hideArea = result.hideArea,
--     reloadArea = result.reloadArea,
--     firePoints = result.firePoints,
--     avoidanceMargin = 0.05  -- Safety distance to avoid positions (nautical miles)
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
-- --u.course=paths.RL[1].waypoints
-- --u.course=paths.RL[2].waypoints
-- --u.course=paths.AHA.waypoints
-- end

return TacticalAreaGenerator
