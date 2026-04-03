local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

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
  [DETECTION_STATUS.DETECTED]     = "[OK]",
  [DETECTION_STATUS.NOT_EMITTING] = "[SKIP]",
  [DETECTION_STATUS.SKIPPED]      = "[SKIP]",
  [DETECTION_STATUS.NOT_FOUND]    = "[FAIL]",
  [DETECTION_STATUS.AUTO_ENABLED] = "[OK]",
  [DETECTION_STATUS.DECAYED]      = "[OK]",
  [DETECTION_STATUS.NO_CHANGE]    = "[OK]",
}



-- ============================================================================
-- Detection Probability
-- ============================================================================

---Calculate signal deviation distance for SIGINT detection position randomization
---Uses complex formula to simulate signal triangulation error based on distance
---@param baseDistance number Base distance between detector and target (nautical miles)
---@param config SBJ__SIGINTConfig|nil Detection configuration (optional overrides)
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
---@param config SBJ__SIGINTConfig|nil Detection configuration
---@return number # Value between 0 and 1
function Sigint.calculateDetectionProbability(distance, config)
  config = config or {}
  local threshold = config.detectionThreshold or 60
  local maxRange = config.maxDetectionRange or { 300, 340 }
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
---@param unitCtxName string Unit context name
---@return string # UNIT_TYPE enum value
local function classifyUnitType(unitCtxName)
  if string.find(unitCtxName, "ROCC") or string.find(unitCtxName, "TAAOC") then
    return UNIT_TYPE.C2
  end
  return UNIT_TYPE.MOBILE
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
    return true, "C2 (always emitting)"
  end

  if unit.dbid == constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION then
    return true, "Control station (always emitting)"
  end

  -- Check for C2 facilities (always emit, no movement check needed as they are fixed buildings)
  for _, dbid in ipairs(config.c.iads.c2FacilityDBIDs) do
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
  if not unitCtx.operationalArea.RL[1].area or #unitCtx.operationalArea.RL[1].area == 0 then
    return false, "No RL area defined"
  end

  local lastCoursePoint = unit.course[courseCount]
  local isLeavingRL = not GameUtils.isInArea(enemySide, lastCoursePoint, unitCtx.operationalArea.RL[1].area) and
      unit.speed > 0
  return isLeavingRL, isLeavingRL and "Leaving real point" or "Within reload point"
end


-- ============================================================================
-- Signal Detection
-- ============================================================================

---Resolve actual unit from unit context
---@param unitCtx SBJ__FiringUnitContext|SBJ__C2Context Unit context
---@param enemySide string Enemy side name
---@return CMO__Unit|nil # Resolved unit or nil if not found
local function resolveUnit(unitCtx, enemySide)
  if unitCtx.weaponDBID then
    return GameApi.ScenEdit_GetUnit(unitCtx.name, enemySide)
  end
  return GameApi.ScenEdit_GetUnit(unitCtx.guid)
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
---@param sigintContext SBJ__SIGINTContext SIGINT context containing reconnaissance aircraft
---@param enemyGUID string Enemy unit GUID to detect
---@param isEmitting boolean Whether target unit is currently emitting signals
---@param config SBJ__SIGINTConfig|nil Detection configuration (optional overrides for thresholds)
---@return SBJ__SIGINTResult # Detection result with position, confidence, and metadata
local function attemptDetection(sigintContext, enemyGUID, isEmitting, config)
  local enemy = GameApi.ScenEdit_GetUnit(enemyGUID)
  if not enemy then
    return buildUndetectedResult()
  end

  for _, ctx in pairs(sigintContext.reconAircraft) do
    local actualReconAC = GameApi.ScenEdit_GetUnit(ctx.guid)
    if not actualReconAC or actualReconAC.condition ~= constants.UNIT_CONDITIONS.AIRBORNE then
      goto continue
    end

    local distance = GameApi.Tool_Range(enemy.guid, ctx.guid)
    if not distance then
      goto continue
    end

    local detectionProbability = Sigint.calculateDetectionProbability(distance, config)

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
---@param pos { latitude: number, longitude: number } Position for notification
---@param notification string Notification message to display
---@param config SBJ__SIGINTConfig|nil Detection configuration
local function showDetectionNotification(pos, notification, config)
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
---@return string # DETECTION_STATUS enum value
local function updateTransmissionData(sigintContext, unitCtx, result, unit)
  local transmission = sigintContext.transmissions[unit.guid]

  if not transmission then
    local unitType = classifyUnitType(unitCtx.name)
    transmission = {
      name = unitCtx.name,
      guid = unit.guid,
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
    sigintContext.transmissions[unit.guid] = transmission
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
  end

  -- Check if should become autodetectable
  local maxCount = sigintContext.maxCount
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
---@param sigintContext SBJ__SIGINTContext SIGINT context containing transmission records
---@param unit CMO__Unit Unit object that was not detected this cycle
---@return string # DETECTION_STATUS enum value
local function handleUndetected(sigintContext, unit)
  local transmission = sigintContext.transmissions[unit.guid]
  if not transmission then
    return DETECTION_STATUS.NO_CHANGE
  end

  local maxCount = sigintContext.maxCount
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
---Accepts multiple unit context groups via varargs, consolidating results and log output
---@param config SBJ__Config Configuration object
---@param sigintContext SBJ__SIGINTContext SIGINT context
---@param sideName string Side name (used to determine enemy side for area checks)
---@param isShown boolean Whether to show detection notifications on map
---@param sigintConfig SBJ__SIGINTConfig|nil SIGINT-specific configuration (optional overrides)
---@param ... table<string, SBJ__FiringUnitContext|SBJ__C2Context> Unit context groups to monitor
---@return table<string, SBJ__SIGINTResult> # Detection results by unit GUID
function Sigint.collectSigint(config, sigintContext, sideName, isShown, sigintConfig, ...)
  local sideConfig = GameUtils.getCachedSideConfig(sideName)
  local enemySide = sideConfig.enemySide

  sigintConfig = sigintConfig or {}
  local detectionSkipProbability = sigintConfig.detectionSkipProbability or 0.3

  local results = {}
  local reportEntries = {}
  local totalProcessed = 0
  local totalDetected = 0
  local totalUnits = 0

  for _, unitContexts in ipairs({ ... }) do
    totalUnits = totalUnits + Utils.getCount(unitContexts)

    for _, unitCtx in pairs(unitContexts) do
      local ctxName = unitCtx.name or unitCtx.guid or "?"

      -- Resolve actual unit
      local actualUnit = resolveUnit(unitCtx, enemySide)
      if not actualUnit then
        table.insert(reportEntries,
          "  " .. SIGINT_RESULT_TAGS[DETECTION_STATUS.NOT_FOUND] .. " " .. ctxName .. " (not found)")
        goto continue
      end

      -- Skip some units randomly for performance
      if math.random() <= detectionSkipProbability then
        table.insert(reportEntries,
          "  " .. SIGINT_RESULT_TAGS[DETECTION_STATUS.SKIPPED] .. " " .. ctxName .. " (random skip)")
        goto continue
      end

      totalProcessed = totalProcessed + 1

      -- Check if unit is emitting
      local isEmitting, emissionReason = isUnitEmitting(config, actualUnit, unitCtx, enemySide)

      -- Perform SIGINT detection
      local result = attemptDetection(sigintContext, actualUnit.guid, isEmitting, sigintConfig)
      results[actualUnit.guid] = result

      -- Update transmission data based on result
      if result.isDetected then
        totalDetected = totalDetected + 1
        local status = updateTransmissionData(sigintContext, unitCtx, result, actualUnit)
        table.insert(reportEntries, "  " .. SIGINT_RESULT_TAGS[status] .. " " .. ctxName .. " (detected)")

        if isShown then
          showDetectionNotification(result, unitCtx.msg, sigintConfig)
        end
      else
        local status = handleUndetected(sigintContext, actualUnit)
        table.insert(reportEntries,
          "  " .. SIGINT_RESULT_TAGS[status] .. " " .. ctxName .. " (" .. (emissionReason or "unknown") .. ")")
      end

      ::continue::
    end
  end

  -- Build single batch log report
  local reportLines = {
    string.format("SIGINT: %d/%d units processed, %d detections",
      totalProcessed, totalUnits, totalDetected)
  }
  for _, entry in ipairs(reportEntries) do
    table.insert(reportLines, entry)
  end

  Logger.log(constants.TAGS.SIGINT, table.concat(reportLines, "\n"))
  return results
end

---Initialize reconnaissance aircraft contexts for SIGINT operations
---Scans all aircraft units for the specified side and registers RC-135V and Y-9DZ reconnaissance aircraft
---@param sigintContext SBJ__SIGINTContext SIGINT context to populate with recon aircraft
---@param sideName string Side name to scan for reconnaissance aircraft
---@param aircraftDefaults SBJ__AircraftCommsDefaults Aircraft communications default values
---@return number # Number of reconnaissance aircraft initialized
function Sigint.initReconAircraftContexts(sigintContext, sideName, aircraftDefaults)
  local filteredUnits = GameApi.VP_GetSide({ side = sideName }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    Logger.warn(string.format("No aircraft units found for side '%s'", sideName))
    return 0
  end

  local initializedCount = 0
  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and unit.type == "Aircraft" and
        (unit.dbid == constants.PLATFORMS.RC135V or unit.dbid == constants.PLATFORMS.Y9DZ) then
      sigintContext.reconAircraft[unit.guid] = {
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

  Logger.log(constants.TAGS.SIGINT,
    string.format("Initialized %d reconnaissance aircraft for %s SIGINT operations", initializedCount, sideName))
  return initializedCount
end

return Sigint
