local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local GameUtils = {}

local sideConfigCache = {}
local UNIT_CREATION = {
  MAX_ATTEMPTS = 50,
  RANDOM_TEXT_LENGTH = 2
}

---Get or create cached side configuration
---Returns side configuration with field identifier, enemy side mapping, and display name
---@param sideName string Side name ('China', 'US', or other)
---@return SBJ__SideConfig # Side configuration with field, enemySide, and displayName
function GameUtils.getCachedSideConfig(sideName)
  if not sideConfigCache[sideName] then
    if sideName == constants.SIDES.ENEMY then
      sideConfigCache[sideName] = {
        field = "c",
        enemySide = constants.SIDES.PLAYER,
        displayName = constants.SIDES.ENEMY
      }
    elseif sideName == "US" then
      sideConfigCache[sideName] = {
        field = "u",
        enemySide = constants.SIDES.ENEMY,
        displayName = "United States"
      }
    else
      sideConfigCache[sideName] = {
        field = "t",
        enemySide = constants.SIDES.ENEMY,
        displayName = sideName
      }
    end
  end
  return sideConfigCache[sideName]
end

---Calculate the great circle distance between two points using Haversine formula
---@param lat1 number|string First point latitude (degrees)
---@param lon1 number|string First point longitude (degrees)
---@param lat2 number|string Second point latitude (degrees)
---@param lon2 number|string Second point longitude (degrees)
---@return number # Distance in nautical miles
local function calculateDistance(lat1, lon1, lat2, lon2)
  -- Earth radius in nautical miles
  local R = 3440.065

  -- Convert degrees to radians
  local lat1Rad = math.rad(tonumber(lat1) or 0)
  local lat2Rad = math.rad(tonumber(lat2) or 0)
  local deltaLatRad = math.rad(lat2 - lat1)
  local deltaLonRad = math.rad(lon2 - lon1)

  -- Haversine formula
  local a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
      math.cos(lat1Rad) * math.cos(lat2Rad) *
      math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2)

  local c = 2 * Utils.atan2(math.sqrt(a), math.sqrt(1 - a))

  return R * c
end

---Calculate total path distance and transit time for a route
---@param waypoints CMO__TableOfWaypoints Array of waypoints defining the route
---@param speedKnots number Transit speed in knots
---@return number totalDistance Total path distance in nautical miles
---@return number totalTime Total transit time in seconds
function GameUtils.calculatePathDistanceAndTime(waypoints, speedKnots)
  if not waypoints or #waypoints < 2 then
    return 0, 0
  end

  if not speedKnots or speedKnots <= 0 then
    error("Speed must be a positive number")
  end

  local totalDistance = 0

  -- Calculate distance between consecutive waypoints
  for i = 1, #waypoints - 1 do
    local point1 = waypoints[i]
    local point2 = waypoints[i + 1]

    local distance = calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude
    )

    totalDistance = totalDistance + distance
  end

  -- Calculate time in seconds
  -- Time = Distance / Speed (in hours), then convert to seconds
  local totalTime = math.floor((totalDistance / speedKnots) * 3600) + 120

  return totalDistance, totalTime
end

---Generate a random position within a circular area around a center point
---@param xLatitude number|string Center point latitude
---@param xLongitude number|string Center point longitude
---@param maxRadius number Maximum radius for random positioning (nautical miles)
---@return CMO__Location|nil # Random position within the circle, or nil if generation fails
local function calculateCircularRandomPosition(xLatitude, xLongitude, maxRadius)
  local randomisationCircle = GameApi.World_GetCircleFromPoint({
    latitude = xLatitude,
    longitude = xLongitude,
    radius = (math.random(0, maxRadius * 10) / 10),
    numpoints = 72
  })

  if not randomisationCircle then
    return nil
  end

  local randomisedPoint = randomisationCircle[math.random(1, #randomisationCircle)]
  return randomisedPoint
end

---Generate a list of locations based on parameters
---@param params SBJ__LinearPlacementParams
---@return table<integer, CMO__Location> # Array of generated locations along the specified bearing
function GameUtils.buildLocations(params)
  local numTemp = params.num
  local bearingTemp = params.bearing
  local distanceTemp = 0
  local firstDistance = params.firstDistance
  local locations = {}
  local locationTemp = params.initialLocation

  if numTemp == 0 then
    return {}
  end

  for i = 1, numTemp, 1 do
    if i > 1 then
      distanceTemp = params.distance
    elseif i == 1 and firstDistance then
      distanceTemp = params.firstDistance or 0
    end

    local newLocation = GameApi.World_GetPointFromBearing({
      latitude = locationTemp.latitude,
      longitude = locationTemp.longitude,
      bearing = bearingTemp,
      distance = distanceTemp
    })

    if not newLocation then
      -- If one point fails, we probably should stop.
      break
    end

    locationTemp = newLocation
    table.insert(locations, locationTemp)
  end

  return locations
end

---Create a reference point area in the specified shape (circle or square)
---@param position CMO__Location Center position for the area
---@param params SBJ__AreaParams Area configuration (shape, side, distance, etc.)
---@return table<integer, CMO__ReferencePoint>|boolean # Array of reference point names forming the area, or false if creation fails
function GameUtils.createArea(position, params)
  local side = params.side
  local shape = params.shape
  if side == nil or shape == nil then return false end
  local name = (params.name or "RP")
  local bearOffset = (params.bearOffset or 0)
  local rpTable = {}
  local a = 1
  --Circle
  if shape == "circle" then
    local distance = params.distance
    for i = 0, 359, 45 do
      local location = GameApi.World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = i
      })

      if location then
        local newRp = GameApi.ScenEdit_AddReferencePoint({
          side = side,
          latitude = location.latitude,
          longitude = location.longitude
        })

        if newRp then
          a = a + 1
          table.insert(rpTable, newRp.name)
        end
      end
    end
  elseif shape == "square" then
    local distance = params.distance
    for i = 0, 3 do
      local b = 45 + (90 * i) + bearOffset
      local location = GameApi.World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = b
      })

      if location then
        GameApi.ScenEdit_AddReferencePoint({
          side = side,
          latitude = location.latitude,
          longitude = location.longitude
        })
      end
    end
  end

  return (rpTable)
end

---Check if current scenario time has reached or passed the specified start time
---@param time string|number A string in the format "YYYY-MM-DD HH:MM:SS" or a timestamp number
---@param advanceSeconds? number Optional seconds to advance the check time (makes condition trigger earlier)
---@return boolean # True if current time >= start time (adjusted by advanceSeconds if provided)
function GameUtils.isAfterStartTime(time, advanceSeconds)
  local result = GameApi.ScenEdit_CurrentTime()

  if not result then
    return false
  end

  local targetTimestamp
  if type(time) == "string" then
    targetTimestamp = Utils.parseDatetimeToTimestamp(time)
  elseif type(time) == "number" then
    targetTimestamp = time
  else
    error("Invalid time parameter type. Expected string or number, got " .. type(time))
  end

  -- Apply advance seconds if provided (subtract from target to make condition trigger earlier)
  if advanceSeconds and type(advanceSeconds) == "number" then
    targetTimestamp = targetTimestamp - advanceSeconds
  end

  return result >= targetTimestamp
end

---Create a new mission with specified parameters and optional EMCON settings
---Combines mission creation, configuration, and EMCON setup in a single operation
---@param sideName string Side name that owns the mission
---@param params SBJ__MissionCreationParams Mission name, type and configuration options
---@param opts? SBJ__CreateMissionOpts Optional EMCON settings
---@return CMO__Mission|nil # Created mission object, or nil if any step fails
function GameUtils.createMission(sideName, params, opts)
  local name = params.name
  local missionOpts = params.opts
  local emcon = opts and opts.emcon
  local mission = GameApi.ScenEdit_AddMission(sideName, name, params.type, missionOpts)

  if not mission then
    return
  end

  if missionOpts then
    local result = GameApi.ScenEdit_SetMission(sideName, name, missionOpts)

    if not result then
      return
    end
  end

  if emcon then
    local result = GameApi.ScenEdit_SetEMCON("mission", name, emcon)

    if not result then
      return
    end
  end

  return mission
end

---Creates, updates, or removes a "Unit Enters Area" event trigger in the CMO scenario
---Sets up event system that executes Lua script when units matching filter enter/exit specified area
---@param params SBJ__UnitEntersAreaEventParams Event name, mode, filter, area and script
---@param opts? SBJ__UnitEntersAreaEventOpts Exit / repeatable / active flags
---@return boolean # True if operation succeeded, false if any API call failed
function GameUtils.setUnitEntersAreaEvent(params, opts)
  opts = opts or {}
  local name, mode, area, script = params.name, params.mode, params.area, params.script
  local filter = params.filter
  local exit = opts.exit or false
  local isRepeatable = opts.isRepeatable or false
  local isActive = opts.isActive ~= false

  if mode == "add" then
    -- Create the trigger component that monitors unit movement
    local result = GameApi.ScenEdit_SetTrigger({
      description = name .. "",
      mode = "add",
      type = "UnitEntersArea",
      TargetFilter = filter,
      Area = area,
      ExitArea = exit -- Controls whether this triggers on enter (false) or exit (true)
    })

    if not result then
      return false
    end

    -- Create the action component that executes the specified Lua script
    local actionResult = GameApi.ScenEdit_SetAction({
      mode = "add",
      type = "LuaScript",
      name = name .. "",
      ScriptText = script
    })

    if not actionResult then
      return false
    end

    -- Create the event and link the trigger and action together
    GameApi.ScenEdit_SetEvent(name, { mode = "add", IsRepeatable = isRepeatable, isActive = isActive, isShown = true })
    GameApi.ScenEdit_SetEventTrigger(name, { mode = "add", name = name .. "" })
    GameApi.ScenEdit_SetEventAction(name, { mode = "add", name = name .. "" })
  elseif mode == "update" then
    -- Update existing trigger if new area parameters are provided
    if area ~= nil then
      GameApi.ScenEdit_SetTrigger({
        description = name .. "",
        mode = "update",
        type = "UnitEntersArea",
        TargetFilter = filter,
        Area = area,
        ExitArea = exit
      })
    end
    -- Update existing action if new script is provided
    if script ~= nil then
      GameApi.ScenEdit_SetAction({ mode = "update", type = "LuaScript", name = name .. "", ScriptText = script })
    end
  elseif mode == "remove" then
    -- Remove all components of the event system

    GameApi.ScenEdit_SetEvent(name, { mode = "remove" })
    GameApi.ScenEdit_SetTrigger({ description = name .. "", mode = "remove" })
    GameApi.ScenEdit_SetAction({ description = name .. "", mode = "remove" })
  end

  return true
end

---Attempts to add a unit to the scenario with retry logic and random positioning
---Retries with different random positions within circular area up to max attempts if creation fails
---@param params SBJ__TryAddUnitParams Unit name, center position, random radius and DBID
---@param opts? SBJ__TryAddUnitOpts Retry settings
---@return CMO__Unit|nil unit The created unit object if successful, nil if all attempts failed
---@return CMO__Location|nil point The final position where unit was placed, nil if creation failed
function GameUtils.tryAddUnit(params, opts)
  local maxAttempts = opts and opts.maxAttempts or 50

  for _ = 1, maxAttempts do
    local point = calculateCircularRandomPosition(params.pos.latitude, params.pos.longitude, params.randomRadius)
    if point then
      local unit = GameApi.ScenEdit_AddUnit({
        type = constants.UNIT_TYPES.FACILITY,
        unitname = params.name,
        dbid = params.unitDBID,
        side = constants.SIDES.ENEMY,
        latitude = point.latitude,
        longitude = point.longitude,
        autodetectable = false
      })
      if unit then
        return unit, point
      end
    end
  end

  print("Failed to create jammer unit after " .. maxAttempts .. " attempts: " .. params.name)
  return nil, nil
end

---Attempt to create a single unit (with retry mechanism)
---@param unitDescriptor CMO__SetUnitDescriptor Unit descriptor
---@param maxAttempts integer|nil Maximum number of attempts
---@return CMO__Unit|nil # Created unit if successful, nil if all attempts failed
function GameUtils.tryCreateUnit(unitDescriptor, maxAttempts)
  maxAttempts = maxAttempts or UNIT_CREATION.MAX_ATTEMPTS

  for attempt = 1, maxAttempts do
    local unit = GameApi.ScenEdit_AddUnit(unitDescriptor)
    if unit then
      return unit
    end

    if attempt == maxAttempts then
      print(string.format("Failed to create unit after %d attempts", maxAttempts))
    end
  end

  return nil
end

---Create units at random positions
---@param descriptor SBJ__RandomUnitsDescriptor Configuration parameters
---@return CMO__Unit|CMO__Unit[] # Created units (single unit if count=1, array otherwise)
function GameUtils.createRandomUnits(descriptor)
  local units = {}
  -- Default to true if not specified (backward compatible)
  local useRandomSuffix = (descriptor.useRandomSuffix ~= false)

  for i = 1, descriptor.count do
    local dbid = descriptor.dbids[math.random(#descriptor.dbids)]
    local point = calculateCircularRandomPosition(
      descriptor.centerPoint.latitude,
      descriptor.centerPoint.longitude,
      descriptor.randomRadius
    )
    local unitDescriptor

    -- Generate unit name with optional random suffix
    local unitname = descriptor.unitname
    if useRandomSuffix then
      unitname = unitname .. Utils.buildRandomText(UNIT_CREATION.RANDOM_TEXT_LENGTH)
    end

    if point then
      unitDescriptor = {
        type = descriptor.unitType,
        dbid = dbid,
        side = descriptor.sideName,
        latitude = point.latitude,
        longitude = point.longitude,
        autodetectable = descriptor.autodetectable,
        unitname = unitname,
      }
    end

    local unit = GameUtils.tryCreateUnit(unitDescriptor)
    if unit then
      table.insert(units, unit)
      if descriptor.count == 1 then
        return unit
      end
    end
  end

  return units
end

---Extract unit type from unit name and convert to subordinate echelon
---Searches through comma-separated parts sequentially until unit type is found
---Converts to subordinate echelon: Bde->Bn, Bn->Coy, Coy/Sqn->Plt
---@param unitName string Unit name
---@return string|nil # Converted unit type (Bn/Coy/Plt), or nil if not found
function GameUtils.resolveUnitType(unitName)
  -- Iterate through each comma-separated part
  for part in unitName:gmatch("([^,]+)") do
    local unitType = part:match("Bde") or
        part:match("Bn") or
        part:match("Coy") or
        part:match("Sqn")

    if unitType then
      if unitType == "Bde" then
        unitType = "Bn"
      elseif unitType == "Bn" then
        unitType = "Coy"
      elseif unitType == "Coy" or unitType == "Sqn" then
        unitType = "Plt"
      end
      return unitType
    end
  end

  return nil
end

---Format unit name with ordinal number suffix
---Generates unit names like "1st Bn", "2nd Coy", "3rd Plt", "4th Bn", etc.
---@param num integer Ordinal number (1, 2, 3, ...)
---@param unitType string Unit type (e.g., "Bn", "Coy", "Plt")
---@param suffix string Additional suffix string to append after unit type
---@return string # Formatted unit name with ordinal suffix
function GameUtils.formatOrdinalUnitName(num, unitType, suffix)
  local ordinal
  if num == 1 then
    ordinal = tostring(num) .. "st"
  elseif num == 2 then
    ordinal = tostring(num) .. "nd"
  elseif num == 3 then
    ordinal = tostring(num) .. "rd"
  else
    ordinal = tostring(num) .. "th"
  end

  return ordinal .. " " .. unitType .. suffix
end

---Converts a zone to an array of reference points
---@param zone CMO__Zone|CMO__TriggerResult Zone table
---@return string[] # Array of reference points
function GameUtils.normalizeToRPArray(zone)
  local rps = {}
  local area = zone.area or (zone.Area or {})

  for _, rp in pairs(area) do
    table.insert(rps, rp.name or rp.Name)
  end

  return rps
end

---Check whether two RP arrays contain the same string items regardless of order
---@param rpArray1 string[] First RP array
---@param rpArray2 string[] Second RP array
---@return boolean # True if both arrays have identical length and matching items
function GameUtils.isSameRPArray(rpArray1, rpArray2)
  if #rpArray1 ~= #rpArray2 then
    return false
  end

  local rpCounts = {}

  for _, rpName in ipairs(rpArray1) do
    rpCounts[rpName] = (rpCounts[rpName] or 0) + 1
  end

  for _, rpName in ipairs(rpArray2) do
    if not rpCounts[rpName] then
      return false
    end

    rpCounts[rpName] = rpCounts[rpName] - 1

    if rpCounts[rpName] == 0 then
      rpCounts[rpName] = nil
    end
  end

  return next(rpCounts) == nil
end

---Remove all reference points from a zone
---@param zone CMO__Zone Zone object containing reference points
---@param sideName string Side name for deletion context
---@return boolean # Whether all reference points were successfully removed
function GameUtils.removeRPs(zone, sideName)
  local rps = GameUtils.normalizeToRPArray(zone)
  for _, rp in ipairs(rps) do
    local result = GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = rp })
    if not result then
      return false
    end
  end
  return true
end

---Check if point is within defined area using reference points
---Converts reference point names to polygon coordinates and performs point-in-polygon test
---@param side string Side name (used to retrieve reference points)
---@param point CMO__Location|nil Point to check
---@param area string[] Array of reference point names defining the polygon boundary
---@return boolean # True if point is inside the area, false otherwise
function GameUtils.isInArea(side, point, area)
  local minPolygonPoints = 3

  if not point or not area then
    return false
  end

  -- area is an array of reference point names that define the polygon
  local points = GameApi.ScenEdit_GetReferencePoints({ side = side, area = area })
  if not points or #points < minPolygonPoints then
    return false
  end

  local polygon = {}
  for _, p in ipairs(points) do
    table.insert(polygon, {
      latitude = tonumber(p.latitude),
      longitude = tonumber(p.longitude)
    })
  end

  return Utils.isPointInPolygon(point, polygon)
end

---Get weapon information for a unit
---@param unit CMO__Unit The unit to check
---@param weaponDBID number|nil Specific weapon DBID to look for
---@return {weaponDBID: number, mountDBID: number, availableWeapons: integer, maxWeapons: integer, assignedWeapons: integer} # Weapon information
function GameUtils.getWeaponInfo(unit, weaponDBID)
  local availableWeapons = 0
  local maxWeaponCapacity = 0
  local mountDBID = unit.mounts[1].mount_dbid
  local mountIndex = 1
  local wpnIndex = 1

  -- Find the specified weapon or use the first available weapon with ammo
  for mountIdx, mount in ipairs(unit.mounts) do
    for wpnIdx, wpn in ipairs(mount.mount_weapons) do
      if (weaponDBID == nil and wpn.wpn_default > 0) or wpn.wpn_dbid == weaponDBID then
        wpnIndex = wpnIdx
        mountIndex = mountIdx
        mountDBID = mount.mount_dbid
        availableWeapons = availableWeapons + wpn.wpn_current
        maxWeaponCapacity = maxWeaponCapacity + wpn.wpn_maxcap
      end
    end
  end

  -- If no weaponDBID was provided, use the one we found
  if weaponDBID == nil then
    weaponDBID = unit.mounts[mountIndex].mount_weapons[wpnIndex].wpn_dbid
  end

  -- Get currently assigned weapons
  local alreadyAllocatedWeapons = 0
  local weaponAllocations = GameApi.ScenEdit_WeaponAllocation(unit.guid, "", "")

  if not weaponAllocations then
    weaponAllocations = {}
  end

  for _, item in ipairs(weaponAllocations) do
    alreadyAllocatedWeapons = alreadyAllocatedWeapons + item.qtyAssigned
  end

  return {
    weaponDBID = weaponDBID,
    mountDBID = mountDBID,
    availableWeapons = availableWeapons,
    maxWeapons = maxWeaponCapacity,
    assignedWeapons = alreadyAllocatedWeapons
  }
end

return GameUtils
