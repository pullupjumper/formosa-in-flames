local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

local GnssJamming = {}

---Add jamming zone for a GNSS jammer unit
---Creates a circular zone around the jammer and sets up event trigger for weapons entering the zone
---@param unit CMO__Unit The GNSS jammer unit
---@param descriptor SBJ__GNSSJammerDescriptor Jammer configuration descriptor containing zone name and radius
---@param point CMO__Location Center point for the jamming zone
---@param sideName string Side name that owns the jammer (e.g., 'China', 'Taiwan')
---@param enemySideName string Enemy side name whose weapons will be jammed
---@return boolean # Whether the jamming zone was successfully created
local function addJammingZone(unit, descriptor, point, sideName, enemySideName)
  GameApi.ScenEdit_SetEMCON("Unit", unit.guid, "OECM=Active")

  local area = GameUtils.newArea(point, {
    side = sideName,
    shape = "circle",
    distance = descriptor.radius
  })

  if area and type(area) == "table" then
    GameApi.ScenEdit_AddZone(sideName, -925, {
      description = descriptor.zoneName,
      area = area
    })

    GameUtils.unitEntersAreaEvent(
      descriptor.zoneName,
      { TargetSide = enemySideName, TargetType = 6 },
      area,
      "GnssJamming.jamming(config, \\\"" .. sideName .. "\\\")",
      "add",
      false,
      true,
      true
    )
    return true
  end
  return false
end

---Remove GNSS jamming event and cleanup
---Deletes reference points, removes zone, optionally deletes unit, and removes event trigger
---@param descriptor SBJ__GNSSJammerDescriptor Jammer configuration descriptor
---@param zone CMO__Zone The zone object to remove
---@param sideObj CMO__Side Side object that owns the zone
---@param sideName string Side name (e.g., 'China', 'Taiwan')
---@param isDeleted? boolean If true, also delete the jammer unit itself
---@return boolean # Whether the removal was successful
local function removeEvent(descriptor, zone, sideObj, sideName, isDeleted)
  local myz = sideObj:getstandardzone(zone.guid)

  if not myz then
    return false
  end

  for _, rp in ipairs(myz.area) do
    GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = rp.name })
  end

  GameApi.ScenEdit_RemoveZone(sideName, constants.ZONE_TYPES.STANDARD, { Description = myz.description })

  if isDeleted then
    GameApi.ScenEdit_DeleteUnit({ side = sideName, unitname = descriptor.name })
  end
  GameUtils.unitEntersAreaEvent(descriptor.zoneName, {}, {}, "", "remove", false, false, false)
  Logger.log("gnssJamming", "[Gnss Jamming] Removed Gnss jamming zone: " .. descriptor.zoneName)
  return true
end

---Process GNSS jamming for weapons entering jamming zone
---Checks if weapon is GNSS-guided, applies random deviation to terminal waypoint based on jamming resistance
---Should be called from 'Unit Enters Area' event trigger
---@param config SBJ__Config Configuration object containing GNSS jamming settings and weapon DBIDs
---@param sideName string Enemy side name whose weapons are being jammed (e.g., 'Taiwan', 'US')
---@return boolean # Whether jamming was successfully applied to the weapon
function GnssJamming.jamming(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local side = sideConfig.field
  local weapon = GameApi.ScenEdit_UnitX()
  local weaponU

  if weapon then
    weaponU = GameApi.ScenEdit_GetUnit(weapon.guid)
  else
    Logger.error("[Gnss Jamming] No weapon unit found in jamming event")
    return false
  end

  if not weaponU then
    Logger.error("[Gnss Jamming] Failed to get weapon unit wrapper")
    return false
  end

  for i, wpn in ipairs(config[side].gnssJamming.gnssGuidedWeapons) do
    if weaponU and weaponU.dbid == wpn.dbid then
      local jamChance = math.random(100)

      if jamChance > wpn.jammingResistance then
        Logger.log("gnssJamming", "[Gnss Jamming] Gnss jamming successful on " .. weaponU.name)

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
            weaponU.target = { latitude = lat, longitude = lon, guid = "BOL" }
            weaponU.course = { { latitude = lat, longitude = lon, TypeOf = "TerminalPoint" } }
          else -- For weapons with a predefined course of waypoints, we maintain all the waypoints
            local newCourse = {}
            for k, v in ipairs(weaponU.course) do
              if k ~= count then
                newCourse[k] = v
              else
                newCourse[k] = { latitude = lat, longitude = lon, TypeOf = "TerminalPoint" }
              end
            end
            weaponU.course = newCourse
            weaponU.target = { latitude = lat, longitude = lon, guid = "BOL" }
          end
        else
          Logger.error("[Gnss Jamming] Weapon " .. weaponU.name .. " has no course data")
          return false
        end
        return true
      else
        Logger.log("gnssJamming", "[Gnss Jamming] Weapon " .. weaponU.name .. " resisted jamming")
        return false
      end
    end
  end

  return false
end

---Remove all GNSS jammers for a side
---Iterates through all standard zones and removes matching GNSS jamming zones and their units
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors indexed by name
---@param sideName string Side name that owns the jammers (e.g., 'China', 'Taiwan')
---@return number # Number of jammers successfully removed
function GnssJamming.removeJammers(jammerDescriptors, sideName)
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

---Add a single GNSS jammer
---Creates a GNSS jammer unit at the specified location and sets up its jamming zone
---@param descriptor SBJ__GNSSJammerDescriptor Jammer configuration with name, location, zone name, and radius
---@param sideName string Side name that will own the jammer (e.g., 'China', 'Taiwan')
---@return boolean success Whether jammer was successfully created and zone set up
---@return CMO__Unit|nil unit The created jammer unit, or nil if creation failed
function GnssJamming.addGnssJammer(descriptor, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
  local unit = GameApi.ScenEdit_AddUnit({
    side = sideName,
    unitname = descriptor.name,
    dbid = constants.PLATFORMS.GPS_JAMMER,
    type = "Facility",
    latitude = descriptor.point.latitude,
    longitude = descriptor.point.longitude
  })
  local point = { latitude = descriptor.point.latitude, longitude = descriptor.point.longitude }

  if unit then
    GameApi.ScenEdit_SetEMCON("Unit", unit.guid, "OECM=Active")
    local success = addJammingZone(unit, descriptor, point, sideName, enemySideName)
    return success, unit
  end
  return false, nil
end

---Add all GNSS jammers for a side
---Creates multiple GNSS jammer units at randomized positions and sets up their jamming zones
---Uses retry logic to find valid placement locations within the random radius
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors to create
---@param sideName string Side name that will own the jammers (e.g., 'China', 'Taiwan')
---@return number # Number of jammers successfully created with zones
function GnssJamming.addGnssJammers(jammerDescriptors, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
  local successCount = 0

  for _, descriptor in pairs(jammerDescriptors) do
    local unit, point = GameUtils.tryAddUnit(
      descriptor.name,
      descriptor.point.latitude,
      descriptor.point.longitude,
      descriptor.randomRadius,
      constants.PLATFORMS.GPS_JAMMER
    )

    if unit and point then
      GameApi.ScenEdit_SetEMCON("Unit", unit.guid, "OECM=Active")

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
-- function GNSSJamming.turnOffGNSSEffectByUnit(config, unit)
--   local s = GameApi.VP_GetSide({ name = 'China' })
--   if s == nil then return end

--   for _, jammer in ipairs(config.c.GNSSJamming.jammers) do
--     if unit.name ~= jammer.name then goto continue end

--     for _, zone in ipairs(s.standardzones) do
--       if zone.description == jammer.zoneName then
--         local myz = s:getstandardzone(zone.guid)
--         myz.enablers = { GNSS_GLONASS = true, GNSS_GNSS = true, GNSS_BeiDou = true, GNSS_NavIC = true }
--       end
--     end

--     ::continue::
--   end
-- end

---Remove specific GNSS jamming zone by name
---Searches for a jamming zone matching the descriptor name and removes it
---Does NOT delete the jammer unit itself, only the zone and event
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors indexed by name
---@param sideName string Side name that owns the jammer (e.g., 'China', 'Taiwan')
---@param name string Unique name/key of the jammer descriptor to remove
---@return boolean # Whether the zone was successfully found and removed
function GnssJamming.removeJammingZoneByName(jammerDescriptors, sideName, name)
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

  -- for _, jammerData in pairs(config[side].GNSSJamming.jammers) do
  --   if unit.name ~= jammerData.name then goto continue end

  --   for _, zone in ipairs(s.standardzones) do
  --     if zone.description == jammerData.zoneName then
  --       local myz = s:getstandardzone(zone.guid)

  --       for _, area in ipairs(myz.area) do
  --         GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = area.name })
  --       end

  --       GameApi.ScenEdit_RemoveZone(sideName, -925, { Description = myz.description })
  --       GameUtils.unitEntersAreaEvent(jammerData.zoneName, {}, {}, '', 'remove', false, false, false)
  --       Logger.log("GNSSJamming", "[GNSS Jamming] Removed GNSS jamming zone: " .. jammerData.zoneName)
  --     end
  --   end

  --   ::continue::
  -- end
end

return GnssJamming
