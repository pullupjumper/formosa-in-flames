local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local LogFormat = require("src.utils.logFormat")
local DynamicPlan = require("src.modules.strikePlanner.dynamicPlan")
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local PackageTiming = require("src.modules.strikePlanner.packageTiming")
local constants = require("src.core.constants")

local AtoBuilder = {}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
---@cast PACKAGE_ROLES SBJ__RoleKey[]

-- Scope and action values shared by every summary this module emits
local LOG_SCOPE = "dynamicAirOperations"
local LOG_ACTION = "Process operations"
local TIMING_LOG_SCOPE = "dynamicAirTiming"
local TIMING_LOG_ACTION = "Build ATO wave timing"

-- Failure reasons, written straight into reason=<token>. NO_VALID_PACKAGES also
-- drives the retry decision OperationBatch makes, so a log line is always
-- greppable back to the branch that produced it.
local PROCESS_REASON = {
  MISSING_TEMPLATE = "missing_wave_template",
  NO_VALID_PACKAGES = "no_valid_packages",
  INSERTION_FAILED = "insertion_failed"
}

-- Reasons that keep an operation pending for a later tick inside the window.
local RETRYABLE_REASON = {
  [PROCESS_REASON.NO_VALID_PACKAGES] = true
}

-- ============================================================================
-- Target Processing
-- ============================================================================

---Build the reservation ledger key pairing one base with one airframe type
---Keyed per (base, DBID) so booking a base's fighters cannot hide its tankers.
---@param baseGUID string GUID of the air base
---@param unitDBID number|nil Aircraft unit database ID
---@return string # Ledger key
local function buildReservationKey(baseGUID, unitDBID)
  return baseGUID .. "#" .. tostring(unitDBID)
end

---Accumulate reserved aircraft counts for a single package's roles
---@param packageData SBJ__Package The package whose roles are counted
---@param reservedAircraftMap table<string, integer> Map of reservation key to reserved count; mutated in place
local function addPackageAircraft(packageData, reservedAircraftMap)
  for _, role in ipairs(PACKAGE_ROLES) do
    local roleData = packageData[role]

    if roleData then
      local key = buildReservationKey(roleData.baseGUID, roleData.unitDBID)
      reservedAircraftMap[key] = (reservedAircraftMap[key] or 0) + (roleData.unitCount or 0)
    end
  end
end

---Accumulate reserved aircraft counts for the not-yet-launched packages of a wave
---@param wave SBJ__Wave The active ATO wave to inspect
---@param reservedAircraftMap table<string, integer> Map of reservation key to reserved count; mutated in place
local function addWaveAircraft(wave, reservedAircraftMap)
  for _, packageData in ipairs(wave.packages) do
    if not packageData.hasLaunched then
      addPackageAircraft(packageData, reservedAircraftMap)
    end
  end
end

---Collect the aircraft already committed by active ATO waves
---Counts them so a new wave cannot book the same airframes twice.
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@return table<string, integer> # Map of reservation key to reserved aircraft count
local function collectReservedAircraft(plannerState)
  local reservedAircraftMap = {}

  for _, wave in pairs(plannerState.air.airTaskingOrder) do
    if wave.isActivated and not wave.hasLaunched then
      addWaveAircraft(wave, reservedAircraftMap)
    end
  end

  return reservedAircraftMap
end

---Read one base's mission-free aircraft, counted per unit DBID
---One sweep answers every role, instead of re-reading the list once per DBID.
---@param baseGUID string The GUID of the air base to read
---@return table<number, integer> # Mission-free aircraft count keyed by unit DBID
local function getBaseFreeAircraft(baseGUID)
  local freeByDBID = {}

  local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)
  if not baseUnit or not baseUnit.embarkedUnits or not baseUnit.embarkedUnits.Aircraft then
    return freeByDBID
  end

  for _, aircraftGUID in ipairs(baseUnit.embarkedUnits.Aircraft) do
    local aircraft = GameApi.ScenEdit_GetUnit(aircraftGUID)

    -- dbid is guarded because it becomes a table key here; the equality check it
    -- replaced tolerated a nil the way an index never would.
    if aircraft and aircraft.dbid and (aircraft.mission == "" or aircraft.mission == nil) then
      freeByDBID[aircraft.dbid] = (freeByDBID[aircraft.dbid] or 0) + 1
    end
  end

  return freeByDBID
end

---Count the mission-free aircraft of one type at one base
---Reads each base once per pass; a base that cannot be resolved caches as empty.
---@param freeAircraftCache table<string, table<number, integer>> Pass-scoped free aircraft cache; mutated
---@param baseGUID string The GUID of the air base to check
---@param requiredUnitDBID number The required aircraft unit database ID (DBID) to filter by
---@return integer # Mission-free aircraft of that type, before this pass's reservations
local function getFreeAircraftCount(freeAircraftCache, baseGUID, requiredUnitDBID)
  local freeByDBID = freeAircraftCache[baseGUID]

  if not freeByDBID then
    freeByDBID = getBaseFreeAircraft(baseGUID)
    freeAircraftCache[baseGUID] = freeByDBID
  end

  return freeByDBID[requiredUnitDBID] or 0
end

---Validate aircraft availability and resolve baseGUID via fallback candidates
---Mutates roleData.baseGUID and context.reservedAircraft when a candidate clears the ratio.
---@param roleData SBJ__MissionDeploymentDescriptor Role configuration; mutated in place on success
---@param role SBJ__RoleKey Role name for error messages (e.g., "striker", "escort", "SEAD")
---@param packageIndex integer Package index for error messages
---@param context SBJ__AircraftValidationContext Aircraft validation state; mutated on success
---@return boolean success true if a base with sufficient aircraft was found
---@return table<string, any>|nil errorFields Log fields describing the best candidate on failure, nil on success
local function validateAircraftRole(roleData, role, packageIndex, context)
  if not roleData then
    return true, nil
  end

  local requiredCount = roleData.unitCount or 0
  local requiredUnitDBID = roleData.unitDBID
  local minimumCount = requiredCount * context.minimumStrengthRatio

  local candidates = { roleData.baseGUID }
  if roleData.baseGUIDCandidates then
    for _, guid in ipairs(roleData.baseGUIDCandidates) do
      table.insert(candidates, guid)
    end
  end

  local bestSpareCount = 0
  for _, baseGUID in ipairs(candidates) do
    local key = buildReservationKey(baseGUID, requiredUnitDBID)
    local reservedCount = context.reservedAircraft[key] or 0
    local freeAtBase = getFreeAircraftCount(context.freeAircraftCache, baseGUID, requiredUnitDBID)
    local spareCount = freeAtBase - reservedCount

    if spareCount >= minimumCount then
      local reserveCount = math.min(spareCount, requiredCount)

      roleData.baseGUID = baseGUID
      context.reservedAircraft[key] = reservedCount + reserveCount
      return true, nil
    end

    if spareCount > bestSpareCount then
      bestSpareCount = spareCount
    end
  end

  return false, {
    package = packageIndex,
    role = role,
    required = requiredCount,
    available = bestSpareCount,
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

  local missionParamsEntries, isSingle = TankerMission.normalizeCreationParams(tankerData.missionCreationParams)
  if isSingle then
    return true, nil
  end

  local missionCount = #missionParamsEntries
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
  for missionIndex, missionParams in ipairs(missionParamsEntries) do
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
---@param context SBJ__AircraftValidationContext Aircraft validation state; mutated on success
---@return boolean success true if package is valid and can be executed
---@return table<string, any>|nil errorFields Validation log fields, nil on success
local function validateIndividualPackage(packageData, packageIndex, context)
  local tankerValid, tankerError = validateTankerMissionConfig(packageData.tanker, packageIndex)
  if not tankerValid then
    return false, tankerError
  end

  local stagedReservations = Utils.deepCopy(context.reservedAircraft)
  local validationCtx = {
    reservedAircraft = stagedReservations,
    freeAircraftCache = context.freeAircraftCache,
    minimumStrengthRatio = context.minimumStrengthRatio
  }
  for _, role in ipairs(PACKAGE_ROLES) do
    local isValid, errorFields = validateAircraftRole(packageData[role], role, packageIndex, validationCtx)

    if not isValid then
      return false, errorFields
    end
  end

  for key, reservedCount in pairs(stagedReservations) do
    context.reservedAircraft[key] = reservedCount
  end

  return true, nil
end

-- ============================================================================
-- Package Assembly
-- ============================================================================

---Build executable package templates from evaluated targets and aircraft validation
---Mutates copied package templates with target lists and resolved baseGUID values.
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@param passCtx SBJ__AtoPassContext Pass-scoped state shared by every operation in this tick; free aircraft cache is mutated
---@return SBJ__PackageTemplate[] validPackages Array of validated packages with assigned targets
---@return table<string, any> fields Package counters for the operation row
---@return SBJ__LogResult[] details One row per package rejected by validation
local function buildExecutablePackages(plannerState, waveTemplate, targetsByPackageIndex, passCtx)
  local validPackages = {}
  local context = {
    reservedAircraft = collectReservedAircraft(plannerState),
    freeAircraftCache = passCtx.freeAircraftCache,
    minimumStrengthRatio = passCtx.config.red.air.minimumStrengthRatio
  }
  local totalTargets = 0
  local previousPackage = nil
  local details = {}

  for packageIndex, packageTemplate in ipairs(waveTemplate.packages) do
    local packageTargets = targetsByPackageIndex[packageIndex]

    if packageTargets then
      local isValid, errorFields = validateIndividualPackage(packageTemplate, packageIndex, context)

      if isValid then
        packageTemplate.target.list = packageTargets
        local builtPackage = PackageTiming.createPackageWithTiming(
          passCtx.config,
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
---reconUAV is excluded: PackageTiming never schedules it, so it would read unknown.
---@param wave SBJ__Wave Wave structure with calculated package timings
---@return SBJ__LogResult[] # One result per configured package role
local function collectWaveTimingResults(wave)
  local timingResults = {}

  for packageIndex, packageData in ipairs(wave.packages) do
    for _, role in ipairs(PACKAGE_ROLES) do
      local roleData = packageData[role]

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
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param params SBJ__WaveInsertParams Template, evaluated targets and recon type of the wave to insert
---@param passCtx SBJ__AtoPassContext Pass-scoped state shared by every operation in this tick; free aircraft cache is mutated
---@return SBJ__AirOperationProcessResult # Outcome of the wave insertion attempt
local function createAndInsertATOWaveFromTemplate(plannerState, params, passCtx)
  local waveTemplate = params.waveTemplate
  local validPackages, fields, details = buildExecutablePackages(
    plannerState,
    waveTemplate,
    params.targetsByPackageIndex,
    passCtx
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

  -- Naming, insertion and registration happen in one call, so the generated name can
  -- never go unregistered.
  local wave
  local waveName = DynamicPlan.add(plannerState, {
    operationType = "air",
    templateName = waveTemplate.name,
    reconType = params.reconType,
    buildPlan = function(planName)
      wave = buildATOWave(waveTemplate, planName, validPackages)
      return wave
    end
  })
  fields.wave = waveName
  return { success = true, tag = "OK", fields = fields, details = details, timing = collectWaveTimingResults(wave) }
end

-- ============================================================================
-- Recon Schedule Orchestration
-- ============================================================================

---Process single air operation: evaluate targets, validate packages, insert ATO wave
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param batchedOp SBJ__BatchedOperation Air operation paired with its parent batch
---@param passCtx SBJ__AtoPassContext Pass-scoped state shared by every operation in this tick
---@return SBJ__AirOperationProcessResult # Outcome of the wave insertion attempt
local function processAirOperation(plannerState, batchedOp, passCtx)
  local operationBatch = batchedOp.operationBatch
  local operation = batchedOp.operation

  local targetsByPackageIndex, qualifiedCount = DynamicPlan.evaluateTargets(passCtx.config, plannerState, {
    contacts = passCtx.contacts,
    operationType = "air",
    template = operation.template
  })

  if qualifiedCount == 0 then
    return {
      success = false,
      tag = "SKIP",
      reason = PROCESS_REASON.NO_VALID_PACKAGES,
      fields = { packages = string.format("0/%d", #operation.template.packages), targets = 0 }
    }
  end

  -- Copied behind the target gate: the build writes resolved targets and baseGUIDs
  -- into the packages, and a retrying tick should not pay for a copy it discards.
  local waveTemplate = Utils.deepCopy(operation.template)
  return createAndInsertATOWaveFromTemplate(plannerState, {
    waveTemplate = waveTemplate,
    targetsByPackageIndex = targetsByPackageIndex,
    reconType = operationBatch.type
  }, passCtx)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Main processing function for Dynamic ATO Insertion
---OperationBatch drives the observation window; this module only answers whether a
---wave can be inserted right now. Retryable operations stay pending inside the
---window; expiry drops them.
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@return boolean # True if any air operation was processed and executed, false if disabled or none ready
function AtoBuilder.build(config, plannerState, contacts)
  if not plannerState.dynamicOperations.enabled then
    return false
  end

  -- Must stay a local: base counts only hold still within one pass, so a module-level
  -- table would keep counting aircraft destroyed or committed since an earlier tick.
  ---@type SBJ__AtoPassContext
  local passCtx = {
    config = config,
    contacts = contacts,
    freeAircraftCache = {}
  }

  local result = OperationBatch.process(plannerState.dynamicOperations.reconTriggeredOperationBatches, "air", {
    currentTime = GameApi.ScenEdit_CurrentTime(),
    windowSec = config.red.recon.observationWindowSec,
    retryableReasonSet = RETRYABLE_REASON,
    tryInsert = function(batchedOp)
      return processAirOperation(plannerState, batchedOp, passCtx)
    end
  })

  local opReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, LOG_ACTION)
  local timingReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, TIMING_LOG_SCOPE, TIMING_LOG_ACTION)

  for _, entry in ipairs(result.entries) do
    local outcome = entry.outcome --[[@as SBJ__AirOperationProcessResult]]
    opReport.add(entry.tag, entry.fields, outcome.details)
    timingReport.addAll(outcome.timing)
  end

  opReport.emit()
  timingReport.emit()
  return result.hasExecutedAny
end

return AtoBuilder
