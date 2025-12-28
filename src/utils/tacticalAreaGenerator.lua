local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

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
  local GameUtils = require("src.utils.gameUtils")
  local distanceToCenter = GameUtils.calculateDistance(centerLat, centerLon, squareLat, squareLon)

  -- Check if square is too close to U-shape
  -- Square should be outside U-shape bounding box plus its own half diagonal
  local halfSquare = squareSize / 2
  local squareDiagonal = math.sqrt(2) * halfSquare
  local minSafeDistance = uShapeMaxDist + squareDiagonal + margin

  return distanceToCenter < minSafeDistance
end

-- ============================================================================
-- Public API Functions
-- ============================================================================

---Generate square vertices from center point
---@param centerLat number Center latitude in degrees
---@param centerLon number Center longitude in degrees
---@param size number Square size in nautical miles
---@param rotationAngle number Rotation angle in degrees
---@return table<CMO__Location> # Array of 4 vertices forming a square
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
  local GameUtils = require("src.utils.gameUtils")
  local distance = GameUtils.calculateDistance(center1Lat, center1Lon, center2Lat, center2Lon)
  return distance < (squareSize + margin)
end

---Generate U-shaped area vertices with specified configuration
---Returns ordered vertices forming a U-shape (3 sides closed, 1 side open), and optionally generates internal squares and fire points
---@param config SBJ__UShapeAreaConfig Configuration object for U-shaped area generation
---@return SBJ__UShapeAreaResult result Contains uShapeVertices and optionally ammoArea, hideArea, reloadArea, firePoints with vertices
function TacticalAreaGenerator.generateUShapeVertices(config)
  -- Validate required fields
  assert(config.centerLat, "config.centerLat is required")
  assert(config.centerLon, "config.centerLon is required")
  assert(config.thickness, "config.thickness is required")
  assert(config.width, "config.width is required")
  assert(config.height, "config.height is required")
  assert(config.openingAngle, "config.openingAngle is required")

  local result = {}
  local vertices = {}

  -- Extract config values
  local centerLat = config.centerLat
  local centerLon = config.centerLon
  local thickness = config.thickness
  local width = config.width
  local height = config.height
  local openingAngle = config.openingAngle

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
  if config.internalSquares then
    local internalSquares = TacticalAreaGenerator.generateInternalSquares(
      innerCorners,
      openingAngle,
      config.internalSquares.size,
      width - 2 * thickness,
      height - thickness,
      config.internalSquares.marginToWall,
      config.internalSquares.marginBetweenSquares
    )

    result.ammoArea = internalSquares.ammoArea
    result.hideArea = internalSquares.hideArea
    result.reloadArea = internalSquares.reloadArea
  end

  -- Generate fire points on circle perimeter if firePoints config is specified
  if config.firePoints then
    result.firePoints = TacticalAreaGenerator.generateFirePoints(
      centerLat,
      centerLon,
      config.firePoints.radius,
      config.firePoints.squareSize,
      config.firePoints.count,
      config.firePoints.angleRange or 360,
      openingAngle,
      config.firePoints.margin or 0.1,
      vertices,
      width,
      height
    )
  end

  return result
end

---Generate three non-overlapping squares inside the U-shape's internal rectangle
---@param innerCorners table<CMO__Location> Four corners of internal rectangle
---@param openingAngle number Opening direction in degrees
---@param squareSize number Size of squares in nautical miles
---@param innerWidth number Width of internal rectangle in nautical miles
---@param innerHeight number Height of internal rectangle in nautical miles
---@param marginToWall? number Safety margin between squares and U-shape walls in nm (default: 0.1)
---@param marginBetweenSquares? number Safety margin between squares in nm (default: 0.1)
---@return table areas Contains ammoArea, hideArea, reloadArea with vertices arrays
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
      error(string.format("Failed to place %s after %d attempts", areaNames[i], maxAttempts))
    end
  end

  -- Generate vertices for each square
  areas.ammoArea = TacticalAreaGenerator.generateSquareVertices(centers[1].latitude, centers[1].longitude, squareSize,
    openingAngle)
  areas.hideArea = TacticalAreaGenerator.generateSquareVertices(centers[2].latitude, centers[2].longitude, squareSize,
    openingAngle)
  areas.reloadArea = TacticalAreaGenerator.generateSquareVertices(centers[3].latitude, centers[3].longitude, squareSize,
    openingAngle)

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
---@return table<table<CMO__Location>> # Array of fire point areas, each with 4 vertices
function TacticalAreaGenerator.generateFirePoints(centerLat, centerLon, radius, squareSize, count, angleRange,
                                                  openingAngle, margin, uShapeVertices, uShapeWidth, uShapeHeight)
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
                existingFirePoint.center.latitude, existingFirePoint.center.longitude,
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

return TacticalAreaGenerator
