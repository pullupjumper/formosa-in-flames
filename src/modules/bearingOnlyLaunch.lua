local math = require("math")

-- Earth radius (nautical miles)
local R = 3440.065

-- Angle and radian conversion
local function deg2rad(d) return d * math.pi / 180 end
local function rad2deg(r) return r * 180 / math.pi end

-- Calculate destination based on starting point, bearing, and distance
local function destination_point(lat, lon, bearing_deg, distance_nm)
  local bearing = deg2rad(bearing_deg)
  local lat1 = deg2rad(lat)
  local lon1 = deg2rad(lon)
  local d_div_r = distance_nm / R

  local lat2 = math.asin(math.sin(lat1) * math.cos(d_div_r) +
    math.cos(lat1) * math.sin(d_div_r) * math.cos(bearing))
  local lon2 = lon1 + math.atan2(math.sin(bearing) * math.sin(d_div_r) * math.cos(lat1),
    math.cos(d_div_r) - math.sin(lat1) * math.sin(lat2))

  return rad2deg(lat2), rad2deg(lon2)
end

-- Calculate distance between two points (nautical miles)
local function haversine_nm(lat1, lon1, lat2, lon2)
  local dlat = deg2rad(lat2 - lat1)
  local dlon = deg2rad(lon2 - lon1)
  local a = math.sin(dlat / 2) ^ 2 +
      math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) * math.sin(dlon / 2) ^ 2
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
  return R * c
end

-- Check if path crosses radar circular area (approximated using midpoint)
local function intersects_radar_circle(lat1, lon1, lat2, lon2, radar_lat, radar_lon, radar_range_nm)
  local mid_lat = (lat1 + lat2) / 2
  local mid_lon = (lon1 + lon2) / 2
  local dist = haversine_nm(mid_lat, mid_lon, radar_lat, radar_lon)
  return dist < radar_range_nm
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
-- print(v.launch_time)
-- print( os.date("%m/%d/%Y %I:%M:%S %p", (v.launch_time)))
-- local r=ScenEdit_AttackContact(u.guid, c.guid, { mode=1, mount=3613, weapon=1133, qty=1, course=v.waypoints})
-- print(r)
-- end
function Generate_missile_paths(params)
  local result = {}
  local now = os.time()

  local target_lat = params.target_lat
  local target_lon = params.target_lon
  local launcher_lat = params.launcher_lat
  local launcher_lon = params.launcher_lon
  local radar_range = params.radar_range
  local radar_dir = params.radar_dir
  local radar_fov = params.radar_fov or 360
  local count = params.missile_count or 5
  local speed = params.missile_speed_kts or 600
  local max_range = params.missile_range_nm or 100

  for i = 1, count do
    local angle = ((i - 1) / count) * 360 -- Evenly distributed angles

    local dist_mult = 1.5
    local max_attempts = 10
    local wp_lat, wp_lon = nil, nil
    local valid = false

    for attempt = 1, max_attempts do
      local d = radar_range * dist_mult
      wp_lat, wp_lon = destination_point(target_lat, target_lon, angle, d)

      local crosses_radar = intersects_radar_circle(launcher_lat, launcher_lon, wp_lat, wp_lon, target_lat, target_lon,
        radar_range)
      local total_distance = haversine_nm(launcher_lat, launcher_lon, wp_lat, wp_lon) +
          haversine_nm(wp_lat, wp_lon, target_lat, target_lon)

      if not crosses_radar and total_distance <= max_range then
        valid = true
        break
      end

      dist_mult = dist_mult + 0.5 -- Push outward
    end

    if valid then
      local total_distance = haversine_nm(launcher_lat, launcher_lon, wp_lat, wp_lon) +
          haversine_nm(wp_lat, wp_lon, target_lat, target_lon)
      local flight_time = total_distance / speed * 3600 -- seconds
      table.insert(result, {
        waypoints = {
          { lat = wp_lat, lon = wp_lon }
        },
        launch_time = now - flight_time
      })
    end
  end

  return result
end

return {
  Generate_missile_paths = Generate_missile_paths
}
