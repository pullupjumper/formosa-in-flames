local math = require("math")
local Utils = require("src.utils.utils")

local BearingOnlyLaunch = {}

-- Earth radius (nautical miles)
EARTH_RADIUS_NM = 3440.065

-- Angle and radian conversion
local function deg2rad(d) return d * math.pi / 180 end
local function rad2deg(r) return r * 180 / math.pi end

-- Calculate destination based on starting point, bearing, and distance
local function destinationPoint(lat, lon, bearingDeg, distanceNm)
  local bearing = deg2rad(bearingDeg)
  local lat1 = deg2rad(lat)
  local lon1 = deg2rad(lon)
  local dDivR = distanceNm / EARTH_RADIUS_NM

  local lat2 = math.asin(math.sin(lat1) * math.cos(dDivR) +
    math.cos(lat1) * math.sin(dDivR) * math.cos(bearing))
  local lon2 = lon1 + Utils.atan2(math.sin(bearing) * math.sin(dDivR) * math.cos(lat1),
    math.cos(dDivR) - math.sin(lat1) * math.sin(lat2))

  return rad2deg(lat2), rad2deg(lon2)
end

-- Calculate distance between two points (nautical miles)
local function haversineNM(lat1, lon1, lat2, lon2)
  local dLat = deg2rad(lat2 - lat1)
  local dLon = deg2rad(lon2 - lon1)
  local a = math.sin(dLat / 2) ^ 2 +
      math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) * math.sin(dLon / 2) ^ 2
  local c = 2 * Utils.atan2(math.sqrt(a), math.sqrt(1 - a))
  return EARTH_RADIUS_NM * c
end

-- Check if path crosses radar circular area (approximated using midpoint)
local function intersectsRadarCircle(lat1, lon1, lat2, lon2, radarLat, radarLon, radarRangeNm)
  local midLat = (lat1 + lat2) / 2
  local midLon = (lon1 + lon2) / 2
  local dist = haversineNM(midLat, midLon, radarLat, radarLon)
  return dist < radarRangeNm
end


-- Main function
---@param params SBJ__GenerateMissilePaths_Params Parameters for generating missile paths
---@return table<integer, SBJ__MissilePath> Returns missile path list
---Example:
-- local paths = Generate_missile_paths({
--   target_lat = 34.0,
--   target_lon = -118.0,
--   launcher_lat = 33.0,
--   launcher_lon = -117.0,
--   radar_range = 50,
--   missile_count = 5,
--   missile_speed_kts = 600,
--   missile_range_nm = 100
-- })
-- local u=ScenEdit_GetUnit({name='SSM Plt (Hsiung Feng III)', guid='IC8B0X-0HND5HOHSH38N'})
-- local c=ScenEdit_GetContact({side='Taiwan', guid='IC8B0X-0HND5HOHSLL5K'})
-- local missiles = generate_missile_paths({
--     target_lat = c.latitude,
--     target_lon = c.longitude,
--     launcher_lat = u.latitude,
--     launcher_lon = u.longitude,
--     radar_range = 7,
--     radar_dir = 0,         -- Enemy radar direction (e.g. facing southwest, towards us)
--     radar_fov = 120,
--     missile_count = 8,
--     missile_speed_kts = 1600,
--     missile_range_nm = 100
-- })
-- print(u.mounts[1])
-- for k,v in ipairs(missiles)do
-- print(v.launchTime)
-- print( os.date("%m/%d/%Y %I:%M:%S %p", (v.launchTime)))
-- local r=ScenEdit_AttackContact(u.guid, c.guid, { mode=1, mount=3613, weapon=1133, qty=1, course=v.waypoints})
-- print(r)
-- end
function BearingOnlyLaunch.generateMissilePaths(params)
  local result = {}
  local now = os.time()

  local targetLat = params.targetLat
  local targetLon = params.targetLon
  local launcherLat = params.launcherLat
  local launcherLon = params.launcherLon
  local radarRange = params.radarRange
  local radarDir = params.radarDir
  local radarFov = params.radarFov or 360
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
      wpLat, wpLon = destinationPoint(targetLat, targetLon, angle, d)

      local crossesRadar = intersectsRadarCircle(launcherLat, launcherLon, wpLat, wpLon, targetLat, targetLon,
        radarRange)
      local totalDistance = haversineNM(launcherLat, launcherLon, wpLat, wpLon) +
          haversineNM(wpLat, wpLon, targetLat, targetLon)

      if not crossesRadar and totalDistance <= maxRange then
        valid = true
        break
      end

      distMult = distMult + 0.5 -- Push outward
    end

    if valid then
      local totalDistance = haversineNM(launcherLat, launcherLon, wpLat, wpLon) +
          haversineNM(wpLat, wpLon, targetLat, targetLon)
      local flightTime = totalDistance / speed * 3600 -- seconds
      table.insert(result, {
        waypoints = {
          { lat = wpLat, lon = wpLon }
        },
        launchTime = now - flightTime
      })
    end
  end

  return result
end

return BearingOnlyLaunch
