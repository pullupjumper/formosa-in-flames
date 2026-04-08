local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local GameUtils = {}

local sideConfigCache = {}
local UNIT_CREATION = {
  MAX_ATTEMPTS = 50,
  RANDOM_TEXT_LENGTH = 2
}

---Check if zone description matches any pattern in the list
---@param description string Zone description to match
---@param patterns string[] Array of patterns to check
---@return boolean # True if description matches any pattern
local function matchesPattern(description, patterns)
  for _, pattern in ipairs(patterns) do
    if string.find(description, pattern) then
      return true
    end
  end
  return false
end

---Get or create cached side configuration
---Returns side configuration with field identifier, enemy side mapping, and display name
---@param sideName string Side name ('China', 'US', or other)
---@return SBJ__SideConfig # Side configuration with field, enemySide, and displayName
function GameUtils.getCachedSideConfig(sideName)
  if not sideConfigCache[sideName] then
    if sideName == "China" then
      sideConfigCache[sideName] = {
        field = "c",
        enemySide = "Taiwan",
        displayName = "China"
      }
    elseif sideName == "US" then
      sideConfigCache[sideName] = {
        field = "u",
        enemySide = "China",
        displayName = "United States"
      }
    else
      sideConfigCache[sideName] = {
        field = "t",
        enemySide = "China",
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
function GameUtils.calculateDistance(lat1, lon1, lat2, lon2)
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

    local distance = GameUtils.calculateDistance(
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
function GameUtils.circularRandomPosition(xLatitude, xLongitude, maxRadius)
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
function GameUtils.generateLocations(params)
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
---@param mode SBJ__AreaMode Area configuration (shape, side, distance, etc.)
---@return table<integer, CMO__ReferencePoint>|boolean # Array of reference point names forming the area, or false if creation fails
function GameUtils.newArea(position, mode)
  local side = mode.side
  local shape = mode.shape
  if side == nil or shape == nil then return false end
  local name = (mode.name or "RP")
  local bear_offset = (mode.bear_offset or 0)
  local rpTable = {}
  local a = 1
  --Circle
  if shape == "circle" then
    local distance = mode.distance
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
    local distance = mode.distance
    for i = 0, 3 do
      local b = 45 + (90 * i) + bear_offset
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
---@param side string Side name that owns the mission
---@param name string Mission name (must be unique)
---@param type string Mission type (e.g., "Strike", "Patrol", "Ferry")
---@param opts CMO__Mission Mission configuration options
---@param emcon? string Optional EMCON settings string
---@return CMO__Mission|nil # Created mission object, or nil if any step fails
function GameUtils.createMission(side, name, type, opts, emcon)
  local mission = GameApi.ScenEdit_AddMission(side, name, type, opts)

  if not mission then
    return
  end

  if opts then
    local result = GameApi.ScenEdit_SetMission(side, name, opts)

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
---@param name string Event name (must be unique within the scenario)
---@param FilterType table Unit filter criteria (e.g., side name, unit type, or complex filter)
---@param area table Reference point area or area table defining the trigger zone
---@param script string Lua script code to execute when the event triggers
---@param mode string Operation mode: 'add' (create new), 'update' (modify existing), 'remove' (delete)
---@param exit boolean If true, triggers when units EXIT the area; if false, triggers on ENTER
---@param isRepeatable boolean If true, event can trigger multiple times; if false, triggers only once
---@param isActive boolean If true, event is immediately active; if false, event is dormant
---@return boolean # True if operation succeeded, false if any API call failed
function GameUtils.unitEntersAreaEvent(name, FilterType, area, script, mode, exit, isRepeatable, isActive)
  -- Set default parameter values
  if isRepeatable == nil then isRepeatable = false end
  if isActive == nil then isActive = true end
  if exit == nil then exit = false end

  if mode == "add" then
    -- Create the trigger component that monitors unit movement
    local result = GameApi.ScenEdit_SetTrigger({
      description = name .. "",
      mode = "add",
      type = "UnitEntersArea",
      TargetFilter = FilterType,
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
        TargetFilter = FilterType,
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
---@param name string Unique name for the unit to be created
---@param latitude number|string Latitude coordinate of the center point for unit placement
---@param longitude number|string Longitude coordinate of the center point for unit placement
---@param randomRadius number Maximum distance in nautical miles from center point for random placement
---@param unitDBID integer Database ID of the unit type to create (must be valid CMO platform DBID)
---@param attempt? integer Current attempt number (used internally for recursion, defaults to 1)
---@param maxAttempts? number Maximum number of placement attempts before giving up (defaults to 50)
---@return CMO__Unit|nil unit The created unit object if successful, nil if all attempts failed
---@return CMO__Location|nil point The final position where unit was placed, nil if creation failed
function GameUtils.tryAddUnit(name, latitude, longitude, randomRadius, unitDBID, attempt, maxAttempts)
  attempt = attempt or 1
  maxAttempts = maxAttempts or 50

  local point = GameUtils.circularRandomPosition(latitude, longitude, randomRadius)
  local unit

  if point then
    unit = GameApi.ScenEdit_AddUnit({
      type = "Facility",
      unitname = name,
      dbid = unitDBID,
      side = "China",
      latitude = point.latitude,
      longitude = point.longitude,
      autodetectable = false
    })
  end

  if unit then
    return unit, point
  elseif attempt < maxAttempts then
    return GameUtils.tryAddUnit(name, latitude, longitude, randomRadius, unitDBID, attempt + 1, maxAttempts)
  else
    print("Failed to create jammer unit after " .. maxAttempts .. " attempts: " .. name)
    return nil, nil
  end
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
    local point = GameUtils.circularRandomPosition(
      descriptor.centerPoint.latitude,
      descriptor.centerPoint.longitude,
      descriptor.randomRadius
    )
    local unitDescriptor

    -- Generate unit name with optional random suffix
    local unitname = descriptor.unitname
    if useRandomSuffix then
      unitname = unitname .. Utils.randomTxt(UNIT_CREATION.RANDOM_TEXT_LENGTH)
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
---Converts to subordinate echelon: Bde→Bn, Bn→Coy, Coy/Sqn→Plt
---@param unitName string Unit name
---@return string|nil # Converted unit type (Bn/Coy/Plt), or nil if not found
function GameUtils.extractUnitType(unitName)
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
function GameUtils.convertToRPArray(zone)
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
  local rps = GameUtils.convertToRPArray(zone)
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

-- ============================================================================
-- Operational Area Code Generation
-- ============================================================================

local AREA_NAME_PREFIXES = {
  RL = "RELOAD_POINT",
  HA = "HIDE_AREA",
  FP = "FIRE_POINT",
  AHA = "AMMO_HOLDING_AREA",
}
local POSITION_TYPE_ORDER = { "RL", "HA", "FP", "AHA" }

---Serialize coordinate value (string or number) to Lua code
---@param val string|number
---@return string
local function serializeCoord(val)
  return type(val) == "string" and ('"' .. val .. '"') or tostring(val)
end

---Serialize string array on single line
---@param arr string[]
---@return string
local function serializeStringArray(arr)
  local parts = {}
  for _, v in ipairs(arr) do parts[#parts + 1] = '"' .. v .. '"' end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

---Serialize waypoint to inline Lua code
---@param wp CMO__Waypoint
---@return string
local function serializeWaypoint(wp)
  return "{ latitude = " .. serializeCoord(wp.latitude) .. ", longitude = " .. serializeCoord(wp.longitude) .. ", }"
end

---Resolve operational area key name from name field or constants reverse-lookup
---@param opArea SBJ__OperationalArea
---@return string|nil
local function resolveOpAreaKey(opArea)
  if opArea.name then
    local str = opArea.name:gsub("#", "")
    return str
  end
  for constKey, constOpArea in pairs(constants.OPERATIONAL_AREAS) do
    if constOpArea == opArea then
      return constKey
    end
  end
  return nil
end

---Recursive Lua value serializer with operationalArea replacement
---@param value any Value to serialize
---@param level integer Indentation level
---@param opAreaMap table<table, string> Maps operationalArea table refs to constant key names
---@return string
local function serializeValue(value, level, opAreaMap)
  local pad = string.rep("  ", level)
  local pad1 = string.rep("  ", level + 1)

  if value == nil then return "nil" end
  if type(value) == "boolean" then return tostring(value) end
  if type(value) == "number" then return tostring(value) end
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) ~= "table" then return tostring(value) end

  local isArray = true
  for k in pairs(value) do
    if type(k) ~= "number" then
      isArray = false; break
    end
  end

  local lines = { "{" }

  if isArray then
    for _, v in ipairs(value) do
      lines[#lines + 1] = pad1 .. serializeValue(v, level + 1, opAreaMap) .. ","
    end
  else
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, k in ipairs(keys) do
      local v = value[k]
      local keyStr = type(k) == "string"
          and (k:match("^[%a_][%w_]*$") and k or '["' .. k .. '"]')
          or ("[" .. tostring(k) .. "]")

      if k == "operationalArea" and type(v) == "table" then
        local opKey = opAreaMap[v] or resolveOpAreaKey(v)
        if opKey then
          lines[#lines + 1] = pad1 .. keyStr .. " = constants.OPERATIONAL_AREAS." .. opKey .. ","
        else
          lines[#lines + 1] = pad1 .. keyStr .. " = " .. serializeValue(v, level + 1, opAreaMap) .. ","
        end
      else
        lines[#lines + 1] = pad1 .. keyStr .. " = " .. serializeValue(v, level + 1, opAreaMap) .. ","
      end
    end
  end

  lines[#lines + 1] = pad .. "}"
  return table.concat(lines, "\n")
end

---Serialize wpnCurrent/wpnDefault value as configPath reference when possible
---@param value number Ammunition count value
---@param wpnDefault number System's default weapon count
---@param configPath string Config path prefix
---@return string # Serialized expression string
local function serializeWpnRef(value, wpnDefault, configPath)
  if wpnDefault and wpnDefault > 0 and value > 0 then
    if value == wpnDefault then
      return configPath .. ".wpnDefault"
    end
    local ratio = value / wpnDefault
    if ratio == math.floor(ratio) and ratio > 1 then
      return configPath .. ".wpnDefault * " .. math.floor(ratio)
    end
    if value * 2 == wpnDefault then
      return configPath .. ".wpnDefault / 2"
    end
  end
  return tostring(value)
end

---Extract operational areas from ground force config and generate Lua code strings
---Collects unique SBJ__OperationalArea from firingUnits, generates constants.AREAS
---and constants.OPERATIONAL_AREAS code, then returns modified config with constant references
---@param sideName string Side name ('Taiwan' or 'China')
---@param groundForceConfig SBJ__GroundForceConfig Ground force configuration
---@return string areasStr constants.AREAS entries
---@return string opAreasStr constants.OPERATIONAL_AREAS entries
---@return string configStr Modified config with ammunitions, resupplyUnits, and firingUnits using constant references
function GameUtils.extractOperationalAreas(sideName, groundForceConfig)
  local sideObj = GameUtils.getCachedSideConfig(sideName)

  -- Phase 1: Collect unique operational areas
  local uniqueAreas = {} ---@type {key: string, opArea: SBJ__OperationalArea}[]
  local seenKeys = {}
  local opAreaMap = {} ---@type table<table, string>

  for _, sysConfig in pairs(groundForceConfig) do
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      for _, unit in pairs(sysConfig.firingUnits) do
        local opArea = unit.operationalArea
        if opArea then
          local key = resolveOpAreaKey(opArea)
          if key then
            opAreaMap[opArea] = key
            if not seenKeys[key] then
              seenKeys[key] = true
              uniqueAreas[#uniqueAreas + 1] = { key = key, opArea = opArea }
            end
          end
        end
      end
      if sysConfig.resupplyUnits then
        for _, unit in pairs(sysConfig.resupplyUnits) do
          local opArea = unit.operationalArea
          if opArea then
            local key = resolveOpAreaKey(opArea)
            if key then
              opAreaMap[opArea] = key
              if not seenKeys[key] then
                seenKeys[key] = true
                uniqueAreas[#uniqueAreas + 1] = { key = key, opArea = opArea }
              end
            end
          end
        end
      end
    end
  end

  table.sort(uniqueAreas, function(a, b) return a.key < b.key end)

  -- Phase 2: Generate constants.AREAS entries
  local areasLines = {}
  local areaRefMap = {} ---@type table<string, table<string, string>>

  for _, entry in ipairs(uniqueAreas) do
    local key, opArea = entry.key, entry.opArea
    areaRefMap[key] = {}

    for _, posType in ipairs(POSITION_TYPE_ORDER) do
      local positions = opArea[posType]
      if positions then
        for i, pos in ipairs(positions) do
          if pos.area then
            local constName = AREA_NAME_PREFIXES[posType] .. "_" .. key
            if posType == "FP" then constName = constName .. "_" .. i end
            areasLines[#areasLines + 1] = "  " .. constName .. " = " .. serializeStringArray(pos.area) .. ","
            areaRefMap[key][posType .. "_" .. i] = constName
          end
        end
      end
    end

    if opArea.mask and opArea.mask.area then
      local constName = "MASK_" .. key
      areasLines[#areasLines + 1] = "  " .. constName .. " = " .. serializeStringArray(opArea.mask.area) .. ","
      areaRefMap[key]["mask"] = constName
    end
  end

  -- Phase 3: Generate constants.OPERATIONAL_AREAS entries
  local opLines = {}

  for _, entry in ipairs(uniqueAreas) do
    local key, opArea = entry.key, entry.opArea
    opLines[#opLines + 1] = "  " .. key .. " = {"

    for _, posType in ipairs(POSITION_TYPE_ORDER) do
      local positions = opArea[posType]
      if positions then
        if #positions == 1 then
          local pos = positions[1]
          opLines[#opLines + 1] = "    " .. posType .. " = { {"
          opLines[#opLines + 1] = "      course = {"
          for _, wp in ipairs(pos.course) do
            opLines[#opLines + 1] = "        " .. serializeWaypoint(wp) .. ","
          end
          opLines[#opLines + 1] = "      },"
          opLines[#opLines + 1] = "      area = constants.AREAS." .. areaRefMap[key][posType .. "_1"]
          opLines[#opLines + 1] = "    } },"
        else
          opLines[#opLines + 1] = "    " .. posType .. " = {"
          for i, pos in ipairs(positions) do
            opLines[#opLines + 1] = "      {"
            opLines[#opLines + 1] = "        course = {"
            for _, wp in ipairs(pos.course) do
              opLines[#opLines + 1] = "          " .. serializeWaypoint(wp) .. ","
            end
            opLines[#opLines + 1] = "        },"
            opLines[#opLines + 1] = "        area = constants.AREAS." .. areaRefMap[key][posType .. "_" .. i]
            opLines[#opLines + 1] = "      },"
          end
          opLines[#opLines + 1] = "    },"
        end
      end
    end

    if opArea.mask then
      local maskRef = areaRefMap[key]["mask"]
      if maskRef then
        opLines[#opLines + 1] = "    mask = { area = constants.AREAS." .. maskRef .. " },"
      end
    end

    opLines[#opLines + 1] = "  },"
  end

  -- Phase 4: Serialize firingUnits with constant references
  local areasStr = "constants.AREAS = {\n" .. table.concat(areasLines, "\n") .. "\n}"
  local opAreasStr = "constants.OPERATIONAL_AREAS = {\n" .. table.concat(opLines, "\n") .. "\n}"

  local FIELD_ORDER = {
    "guid", "name", "msg", "state", "operationalArea",
    "weaponDBID", "ammoThreshold", "resupplyUnit", "dbid", "mountDescriptors"
  }

  local reverseState = {}
  for k, v in pairs(constants.MISSILE_SYSTEM_STATE) do reverseState[v] = k end
  local reverseWeapons = {}
  for k, v in pairs(constants.WEAPONS) do reverseWeapons[v] = k end
  local reversePlatforms = {}
  for k, v in pairs(constants.PLATFORMS) do reversePlatforms[v] = k end

  local firingUnitBlocks = {}
  local groundKeys = {}
  for k in pairs(groundForceConfig) do
    if type(k) == "string" then
      groundKeys[#groundKeys + 1] = k
    end
  end
  table.sort(groundKeys, function(a, b) return a < b end)

  for _, sysKey in ipairs(groundKeys) do
    local sysConfig = groundForceConfig[sysKey]
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      local configPath = "config." .. sideObj.field .. ".ground." .. sysKey

      -- Serialize ammunitions
      if sysConfig.ammunitions then
        local ammoLines = { configPath .. ".ammunitions = {" }
        local ammoNames = {}
        for k in pairs(sysConfig.ammunitions) do ammoNames[#ammoNames + 1] = k end
        table.sort(ammoNames)

        for _, ammoName in ipairs(ammoNames) do
          local ammo = sysConfig.ammunitions[ammoName]
          ammoLines[#ammoLines + 1] = '  ["' .. ammoName .. '"] = {'
          ammoLines[#ammoLines + 1] = "    guid = " .. string.format("%q", ammo.guid) .. ","
          ammoLines[#ammoLines + 1] = "    name = " .. string.format("%q", ammo.name) .. ","
          ammoLines[#ammoLines + 1] = "    wpnCurrent = " ..
              serializeWpnRef(ammo.wpnCurrent, sysConfig.wpnDefault, configPath) .. ","
          ammoLines[#ammoLines + 1] = "    wpnDefault = " ..
              serializeWpnRef(ammo.wpnDefault, sysConfig.wpnDefault, configPath) .. ","
          ammoLines[#ammoLines + 1] = "  },"
        end

        ammoLines[#ammoLines + 1] = "}"
        firingUnitBlocks[#firingUnitBlocks + 1] = table.concat(ammoLines, "\n")
      end

      -- Serialize resupplyUnits
      if sysConfig.resupplyUnits then
        local resLines = { configPath .. ".resupplyUnits = {" }
        local resNames = {}
        for k in pairs(sysConfig.resupplyUnits) do resNames[#resNames + 1] = k end
        table.sort(resNames)

        for _, resName in ipairs(resNames) do
          local unit = sysConfig.resupplyUnits[resName]
          resLines[#resLines + 1] = '  ["' .. resName .. '"] = {'
          resLines[#resLines + 1] = "    guid = " .. string.format("%q", unit.guid) .. ","
          resLines[#resLines + 1] = "    name = " .. string.format("%q", unit.name) .. ","
          resLines[#resLines + 1] = "    wpnCurrent = " ..
              serializeWpnRef(unit.wpnCurrent, sysConfig.wpnDefault, configPath) .. ","
          resLines[#resLines + 1] = "    wpnDefault = " ..
              serializeWpnRef(unit.wpnDefault, sysConfig.wpnDefault, configPath) .. ","
          resLines[#resLines + 1] = "    unitCount = " .. tostring(unit.unitCount) .. ","

          local opKey = opAreaMap[unit.operationalArea]
          resLines[#resLines + 1] = "    operationalArea = " ..
              (opKey and ("constants.OPERATIONAL_AREAS." .. opKey) or serializeValue(unit.operationalArea, 2, opAreaMap)) ..
              ","

          local stateKey = reverseState[unit.state]
          resLines[#resLines + 1] = "    state = " ..
              (stateKey and ("constants.MISSILE_SYSTEM_STATE." .. stateKey) or tostring(unit.state)) .. ","

          resLines[#resLines + 1] = "    ammunition = " .. string.format("%q", unit.ammunition) .. ","

          if type(unit.firingUnit) == "string" then
            resLines[#resLines + 1] = "    firingUnit = " .. string.format("%q", unit.firingUnit)
          elseif type(unit.firingUnit) == "table" then
            local parts = {}
            for _, v in ipairs(unit.firingUnit) do
              parts[#parts + 1] = string.format("%q", v)
            end
            resLines[#resLines + 1] = "    firingUnit = { " .. table.concat(parts, ", ") .. " }"
          end

          resLines[#resLines + 1] = "  },"
        end

        resLines[#resLines + 1] = "}"
        firingUnitBlocks[#firingUnitBlocks + 1] = table.concat(resLines, "\n")
      end

      local lines = { configPath .. ".firingUnits = {" }

      local unitNames = {}
      for unitName in pairs(sysConfig.firingUnits) do
        unitNames[#unitNames + 1] = unitName
      end
      table.sort(unitNames)

      for _, unitName in ipairs(unitNames) do
        local unit = sysConfig.firingUnits[unitName]
        lines[#lines + 1] = '  ["' .. unitName .. '"] = {'

        local orderedFields = {}
        local fieldSet = {}
        for _, f in ipairs(FIELD_ORDER) do
          if unit[f] ~= nil then
            orderedFields[#orderedFields + 1] = f
            fieldSet[f] = true
          end
        end
        local extraFields = {}
        for f in pairs(unit) do
          if not fieldSet[f] then extraFields[#extraFields + 1] = f end
        end
        table.sort(extraFields)
        for _, f in ipairs(extraFields) do orderedFields[#orderedFields + 1] = f end

        for _, field in ipairs(orderedFields) do
          local value = unit[field]
          local serialized

          if field == "state" and type(value) == "number" then
            local stateKey = reverseState[value]
            serialized = stateKey and ("constants.MISSILE_SYSTEM_STATE." .. stateKey) or tostring(value)
          elseif field == "operationalArea" and type(value) == "table" then
            local opKey = opAreaMap[value]
            serialized = opKey and ("constants.OPERATIONAL_AREAS." .. opKey) or serializeValue(value, 2, opAreaMap)
          elseif field == "weaponDBID" then
            if type(value) == "number" then
              local wpnKey = reverseWeapons[value]
              serialized = wpnKey and ("constants.WEAPONS." .. wpnKey) or tostring(value)
            elseif type(value) == "table" then
              local parts = {}
              for _, v in ipairs(value) do
                local wpnKey = reverseWeapons[v]
                parts[#parts + 1] = wpnKey and ("constants.WEAPONS." .. wpnKey) or tostring(v)
              end
              serialized = "{ " .. table.concat(parts, ", ") .. " }"
            end
          elseif field == "ammoThreshold" then
            serialized = configPath .. ".ammoThreshold"
          elseif field == "dbid" and type(value) == "number" then
            local platKey = reversePlatforms[value]
            serialized = platKey and ("constants.PLATFORMS." .. platKey) or tostring(value)
          elseif field == "mountDescriptors" and type(value) == "table" then
            local mountKey
            for k, v in pairs(constants.MOUNT_DESCRIPTORS) do
              if #v == #value then
                local match = true
                for i, entry in ipairs(v) do
                  if not value[i] or entry.dbid ~= value[i].dbid or entry.mountCount ~= value[i].mountCount then
                    match = false; break
                  end
                end
                if match then
                  mountKey = k; break
                end
              end
            end
            serialized = mountKey and ("constants.MOUNT_DESCRIPTORS." .. mountKey) or serializeValue(value, 2, opAreaMap)
          end

          if not serialized then
            if type(value) == "string" then
              serialized = string.format("%q", value)
            elseif type(value) == "number" or type(value) == "boolean" then
              serialized = tostring(value)
            else
              serialized = serializeValue(value, 2, opAreaMap)
            end
          end

          lines[#lines + 1] = "    " .. field .. " = " .. serialized .. ","
        end

        lines[#lines + 1] = "  },"
      end

      lines[#lines + 1] = "}"
      firingUnitBlocks[#firingUnitBlocks + 1] = table.concat(lines, "\n")
    end
  end

  return areasStr, opAreasStr, table.concat(firingUnitBlocks, "\n")
end

return GameUtils
