local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")

local Sigint = {}


-- ============================================================================
-- Enumerations & Constants
-- ============================================================================

local UNIT_TYPE = {
  C2     = "C2",
  MOBILE = "mobile",
}

local DETECTION_STATUS = {
  DETECTED     = "detected",
  NOT_EMITTING = "not_emitting",
  SKIPPED      = "skipped",
  NOT_FOUND    = "not_found",
  AUTO_ENABLED = "auto_enabled",
  DECAYED      = "decayed",
  NO_CHANGE    = "no_change",
}

local SIGINT_RESULT_TAGS = {
  [DETECTION_STATUS.DETECTED]     = "OK",
  [DETECTION_STATUS.NOT_EMITTING] = "SKIP",
  [DETECTION_STATUS.SKIPPED]      = "SKIP",
  [DETECTION_STATUS.NOT_FOUND]    = "FAIL",
  [DETECTION_STATUS.AUTO_ENABLED] = "OK",
  [DETECTION_STATUS.DECAYED]      = "OK",
  [DETECTION_STATUS.NO_CHANGE]    = "OK",
}



-- ============================================================================
-- Detection Probability
-- ============================================================================

---Calculate signal deviation distance for SIGINT detection position randomization
---Uses complex formula to simulate signal triangulation error based on distance
---@param baseDistance number Base distance between detector and target (nautical miles)
---@param config SBJ__SIGINTConfig|nil
---@return number # Distance from actual position (nautical miles)
local function calculateSignalDeviation(baseDistance, config)
  config = config or {}
  local consts = config.formulaConstants or {}
  local randomFactor = consts.randomFactor or 120

  local baseCoeff = consts.baseCoefficient or 0.00007937
  local powerDivisor = consts.powerDivisor or (10 ^ 6.1)
  local randomDivisor = consts.randomDivisor or 1500000
  local randomPowerDivisor = consts.randomPowerDivisor or (10 ^ 5)
  local distancePower = consts.distancePower or 2.25
  local distanceDivisor = consts.distanceDivisor or (10 ^ 2.4)

  local baseDeviation = (baseCoeff * (baseDistance ^ 3.8518)) / powerDivisor
  local randomDeviation = ((math.random(-randomFactor * baseDistance, randomFactor * baseDistance) ^ 2) / randomDivisor) /
      randomPowerDivisor * ((baseDistance ^ distancePower) / distanceDivisor)

  return baseDeviation + randomDeviation
end

---Calculate SIGINT detection probability based on distance
---Uses exponential decay model: P(x) = e^(-k*x^p) where k=1/450, p=0.8
---@internal Exposed for testing
---@param distance number Distance in nautical miles
---@param config SBJ__SIGINTConfig|nil
---@return number # Value between 0 and 1
local function calculateDetectionProbability(distance, config)
  config = config or {}
  local threshold = config.detectionThreshold or 60
  local maxRange = config.maxDetectionRangeNm or { 300, 340 }
  local formulaConstants = config.formulaConstants or {}
  local decayRate = formulaConstants.decayRate or (-1 / 450)
  local power = formulaConstants.power or 0.8

  if distance <= threshold then
    return 1.0
  elseif distance >= math.random(maxRange[1], maxRange[2]) then
    return 0.0
  else
    return math.exp(decayRate * (distance ^ power))
  end
end

-- ============================================================================
-- Emission Status Check
-- ============================================================================

---Classify unit type based on context name
---@param unitStateName string
---@return string # UNIT_TYPE enum value
local function resolveUnitType(unitStateName)
  if string.find(unitStateName, "ROCC") or string.find(unitStateName, "TAAOC") then
    return UNIT_TYPE.C2
  end
  return UNIT_TYPE.MOBILE
end

---Check if unit is emitting signal with enhanced logic
---@param config SBJ__Config
---@param unit CMO__Unit
---@param unitState SBJ__FiringUnitState|SBJ__C2State Unit data (Battery units check movement, C2 units always emit)
---@param enemySide string
---@return boolean isEmitting Whether unit is emitting signal
---@return string reason Reason for emission status
local function isUnitEmitting(config, unit, unitState, enemySide)
  -- Check for specific platform types that always emit
  if unit.dbid == constants.PLATFORMS.C2 then
    return true, "C2 (always emitting)"
  end

  if unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
    return true, "Control station (always emitting)"
  end

  -- Check for C2 facilities (always emit, no movement check needed as they are fixed buildings)
  for _, dbid in ipairs(config.red.iads.c2FacilityDBIDs) do
    if unit.dbid == dbid then
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
  if not unitState.operationalArea.RL[1].area or #unitState.operationalArea.RL[1].area == 0 then
    return false, "No RL area defined"
  end

  local lastCoursePoint = unit.course[courseCount]
  local isLeavingRL = not GameUtils.isInArea(enemySide, lastCoursePoint, unitState.operationalArea.RL[1].area) and
      unit.speed > 0
  return isLeavingRL, isLeavingRL and "Leaving real point" or "Within reload point"
end


-- ============================================================================
-- Signal Detection
-- ============================================================================

---Resolve actual unit from unit state
---@param unitState SBJ__FiringUnitState|SBJ__C2State
---@param enemySide string
---@return CMO__Unit|nil # Resolved unit or nil if not found
local function resolveUnit(unitState, enemySide)
  if unitState.weaponDBID then
    return GameApi.ScenEdit_GetUnit(unitState.name, enemySide)
  end
  return GameApi.ScenEdit_GetUnit(unitState.guid)
end

---Build undetected result object
---@return SBJ__SIGINTResult # Detection result with zeroed position
local function buildUndetectedResult()
  return {
    longitude = 0,
    latitude = 0,
    isDetected = false,
    confidence = 0,
    timestamp = GameApi.ScenEdit_CurrentTime()
  }
end

---Attempt SIGINT detection against an enemy unit using all airborne recon aircraft
---@param sigintState SBJ__SIGINTState
---@param enemyGUID string
---@param isEmitting boolean
---@param config SBJ__SIGINTConfig|nil
---@return SBJ__SIGINTResult # Detection result with position, confidence, and metadata
local function rollDetection(sigintState, enemyGUID, isEmitting, config)
  local enemy = GameApi.ScenEdit_GetUnit(enemyGUID)
  if not enemy then
    return buildUndetectedResult()
  end

  for _, ctx in pairs(sigintState.reconAircraft) do
    local actualReconAC = GameApi.ScenEdit_GetUnit(ctx.guid)
    if not actualReconAC or actualReconAC.condition ~= constants.UNIT_CONDITIONS.AIRBORNE then
      goto continue
    end

    local distance = GameApi.Tool_Range(enemy.guid, ctx.guid)
    if not distance then
      goto continue
    end

    local detectionProbability = calculateDetectionProbability(distance, config)

    if math.random() < detectionProbability and isEmitting then
      local deviation = calculateSignalDeviation(distance, config)
      local pos = GameApi.World_GetPointFromBearing({
        latitude = enemy.latitude,
        longitude = enemy.longitude,
        distance = deviation,
        bearing = math.random(0, 359)
      })

      if not pos then
        goto continue
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

  return buildUndetectedResult()
end

---Show detection notification on the map
---@param pos { latitude: number, longitude: number }
---@param notification string
---@param config SBJ__SIGINTConfig|nil
local function createDetectionNotification(pos, notification, config)
  config = config or {}
  local defaultDisplay = config.defaultDisplay or {}
  local displayConfig = {
    R = defaultDisplay.r or 255,
    G = defaultDisplay.g or 255,
    B = defaultDisplay.b or 255,
    lifeTime = defaultDisplay.lifeTime or 4,
    fontSize = defaultDisplay.fontSize or 16,
  }

  GameApi.ScenEdit_CreateBarkNotification_Geo(
    pos.longitude,
    pos.latitude,
    notification,
    displayConfig.R,
    displayConfig.G,
    displayConfig.B,
    true,
    true,
    displayConfig.lifeTime,
    displayConfig.fontSize
  )
end


-- ============================================================================
-- Transmission State Management
-- ============================================================================

---Update unit autodetectable state for SIGINT targets
---If unit is in a group, updates all group members; otherwise updates individual unit
---@param unit CMO__Unit
---@param isAutodetectable boolean
local function updateAutodetectableState(unit, isAutodetectable)
  if unit.group then
    for _, guid in ipairs(unit.group.unitlist) do
      GameApi.ScenEdit_SetUnit({ guid = guid, autodetectable = isAutodetectable })
    end
  else
    GameApi.ScenEdit_SetUnit({ guid = unit.guid, autodetectable = isAutodetectable })
  end
end

---Update or create transmission record after successful SIGINT detection
---Creates new transmission record if first detection, otherwise updates existing record
---Increments currentDetectionLevel and checks autodetectable threshold
---@param sigintState SBJ__SIGINTState
---@param unitState SBJ__FiringUnitState|SBJ__C2State
---@param hit SBJ__SIGINTHit Detected unit paired with its detection result
---@param maxCount integer Detection level above which the unit becomes autodetectable
---@return string # DETECTION_STATUS enum value
local function updateTransmissionData(sigintState, unitState, hit, maxCount)
  local unit, result = hit.unit, hit.result
  local transmission = sigintState.transmissions[unit.guid]

  if not transmission then
    local unitType = resolveUnitType(unitState.name)
    transmission = {
      name = unitState.name,
      guid = unit.guid,
      msg = unitState.msg,
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
    sigintState.transmissions[unit.guid] = transmission
  end

  transmission.latitude = result.latitude
  transmission.longitude = result.longitude
  transmission.lastDetected = result.timestamp
  transmission.detectionCount = transmission.detectionCount + 1
  transmission.confidence = math.max(transmission.confidence, result.confidence)
  transmission.currentDetectionLevel = transmission.currentDetectionLevel + 1

  if transmission.autodetectable then
    updateAutodetectableState(unit, false)
    transmission.autodetectable = false
  end

  -- Check if should become autodetectable
  if transmission.currentDetectionLevel > maxCount and not transmission.autodetectable then
    updateAutodetectableState(unit, true)
    transmission.autodetectable = true
    return DETECTION_STATUS.AUTO_ENABLED
  end

  return DETECTION_STATUS.DETECTED
end

---Handle undetected case for SIGINT target
---Decrements currentDetectionLevel when unit is not detected, simulating signal fade
---Resets autodetectable state to false if currently autodetectable
---@param sigintState SBJ__SIGINTState
---@param unit CMO__Unit Unit object that was not detected this cycle
---@param maxCount integer Detection level above which the unit becomes autodetectable
---@return string # DETECTION_STATUS enum value
local function processUndetected(sigintState, unit, maxCount)
  local transmission = sigintState.transmissions[unit.guid]
  if not transmission then
    return DETECTION_STATUS.NO_CHANGE
  end

  if transmission.currentDetectionLevel > maxCount - 1 then
    transmission.currentDetectionLevel = transmission.currentDetectionLevel - 1
  end

  if transmission.autodetectable then
    updateAutodetectableState(unit, false)
    transmission.autodetectable = false
    return DETECTION_STATUS.DECAYED
  end

  return DETECTION_STATUS.NO_CHANGE
end


-- ============================================================================
-- Public API
-- ============================================================================

---Enhanced SIGINT detection handler
---Monitors several unit state groups, consolidating results and log output
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param isShown boolean
---@return table<string, SBJ__SIGINTResult> # Detection results by unit GUID
local function collectSigint(config, saveData, sideName, isShown)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local sigintState = PersistentState.sigint(saveData, sideName)
  local sigintConfig = config[sideConfig.field].sigint
  local emitterGroups = PersistentState.sigintEmitters(saveData, sideName)
  local enemySide = sideConfig.enemySide

  local maxCount = sigintConfig.maxCount
  local detectionSkipProbability = sigintConfig.detectionSkipProbability or 0.3

  local resultMap = {}
  local report = LogFormat.report(constants.TAGS.SIGINT, "side=" .. sideName, "Collect SIGINT")
  local totalProcessed = 0
  local totalDetected = 0
  local totalUnits = 0

  for _, unitStateMap in ipairs(emitterGroups) do
    totalUnits = totalUnits + Utils.getCount(unitStateMap)

    for _, unitState in pairs(unitStateMap) do
      local ctxName = unitState.name or unitState.guid or "?"

      -- Resolve actual unit
      local actualUnit = resolveUnit(unitState, enemySide)
      if not actualUnit then
        report.add(SIGINT_RESULT_TAGS[DETECTION_STATUS.NOT_FOUND], { unit = ctxName, reason = "unit_not_found" })
        goto continue
      end

      -- Skip some units randomly for performance
      if math.random() <= detectionSkipProbability then
        report.add(SIGINT_RESULT_TAGS[DETECTION_STATUS.SKIPPED], { unit = ctxName, reason = "random_skip" })
        goto continue
      end

      totalProcessed = totalProcessed + 1

      local isEmitting, emissionReason = isUnitEmitting(config, actualUnit, unitState, enemySide)

      -- Perform SIGINT detection
      local result = rollDetection(sigintState, actualUnit.guid, isEmitting, sigintConfig)
      resultMap[actualUnit.guid] = result

      if result.isDetected then
        totalDetected = totalDetected + 1
        local status = updateTransmissionData(sigintState, unitState, { unit = actualUnit, result = result }, maxCount)
        report.add(SIGINT_RESULT_TAGS[status], { unit = ctxName, result = status })

        if isShown then
          createDetectionNotification(result, unitState.msg, sigintConfig)
        end
      else
        local status = processUndetected(sigintState, actualUnit, maxCount)
        report.add(SIGINT_RESULT_TAGS[status], {
          unit = ctxName,
          result = status,
          reason = emissionReason or "unknown"
        })
      end

      ::continue::
    end
  end

  report.emit({ processed = totalProcessed, units = totalUnits, detections = totalDetected })
  return resultMap
end

---Collect SIGINT for a collecting side when its SIGINT is enabled
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function Sigint.processSide(config, saveData, sideName)
  local sigintState = PersistentState.sigint(saveData, sideName)
  if not sigintState.enabled then
    return
  end

  collectSigint(config, saveData, sideName, true)
end

---Initialize reconnaissance aircraft states for SIGINT operations
---Scans all aircraft units for the specified side and registers RC-135V and Y-9DZ reconnaissance aircraft
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@return number # Number of reconnaissance aircraft initialized
function Sigint.initSide(config, saveData, sideName)
  local sigintState = PersistentState.sigint(saveData, sideName)
  local aircraftDefaults = config.red.commsJamming.aircraftDefaults
  local filteredUnits = GameApi.VP_GetSide({ side = sideName }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not sigintState.enabled then
    return 0
  end

  if not filteredUnits then
    Logger.warn(LogFormat.line("WARN", { side = sideName, reason = "no_aircraft_units" }))
    return 0
  end

  local initializedCount = 0
  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == "Aircraft" and
        (unit.dbid == constants.PLATFORMS.RC135V or unit.dbid == constants.PLATFORMS.Y9DZ) then
      sigintState.reconAircraft[unit.guid] = {
        guid = unit.guid,
        OODA = unit.OODA,
        commsLevel = aircraftDefaults.commsLevel,
        commsBase = aircraftDefaults.commsBase,
        commsThreshold = aircraftDefaults.commsThreshold,
        outofcomms = aircraftDefaults.outOfComms,
      }
      initializedCount = initializedCount + 1
    end
  end

  Logger.log(constants.TAGS.SIGINT, LogFormat.line("OK", {
    side = sideName,
    action = "init_recon_aircraft",
    count = initializedCount
  }))
  return initializedCount
end

return Sigint
