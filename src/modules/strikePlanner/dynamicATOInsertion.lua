local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")

local DynamicATOInsertion = {}

-- Time constants
local TIME_CONSTANTS = {
  ESCORT_ADVANCE_TIME = 20 * 60, -- Escort advance 20 minutes
  MISSION_DURATION = 40 * 60,    -- General mission duration 40 minutes
  TANKER_DURATION = 120 * 60,    -- Tanker mission duration 120 minutes
  TANKER_ADVANCE_TIME = 0 * 60,  -- Tanker advance 0 minutes
  ELAPSED_TIME = 30 * 60,
  MAX_SPEED = 470,
  MIN_SPEED = 430,
  TANKER_SPEED = 250,
  MAX_DISTANCE = 450,
  MAX_FLIGHT_TIME = 60 * 60
}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
local SUPPORT_ROLES = { "escort", "wildWeasel", "jammer", "tanker" }
local ALL_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker", "reconUAV" }


-- ============================================================================
-- Target Processing
-- ============================================================================

---Collect all currently assigned aircraft from active ATO waves
---Counts aircraft already assigned to missions across all active ATO waves to prevent over-allocation
---@param saveData SBJ__SaveData The persistent save data containing ATO wave information
---@return table<string, integer> # Map of base GUID to assigned aircraft count
local function collectAssignedAircraft(saveData)
  local assignedAircraft = {}

  if not saveData.c.air.airTaskingOrder then
    return assignedAircraft
  end

  for _, wave in pairs(saveData.c.air.airTaskingOrder) do
    if wave.isActivated and not wave.hasLaunched and wave.packages then
      for _, package in ipairs(wave.packages) do
        if not package.hasLaunched then
          for _, roleName in ipairs(PACKAGE_ROLES) do
            local role = package[roleName]
            if role and role.baseGUID then
              assignedAircraft[role.baseGUID] = (assignedAircraft[role.baseGUID] or 0) + (role.unitCount or 0)
            end
          end
        end
      end
    end
  end

  return assignedAircraft
end

---Get available aircraft count at a specific base for a specific unit type
---Counts embarked aircraft matching the required DBID that are not assigned to missions
---@param baseGUID string The GUID of the air base to check
---@param requiredUnitDBID number The required aircraft unit database ID (DBID) to filter by
---@return integer # Number of available unassigned aircraft of the specified type
local function getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
  local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)
  if not baseUnit then
    return 0
  end

  if not baseUnit.embarkedUnits or not baseUnit.embarkedUnits.Aircraft then
    return 0
  end

  local availableCount = 0
  for _, aircraftGUID in ipairs(baseUnit.embarkedUnits.Aircraft) do
    local aircraft = GameApi.ScenEdit_GetUnit(aircraftGUID)
    if aircraft and aircraft.dbid == requiredUnitDBID then
      if aircraft.mission == "" or aircraft.mission == nil then
        availableCount = availableCount + 1
      end
    end
  end

  return availableCount
end

---Validate aircraft availability for a role, resolving baseGUID via fallback candidates
---Iterates roleData.baseGUID then roleData.baseGUIDCandidates in order; picks the first base with
---enough unassigned aircraft of unitDBID. On success: rewrites roleData.baseGUID to the chosen GUID
---(downstream sees a single string) and increments assignedAircraft so later packages in the same
---wave deduct correctly.
---@param roleData SBJ__MissionDeploymentDescriptor Role configuration; mutated in place on success
---@param roleName string Role name for error messages (e.g., "striker", "escort", "SEAD")
---@param packageIndex integer Package index for error messages
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count; mutated on success
---@return boolean success true if a base with sufficient aircraft was found
---@return string|nil errorMessage Error message listing all attempted bases on failure, nil on success
local function validateAircraftRole(roleData, roleName, packageIndex, assignedAircraft)
  if not roleData then
    return true, nil
  end

  local requiredCount = roleData.unitCount or 0
  local requiredUnitDBID = roleData.unitDBID

  local candidates = { roleData.baseGUID }
  if roleData.baseGUIDCandidates then
    for _, guid in ipairs(roleData.baseGUIDCandidates) do
      table.insert(candidates, guid)
    end
  end

  local attempts = {}
  for _, baseGUID in ipairs(candidates) do
    local assignedCount = assignedAircraft[baseGUID] or 0
    local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
    if availableCount - assignedCount >= requiredCount / 2 then
      roleData.baseGUID = baseGUID
      assignedAircraft[baseGUID] = assignedCount +
          (availableCount - assignedCount >= requiredCount and requiredCount or availableCount - assignedCount)
      return true, nil
    end

    table.insert(attempts, string.format("%s:available=%d:assigned=%d",
      LogFormat.value(baseGUID), availableCount, assignedCount))
  end

  return false, string.format(
    "package=%d role=%s reason=insufficient_aircraft required=%d attempts=%s",
    packageIndex, LogFormat.value(roleName), requiredCount, table.concat(attempts, "|")
  )
end

---Check if individual package has sufficient targets and resources
---Validates both target count meets minimum requirements and all roles have available aircraft
---@param packageData SBJ__PackageTemplate Package configuration with target and role requirements
---@param packageTargets string[] Array of target GUIDs found for this package
---@param packageIndex integer Index of the package for logging
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count
---@return boolean success true if package is valid and can be executed
---@return string|nil reason Reason string (error message on failure, success message on pass)
local function validateIndividualPackage(packageData, packageTargets, packageIndex, assignedAircraft)
  -- Check target sufficiency
  local targetCount = #packageTargets
  local minTargetCount = 1

  if packageData.target and packageData.target.minTargetCount then
    minTargetCount = packageData.target.minTargetCount
  end

  if targetCount < minTargetCount then
    return false, string.format("package=%d reason=insufficient_targets targets=%d required=%d",
      packageIndex, targetCount, minTargetCount)
  end

  for _, role in ipairs(PACKAGE_ROLES) do
    local isValid, errorMessage = validateAircraftRole(packageData[role], role, packageIndex, assignedAircraft)
    if not isValid then
      return false, errorMessage
    end
  end

  return true, string.format("package=%d status=valid", packageIndex)
end


---Process ATO template with integrated validation - single pass through packages
---Processes all packages in wave template, finding targets and validating resources in one pass
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param isFirstWave boolean Whether this is the first wave (affects BDA assessment)
---@return SBJ__PackageTemplate[] validPackages Array of validated packages with assigned targets
---@return string statusSummary Human-readable summary of validation results
local function processATOTemplateWithValidation(config, saveData, contacts, waveTemplate, isFirstWave)
  local copyPackages = Utils.deepCopy(waveTemplate.packages)
  local validPackages = {}
  local assignedAircraft = collectAssignedAircraft(saveData)
  local totalTargets = 0
  local skippedReasons = {}

  for packageIndex, packageData in ipairs(copyPackages) do
    local strikeTargets = TargetingProcess.processTargets(config, saveData, contacts, packageData.target, isFirstWave)
    local isValid, reason = validateIndividualPackage(packageData, strikeTargets, packageIndex, assignedAircraft)

    if isValid then
      if packageData.target then
        packageData.target.list = strikeTargets
      end
      table.insert(validPackages, packageData)
      totalTargets = totalTargets + #strikeTargets
    else
      table.insert(skippedReasons, reason)
    end
  end

  local summary = string.format("packagesValid=%d packagesTotal=%d targets=%d packagesSkipped=%d",
    #validPackages, #copyPackages, totalTargets, #skippedReasons)

  return validPackages, summary
end

-- ============================================================================
-- Flight Time Calculation
-- ============================================================================

---Get the operational reference point for a role's mission zone
---Reads patrolZone first (patrol-type missions), falls back to zone (support-type missions like jammer/tanker)
---@param packageData SBJ__PackageTemplate Package configuration containing role mission parameters
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return CMO__Location|nil # Zone reference point coordinates or nil if unavailable
local function getPatrolZonePoint(packageData, role)
  local missionRole = packageData[role]
  local opts = missionRole and missionRole.missionCreationParams and missionRole.missionCreationParams.opts
  if not opts then
    return nil
  end

  local zone = opts.patrolZone or opts.zone
  if not zone or #zone == 0 then
    return nil
  end

  local point = GameApi.ScenEdit_GetReferencePoint({ side = constants.SIDES.ENEMY, name = zone[1] })
  if not point then
    return nil
  end

  return { latitude = point.latitude, longitude = point.longitude }
end

---Calculate flight time in seconds from distance in nautical miles
---@param distance number Distance in nautical miles
---@param role? string Role name; "tanker" uses tanker cruise speed, others use fighter speed
---@return integer # Flight time in seconds, rounded up
local function calculateFlightTimeFromDistance(distance, role)
  local speed
  if role == "tanker" then
    speed = TIME_CONSTANTS.TANKER_SPEED
  elseif distance >= TIME_CONSTANTS.MAX_DISTANCE then
    speed = TIME_CONSTANTS.MIN_SPEED
  else
    speed = TIME_CONSTANTS.MAX_SPEED
  end
  return math.ceil((distance / speed) * 3600)
end

---Compute flight time from a role's base to its operational zone
---@param packageData SBJ__PackageTemplate Package configuration containing role data
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return integer|nil # Flight time in seconds, or nil if role/base/zone/distance unavailable
local function computeRoleFlightTime(packageData, role)
  ---@type SBJ__MissionDeploymentDescriptor|nil
  local missionRole = packageData[role]
  if not missionRole or not missionRole.baseGUID then
    return nil
  end

  local targetPoint = getPatrolZonePoint(packageData, role)
  if not targetPoint then
    return nil
  end

  local distance = GameApi.Tool_Range(missionRole.baseGUID, targetPoint)
  if not distance or distance <= 0 then
    return nil
  end

  return calculateFlightTimeFromDistance(distance, role)
end

---Calculate advance time for a specific role based on distance to its operational zone
---@param packageData SBJ__PackageTemplate Package configuration containing role data and patrol zone
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return integer # Flight time in seconds, or ESCORT_ADVANCE_TIME as fallback
local function calculateRoleAdvanceTime(packageData, role)
  return computeRoleFlightTime(packageData, role) or TIME_CONSTANTS.ESCORT_ADVANCE_TIME
end

---Calculate support advance time as the longest support role flight time
---Each role uses its own zone and speed (tanker uses zone + 250kt, others use patrolZone + fighter speed)
---@param packageData SBJ__PackageTemplate Package configuration containing all support roles
---@return integer # Longest flight time in seconds, or ESCORT_ADVANCE_TIME if no role is computable
local function calculateSupportAdvanceTime(packageData)
  local maxFlightTime = 0

  for _, role in ipairs(SUPPORT_ROLES) do
    local flightTime = computeRoleFlightTime(packageData, role)
    if flightTime and flightTime > maxFlightTime then
      maxFlightTime = flightTime
    end
  end

  if maxFlightTime == 0 then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  return maxFlightTime
end

---Calculate striker flight time to target accounting for weapon range
---@param packageData SBJ__PackageTemplate Package data containing striker baseGUID, weaponDBID, and target list
---@return integer # Flight time in seconds from base to weapon release point
local function calculateStrikerFlightTime(packageData)
  if not packageData.striker or not packageData.striker.baseGUID or
      not packageData.target or not packageData.target.list or #packageData.target.list == 0 then
    return TIME_CONSTANTS.MISSION_DURATION
  end

  local range = GameApi.ScenEdit_QueryDB("weapon", packageData.striker.weaponDBID).ranges.land.max
  local distance = GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1]) - range

  if not distance or distance <= 0 then
    return TIME_CONSTANTS.MISSION_DURATION
  end

  return calculateFlightTimeFromDistance(distance)
end

-- ============================================================================
-- Package Timing
-- ============================================================================

---Calculate mission timing for a package
---Determines striker start and end times based on support advance time and strike intervals
---@param packageData SBJ__PackageTemplate Package configuration with role and timing information
---@param packageIndex integer Index of the package (1-based)
---@param previousPackage SBJ__PackageTemplate|nil Previous package for sequential timing, nil for first package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return {strikerStart: string, strikerEnd: string} # Table with striker start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculatePackageTiming(packageData, packageIndex, previousPackage, strikeInterval)
  local timing = {}

  -- Calculate striker timing
  if not packageData.striker.startTime then
    if packageIndex == 1 then
      -- Check if there are support roles
      local hasSupportRoles = packageData.escort or packageData.wildWeasel or packageData.jammer
      local advanceTime = 0

      if hasSupportRoles then
        advanceTime = calculateSupportAdvanceTime(packageData)
      end

      local delayTime = advanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0
      local startTime = GameApi.ScenEdit_CurrentTime() + advanceTime - delayTime + (packageData.timeToReady or (5 * 60))
      timing.strikerStart = os.date("!%Y-%m-%d %H:%M:%S", startTime) --[[@as string]]
    else
      if previousPackage and previousPackage.striker.startTime then
        local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
        timing.strikerStart = os.date("!%Y-%m-%d %H:%M:%S", previousStartTime + strikeInterval) --[[@as string]]
      end
    end
  else
    -- Use existing startTime
    timing.strikerStart = packageData.striker.startTime
  end

  -- Calculate striker end time
  local strikerStartTime = Utils.parseDatetimeToTimestamp(timing.strikerStart)
  local missionDuration = packageData.tanker and TIME_CONSTANTS.TANKER_DURATION or TIME_CONSTANTS.MISSION_DURATION
  local endTime = strikerStartTime + missionDuration
  timing.strikerEnd = os.date("!%Y-%m-%d %H:%M:%S", endTime) --[[@as string]]
  return timing
end


---Calculate support role timing (escort, wildWeasel, jammer, tanker)
---Computes when support aircraft should launch to arrive before striker
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@param packageData SBJ__PackageTemplate Package data containing striker timing and role configurations
---@return {startTime: string, endTime: string, timeOnStation: string|nil} # Table with start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculateRoleTiming(role, packageData)
  local strikerTimestamp = Utils.parseDatetimeToTimestamp(packageData.striker.startTime)
  local timing = {}

  -- Calculate start time based on role
  local advanceTime = calculateRoleAdvanceTime(packageData, role)
  local maxAdvanceTime = calculateSupportAdvanceTime(packageData)
  -- Setting delay time based on max advance time and role
  local delayTime = maxAdvanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0
  local startTime = strikerTimestamp - (role == "tanker" and maxAdvanceTime or advanceTime) + delayTime +
      (packageData.timeToReady or (5 * 60))
  timing.startTime = os.date("!%Y-%m-%d %H:%M:%S", startTime) --[[@as string]]
  local strikerFlightTime = calculateStrikerFlightTime(packageData)
  local duration = maxAdvanceTime + strikerFlightTime + 10 * 60
  local endTime = role == "tanker" and (startTime + duration - TIME_CONSTANTS.ELAPSED_TIME) or startTime + duration
  timing.endTime = os.date("%Y-%m-%d %H:%M:%S", endTime)
  return timing
end

---Create a single package with proper timing
---Converts package template to executable package with calculated timings for all roles
---@param packageData SBJ__PackageTemplate Package template configuration
---@param packageIndex integer Index of the package (1-based)
---@param previousPackage SBJ__PackageTemplate|nil Previous package for sequential timing, nil for first package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return SBJ__Package # Executable package with complete timing and loadout status
local function createPackageWithTiming(packageData, packageIndex, previousPackage, strikeInterval)
  -- Calculate main timing
  local timing = calculatePackageTiming(packageData, packageIndex, previousPackage, strikeInterval)

  -- Set striker timing
  if not packageData.striker.startTime then
    packageData.striker.startTime = timing.strikerStart
  end
  if not packageData.striker.endTime then
    packageData.striker.endTime = timing.strikerEnd
  end

  -- Set support role timing
  for _, role in ipairs(SUPPORT_ROLES) do
    local missionRole = packageData[role]

    if not missionRole then
      goto continue
    end

    if not missionRole.startTime or not missionRole.endTime then
      local roleTiming = calculateRoleTiming(role, packageData)
      missionRole.startTime = missionRole.startTime or roleTiming.startTime
      missionRole.endTime = missionRole.endTime or roleTiming.endTime

      if roleTiming.timeOnStation then
        missionRole.timeOnStation = roleTiming.timeOnStation
      end
    end

    ::continue::
  end

  -- Create package structure
  ---@type SBJ__Package
  return {
    timeToReady = packageData.timeToReady or (5 * 60),
    loadoutStatus = {
      isLoadoutInitiated = false,
      loadoutInitiatedTime = nil,
      expectedReadyTime = nil,
      loadoutStartTime = nil
    },
    hasLaunched = false,
    striker = packageData.striker,
    escort = packageData.escort,
    wildWeasel = packageData.wildWeasel,
    jammer = packageData.jammer,
    tanker = packageData.tanker,
    reconUAV = packageData.reconUAV,
    target = packageData.target
  }
end

-- ============================================================================
-- Wave Construction
-- ============================================================================

---Build ATO wave structure from template and validated packages
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param waveName string Generated unique wave name
---@return SBJ__Wave wave Wave structure with all packages and timing applied
---@return string[] timingLogEntries Package timing log entries
local function buildATOWave(waveTemplate, waveName)
  ---@type SBJ__Wave
  local newWave = {
    name = waveName,
    isActivated = true,
    isFirstWave = waveTemplate.isFirstWave or false,
    hasLaunched = false,
    strikeInterval = waveTemplate.strikeInterval or 0,
    packages = {}
  }

  local previousPackage = nil
  local timingLogEntries = {}

  for packageIndex, packageData in ipairs(waveTemplate.packages) do
    local newPackage = createPackageWithTiming(
      packageData,
      packageIndex,
      previousPackage,
      waveTemplate.strikeInterval or 0
    )
    table.insert(newWave.packages, newPackage)

    -- Record each role's timing for batched output by the public API.
    for _, role in ipairs(ALL_ROLES) do
      local roleData = newPackage[role]
      if roleData then
        table.insert(timingLogEntries, LogFormat.entry("OK", string.format(
          "wave=%s package=%d role=%s startTime=%q endTime=%q",
          LogFormat.value(waveName),
          packageIndex,
          LogFormat.value(role),
          tostring(roleData.startTime or "unknown"),
          tostring(roleData.endTime or "unknown"))))
      end
    end

    previousPackage = packageData
  end

  return newWave, timingLogEntries
end

---Insert ATO wave into saveData and register as generated operation
---@param saveData SBJ__SaveData Persistent save data to insert wave into
---@param wave SBJ__Wave Complete wave structure ready for insertion
---@return boolean # True if wave was successfully inserted
local function insertWave(saveData, wave)
  saveData.c.air.airTaskingOrder[wave.name] = wave
  DynamicOperationsUtils.registerGeneratedOperation("air", wave.name, saveData)
  return true
end

---Build and insert ATO wave into saveData
---@param saveData SBJ__SaveData Persistent save data to insert wave into
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param operationBatchType string Reconnaissance type identifier used for wave naming
---@return boolean success True if wave was successfully inserted, false on failure
---@return string|nil waveName Generated wave name when available
---@return string[] timingLogEntries Package timing log entries
local function insertATOWave(saveData, waveTemplate, operationBatchType)
  if not saveData.c.air.airTaskingOrder then
    return false, nil, {}
  end

  local waveName = DynamicOperationsUtils.generateUniqueAirOperationName(waveTemplate.name, operationBatchType, saveData)
  local wave, timingLogEntries = buildATOWave(waveTemplate, waveName)
  return insertWave(saveData, wave), waveName, timingLogEntries
end

-- ============================================================================
-- Recon Schedule Orchestration
-- ============================================================================

---Check whether recon trigger time is reached for processing
---@param reconEntry SBJ__ReconTriggeredOperationBatch Reconnaissance-triggered operation batch
---@return boolean # True when current time is at or past trigger time
local function isReconTriggered(reconEntry)
  local scheduledTimestamp = Utils.parseDatetimeToTimestamp(reconEntry.time)
  if reconEntry.delay then
    scheduledTimestamp = scheduledTimestamp + reconEntry.delay
  end
  return GameUtils.isAfterStartTime(scheduledTimestamp)
end

---Convert an internal reason code to a log-safe snake_case value
---@param reason? string Internal reason code
---@return string # Log-safe reason value
local function formatReason(reason)
  return LogFormat.value(string.lower(reason or "unknown"))
end

---Process single air operation: evaluate targets, validate packages, insert ATO wave
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param reconEntry SBJ__ReconTriggeredOperationBatch Operation batch triggering this operation
---@param operation SBJ__Operation Air operation containing wave template
---@return boolean success True if ATO wave was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string|nil statusSummary Package validation summary
---@return table|nil details Additional operation details for logging
local function processAirOperation(config, saveData, contacts, reconEntry, operation)
  if not operation.template then
    return false, "MISSING_TEMPLATE", nil, nil
  end

  local validPackages, statusSummary = processATOTemplateWithValidation(
    config, saveData, contacts, operation.template, operation.template.isFirstWave
  )

  if #validPackages == 0 then
    return false, "NO_VALID_PACKAGES", statusSummary, nil
  end

  local modifiedTemplate = Utils.deepCopy(operation.template)
  modifiedTemplate.packages = validPackages

  local success, waveName, timingLogEntries = insertATOWave(saveData, modifiedTemplate, reconEntry.type)
  if not success then
    return false, "INSERTION_FAILED", statusSummary, {
      waveName = waveName,
      timingLogEntries = timingLogEntries or {}
    }
  end

  return true, nil, statusSummary, {
    waveName = waveName,
    timingLogEntries = timingLogEntries or {}
  }
end

-- ============================================================================
-- Public API
-- ============================================================================

---Main processing function for Dynamic ATO Insertion
---Entry point for dynamic ATO system, validates configuration and processes air operations
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data with dynamic operations configuration
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@return boolean # True if any air operation was processed and executed, false if disabled or none ready
function DynamicATOInsertion.process(config, saveData, contacts)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.enabled then
    return false
  end

  saveData.c.dynamicOperations.lastEvaluationTime = GameApi.ScenEdit_CurrentTime()

  local reconTriggeredOperations = saveData.c.dynamicOperations.reconTriggeredOperations
  if not reconTriggeredOperations or #reconTriggeredOperations == 0 then
    return false
  end

  local airOperations = DynamicOperationsUtils.filterOperationsByType(reconTriggeredOperations, "air")
  if #airOperations == 0 then
    return false
  end

  local hasExecutedAny = false
  local processedResults = {}

  for _, item in ipairs(airOperations) do
    local operationBatch = item.operationBatch
    local operation = item.operation

    if isReconTriggered(operationBatch) then
      local operationName = (operation.template and operation.template.name) or "unknown"
      local success, reason, statusSummary, details = processAirOperation(config, saveData, contacts, operationBatch,
        operation)

      if reason ~= "MISSING_TEMPLATE" then
        DynamicOperationsUtils.markOperationExecuted(operationBatch, operation, true)
      end

      if success then
        hasExecutedAny = true
      end

      table.insert(processedResults, {
        operationName = operationName,
        operationBatchTime = operationBatch.time,
        operationBatchType = operationBatch.type,
        success = success,
        reason = reason,
        statusSummary = statusSummary,
        waveName = details and details.waveName or nil,
        timingLogEntries = details and details.timingLogEntries or nil
      })
    end
  end

  if #processedResults > 0 then
    local infoLines = {}
    local errorLines = {}
    local timingLines = {}

    for _, r in ipairs(processedResults) do
      if r.success then
        table.insert(infoLines, LogFormat.entry("OK", string.format(
          "operation=%s operationBatchTime=%q operationBatchType=%s wave=%s %s",
          LogFormat.value(r.operationName),
          r.operationBatchTime,
          LogFormat.value(r.operationBatchType),
          LogFormat.value(r.waveName),
          r.statusSummary or "status=none")))
      elseif r.reason == "NO_VALID_PACKAGES" then
        table.insert(infoLines, LogFormat.entry("SKIP", string.format(
          "operation=%s operationBatchTime=%q operationBatchType=%s reason=no_valid_packages %s",
          LogFormat.value(r.operationName),
          r.operationBatchTime,
          LogFormat.value(r.operationBatchType),
          r.statusSummary or "status=none")))
      elseif r.reason == "MISSING_TEMPLATE" then
        table.insert(errorLines, LogFormat.entry("ERROR", string.format(
          "operation=%s operationBatchTime=%q operationBatchType=%s reason=missing_wave_template",
          LogFormat.value(r.operationName),
          r.operationBatchTime,
          LogFormat.value(r.operationBatchType))))
      else
        table.insert(errorLines, LogFormat.entry("FAIL", string.format(
          "operation=%s operationBatchTime=%q operationBatchType=%s reason=%s %s",
          LogFormat.value(r.operationName),
          r.operationBatchTime,
          LogFormat.value(r.operationBatchType),
          formatReason(r.reason),
          r.statusSummary or "status=none")))
      end

      if r.timingLogEntries then
        for _, entry in ipairs(r.timingLogEntries) do
          table.insert(timingLines, entry)
        end
      end
    end

    if #infoLines > 0 then
      Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary(
        "scope", "dynamicAirOperations", "Process operations", infoLines))
    end

    if #timingLines > 0 then
      Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary(
        "scope", "dynamicAirTiming", "Build ATO wave timing", timingLines))
    end

    if #errorLines > 0 then
      Logger.error(LogFormat.summary(
        "scope", "dynamicAirOperations", "Process operations", errorLines))
    end
  end

  return hasExecutedAny
end

return DynamicATOInsertion
