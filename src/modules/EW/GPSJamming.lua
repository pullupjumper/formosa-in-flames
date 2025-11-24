local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

--- GPS Jamming
---
--- GPS denial operations management including jamming zone creation,
--- weapon course deviation simulation, and jammer deployment coordination
local GPSJamming = {}

---Add jamming zone for a GPS jammer unit
---Creates a circular zone around the jammer and sets up event trigger for weapons entering the zone
---@param unit CMO__Unit The GPS jammer unit
---@param descriptor SBJ__GPSJammerDescriptor Jammer configuration descriptor containing zone name and radius
---@param point CMO__Location Center point for the jamming zone
---@param sideName string Side name that owns the jammer (e.g., 'China', 'Taiwan')
---@param enemySideName string Enemy side name whose weapons will be jammed
---@return boolean # Whether the jamming zone was successfully created
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
---Deletes reference points, removes zone, optionally deletes unit, and removes event trigger
---@param descriptor SBJ__GPSJammerDescriptor Jammer configuration descriptor
---@param zone CMO__Zone The zone object to remove
---@param sideObj CMO__Side Side object that owns the zone
---@param sideName string Side name (e.g., 'China', 'Taiwan')
---@param isDeleted? boolean If true, also delete the jammer unit itself
---@return boolean # Whether the removal was successful
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
  Logger.log("GPSJamming", "[GPS Jamming] Removed GPS jamming zone: " .. descriptor.zoneName)
  return true
end

---Process GPS jamming for weapons entering jamming zone
---Checks if weapon is GPS-guided, applies random deviation to terminal waypoint based on jamming resistance
---Should be called from 'Unit Enters Area' event trigger
---@param config SBJ__CONFIG Configuration object containing GPS jamming settings and weapon DBIDs
---@param sideName string Enemy side name whose weapons are being jammed (e.g., 'Taiwan', 'US')
---@return boolean # Whether jamming was successfully applied to the weapon
function GPSJamming.jamming(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local side = sideConfig.field
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
        Logger.log("GPSJamming", "[GPS Jamming] GPS jamming successful on " .. weaponU.name)

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
        Logger.log("GPSJamming", "[GPS Jamming] Weapon " .. weaponU.name .. " resisted jamming")
        return false
      end
    end
  end

  return false
end

---Remove all GPS jammers for a side
---Iterates through all standard zones and removes matching GPS jamming zones and their units
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor> Collection of jammer descriptors indexed by name
---@param sideName string Side name that owns the jammers (e.g., 'China', 'Taiwan')
---@return number # Number of jammers successfully removed
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
---Creates a GPS jammer unit at the specified location and sets up its jamming zone
---@param config SBJ__CONFIG Configuration object containing platform DBIDs
---@param descriptor SBJ__GPSJammerDescriptor Jammer configuration with name, location, zone name, and radius
---@param sideName string Side name that will own the jammer (e.g., 'China', 'Taiwan')
---@return boolean success Whether jammer was successfully created and zone set up
---@return CMO__Unit|nil unit The created jammer unit, or nil if creation failed
function GPSJamming.addGPSJammer(config, descriptor, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
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
    GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')
    local success = addJammingZone(unit, descriptor, point, sideName, enemySideName)
    return success, unit
  end
  return false, nil
end

---Add all GPS jammers for a side
---Creates multiple GPS jammer units at randomized positions and sets up their jamming zones
---Uses retry logic to find valid placement locations within the random radius
---@param config SBJ__CONFIG Configuration object containing platform DBIDs
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor> Collection of jammer descriptors to create
---@param sideName string Side name that will own the jammers (e.g., 'China', 'Taiwan')
---@return number # Number of jammers successfully created with zones
function GPSJamming.addGPSJammers(config, jammerDescriptors, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
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
      GameApi.ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

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
---Searches for a jamming zone matching the descriptor name and removes it
---Does NOT delete the jammer unit itself, only the zone and event
---@param jammerDescriptors table<string, SBJ__GPSJammerDescriptor> Collection of jammer descriptors indexed by name
---@param sideName string Side name that owns the jammer (e.g., 'China', 'Taiwan')
---@param name string Unique name/key of the jammer descriptor to remove
---@return boolean # Whether the zone was successfully found and removed
function GPSJamming.removeJammingZoneByName(jammerDescriptors, sideName, name)
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
  --       Logger.log("GPSJamming", "[GPS Jamming] Removed GPS jamming zone: " .. jammerData.zoneName)
  --     end
  --   end

  --   ::continue::
  -- end
end

return GPSJamming
