local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

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
      distanceTemp = params.firstDistance
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

return GameUtils
