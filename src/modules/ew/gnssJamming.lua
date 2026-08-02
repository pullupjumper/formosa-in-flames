local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")

local GnssJamming = {}


-- ============================================================================
-- Enumerations & Constants
-- ============================================================================

local GNSS_JAMMING_RESULT = {
  JAMMED     = "jammed",
  RESISTED   = "resisted",
  NO_COURSE  = "no_course",
  NOT_GUIDED = "not_guided",
  NO_WEAPON  = "no_weapon",
}

local GNSS_RESULT_TAGS = {
  [GNSS_JAMMING_RESULT.JAMMED]     = "OK",
  [GNSS_JAMMING_RESULT.RESISTED]   = "SKIP",
  [GNSS_JAMMING_RESULT.NO_COURSE]  = "FAIL",
  [GNSS_JAMMING_RESULT.NOT_GUIDED] = "SKIP",
  [GNSS_JAMMING_RESULT.NO_WEAPON]  = "ERROR",
}


local TARGET_TYPE_WEAPON = 6


---Format GNSS jamming result as key=value fields
---@param status string GNSS jamming result enum value
---@param message string Result message or weapon name
---@return table<string, string> # Formatted log message
local function formatGnssResult(status, message)
  if status == GNSS_JAMMING_RESULT.NO_WEAPON then
    return { result = "no_weapon", reason = "no_weapon_unit_found" }
  end

  if status == GNSS_JAMMING_RESULT.NO_COURSE then
    return { result = "no_course", weapon = message, reason = "no_course_data" }
  end

  return { result = status, weapon = message }
end


-- ============================================================================
-- Weapon Resolution & Matching
-- ============================================================================

---Resolve weapon unit from the current event context
---@return CMO__Unit|nil unit Resolved weapon unit or nil
---@return string|nil status JAMMING_RESULT enum value if failed
local function resolveWeapon()
  local weapon = GameApi.ScenEdit_UnitX()
  if not weapon then
    return nil, GNSS_JAMMING_RESULT.NO_WEAPON
  end

  local weaponUnit = GameApi.ScenEdit_GetUnit(weapon.guid)
  if not weaponUnit then
    return nil, GNSS_JAMMING_RESULT.NO_WEAPON
  end

  return weaponUnit, nil
end


---Find matching GNSS-guided weapon configuration by DBID
---@param gnssGuidedWeapons SBJ__GNSSJammedWeapon[] List of GNSS-guided weapon configurations
---@param dbid number Weapon database ID to match
---@return SBJ__GNSSJammedWeapon|nil # Matched weapon config or nil
local function matchGnssGuidedWeapon(gnssGuidedWeapons, dbid)
  for _, wpn in ipairs(gnssGuidedWeapons) do
    if dbid == wpn.dbid then
      return wpn
    end
  end
  return nil
end


---Roll jamming resistance check
---@param jammingResistance number Resistance percentage (0-100)
---@return boolean # True if jamming overcomes resistance
local function rollJammingResistance(jammingResistance)
  return math.random(100) > jammingResistance
end


-- ============================================================================
-- Course Deviation
-- ============================================================================

---Calculate random coordinate deviation for jamming effect
---@param originalLat number|string Original latitude
---@param originalLon number|string Original longitude
---@return number lat Deviated latitude
---@return number lon Deviated longitude
local function calculateDeviation(originalLat, originalLon)
  local lat = originalLat + math.random(-100, 100) / 10 ^ 4
  local lon = originalLon + math.random(-100, 100) / 10 ^ 4
  return lat, lon
end


---Build deviated course and target for the jammed weapon
---Replaces terminal waypoint with deviated coordinates, preserving earlier waypoints
---@param weaponUnit CMO__Unit The weapon unit to modify
---@param lat number Deviated latitude
---@param lon number Deviated longitude
---@param waypointCount number Number of waypoints in original course
local function buildDeviatedCourse(weaponUnit, lat, lon, waypointCount)
  local deviatedTarget = { latitude = lat, longitude = lon, guid = "BOL" }
  local terminalPoint = { latitude = lat, longitude = lon, TypeOf = "TerminalPoint" }

  if waypointCount <= 1 then
    weaponUnit.target = deviatedTarget
    weaponUnit.course = { terminalPoint }
  else
    local newCourse = {}
    for k, v in ipairs(weaponUnit.course) do
      newCourse[k] = (k == waypointCount) and terminalPoint or v
    end
    weaponUnit.course = newCourse
    weaponUnit.target = deviatedTarget
  end
end


---Attempt GNSS jamming on the event weapon
---Orchestrates weapon resolution, matching, resistance roll, and course deviation
---@param gnssGuidedWeapons SBJ__GNSSJammedWeapon[] List of GNSS-guided weapon configs
---@return string status JAMMING_RESULT enum value
---@return string message Human-readable description
local function attemptJamming(gnssGuidedWeapons)
  local weaponUnit, resolveStatus = resolveWeapon()
  if not weaponUnit then
    return resolveStatus or GNSS_JAMMING_RESULT.NO_WEAPON, "No weapon unit found"
  end

  local weaponConfig = matchGnssGuidedWeapon(gnssGuidedWeapons, weaponUnit.dbid)
  if not weaponConfig then
    return GNSS_JAMMING_RESULT.NOT_GUIDED, weaponUnit.name
  end

  if not rollJammingResistance(weaponConfig.jammingResistance) then
    return GNSS_JAMMING_RESULT.RESISTED, weaponUnit.name
  end

  if not weaponUnit.course then
    return GNSS_JAMMING_RESULT.NO_COURSE, weaponUnit.name
  end

  local count = #weaponUnit.course
  local lastWaypoint

  if count == 0 then
    lastWaypoint = { latitude = weaponUnit.target.latitude, longitude = weaponUnit.target.longitude }
  else
    lastWaypoint = weaponUnit.course[count]
  end

  local lat, lon = calculateDeviation(lastWaypoint.latitude, lastWaypoint.longitude)
  buildDeviatedCourse(weaponUnit, lat, lon, count)

  return GNSS_JAMMING_RESULT.JAMMED, weaponUnit.name
end


-- ============================================================================
-- Zone Management
-- ============================================================================

---Create a circular jamming zone around a jammer unit with event trigger
---@param unit CMO__Unit The GNSS jammer unit
---@param descriptor SBJ__GNSSJammerDescriptor Jammer configuration descriptor
---@param point CMO__Location Center point for the jamming zone
---@param sideName string Side name that owns the jammer
---@param enemySideName string Enemy side name whose weapons will be jammed
---@return boolean # Whether the jamming zone was successfully created
local function createJammingZone(unit, descriptor, point, sideName, enemySideName)
  GameApi.ScenEdit_SetEMCON("Unit", unit.guid, "OECM=Active")

  local area = GameUtils.newArea(point, {
    side = sideName,
    shape = "circle",
    distance = descriptor.radius
  })

  if not area or type(area) ~= "table" then
    return false
  end

  GameApi.ScenEdit_AddZone(sideName, -925, {
    description = descriptor.zoneName,
    area = area
  })

  GameUtils.unitEntersAreaEvent(
    descriptor.zoneName,
    { TargetSide = enemySideName, TargetType = TARGET_TYPE_WEAPON },
    area,
    "GnssJamming.jamming(config, \\\"" .. sideName .. "\\\")",
    "add",
    false,
    true,
    true
  )

  return true
end


---Clean up zone resources (reference points, zone, event trigger)
---@param sideObj CMO__Side Side object that owns the zone
---@param zone CMO__Zone The zone object to remove
---@param sideName string Side name
---@param zoneName string Zone description for event removal
---@return boolean # Whether cleanup was successful
local function cleanupZoneResources(sideObj, zone, sideName, zoneName)
  local myz = sideObj:getstandardzone(zone.guid)
  if not myz then
    return false
  end

  for _, rp in ipairs(myz.area) do
    GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = rp.name })
  end

  GameApi.ScenEdit_RemoveZone(sideName, constants.ZONE_TYPES.STANDARD, { Description = myz.description })
  GameUtils.unitEntersAreaEvent(zoneName, {}, {}, "", "remove", false, false, false)

  return true
end


---Delete a jammer unit by name
---@param unitName string Unit name to delete
---@param sideName string Side name that owns the unit
local function deleteJammerUnit(unitName, sideName)
  GameApi.ScenEdit_DeleteUnit({ side = sideName, unitname = unitName })
end


-- ============================================================================
-- Public API
-- ============================================================================

---Process GNSS jamming for weapons entering jamming zone
---Called from 'Unit Enters Area' event trigger
---@param config SBJ__Config Configuration object containing GNSS jamming settings
---@param sideName string Enemy side name whose weapons are being jammed
---@return boolean # Whether jamming was successfully applied
function GnssJamming.jamming(config, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local side = sideConfig.field
  local gnssGuidedWeapons = config[side].gnssJamming.gnssGuidedWeapons

  local status, message = attemptJamming(gnssGuidedWeapons)
  local tag = GNSS_RESULT_TAGS[status] or "OK"
  local resultFields = formatGnssResult(status, message)

  if status == GNSS_JAMMING_RESULT.NO_WEAPON or status == GNSS_JAMMING_RESULT.NO_COURSE then
    Logger.error(LogFormat.line(tag, LogFormat.merge({ module = constants.TAGS.GNSS_JAMMING }, resultFields)))
    return false
  end

  Logger.log(constants.TAGS.GNSS_JAMMING, LogFormat.line(tag, LogFormat.merge({ side = sideName }, resultFields)))
  return status == GNSS_JAMMING_RESULT.JAMMED
end

---Add a single GNSS jammer
---Creates a GNSS jammer unit at the specified location and sets up its jamming zone
---@param descriptor SBJ__GNSSJammerDescriptor Jammer configuration
---@param sideName string Side name that will own the jammer
---@return boolean success Whether jammer was successfully created
---@return CMO__Unit|nil unit The created jammer unit
function GnssJamming.addGnssJammer(descriptor, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
  local unit = GameApi.ScenEdit_AddUnit({
    side = sideName,
    unitname = descriptor.name,
    dbid = constants.PLATFORMS.GPS_JAMMER,
    type = constants.UNIT_TYPES.FACILITY,
    latitude = descriptor.point.latitude,
    longitude = descriptor.point.longitude
  })

  if not unit then
    Logger.log(constants.TAGS.GNSS_JAMMING, LogFormat.line("FAIL", {
      jammer = descriptor.name,
      side = sideName,
      reason = "unit_creation_failed"
    }))
    return false, nil
  end

  local point = { latitude = descriptor.point.latitude, longitude = descriptor.point.longitude }
  local success = createJammingZone(unit, descriptor, point, sideName, enemySideName)

  Logger.log(constants.TAGS.GNSS_JAMMING, LogFormat.line(success and "OK" or "FAIL", {
    jammer = descriptor.name,
    side = sideName,
    zone = descriptor.zoneName,
    result = success and "created" or nil,
    reason = success and nil or "zone_creation_failed"
  }))

  return success, unit
end

---Add all GNSS jammers for a side
---Creates multiple GNSS jammer units at randomized positions and sets up their jamming zones
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors
---@param sideName string Side name that will own the jammers
---@return number # Number of jammers successfully created
function GnssJamming.addGnssJammers(jammerDescriptors, sideName)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySideName = sideConfig.enemySide
  local successCount = 0
  local report = LogFormat.report(constants.TAGS.GNSS_JAMMING, "side=" .. sideName, "Add GNSS jammers")

  for _, descriptor in pairs(jammerDescriptors) do
    local unit, point = GameUtils.tryAddUnit(
      descriptor.name,
      descriptor.point.latitude,
      descriptor.point.longitude,
      descriptor.randomRadius,
      constants.PLATFORMS.GPS_JAMMER
    )

    if not unit or not point then
      report.add("FAIL", {
        jammer = descriptor.name,
        zone = descriptor.zoneName,
        reason = "unit_creation_failed"
      })
      goto continue
    end

    if createJammingZone(unit, descriptor, point, sideName, enemySideName) then
      successCount = successCount + 1
      report.add("OK", { jammer = descriptor.name, zone = descriptor.zoneName })
    else
      report.add("FAIL", {
        jammer = descriptor.name,
        zone = descriptor.zoneName,
        reason = "zone_creation_failed"
      })
    end

    ::continue::
  end

  report.emit({ created = successCount })

  return successCount
end

---Remove all GNSS jammers for a side
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors
---@param sideName string Side name that owns the jammers
---@return number # Number of jammers successfully removed
function GnssJamming.removeJammers(jammerDescriptors, sideName)
  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if not sideObj then return 0 end

  local removedCount = 0
  local report = LogFormat.report(constants.TAGS.GNSS_JAMMING, "side=" .. sideName, "Remove GNSS jammers")

  for _, zone in ipairs(sideObj.standardzones) do
    for _, descriptor in pairs(jammerDescriptors) do
      if zone.description == descriptor.zoneName then
        if cleanupZoneResources(sideObj, zone, sideName, descriptor.zoneName) then
          deleteJammerUnit(descriptor.name, sideName)
          removedCount = removedCount + 1
          report.add("OK", { jammer = descriptor.name, zone = descriptor.zoneName })
        else
          report.add("FAIL", {
            jammer = descriptor.name,
            zone = descriptor.zoneName,
            reason = "zone_not_found"
          })
        end
      end
    end
  end

  report.emit({ removed = removedCount })

  return removedCount
end

---Remove specific GNSS jamming zone by name
---Does NOT delete the jammer unit, only the zone and event
---@param jammerDescriptors table<string, SBJ__GNSSJammerDescriptor> Collection of jammer descriptors
---@param sideName string Side name that owns the jammer
---@param name string Unique name/key of the jammer descriptor to remove
---@return boolean # Whether the zone was successfully removed
function GnssJamming.removeJammingZoneByName(jammerDescriptors, sideName, name)
  local sideObj = GameApi.VP_GetSide({ name = sideName })
  if not sideObj then return false end

  local descriptor = jammerDescriptors[name]
  if not descriptor then return false end

  for _, zone in ipairs(sideObj.standardzones) do
    if zone.description == descriptor.zoneName then
      local success = cleanupZoneResources(sideObj, zone, sideName, descriptor.zoneName)

      Logger.log(constants.TAGS.GNSS_JAMMING, LogFormat.line(success and "OK" or "FAIL", {
        zone = descriptor.zoneName,
        side = sideName,
        jammer = descriptor.name,
        result = success and "removed" or nil,
        reason = success and nil or "zone_cleanup_failed"
      }))

      return success
    end
  end

  return false
end

return GnssJamming
