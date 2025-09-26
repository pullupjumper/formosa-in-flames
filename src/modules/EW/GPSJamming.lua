local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local GPSJamming = {}


---comment
---@param unit CMO__Unit
---@param jammerData SBJ__GPSJammerData
---@param point CMO__Location
---@param sideName string
---@param enemySideName string
local function addJammingZone(unit, jammerData, point, sideName, enemySideName)
  GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

  local area = GameUtils.newArea(point, {
    side = sideName,
    shape = 'circle',
    distance = jammerData.radius
  })

  if area and type(area) == 'table' then
    GameApi.ScenEdit_AddZone(sideName, -925, {
      description = jammerData.zoneName,
      area = area
    })

    GameUtils.unitEntersAreaEvent(
      jammerData.zoneName,
      { TargetSide = enemySideName, TargetType = 6 },
      area,
      'GPSJamming.jamming(config, \"' .. sideName .. '\")',
      'add',
      false,
      true,
      true
    )
  end
end

---comment
---@param jammerData SBJ__GPSJammerData
---@param zone CMO__Zone
---@param sideObj CMO__Side
---@param sideName string
local function removeEvent(jammerData, zone, sideObj, sideName)
  local myz = sideObj:getstandardzone(zone.guid)

  for _, area in ipairs(myz.area) do
    GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = area.name })
  end

  GameApi.ScenEdit_RemoveZone('China', -925, { Description = myz.description })
  GameApi.ScenEdit_DeleteUnit({ side = sideName, unitname = jammerData.name })
  GameUtils.unitEntersAreaEvent(jammerData.zoneName, {}, {}, '', 'remove', false, false, false)
  Logger.log("[GPS Jamming] Removed GPS jamming zone: " .. jammerData.zoneName)
end

---comment
---@param config SBJ__CONFIG Configuration
---@param sideName string Side name
function GPSJamming.jamming(config, sideName)
  Logger.log("[GPS Jamming] GPS jamming event triggered for side: " .. sideName)

  local side = sideName == 'China' and 'c' or 't'
  local weapon = GameApi.ScenEdit_UnitX() -- Unit that trigger the events
  local weaponU

  if weapon then
    weaponU = GameApi.ScenEdit_GetUnit(weapon.guid) --Unit Wrapper of the Unit
    Logger.log("[GPS Jamming] Found weapon unit: " ..
      (weaponU and weaponU.name or "nil") .. " (GUID: " .. weapon.guid .. ")")
  else
    Logger.error("[GPS Jamming] No weapon unit found in jamming event")
    return
  end

  if not weaponU then
    Logger.error("[GPS Jamming] Failed to get weapon unit wrapper")
    return
  end

  Logger.log("[GPS Jamming] Checking weapon DBID: " ..
    weaponU.dbid .. " against " .. #config[side].GPSJamming.GPSGuidedWeapons .. " configured GPS weapons")

  for i, wpn in ipairs(config[side].GPSJamming.GPSGuidedWeapons) do
    if weaponU and weaponU.dbid == wpn.dbid then
      Logger.log("[GPS Jamming] Found matching GPS weapon: " .. weaponU.name .. " (DBID: " .. wpn.dbid .. ")")
      Logger.log("[GPS Jamming] Jamming resistance: " .. wpn.jammingResistance .. "%")

      local jamChance = math.random(100)
      Logger.log("[GPS Jamming] Jamming roll: " .. jamChance .. " vs resistance: " .. wpn.jammingResistance)

      if jamChance > wpn.jammingResistance then
        Logger.log("[GPS Jamming] GPS jamming successful! Applying course deviation to " .. weaponU.name)

        if weaponU.course then
          local count = Utils.getCount(weaponU.course)
          local lastWaypoint
          Logger.log("[GPS Jamming] Weapon course has " .. count .. " waypoints")

          if count == 0 then
            lastWaypoint = { latitude = weaponU.target.latitude, longitude = weaponU.target.longitude }
            Logger.log("[GPS Jamming] Using target coordinates as reference: " ..
              lastWaypoint.latitude .. ", " .. lastWaypoint.longitude)
          else
            lastWaypoint = weaponU.course[count]
            Logger.log("[GPS Jamming] Using last waypoint as reference: " ..
              lastWaypoint.latitude .. ", " .. lastWaypoint.longitude)
          end

          local originalLat = lastWaypoint.latitude
          local originalLon = lastWaypoint.longitude

          local lat = originalLat + math.random(-100, 100) / 10 ^ 4
          local lon = originalLon + math.random(-100, 100) / 10 ^ 4

          local deviationLat = lat - originalLat
          local deviationLon = lon - originalLon
          Logger.log(string.format("[GPS Jamming] Applied GPS deviation: Lat %+.6f, Lon %+.6f", deviationLat,
            deviationLon))
          Logger.log(string.format("[GPS Jamming] New target coordinates: %.6f, %.6f (was %.6f, %.6f)", lat, lon,
            originalLat, originalLon))

          -- We change the course of the weapon assigning the new latitude and longitude info
          if count == 1 or count == 0 then -- If the unit only has the terminal point
            weaponU.target = { latitude = lat, longitude = lon, GUID = 'BOL' }
            weaponU.course = { { latitude = lat, longitude = lon, TypeOf = 'TerminalPoint' } }
            Logger.log("[GPS Jamming] Updated simple course (terminal point only)")
          else -- For weapons with a predefined course of waypoints, we maintain all the waypoints
            local newCourse = {}
            for k, v in ipairs(weaponU.course) do
              if k ~= count then
                newCourse[k] = v
              else
                newCourse[k] = { latitude = lat, longitude = lon, TypeOf = 'TerminalPoint' }
              end
            end
            weaponU.course = newCourse
            weaponU.target = { latitude = lat, longitude = lon, GUID = 'BOL' }
            Logger.log("[GPS Jamming] Updated complex course (modified waypoint " .. count .. " of " .. count .. ")")
          end
        else
          Logger.error("[GPS Jamming] Weapon " .. weaponU.name .. " has no course data - cannot apply jamming")
        end
      else
        Logger.log("[GPS Jamming] GPS jamming failed - weapon " ..
          weaponU.name .. " resisted jamming (roll: " .. jamChance .. ")")
      end

      return -- Found matching weapon, exit loop
    end
  end

  Logger.log("[GPS Jamming] No matching GPS weapon found for DBID: " .. weaponU.dbid)
end

---comment
---@param config SBJ__CONFIG
---@param sideName string
function GPSJamming.removeJammers(config, sideName)
  local side = sideName == 'China' and 'c' or 't'
  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if sideObj == nil then return end

  for _, zone in ipairs(sideObj.standardzones) do
    for _, jammerData in pairs(config[side].GPSJamming.jammers) do
      if zone.description == jammerData.zoneName then
        removeEvent(jammerData, zone, sideObj, sideName)
      end
    end
  end
end

---comment
---@param config SBJ__CONFIG
---@param jammerData SBJ__GPSJammerData
---@param sideName string
function GPSJamming.addGPSJammer(config, jammerData, sideName)
  local enemySideName = sideName == 'China' and 'Taiwan' or 'China'
  local unit = GameApi.ScenEdit_AddUnit({
    side = sideName,
    unitname = jammerData.name,
    dbid = config.platform.GPS_JAMMER,
    type = 'Facility',
    latitude = jammerData.point.lat,
    longitude = jammerData.point.lon
  })
  local point = { latitude = jammerData.point.lat, longitude = jammerData.point.lon }

  if unit then
    addJammingZone(unit, jammerData, point, sideName, enemySideName)
  end
end

---comment
---@param config SBJ__CONFIG
---@param sideName string
function GPSJamming.addGPSJammers(config, sideName)
  local side = sideName == 'China' and 'c' or 't'
  local enemySideName = sideName == 'China' and 'Taiwan' or 'China'

  for _, jammerData in pairs(config[side].GPSJamming.jammers) do
    local unit, point = GameUtils.tryAddUnit(
      config,
      jammerData.name,
      jammerData.point.lat,
      jammerData.point.lon,
      jammerData.randomRadius,
      config.platform.GPS_JAMMER
    )

    if unit and point then
      addJammingZone(unit, jammerData, point, sideName, enemySideName)
    end
  end
end

---comment
-- -@param config SBJ__CONFIG
-- -@param unit CMO__Unit
-- function GPSJamming.turnOffGPSEffectByUnit(config, unit)
--   local s = GameApi.VP_GetSide({ name = 'China' })
--   if s == nil then return end

--   for _, jammer in ipairs(config.c.GPSJamming.jammers) do
--     if unit.name ~= jammer.name then goto continue end

--     for _, zone in ipairs(s.standardzones) do
--       if zone.description == jammer.zoneName then
--         local myz = s:getstandardzone(zone.guid)
--         myz.enablers = { GNSS_GLONASS = true, GNSS_GPS = true, GNSS_BeiDou = true, GNSS_NavIC = true }
--       end
--     end

--     ::continue::
--   end
-- end

---comment
---@param config SBJ__CONFIG
---@param sideName string
---@param unit CMO__Unit
function GPSJamming.removeJammingZoneByUnit(config, sideName, unit)
  local side = sideName == 'China' and 'c' or 't'

  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if sideObj == nil then return end

  local jammerData = config[side].GPSJamming.jammers[unit.name]

  if jammerData then
    for _, zone in ipairs(sideObj.standardzones) do
      if zone.description == jammerData.zoneName then
        removeEvent(jammerData, zone, sideObj, sideName)
      end
    end
  end

  -- for _, jammerData in pairs(config[side].GPSJamming.jammers) do
  --   if unit.name ~= jammerData.name then goto continue end

  --   for _, zone in ipairs(s.standardzones) do
  --     if zone.description == jammerData.zoneName then
  --       local myz = s:getstandardzone(zone.guid)

  --       for _, area in ipairs(myz.area) do
  --         GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = area.name })
  --       end

  --       GameApi.ScenEdit_RemoveZone('China', -925, { Description = myz.description })
  --       GameUtils.unitEntersAreaEvent(jammerData.zoneName, {}, {}, '', 'remove', false, false, false)
  --       Logger.log("[GPS Jamming] Removed GPS jamming zone: " .. jammerData.zoneName)
  --     end
  --   end

  --   ::continue::
  -- end
end

return GPSJamming
