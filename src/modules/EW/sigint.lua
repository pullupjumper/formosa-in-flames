local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local SIGINT = {}

local SIGINT_CONSTANTS = {
  DETECTION_THRESHOLD = 60,
  MAX_DETECTION_RANGE = { 300, 340 },
  DETECTION_FORMULA_CONSTANTS = {
    DECAY_RATE = -1 / 450,
    POWER = 0.8,
    BASE_COEFFICIENT = 0.00007937,
    POWER_DIVISOR = 10 ^ 6.1,
    RANDOM_FACTOR = 120,
    RANDOM_DIVISOR = 1500000,
    RANDOM_POWER_DIVISOR = 10 ^ 5,
    DISTANCE_POWER = 2.25,
    DISTANCE_DIVISOR = 10 ^ 2.4
  },
  DEFAULT_DISPLAY = {
    R = 255,
    G = 255,
    B = 255,
    LIFE_TIME = 4,
    FONT_SIZE = 16
  },
  MIN_POLYGON_POINTS = 3,
  DETECTION_SKIP_PROBABILITY = 0.3
}

---Calculate SIGINT detection probability based on distance
---Uses exponential decay model: P(x) = e^(-k*x^p) where k=1/450, p=0.8
---@param distance number Distance in nautical miles
---@param config SBJ__SIGINTConfig|nil Detection configuration
---@return number # Value between 0 and 1
function SIGINT.calculateDetectionProbability(distance, config)
  config = config or {}
  local threshold = config.detectionThreshold or SIGINT_CONSTANTS.DETECTION_THRESHOLD
  local maxRange = config.maxRange or SIGINT_CONSTANTS.MAX_DETECTION_RANGE
  local decayRate = config.decayRate or SIGINT_CONSTANTS.DETECTION_FORMULA_CONSTANTS.DECAY_RATE
  local power = SIGINT_CONSTANTS.DETECTION_FORMULA_CONSTANTS.POWER

  if distance <= threshold then
    return 1.0
  elseif distance >= math.random(maxRange[1], maxRange[2]) then
    return 0.0
  else
    return math.exp(decayRate * (distance ^ power))
  end
end

---Calculate signal deviation distance for SIGINT detection position randomization
---Uses complex formula to simulate signal triangulation error based on distance
---@param baseDistance number Base distance between detector and target (nautical miles)
---@param config SBJ__SIGINTConfig|nil Detection configuration (optional overrides)
---@return number # Distance from actual position (nautical miles)
local function calculateSignalDeviation(baseDistance, config)
  local constants = SIGINT_CONSTANTS.DETECTION_FORMULA_CONSTANTS
  local randomFactor = (config and config.randomFactor) or constants.RANDOM_FACTOR

  local baseDeviation = (constants.BASE_COEFFICIENT * (baseDistance ^ 3.8518)) / constants.POWER_DIVISOR
  local randomDeviation = ((math.random(-randomFactor * baseDistance, randomFactor * baseDistance) ^ 2) / constants.RANDOM_DIVISOR) /
      constants.RANDOM_POWER_DIVISOR * ((baseDistance ^ constants.DISTANCE_POWER) / constants.DISTANCE_DIVISOR)

  return baseDeviation + randomDeviation
end

---Check if point is within polygon using ray casting algorithm
---@param point CMO__Location Point to check
---@param polygon CMO__Location[] Polygon vertices
---@return boolean # Whether point is inside polygon
function SIGINT.isPointInPolygon(point, polygon)
  if not point or not polygon or #polygon < SIGINT_CONSTANTS.MIN_POLYGON_POINTS then
    return false
  end

  local crossings = 0
  local n = #polygon

  for i = 1, n do
    local p1 = polygon[i]
    local p2 = polygon[i % n + 1]

    if (p1.latitude > point.latitude) ~= (p2.latitude > point.latitude) then
      local intersectLon = (p2.longitude - p1.longitude) * (point.latitude - p1.latitude) /
          (p2.latitude - p1.latitude) + p1.longitude
      if point.longitude < intersectLon then
        crossings = crossings + 1
      end
    end
  end

  return (crossings % 2 == 1)
end

---Check if point is within defined area using reference points
---Converts reference point names to polygon coordinates and performs point-in-polygon test
---@param side string Side name (used to retrieve reference points)
---@param point CMO__Location|nil Point to check
---@param area string[] Array of reference point names defining the polygon boundary
---@return boolean # True if point is inside the area, false otherwise
local function isInArea(side, point, area)
  if not point or not area then
    return false
  end

  -- area is an array of reference point names that define the polygon
  local points = GameApi.ScenEdit_GetReferencePoints({ side = side, area = area })
  if not points or #points < SIGINT_CONSTANTS.MIN_POLYGON_POINTS then
    return false
  end

  local polygon = {}
  for _, p in ipairs(points) do
    table.insert(polygon, {
      latitude = tonumber(p.latitude),
      longitude = tonumber(p.longitude)
    })
  end

  return SIGINT.isPointInPolygon(point, polygon)
end

---Check if unit is emitting signal with enhanced logic
---@param config SBJ__Config Configuration object
---@param unit CMO__Unit Unit object
---@param unitCtx SBJ__FiringUnitContext|SBJ__C2Context Unit data (Battery units check movement, C2 units always emit)
---@param enemySide string Enemy side name
---@return boolean isEmitting Whether unit is emitting signal
---@return string reason Reason for emission status
local function isUnitEmitting(config, unit, unitCtx, enemySide)
  -- Check for specific platform types that always emit
  if unit.dbid == constants.PLATFORMS.C2 then
    return true, "Platform type 46 (always emitting)"
  end

  if unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
    return true, "Platform type 78 (always emitting)"
  end

  -- Check for C2 facilities (always emit, no movement check needed as they are fixed buildings)
  for _, DBID in ipairs(config.c.IADS.C2FacilityDBIDs) do
    if unit.dbid == DBID then
      return true, "C2 facility (always emitting)"
    end
  end

  -- For mobile Battery units: check movement status
  -- Battery units are mobile missile launchers that emit signals when moving/repositioning
  local courseCount = #unit.course
  if courseCount == 0 then
    return false, "No course set"
  end

  if unit.speed == 0 then
    return false, "Unit not moving"
  end

  -- Check if leaving restricted launch area (only for Battery units)
  if not unitCtx.operationalArea.RL[1].area or #unitCtx.operationalArea.RL[1].area == 0 then
    return false, "No RL area defined"
  end

  local lastCoursePoint = unit.course[courseCount]
  local isLeavingRL = not isInArea(enemySide, lastCoursePoint, unitCtx.operationalArea.RL.area) and unit.speed > 0

  return isLeavingRL, isLeavingRL and "Leaving restricted area" or "Within restricted area"
end

---Perform SIGINT detection attempt for enemy unit
---Checks all airborne reconnaissance aircraft in SIGINT context for detection probability
---Returns randomized position if detected, zero position if not detected
---@param sigintContext SBJ__SIGINTContext SIGINT context containing reconnaissance aircraft
---@param enemyUnit string|CMO__Unit Enemy unit GUID or unit object to detect
---@param notification string Notification message to display on map if detected
---@param isEmitting boolean Whether target unit is currently emitting signals
---@param isShown boolean Whether to show visual notification on map
---@param data SBJ__SIGINTDisplayData|nil Display configuration (colors, lifetime, font size)
---@param config SBJ__SIGINTConfig|nil Detection configuration (optional overrides for thresholds)
---@return SBJ__SIGINTResult # Detection result with position, confidence, and metadata
local function getSIGINT(sigintContext, enemyUnit, notification, isEmitting, isShown, data, config)
  -- Get enemy unit
  local enemy
  if type(enemyUnit) == "string" then
    enemy = GameApi.ScenEdit_GetUnit(enemyUnit)
    if not enemy then
      return {
        longitude = 0,
        latitude = 0,
        isDetected = false,
        confidence = 0,
        timestamp = GameApi.ScenEdit_CurrentTime()
      }
    end
  else
    enemy = enemyUnit
  end

  -- Setup display configuration
  data = data or {}
  local displayConfig = {
    R = data.R or SIGINT_CONSTANTS.DEFAULT_DISPLAY.R,
    G = data.G or SIGINT_CONSTANTS.DEFAULT_DISPLAY.G,
    B = data.B or SIGINT_CONSTANTS.DEFAULT_DISPLAY.B,
    lifeTime = data.lifeTime or SIGINT_CONSTANTS.DEFAULT_DISPLAY.LIFE_TIME,
    fontSize = data.fontSize or SIGINT_CONSTANTS.DEFAULT_DISPLAY.FONT_SIZE,
    showConfidence = data.showConfidence or false
  }

  -- Detection logic
  for _, ctx in pairs(sigintContext.RA) do
    local actualReconAC = GameApi.ScenEdit_GetUnit(ctx.guid)
    if not actualReconAC or actualReconAC.condition ~= 'Airborne' then
      goto continue
    end

    local distance = GameApi.Tool_Range(enemy.guid, ctx.guid)
    local detectionProbability = SIGINT.calculateDetectionProbability(distance, config)

    if math.random() < detectionProbability and isEmitting then
      local deviation = calculateSignalDeviation(distance, config)
      local pos = GameApi.World_GetPointFromBearing({
        latitude = enemy.latitude,
        longitude = enemy.longitude,
        distance = deviation,
        bearing = math.random(0, 359)
      })

      if isShown then
        local displayText = notification
        if displayConfig.showConfidence then
          displayText = displayText .. string.format(" (%.1f%%)", detectionProbability * 100)
        end

        GameApi.ScenEdit_CreateBarkNotification_Geo(
          pos.longitude,
          pos.latitude,
          displayText,
          displayConfig.R,
          displayConfig.G,
          displayConfig.B,
          true,
          true,
          displayConfig.lifeTime,
          displayConfig.fontSize
        )
      end

      return {
        longitude = pos.longitude,
        latitude = pos.latitude,
        isDetected = true,
        confidence = detectionProbability,
        detectorId = ctx.guid,
        timestamp = GameApi.ScenEdit_CurrentTime()
      }
    end

    ::continue::
  end

  return {
    longitude = 0,
    latitude = 0,
    isDetected = false,
    confidence = 0,
    timestamp = GameApi.ScenEdit_CurrentTime()
  }
end

---Update unit autodetectable state for SIGINT targets
---If unit is in a group, updates all group members; otherwise updates individual unit
---@param unit CMO__Unit Unit object to update (can be group leader or individual unit)
---@param isAutodetectable boolean Target autodetectable state (true = can be auto-detected by enemy)
local function updateAutodetectableState(unit, isAutodetectable)
  if unit.group then
    for _, v in ipairs(unit.group.unitlist) do
      GameApi.ScenEdit_SetUnit({ guid = v, autodetectable = isAutodetectable })
    end
  else
    GameApi.ScenEdit_SetUnit({ guid = unit.guid, autodetectable = isAutodetectable })
  end
end

---Update or create transmission record after successful SIGINT detection
---Creates new transmission record if first detection, otherwise updates existing record
---Increments currentDetectionLevel and checks autodetectable threshold
---@param sigintContext SBJ__SIGINTContext SIGINT context to update transmission records
---@param unitCtx SBJ__FiringUnitContext|SBJ__C2Context Unit context data with metadata
---@param result SBJ__SIGINTResult Detection result with position and confidence
---@param unit CMO__Unit Actual unit object for autodetectable state updates
local function updateTransmissionData(sigintContext, unitCtx, result, unit)
  local transmission = sigintContext.transmissions[unitCtx.guid]

  if not transmission then
    local unitType = (string.find(unitCtx.name, 'ROCC') or string.find(unitCtx.name, 'TAAOC')) and 'C2' or 'mobile'
    transmission = {
      name = unitCtx.name,
      guid = unitCtx.guid,
      msg = unitCtx.msg,
      type = unitType,
      latitude = result.latitude,
      longitude = result.longitude,
      contacts = {},
      currentDetectionLevel = 0,
      autodetectable = false,
      firstDetected = result.timestamp,
      lastDetected = result.timestamp,
      detectionCount = 0,
      confidence = result.confidence
    }
    sigintContext.transmissions[unitCtx.guid] = transmission
  end

  -- Update transmission data
  transmission.latitude = result.latitude
  transmission.longitude = result.longitude
  transmission.lastDetected = result.timestamp
  transmission.detectionCount = transmission.detectionCount + 1
  transmission.confidence = math.max(transmission.confidence, result.confidence)
  transmission.currentDetectionLevel = transmission.currentDetectionLevel + 1

  if transmission.autodetectable then
    updateAutodetectableState(unit, false)
    transmission.autodetectable = false
    Logger.log("SIGINT", "updateTransmissionData: Updated autodetectable state for unit " .. unit.name .. " to false")
  end

  -- Check if should become autodetectable
  local maxCount = sigintContext.maxCount
  if transmission.currentDetectionLevel > maxCount and not transmission.autodetectable then
    updateAutodetectableState(unit, true)
    transmission.autodetectable = true
    Logger.log("SIGINT", "updateTransmissionData: Updated autodetectable state for unit " .. unit.name .. " to true")
  end
end

---Handle undetected case for SIGINT target
---Decrements currentDetectionLevel when unit is not detected, simulating signal fade
---Resets autodetectable state to false if currently autodetectable
---@param sigintContext SBJ__SIGINTContext SIGINT context containing transmission records
---@param unit CMO__Unit Unit object that was not detected this cycle
local function handleUndetected(sigintContext, unit)
  local transmission = sigintContext.transmissions[unit.guid]
  if not transmission then
    return
  end

  local maxCount = sigintContext.maxCount
  if transmission.currentDetectionLevel > maxCount - 1 then
    transmission.currentDetectionLevel = transmission.currentDetectionLevel - 1
  end

  if transmission.autodetectable then
    updateAutodetectableState(unit, false)
    transmission.autodetectable = false
    Logger.log("SIGINT", "handleUndetected: Updated autodetectable state for unit " .. unit.name .. " to false")
  end
end

---Enhanced SIGINT detection handler
---@param config SBJ__Config Configuration object
---@param sigintContext SBJ__SIGINTContext SIGINT context
---@param sideName string Side name (used to determine enemy side for area checks)
---@param unitContexts table<string, SBJ__FiringUnitContext|SBJ__C2Context> Unit contexts to monitor (firing units and C2 nodes)
---@param isShown boolean Whether to show detection notifications on map
---@param sigintConfig SBJ__SIGINTConfig|nil SIGINT-specific configuration (optional overrides)
---@return table<string, SBJ__SIGINTResult> # Detection results by unit GUID
function SIGINT.handleSIGINT(config, sigintContext, sideName, unitContexts, isShown, sigintConfig)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySide = sideConfig.enemySide
  local results = {}
  local processedCount = 0
  local detectedCount = 0

  for _, unitCtx in pairs(unitContexts) do
    -- Get actual unit
    local actualUnit = GameApi.ScenEdit_GetUnit(unitCtx.guid)
    if not actualUnit then
      goto continue
    end

    -- Skip some units randomly for performance
    if math.random() <= SIGINT_CONSTANTS.DETECTION_SKIP_PROBABILITY then
      goto continue
    end

    processedCount = processedCount + 1

    -- Check if unit is emitting
    local isEmitting, emissionReason = isUnitEmitting(config, actualUnit, unitCtx, enemySide)

    -- Perform SIGINT detection
    local result = getSIGINT(sigintContext, unitCtx.guid, unitCtx.msg, isEmitting, isShown, nil, sigintConfig)
    results[unitCtx.guid] = result

    -- Update transmission data based on result
    if result.isDetected then
      detectedCount = detectedCount + 1
      updateTransmissionData(sigintContext, unitCtx, result, actualUnit)
    else
      handleUndetected(sigintContext, actualUnit)
    end

    ::continue::
  end

  Logger.log("SIGINT", string.format("SIGINT processing: %d/%d units processed, %d detections",
    processedCount, Utils.getCount(unitContexts), detectedCount))

  return results
end

---Initialize reconnaissance aircraft contexts for SIGINT operations
---Scans all aircraft units for the specified side and registers RC-135V and Y-9DZ reconnaissance aircraft
---@param SIGINTContext SBJ__SIGINTContext SIGINT context to populate with recon aircraft
---@param sideName string Side name to scan for reconnaissance aircraft
---@return number # Number of reconnaissance aircraft initialized
function SIGINT.initReconAircraftContexts(SIGINTContext, sideName)
  local filteredUnits = GameApi.VP_GetSide({ side = sideName }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    Logger.warn(string.format("No aircraft units found for side '%s'", sideName))
    return 0
  end

  local initializedCount = 0
  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == 'Aircraft' and
        (unit.dbid == constants.PLATFORMS.RC135V or unit.dbid == constants.PLATFORMS.Y9DZ) then
      SIGINTContext.RA[unit.guid] = {
        guid = unit.guid,
        OODA = unit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
      initializedCount = initializedCount + 1
    end
  end

  Logger.log("SIGINT", string.format("Initialized %d reconnaissance aircraft for %s SIGINT operations",
    initializedCount, sideName))

  return initializedCount
end

return SIGINT
