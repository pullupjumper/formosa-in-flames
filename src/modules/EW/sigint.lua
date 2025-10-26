local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")

local SIGINT = {}

-- ============================================================================
-- Constants and Configuration
-- ============================================================================

---SIGINT detection constants
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


-- ============================================================================
-- Cache and State Management
-- ============================================================================

local sideConfigCache = {}
local detectionHistory = {}

-- ============================================================================
-- Utility Functions
-- ============================================================================

---Get cached side configuration
---@param side string side name
---@return SBJ__SideConfig side configuration
local function getCachedSideConfig(side)
  if not sideConfigCache[side] then
    if side == 'China' then
      sideConfigCache[side] = {
        field = 'c',
        enemySide = 'Taiwan',
        displayName = 'China'
      }
    elseif side == 'US' then
      sideConfigCache[side] = {
        field = 'u',
        enemySide = 'China',
        displayName = 'United States'
      }
    else
      sideConfigCache[side] = {
        field = 'u',
        enemySide = 'China',
        displayName = side
      }
    end
  end
  return sideConfigCache[side]
end

-- ============================================================================
-- Detection Algorithm Functions
-- ============================================================================

---Calculate SIGINT detection probability based on distance
---Uses exponential decay model: P(x) = e^(-k*x^p) where k=1/450, p=0.8
---@param distance number distance in nautical miles
---@param config SBJ__SIGINTConfig|nil detection configuration
---@return number probability value between 0 and 1
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

---Calculate signal deviation distance
---@param baseDistance number base distance for calculation
---@param config SBJ__SIGINTConfig|nil detection configuration
---@return number deviation distance
local function calculateSignalDeviation(baseDistance, config)
  local constants = SIGINT_CONSTANTS.DETECTION_FORMULA_CONSTANTS
  local randomFactor = (config and config.randomFactor) or constants.RANDOM_FACTOR

  local baseDeviation = (constants.BASE_COEFFICIENT * (baseDistance ^ 3.8518)) / constants.POWER_DIVISOR
  local randomDeviation = ((math.random(-randomFactor * baseDistance, randomFactor * baseDistance) ^ 2) / constants.RANDOM_DIVISOR) /
      constants.RANDOM_POWER_DIVISOR * ((baseDistance ^ constants.DISTANCE_POWER) / constants.DISTANCE_DIVISOR)

  return baseDeviation + randomDeviation
end

---Check if point is within polygon using ray casting algorithm
---@param point CMO__Location point to check
---@param polygon CMO__Location[] polygon vertices
---@return boolean whether point is inside polygon
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

---Enhanced area checking
---@param side string side name
---@param point CMO__Location|nil point to check
---@param area string[] reference point names array defining the area
---@return boolean whether point is in the area
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

-- ============================================================================
-- Unit Analysis Functions
-- ============================================================================

---Check if unit is emitting signal with enhanced logic
---@param config SBJ__CONFIG configuration object
---@param unit CMO__Unit unit object
---@param unitData SBJ__FiringUnitContext unit data (only Battery units are processed for movement)
---@param enemySide string enemy side name
---@return boolean whether unit is emitting signal
---@return string reason reason for emission status
local function isUnitEmitting(config, unit, unitData, enemySide)
  -- Check for specific platform types that always emit
  if unit.dbid == config.platform.C2 then
    return true, "Platform type 46 (always emitting)"
  end

  if unit.dbid == config.platform.BUNKER_SECTOR_CONTROL_STATION then
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
  if not unitData.OPAREA.RL[1].area or #unitData.OPAREA.RL[1].area == 0 then
    return false, "No RL area defined"
  end

  local lastCoursePoint = unit.course[courseCount]
  local isLeavingRL = not isInArea(enemySide, lastCoursePoint, unitData.OPAREA.RL.area)

  return isLeavingRL, isLeavingRL and "Leaving restricted area" or "Within restricted area"
end

-- ============================================================================
-- Detection Core Functions
-- ============================================================================

---Enhanced SIGINT detection
---@param saveData SBJ__SaveData save data
---@param side string side name
---@param enemy_unit string|CMO__Unit enemy unit GUID or unit object
---@param notification string notification message
---@param isEmitting boolean whether emitting signal
---@param isShown boolean whether to show notification
---@param data SBJ__SIGINTDisplayData|nil display data configuration
---@param config SBJ__SIGINTConfig|nil detection configuration
---@return SBJ__SIGINTResult -- detection result
local function getSIGINT(saveData, side, enemy_unit, notification, isEmitting, isShown, data, config)
  local sideConfig = getCachedSideConfig(side)
  local key = sideConfig.field

  -- Get enemy unit
  local enemyUnit
  if type(enemy_unit) == "string" then
    enemyUnit = GameApi.ScenEdit_GetUnit(enemy_unit)
    if not enemyUnit then
      return {
        longitude = 0,
        latitude = 0,
        isDetected = false,
        confidence = 0,
        timestamp = GameApi.ScenEdit_CurrentTime()
      }
    end
  else
    enemyUnit = enemy_unit
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
  for elint_guid, value in pairs(saveData[key].SIGINT.RA) do
    local elint_u = GameApi.ScenEdit_GetUnit(elint_guid)
    if not elint_u or elint_u.condition ~= 'Airborne' then
      goto continue
    end

    local distance = GameApi.Tool_Range(enemyUnit.guid, elint_guid)
    local detectionProbability = SIGINT.calculateDetectionProbability(distance, config)

    if math.random() < detectionProbability and isEmitting then
      local deviation = calculateSignalDeviation(distance, config)
      local pos = GameApi.World_GetPointFromBearing({
        latitude = enemyUnit.latitude,
        longitude = enemyUnit.longitude,
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
        detectorId = elint_guid,
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

-- ============================================================================
-- State Management Functions
-- ============================================================================

---Update unit autodetectable state
---@param unit CMO__Unit unit object
---@param guid string unit GUID
---@param isAutodetectable boolean whether autodetectable
local function updateAutodetectableState(unit, guid, isAutodetectable)
  if unit.group then
    for _, v in ipairs(unit.group.unitlist) do
      GameApi.ScenEdit_SetUnit({ guid = v, autodetectable = isAutodetectable })
    end
  else
    GameApi.ScenEdit_SetUnit({ guid = guid, autodetectable = isAutodetectable })
  end
end

---Enhanced transmission data update
---@param config SBJ__CONFIG configuration object
---@param saveData SBJ__SaveData save data
---@param field string side field identifier
---@param unitData SBJ__FiringUnitContext|SBJ__C2Context unit data
---@param result SBJ__SIGINTResult SIGINT detection result
---@param unit CMO__Unit unit object
local function updateTransmissionData(config, saveData, field, unitData, result, unit)
  local transmission = saveData[field].SIGINT.transmissions[unitData.guid]

  if not transmission then
    local unitType = (string.find(unitData.name, 'ROCC') or string.find(unitData.name, 'TAAOC')) and 'C2' or 'mobile'
    transmission = {
      name = unitData.name,
      guid = unitData.guid,
      msg = unitData.msg,
      type = unitType,
      latitude = result.latitude,
      longitude = result.longitude,
      contacts = {},
      temp = 0,
      autodetectable = false,
      firstDetected = result.timestamp,
      lastDetected = result.timestamp,
      detectionCount = 0,
      confidence = result.confidence
    }
    saveData[field].SIGINT.transmissions[unitData.guid] = transmission
  end

  -- Update transmission data
  transmission.latitude = result.latitude
  transmission.longitude = result.longitude
  transmission.lastDetected = result.timestamp
  transmission.detectionCount = transmission.detectionCount + 1
  transmission.confidence = math.max(transmission.confidence, result.confidence)
  transmission.temp = transmission.temp + 1

  -- Check if should become autodetectable
  local maxCount = config[field].SIGINT.maxCount
  if transmission.temp > maxCount and not transmission.autodetectable then
    updateAutodetectableState(unit, unitData.guid, true)
    transmission.autodetectable = true
  end
end

---Enhanced undetected case handling
---@param config SBJ__CONFIG configuration object
---@param saveData SBJ__SaveData save data
---@param field string side field identifier
---@param unit CMO__Unit unit object
---@param unitData SBJ__FiringUnitContext|SBJ__C2Context unit data
local function handleUndetected(config, saveData, field, unit, unitData)
  local transmission = saveData[field].SIGINT.transmissions[unitData.guid]
  if not transmission then
    return
  end

  local maxCount = config[field].SIGINT.maxCount
  if transmission.temp > maxCount - 1 then
    transmission.temp = transmission.temp - 1
  end

  if transmission.autodetectable then
    updateAutodetectableState(unit, unitData.guid, false)
    transmission.autodetectable = false
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Enhanced SIGINT detection handler
---@param config SBJ__CONFIG configuration object
---@param saveData SBJ__SaveData save data
---@param side string side name
---@param units SBJ__FiringUnitContext[]|SBJ__C2Context[] unit list (mobile missile launchers)
---@param isShown boolean whether to show notification
---@param sigintConfig SBJ__SIGINTConfig|nil SIGINT-specific configuration
---@return table<string, SBJ__SIGINTResult> detection results by unit GUID
function SIGINT.handleSIGINT(config, saveData, side, units, isShown, sigintConfig)
  local sideConfig = getCachedSideConfig(side)
  local field, enemySide = sideConfig.field, sideConfig.enemySide
  local results = {}
  local processedCount = 0
  local detectedCount = 0

  for _, unitData in pairs(units) do
    -- Get actual unit
    local actualUnit = GameApi.ScenEdit_GetUnit(unitData.guid)
    if not actualUnit then
      goto continue
    end

    -- Skip some units randomly for performance
    if math.random() <= SIGINT_CONSTANTS.DETECTION_SKIP_PROBABILITY then
      goto continue
    end

    processedCount = processedCount + 1

    -- Check if unit is emitting
    local isEmitting, emissionReason = isUnitEmitting(config, actualUnit, unitData, enemySide)

    -- Perform SIGINT detection
    local result = getSIGINT(saveData, side, unitData.guid, unitData.msg,
      isEmitting, isShown, nil, sigintConfig)
    results[unitData.guid] = result

    -- Update transmission data based on result
    if result.isDetected then
      detectedCount = detectedCount + 1
      updateTransmissionData(config, saveData, field, unitData, result, actualUnit)
    else
      handleUndetected(config, saveData, field, actualUnit, unitData)
    end

    ::continue::
  end

  Logger.log(string.format("SIGINT processing: %d/%d units processed, %d detections",
    processedCount, Utils.getCount(units), detectedCount))

  return results
end

---Clear detection cache
function SIGINT.clearCache()
  sideConfigCache = {}
  detectionHistory = {}
end

---Get detection statistics
---@param saveData SBJ__SaveData save data
---@param side string side name
---@return table statistics detection statistics
function SIGINT.getDetectionStatistics(saveData, side)
  local sideConfig = getCachedSideConfig(side)
  local transmissions = saveData[sideConfig.field].SIGINT.transmissions

  local stats = {
    totalTransmissions = 0,
    autodetectableUnits = 0,
    averageDetections = 0,
    mostDetectedUnit = nil,
    maxDetections = 0
  }

  local totalDetections = 0

  for guid, transmission in pairs(transmissions) do
    stats.totalTransmissions = stats.totalTransmissions + 1
    totalDetections = totalDetections + (transmission.detectionCount or transmission.temp or 0)

    if transmission.autodetectable then
      stats.autodetectableUnits = stats.autodetectableUnits + 1
    end

    local detectionCount = transmission.detectionCount or transmission.temp or 0
    if detectionCount > stats.maxDetections then
      stats.maxDetections = detectionCount
      stats.mostDetectedUnit = transmission.name
    end
  end

  if stats.totalTransmissions > 0 then
    stats.averageDetections = totalDetections / stats.totalTransmissions
  end

  return stats
end

return SIGINT
