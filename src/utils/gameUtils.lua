local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

local GameUtils = {}

-- ============================================================================
-- Constants definition
-- ============================================================================

local UNIT_CREATION = {
  MAX_ATTEMPTS = 50,
  RANDOM_TEXT_LENGTH = 2
}

---@param xLatitude number
---@param xLongitude number
---@param maxRadius number
---@return CMO__Location|nil
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
---@return table<integer, CMO__Location>
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
      LATITUDE = locationTemp.latitude,
      LONGITUDE = locationTemp.longitude,
      BEARING = bearingTemp,
      DISTANCE = distanceTemp
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

---@param position CMO__Location
---@param mode SBJ__AreaMode
---@return table<integer, CMO__ReferencePoint>|boolean
function GameUtils.newArea(position, mode)
  local side = mode.side
  local shape = mode.shape
  if side == nil or shape == nil then return false end
  local name = (mode.name or "RP")
  local bear_offset = (mode.bear_offset or 0)
  local rpTable = {}
  local a = 1
  --Circle
  if shape == 'circle' then
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
  elseif shape == 'square' then
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

---@param time string|number @A string in the format "YYYY-MM-DD HH:MM:SS" or a timestamp number
---@param advanceSeconds? number @Optional seconds to advance the check time (makes condition trigger earlier)
---@return boolean
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

---comment
---@param side string
---@param name string
---@param type string
---@param opts? CMO__Mission
---@param emcon? string
---@return CMO__Mission|nil
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
    local result = GameApi.ScenEdit_SetEMCON('mission', name, emcon)

    if not result then
      return
    end
  end

  return mission
end

--- Creates, updates, or removes a "Unit Enters Area" event trigger in the CMO scenario
--- This function sets up an event system that executes a Lua script when units matching
--- a filter enter or exit a specified area during the simulation
---@param name string Event name (must be unique within the scenario)
---@param FilterType table Unit filter criteria (e.g., side name, unit type, or complex filter)
---@param area table Reference point area or area table defining the trigger zone
---@param script string Lua script code to execute when the event triggers
---@param mode string Operation mode: 'add' (create new), 'update' (modify existing), 'remove' (delete)
---@param exit boolean If true, triggers when units EXIT the area; if false, triggers on ENTER
---@param isRepeatable boolean If true, event can trigger multiple times; if false, triggers only once
---@param isActive boolean If true, event is immediately active; if false, event is dormant
---@return boolean True if operation succeeded, false if any API call failed
function GameUtils.unitEntersAreaEvent(name, FilterType, area, script, mode, exit, isRepeatable, isActive)
  -- Set default parameter values
  if isRepeatable == nil then isRepeatable = false end
  if isActive == nil then isActive = true end
  if exit == nil then exit = false end

  if mode == 'add' then
    -- Create the trigger component that monitors unit movement
    local result = GameApi.ScenEdit_SetTrigger({
      description = name .. '',
      mode = 'add',
      type = 'UnitEntersArea',
      TargetFilter = FilterType,
      Area = area,
      ExitArea = exit -- Controls whether this triggers on enter (false) or exit (true)
    })

    if not result then
      return false
    end

    -- Create the action component that executes the specified Lua script
    local actionResult = GameApi.ScenEdit_SetAction({
      mode = 'add',
      type = 'LuaScript',
      name = name .. '',
      ScriptText = script
    })

    if not actionResult then
      return false
    end

    -- Create the event and link the trigger and action together
    GameApi.ScenEdit_SetEvent(name, { mode = 'add', IsRepeatable = isRepeatable, isActive = isActive, isShown = true })
    GameApi.ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '' })
    GameApi.ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '' })
  elseif mode == 'update' then
    -- Update existing trigger if new area parameters are provided
    if area ~= nil then
      GameApi.ScenEdit_SetTrigger({
        description = name .. '',
        mode = 'update',
        type = 'UnitEntersArea',
        TargetFilter = FilterType,
        Area = area,
        ExitArea = exit
      })
    end
    -- Update existing action if new script is provided
    if script ~= nil then
      GameApi.ScenEdit_SetAction({ mode = 'update', type = 'LuaScript', name = name .. '', ScriptText = script })
    end
  elseif mode == 'remove' then
    -- Remove all components of the event system

    GameApi.ScenEdit_SetEvent(name, { mode = 'remove' })
    GameApi.ScenEdit_SetTrigger({ description = name .. '', mode = 'remove' })
    GameApi.ScenEdit_SetAction({ description = name .. '', mode = 'remove' })
  end

  return true
end

---Attempts to add a unit to the scenario with retry logic and random positioning
---This function tries to create a unit at a randomized position within a circular area.
---If unit creation fails (e.g., due to terrain constraints or API issues), it retries
---with different random positions up to the specified maximum attempts.
---@param name string Unique name for the unit to be created
---@param lat number Latitude coordinate of the center point for unit placement
---@param lon number Longitude coordinate of the center point for unit placement
---@param randomRadius number Maximum distance in nautical miles from center point for random placement
---@param unitDBID number Database ID of the unit type to create (must be valid CMO platform DBID)
---@param attempt? number Current attempt number (used internally for recursion, defaults to 1)
---@param max_attempts? number Maximum number of placement attempts before giving up (defaults to 50)
---@return CMO__Unit|nil unit The created unit object if successful, nil if all attempts failed
---@return CMO__Location|nil point The final position where unit was placed, nil if creation failed
function GameUtils.tryAddUnit(name, lat, lon, randomRadius, unitDBID, attempt, max_attempts)
  attempt = attempt or 1
  max_attempts = max_attempts or 50

  local point = GameUtils.circularRandomPosition(lat, lon, randomRadius)
  local unit = GameApi.ScenEdit_AddUnit({
    type = 'Facility',
    unitname = name,
    dbid = unitDBID,
    side = 'China',
    Lat = point.latitude,
    Lon = point.longitude,
    autodetectable = false
  })

  if unit then
    return unit, point
  elseif attempt < max_attempts then
    return GameUtils.tryAddUnit(name, lat, lon, randomRadius, unitDBID, attempt + 1, max_attempts)
  else
    print("Failed to create jammer unit after " .. max_attempts .. " attempts: " .. name)
    return nil, nil
  end
end

---Attempt to create a single unit (with retry mechanism)
---@param unitDescriptor CMO__SetUnitDescriptor Unit descriptor
---@param maxAttempts number|nil Maximum number of attempts
---@return CMO__Unit|nil Created unit
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
---@return CMO__Unit|CMO__Unit[] Created units
function GameUtils.createRandomUnits(descriptor)
  local units = {}

  for i = 1, descriptor.count do
    local dbid = descriptor.dbids[math.random(#descriptor.dbids)]
    local point = GameUtils.circularRandomPosition(
      descriptor.centerPoint.lat,
      descriptor.centerPoint.lon,
      descriptor.randomRadius
    )

    local unitDescriptor = {
      type = descriptor.unitType,
      dbid = dbid,
      side = descriptor.sideName,
      Lat = point.latitude,
      Lon = point.longitude,
      autodetectable = descriptor.autodetectable,
      unitname = descriptor.unitname .. Utils.randomTxt(UNIT_CREATION.RANDOM_TEXT_LENGTH),
    }

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

return GameUtils
