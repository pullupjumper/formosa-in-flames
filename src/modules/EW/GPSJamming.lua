local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local GPSJamming = {}

---Convert full side name to config key
---@param sideName string Full side name (e.g., "China", "Taiwan")
---@return string -- Config key ("c" or "t")
local function getSideKey(sideName)
  return sideName == 'China' and 'c' or 't'
end

---Get enemy side name
---@param sideName string Current side name
---@return string -- Enemy side name
local function getEnemySide(sideName)
  return sideName == 'China' and 'Taiwan' or 'China'
end


---Add jamming zone for a GPS jammer unit
---@param unit CMO__Unit
---@param descriptor SBJ__GPSJammerDescriptor
---@param point CMO__Location
---@param sideName string
---@param enemySideName string
---@return boolean -- Whether the jamming zone was successfully created
local function addJammingZone(unit, descriptor, point, sideName, enemySideName)
  GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

  local area = GameUtils.newArea(point, {
    side = sideName,
    shape = 'circle',
    distance = descriptor.radius
  })

  if area and type(area) == 'table' then
    GameApi.ScenEdit_AddZone(sideName, -925, {
      description = descriptor.zoneName,
      area = area
    })

    GameUtils.unitEntersAreaEvent(
      descriptor.zoneName,
      { TargetSide = enemySideName, TargetType = 6 },
      area,
      'GPSJamming.jamming(config, \"' .. sideName .. '\")',
      'add',
      false,
      true,
      true
    )
    return true
  end
  return false
end

---Remove GPS jamming event and cleanup
---@param descriptor SBJ__GPSJammerDescriptor
---@param zone CMO__Zone
---@param sideObj CMO__Side
---@param sideName string
---@param isDeleted? boolean
---@return boolean -- Whether the removal was successful
local function removeEvent(descriptor, zone, sideObj, sideName, isDeleted)
  local myz = sideObj:getstandardzone(zone.guid)

  for _, area in ipairs(myz.area) do
    GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = area.name })
  end

  GameApi.ScenEdit_RemoveZone(sideName, -925, { Description = myz.description })

  if isDeleted then
    GameApi.ScenEdit_DeleteUnit({ side = sideName, unitname = descriptor.name })
  end
  GameUtils.unitEntersAreaEvent(descriptor.zoneName, {}, {}, '', 'remove', false, false, false)
  Logger.log("[GPS Jamming] Removed GPS jamming zone: " .. descriptor.zoneName)
  return true
end

---Process GPS jamming for weapons entering jamming zone
---@param config SBJ__CONFIG Configuration
---@param sideName string Side name
---@return boolean -- Whether jamming was successfully applied
function GPSJamming.jamming(config, sideName)
  local side = getSideKey(sideName)
  local weapon = GameApi.ScenEdit_UnitX()
  local weaponU

  if weapon then
    weaponU = GameApi.ScenEdit_GetUnit(weapon.guid)
  else
    Logger.error("[GPS Jamming] No weapon unit found in jamming event")
    return false
  end

  if not weaponU then
    Logger.error("[GPS Jamming] Failed to get weapon unit wrapper")
    return false
  end

  for i, wpn in ipairs(config[side].GPSJamming.GPSGuidedWeapons) do
    if weaponU and weaponU.dbid == wpn.dbid then
      local jamChance = math.random(100)

      if jamChance > wpn.jammingResistance then
        Logger.log("[GPS Jamming] GPS jamming successful on " .. weaponU.name)

        if weaponU.course then
          local count = Utils.getCount(weaponU.course)
          local lastWaypoint

          if count == 0 then
            lastWaypoint = { latitude = weaponU.target.latitude, longitude = weaponU.target.longitude }
          else
            lastWaypoint = weaponU.course[count]
          end

          local originalLat = lastWaypoint.latitude
          local originalLon = lastWaypoint.longitude

          local lat = originalLat + math.random(-100, 100) / 10 ^ 4
          local lon = originalLon + math.random(-100, 100) / 10 ^ 4

          -- We change the course of the weapon assigning the new latitude and longitude info
          if count == 1 or count == 0 then -- If the unit only has the terminal point
            weaponU.target = { latitude = lat, longitude = lon, GUID = 'BOL' }
            weaponU.course = { { latitude = lat, longitude = lon, TypeOf = 'TerminalPoint' } }
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
          end
        else
          Logger.error("[GPS Jamming] Weapon " .. weaponU.name .. " has no course data")
          return false
        end
        return true
      else
        Logger.log("[GPS Jamming] Weapon " .. weaponU.name .. " resisted jamming")
        return false
      end
    end
  end

  return false
end

---Remove all GPS jammers for a side
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor>
---@param sideName string
---@return number -- Number of jammers removed
function GPSJamming.removeJammers(jammerDescriptors, sideName)
  -- local side = getSideKey(sideName)
  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if sideObj == nil then return 0 end

  local removedCount = 0
  for _, zone in ipairs(sideObj.standardzones) do
    for _, descriptor in pairs(jammerDescriptors) do
      if zone.description == descriptor.zoneName then
        if removeEvent(descriptor, zone, sideObj, sideName, true) then
          removedCount = removedCount + 1
        end
      end
    end
  end
  return removedCount
end

---Add a single GPS jammer
---@param config SBJ__CONFIG
---@param descriptor SBJ__GPSJammerDescriptor
---@param sideName string
---@return boolean, CMO__Unit|nil -- Success status and created unit
function GPSJamming.addGPSJammer(config, descriptor, sideName)
  local enemySideName = getEnemySide(sideName)
  local unit = GameApi.ScenEdit_AddUnit({
    side = sideName,
    unitname = descriptor.name,
    dbid = config.platform.GPS_JAMMER,
    type = 'Facility',
    latitude = descriptor.point.lat,
    longitude = descriptor.point.lon
  })
  local point = { latitude = descriptor.point.lat, longitude = descriptor.point.lon }

  if unit then
    local success = addJammingZone(unit, descriptor, point, sideName, enemySideName)
    return success, unit
  end
  return false, nil
end

---Add all GPS jammers for a side
---@param config SBJ__CONFIG
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor>
---@param sideName string
---@return number -- Number of jammers successfully created
function GPSJamming.addGPSJammers(config, jammerDescriptors, sideName)
  -- local side = getSideKey(sideName)
  local enemySideName = getEnemySide(sideName)
  local successCount = 0

  for _, descriptor in pairs(jammerDescriptors) do
    local unit, point = GameUtils.tryAddUnit(
      descriptor.name,
      descriptor.point.lat,
      descriptor.point.lon,
      descriptor.randomRadius,
      config.platform.GPS_JAMMER
    )

    if unit and point then
      if addJammingZone(unit, descriptor, point, sideName, enemySideName) then
        successCount = successCount + 1
      end
    end
  end
  return successCount
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

---Remove specific GPS jamming zone by name
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor>
---@param sideName string
---@param name string
---@return boolean -- Whether the zone was successfully removed
function GPSJamming.removeJammingZoneByName(jammerDescriptors, sideName, name)
  -- local side = getSideKey(sideName)

  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if sideObj == nil then return false end

  local descriptor = jammerDescriptors[name]

  if descriptor then
    for _, zone in ipairs(sideObj.standardzones) do
      if zone.description == descriptor.zoneName then
        return removeEvent(descriptor, zone, sideObj, sideName)
      end
    end
  end
  return false

  -- for _, jammerData in pairs(config[side].GPSJamming.jammers) do
  --   if unit.name ~= jammerData.name then goto continue end

  --   for _, zone in ipairs(s.standardzones) do
  --     if zone.description == jammerData.zoneName then
  --       local myz = s:getstandardzone(zone.guid)

  --       for _, area in ipairs(myz.area) do
  --         GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = area.name })
  --       end

  --       GameApi.ScenEdit_RemoveZone(sideName, -925, { Description = myz.description })
  --       GameUtils.unitEntersAreaEvent(jammerData.zoneName, {}, {}, '', 'remove', false, false, false)
  --       Logger.log("[GPS Jamming] Removed GPS jamming zone: " .. jammerData.zoneName)
  --     end
  --   end

  --   ::continue::
  -- end
end

return GPSJamming
