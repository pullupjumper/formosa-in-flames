local math = require("math")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")

local BearingOnlyLaunch = {}

-- Earth radius (nautical miles)
EARTH_RADIUS_NM = 3440.065

---Convert degrees to radians
---@param degrees number Degrees
---@return number # Radians
local function deg2rad(degrees) return degrees * math.pi / 180 end

---Convert radians to degrees
---@param radians number Radians
---@return number # Degrees
local function rad2deg(radians) return radians * 180 / math.pi end

---Calculate destination point based on starting point, bearing, and distance
---@param pos CMO__Location Starting point
---@param bearingDeg number Bearing in degrees
---@param distanceNm number Distance in nautical miles
---@return CMO__Location # Destination point
local function calculateDestinationPoint(pos, bearingDeg, distanceNm)
  local bearing = deg2rad(bearingDeg)
  local lat1 = deg2rad(pos.latitude)
  local lon1 = deg2rad(pos.longitude)
  local dDivR = distanceNm / EARTH_RADIUS_NM

  local lat2 = math.asin(math.sin(lat1) * math.cos(dDivR) +
    math.cos(lat1) * math.sin(dDivR) * math.cos(bearing))
  local lon2 = lon1 + Utils.atan2(math.sin(bearing) * math.sin(dDivR) * math.cos(lat1),
    math.cos(dDivR) - math.sin(lat1) * math.sin(lat2))

  return { latitude = rad2deg(lat2), longitude = rad2deg(lon2) }
end

---Calculate distance between two points using Haversine formula
---@param lat1 number First point latitude
---@param lon1 number First point longitude
---@param lat2 number Second point latitude
---@param lon2 number Second point longitude
---@return number # Distance in nautical miles
local function calculateHaversineNM(lat1, lon1, lat2, lon2)
  local dLat = deg2rad(lat2 - lat1)
  local dLon = deg2rad(lon2 - lon1)
  local a = math.sin(dLat / 2) ^ 2 +
      math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) * math.sin(dLon / 2) ^ 2
  local c = 2 * Utils.atan2(math.sqrt(a), math.sqrt(1 - a))
  return EARTH_RADIUS_NM * c
end

---Check if path crosses radar circular area using midpoint approximation
---@param startPos {latitude: number, longitude: number} Path start
---@param endPos {latitude: number, longitude: number} Path end
---@param radarPos {latitude: number, longitude: number} Radar position
---@param radarRangeNm number Radar range in nautical miles
---@return boolean # True if path intersects radar circle
local function isIntersectingRadarCircle(startPos, endPos, radarPos, radarRangeNm)
  local midLat = (startPos.latitude + endPos.latitude) / 2
  local midLon = (startPos.longitude + endPos.longitude) / 2
  local dist = calculateHaversineNM(midLat, midLon, radarPos.latitude, radarPos.longitude)
  return dist < radarRangeNm
end


---Generate missile paths that avoid radar detection zones
---@param params SBJ__GenerateMissilePathsParams Parameters for generating missile paths
---@return table<integer, SBJ__MissilePath> # Missile path list with waypoints and launch times
function BearingOnlyLaunch.buildMissilePaths(params)
  local result = {}
  local now = GameApi.ScenEdit_CurrentTime()

  local targetLat = params.targetLat
  local targetLon = params.targetLon
  local launcherLat = params.launcherLat
  local launcherLon = params.launcherLon
  local radarRange = params.radarRange
  -- local radarDir = params.radarDir
  -- local radarFov = params.radarFov or 360
  local count = params.missileCount or 5
  local speed = params.missileSpeedKts or 600
  local maxRange = params.missileRangeNm or 100

  for i = 1, count do
    local angle = ((i - 1) / count) * 360 -- Evenly distributed angles

    local distMult = 1.5
    local maxAttempts = 10
    local wpLat, wpLon = nil, nil
    local valid = false

    for attempt = 1, maxAttempts do
      local d = radarRange * distMult
      local wpPos = calculateDestinationPoint({ latitude = targetLat, longitude = targetLon }, angle, d)
      wpLat, wpLon = wpPos.latitude, wpPos.longitude

      local crossesRadar = isIntersectingRadarCircle(
        { latitude = launcherLat, longitude = launcherLon },
        { latitude = wpLat, longitude = wpLon },
        { latitude = targetLat, longitude = targetLon },
        radarRange
      )
      local totalDistance = calculateHaversineNM(launcherLat, launcherLon, wpLat, wpLon) +
          calculateHaversineNM(wpLat, wpLon, targetLat, targetLon)

      if not crossesRadar and totalDistance <= maxRange then
        valid = true
        break
      end

      distMult = distMult + 0.5 -- Push outward
    end

    if valid then
      local totalDistance = calculateHaversineNM(launcherLat, launcherLon, wpLat, wpLon) +
          calculateHaversineNM(wpLat, wpLon, targetLat, targetLon)
      local flightTime = totalDistance / speed * 3600 -- seconds
      table.insert(result, {
        waypoints = {
          { latitude = wpLat, longitude = wpLon }
        },
        launchTime = now - flightTime
      })
    end
  end

  return result
end

return BearingOnlyLaunch
