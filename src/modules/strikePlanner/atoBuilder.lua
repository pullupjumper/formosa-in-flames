local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local PackageTiming = require("src.modules.strikePlanner.packageTiming")
local constants = require("src.core.constants")

local AtoBuilder = {}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
local ALL_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker", "reconUAV" }

-- Scope and action values shared by every summary this module emits
local LOG_SCOPE = "dynamicAirOperations"
local LOG_ACTION = "Process operations"
local TIMING_LOG_SCOPE = "dynamicAirTiming"
local TIMING_LOG_ACTION = "Build ATO wave timing"

-- Failure reasons, written straight into reason=<token>. The same string also
-- drives control flow in AtoBuilder.process, so a log line is always greppable
-- back to the branch that produced it.
local PROCESS_REASON = {
  MISSING_TEMPLATE = "missing_wave_template",
  NO_VALID_PACKAGES = "no_valid_packages",
  INSERTION_FAILED = "insertion_failed"
}

-- ============================================================================
-- Target Processing
-- ============================================================================

---Accumulate assigned aircraft counts for a single package's roles
---@param packageData SBJ__Package The package whose roles are counted
---@param assignedAircraft table<string, integer> Map of base GUID to assigned count; mutated in place
local function accumulatePackageAircraft(packageData, assignedAircraft)
  for _, role in ipairs(PACKAGE_ROLES) do
    local roleData = packageData[role] --[[@as SBJ__MissionDeploymentDescriptor]]

    if roleData then
      assignedAircraft[roleData.baseGUID] = (assignedAircraft[roleData.baseGUID] or 0) + (roleData.unitCount or 0)
    end
  end
end

---Accumulate assigned aircraft counts for the not-yet-launched packages of a wave
---@param wave SBJ__Wave The active ATO wave to inspect
---@param assignedAircraft table<string, integer> Map of base GUID to assigned count; mutated in place
local function accumulateWaveAircraft(wave, assignedAircraft)
  for _, packageData in ipairs(wave.packages) do
    if not packageData.hasLaunched then
      accumulatePackageAircraft(packageData, assignedAircraft)
    end
  end
end

---Collect all currently assigned aircraft from active ATO waves
---Counts aircraft already assigned to missions across all active ATO waves to prevent over-allocation
---@param saveData SBJ__SaveData The persistent save data containing ATO wave information
---@return table<string, integer> # Map of base GUID to assigned aircraft count
local function collectAssignedAircraft(saveData)
  local assignedAircraft = {}

  for _, wave in pairs(saveData.c.air.airTaskingOrder) do
    if wave.isActivated and not wave.hasLaunched then
      accumulateWaveAircraft(wave, assignedAircraft)
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

---Validate aircraft availability and resolve baseGUID via fallback candidates
---Mutates roleData.baseGUID and assignedAircraft when a candidate reaches half-strength.
---@param roleData SBJ__MissionDeploymentDescriptor Role configuration; mutated in place on success
---@param role string Role name for error messages (e.g., "striker", "escort", "SEAD")
---@param packageIndex integer Package index for error messages
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count; mutated on success
---@return boolean success true if a base with sufficient aircraft was found
---@return table<string, any>|nil errorFields Log fields describing the best candidate on failure, nil on success
local function validateAircraftRole(roleData, role, packageIndex, assignedAircraft)
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

  -- Best free count across every candidate; enough to explain the rejection
  -- without embedding a per-base list inside one field value.
  local bestAvailable = 0
  for _, baseGUID in ipairs(candidates) do
    local assignedCount = assignedAircraft[baseGUID] or 0
    local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
    local freeCount = availableCount - assignedCount

    if freeCount >= requiredCount / 2 then
      roleData.baseGUID = baseGUID
      assignedAircraft[baseGUID] = assignedCount + (freeCount >= requiredCount and requiredCount or freeCount)
      return true, nil
    end

    if freeCount > bestAvailable then
      bestAvailable = freeCount
    end
  end

  return false, {
    package = packageIndex,
    role = role,
    required = requiredCount,
    available = bestAvailable,
    bases = #candidates,
    reason = "insufficient_aircraft"
  }
end

---Validate multi-mission tanker configuration
---@param tankerData SBJ__TankerMissionDeploymentDescriptor|nil Tanker role configuration
---@param packageIndex integer Package index for error messages
---@return boolean success True when tanker mission configuration is valid
---@return table<string, any>|nil errorFields Validation log fields, nil on success
local function validateTankerMissionConfig(tankerData, packageIndex)
  if not tankerData or not tankerData.missionCreationParams then
    return true, nil
  end

  local missionParamsList, isSingle = TankerMission.normalizeCreationParams(tankerData.missionCreationParams)
  if isSingle then
    return true, nil
  end

  local missionCount = #missionParamsList
  local context = { package = packageIndex, role = "tanker" }

  if missionCount == 0 then
    return false, LogFormat.merge(context, { reason = "empty_tanker_missions" })
  end

  local unitCount = tankerData.unitCount or 0
  if unitCount <= 0 or unitCount % missionCount ~= 0 then
    return false, LogFormat.merge(context, {
      unitCount = unitCount,
      missions = missionCount,
      reason = "indivisible_tanker_unit_count"
    })
  end

  local missionNames = {}
  for missionIndex, missionParams in ipairs(missionParamsList) do
    if type(missionParams.name) ~= "string" or missionParams.name == "" then
      return false, LogFormat.merge(context, {
        mission = missionIndex,
        reason = "invalid_tanker_mission_name"
      })
    end

    if missionNames[missionParams.name] then
      return false, LogFormat.merge(context, {
        mission = missionParams.name,
        reason = "duplicate_tanker_mission_name"
      })
    end

    missionNames[missionParams.name] = true
  end

  return true, nil
end

---Check whether one package has sufficient aircraft resources
---Commits staged aircraft reservations only when every configured role passes.
---@param packageData SBJ__PackageTemplate Package configuration with target and role requirements
---@param packageIndex integer Index of the package for logging
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count
---@return boolean success true if package is valid and can be executed
---@return table<string, any>|nil errorFields Validation log fields, nil on success
local function validateIndividualPackage(packageData, packageIndex, assignedAircraft)
  local tankerValid, tankerError = validateTankerMissionConfig(packageData.tanker, packageIndex)
  if not tankerValid then
    return false, tankerError
  end

  local stagedAssignedAircraft = Utils.deepCopy(assignedAircraft)
  for _, role in ipairs(PACKAGE_ROLES) do
    local isValid, errorFields = validateAircraftRole(
      packageData[role],
      role,
      packageIndex,
      stagedAssignedAircraft
    )

    if not isValid then
      return false, errorFields
    end
  end

  for baseGUID, assignedCount in pairs(stagedAssignedAircraft) do
    assignedAircraft[baseGUID] = assignedCount
  end

  return true, nil
end

---Evaluate targets for all packages in a wave template
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@return table<integer, string[]> # Evaluated targets grouped by package index
local function evaluateTargetsFromTemplate(config, saveData, contacts, waveTemplate)
  local targetsByPackageIndex = {}

  for packageIndex, packageData in ipairs(waveTemplate.packages) do
    local packageTargets = TargetingProcess.processTargets(
      config,
      saveData,
      contacts,
      packageData.target,
      waveTemplate.isFirstWave
    )
    packageTargets = packageTargets or {}
    local targetCount = #packageTargets
    local requiredCount = packageData.target and packageData.target.minTargetCount or 1

    if targetCount >= requiredCount then
      targetsByPackageIndex[packageIndex] = packageTargets
    end
  end

  return targetsByPackageIndex
end

-- ============================================================================
-- Package Assembly
-- ============================================================================

---Build executable package templates from evaluated targets and aircraft validation
---Mutates copied package templates with target lists and resolved baseGUID values.
---@param config SBJ__Config Global configuration
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@return SBJ__PackageTemplate[] validPackages Array of validated packages with assigned targets
---@return table<string, any> fields Package counters for the operation row
---@return SBJ__LogResult[] details One row per package rejected by validation
local function buildExecutablePackages(config, saveData, waveTemplate, targetsByPackageIndex)
  local validPackages = {}
  local assignedAircraft = collectAssignedAircraft(saveData)
  local totalTargets = 0
  local previousPackage = nil
  local details = {}

  for packageIndex, packageTemplate in ipairs(waveTemplate.packages) do
    local packageTargets = targetsByPackageIndex[packageIndex]

    if packageTargets then
      local isValid, errorFields = validateIndividualPackage(packageTemplate, packageIndex, assignedAircraft)

      if isValid then
        packageTemplate.target.list = packageTargets
        local builtPackage = PackageTiming.createPackageWithTiming(
          config,
          packageTemplate,
          previousPackage,
          waveTemplate.strikeInterval
        )
        table.insert(validPackages, builtPackage)
        previousPackage = builtPackage
        totalTargets = totalTargets + #packageTargets
      elseif errorFields then
        table.insert(details, { tag = "SKIP", fields = errorFields })
      end
    end
  end

  local fields = {
    packages = string.format("%d/%d", #validPackages, #waveTemplate.packages),
    targets = totalTargets
  }

  return validPackages, fields, details
end

-- ============================================================================
-- Wave Construction
-- ============================================================================

---Build ATO wave structure from template and validated packages
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param waveName string Generated unique wave name
---@param packages SBJ__Package[] Validated packages to insert into the wave
---@return SBJ__Wave # Wave structure with all packages and timing applied
local function buildATOWave(waveTemplate, waveName, packages)
  return {
    name = waveName,
    isActivated = true,
    isFirstWave = waveTemplate.isFirstWave,
    hasLaunched = false,
    strikeInterval = waveTemplate.strikeInterval,
    packages = packages
  }
end

---Collect package role timing results for the consolidated timing summary
---@param wave SBJ__Wave Wave structure with calculated package timings
---@return SBJ__LogResult[] # One result per configured package role
local function collectWaveTimingResults(wave)
  local timingResults = {}

  for packageIndex, packageData in ipairs(wave.packages) do
    for _, role in ipairs(ALL_ROLES) do
      local roleData = packageData[role] --[[@as SBJ__MissionDeploymentDescriptor]]

      if roleData then
        table.insert(timingResults, {
          tag = "OK",
          fields = {
            wave = wave.name,
            package = packageIndex,
            role = role,
            startTime = roleData.startTime or "unknown",
            timeOnStation = roleData.timeOnStation or "unknown",
            endTime = roleData.endTime or "unknown"
          }
        })
      end
    end
  end

  return timingResults
end

---Create actual ATO wave from template and evaluation results
---Constructs executable packages, calculates timing, and inserts the wave.
---@param config SBJ__Config Global configuration
---@param saveData SBJ__SaveData Persistent save data for ATO insertion
---@param waveTemplate SBJ__WaveTemplate Template defining ATO wave and package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@param reconType string Reconnaissance type identifier used for wave naming
---@return SBJ__AirOperationProcessResult # Outcome of the wave insertion attempt
local function createAndInsertATOWaveFromTemplate(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    reconType)
  local validPackages, fields, details = buildExecutablePackages(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex
  )

  if #validPackages == 0 then
    return {
      success = false,
      tag = "SKIP",
      reason = PROCESS_REASON.NO_VALID_PACKAGES,
      fields = fields,
      details = details
    }
  end

  local waveName = DynamicState.generateUniqueAirOperationName(waveTemplate.name, reconType, saveData)
  local wave = buildATOWave(waveTemplate, waveName, validPackages)

  saveData.c.air.airTaskingOrder[wave.name] = wave
  DynamicState.registerGeneratedOperation("air", wave.name, saveData)

  fields.wave = waveName

  return {
    success = true,
    tag = "OK",
    fields = fields,
    details = details,
    timing = collectWaveTimingResults(wave)
  }
end

-- ============================================================================
-- Recon Schedule Orchestration
-- ============================================================================

---Check whether recon trigger time is reached for processing
---@param operationBatch SBJ__ReconTriggeredOperationBatch Reconnaissance-triggered operation batch
---@return boolean # True when current time is at or past trigger time
local function isReconTriggered(operationBatch)
  local scheduledTimestamp = Utils.parseDatetimeToTimestamp(operationBatch.time)

  if operationBatch.delay then
    scheduledTimestamp = scheduledTimestamp + operationBatch.delay
  end

  return GameUtils.isAfterStartTime(scheduledTimestamp)
end

---Process single air operation: evaluate targets, validate packages, insert ATO wave
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param batchedOp SBJ__BatchedOperation Air operation paired with its parent batch
---@return SBJ__AirOperationProcessResult # Outcome of the wave insertion attempt
local function processAirOperation(config, saveData, contacts, batchedOp)
  local operationBatch = batchedOp.operationBatch
  local operation = batchedOp.operation

  if not operation.template then
    return { success = false, tag = "ERROR", reason = PROCESS_REASON.MISSING_TEMPLATE }
  end

  if not saveData.c.air.airTaskingOrder then
    return { success = false, tag = "FAIL", reason = PROCESS_REASON.INSERTION_FAILED }
  end

  local waveTemplate = Utils.deepCopy(operation.template)
  local targetsByPackageIndex = evaluateTargetsFromTemplate(
    config,
    saveData,
    contacts,
    operation.template
  )

  if not next(targetsByPackageIndex) then
    return {
      success = false,
      tag = "SKIP",
      reason = PROCESS_REASON.NO_VALID_PACKAGES,
      fields = { packages = string.format("0/%d", #waveTemplate.packages), targets = 0 }
    }
  end

  return createAndInsertATOWaveFromTemplate(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    operationBatch.type
  )
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
function AtoBuilder.process(config, saveData, contacts)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.enabled then
    return false
  end

  saveData.c.dynamicOperations.lastEvaluationTime = GameApi.ScenEdit_CurrentTime()

  local reconTriggeredOperationBatches = saveData.c.dynamicOperations.reconTriggeredOperationBatches
  if not reconTriggeredOperationBatches or #reconTriggeredOperationBatches == 0 then
    return false
  end

  local airBatchedOperations = DynamicState.filterOperationsByType(reconTriggeredOperationBatches, "air")
  if #airBatchedOperations == 0 then
    return false
  end

  local opReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, LOG_ACTION)
  local timingReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, TIMING_LOG_SCOPE, TIMING_LOG_ACTION)
  local hasExecutedAny = false

  for _, batchedOp in ipairs(airBatchedOperations) do
    local operationBatch = batchedOp.operationBatch
    local operation = batchedOp.operation

    if isReconTriggered(operationBatch) then
      local outcome = processAirOperation(config, saveData, contacts, batchedOp)

      if outcome.reason ~= PROCESS_REASON.MISSING_TEMPLATE then
        DynamicState.markOperationExecuted(operationBatch, operation, true)
      end

      hasExecutedAny = hasExecutedAny or outcome.success

      local fields = LogFormat.merge({
        operation = (operation.template and operation.template.name) or "unknown",
        batch = operationBatch.type .. "@" .. operationBatch.time
      }, outcome.fields)
      fields.reason = outcome.reason

      opReport.add(outcome.tag, fields, outcome.details)
      timingReport.addAll(outcome.timing)
    end
  end

  opReport.emit()
  timingReport.emit()
  return hasExecutedAny
end

return AtoBuilder
