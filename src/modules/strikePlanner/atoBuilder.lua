local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local constants = require("src.core.constants")

local AtoBuilder = {}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
local ALL_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker", "reconUAV" }

local PROCESS_REASON = {
  MISSING_TEMPLATE = "missing_template",
  NO_VALID_PACKAGES = "no_valid_packages",
  INSERTION_FAILED = "insertion_failed"
}

local OPERATION_OUTCOME = {
  OK = "ok",
  SKIP = "skip",
  MISSING_TEMPLATE = "missing_template",
  FAIL = "fail"
}

-- ============================================================================
-- Target Processing
-- ============================================================================

---Collect all currently assigned aircraft from active ATO waves
---Counts aircraft already assigned to missions across all active ATO waves to prevent over-allocation
---@param saveData SBJ__SaveData The persistent save data containing ATO wave information
---@return table<string, integer> # Map of base GUID to assigned aircraft count
local function collectAssignedAircraft(saveData)
  local assignedAircraft = {}

  for _, wave in pairs(saveData.c.air.airTaskingOrder) do
    if wave.isActivated and not wave.hasLaunched then
      for _, package in ipairs(wave.packages) do
        if not package.hasLaunched then
          for _, roleName in ipairs(PACKAGE_ROLES) do
            local role = package[roleName] --[[@as SBJ__MissionDeploymentDescriptor]]

            if role then
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

---Validate aircraft availability and resolve baseGUID via fallback candidates
---Mutates roleData.baseGUID and assignedAircraft when a candidate reaches half-strength.
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

    table.insert(attempts, string.format(
      "%s:available=%d:assigned=%d",
      LogFormat.value(baseGUID),
      availableCount,
      assignedCount
    ))
  end

  local msg = string.format(
    "package=%d role=%s reason=insufficient_aircraft required=%d attempts=%s",
    packageIndex,
    LogFormat.value(roleName),
    requiredCount,
    table.concat(attempts, "|")
  )
  return false, msg
end

---Validate multi-mission tanker configuration
---@param tankerData SBJ__TankerMissionDeploymentDescriptor|nil Tanker role configuration
---@param packageIndex integer Package index for error messages
---@return boolean success True when tanker mission configuration is valid
---@return string|nil errorMessage Validation error message, nil on success
local function validateTankerMissionConfig(tankerData, packageIndex)
  if not tankerData or not tankerData.missionCreationParams then
    return true, nil
  end

  local missionParamsList, isSingle = TankerMission.normalizeCreationParams(tankerData.missionCreationParams)
  if isSingle then
    return true, nil
  end

  local missionCount = #missionParamsList

  if missionCount == 0 then
    return false, string.format("package=%d role=tanker reason=empty_tanker_missions", packageIndex)
  end

  local unitCount = tankerData.unitCount or 0
  if unitCount <= 0 or unitCount % missionCount ~= 0 then
    return false, string.format(
      "package=%d role=tanker reason=indivisible_tanker_unit_count unitCount=%d missions=%d",
      packageIndex,
      unitCount,
      missionCount
    )
  end

  local missionNames = {}
  for missionIndex, missionParams in ipairs(missionParamsList) do
    if type(missionParams.name) ~= "string" or missionParams.name == "" then
      return false, string.format(
        "package=%d role=tanker reason=invalid_tanker_mission_name mission=%d",
        packageIndex,
        missionIndex
      )
    end

    if missionNames[missionParams.name] then
      return false, string.format(
        "package=%d role=tanker reason=duplicate_tanker_mission_name mission=%s",
        packageIndex,
        LogFormat.value(missionParams.name)
      )
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
---@return string|nil errorMessage Validation error message, nil on success
local function validateIndividualPackage(packageData, packageIndex, assignedAircraft)
  local tankerValid, tankerError = validateTankerMissionConfig(packageData.tanker, packageIndex)
  if not tankerValid then
    return false, tankerError
  end

  local stagedAssignedAircraft = Utils.deepCopy(assignedAircraft)
  for _, role in ipairs(PACKAGE_ROLES) do
    local isValid, errorMessage = validateAircraftRole(
      packageData[role],
      role,
      packageIndex,
      stagedAssignedAircraft
    )

    if not isValid then
      return false, errorMessage
    end
  end

  for baseGUID, assignedCount in pairs(stagedAssignedAircraft) do
    assignedAircraft[baseGUID] = assignedCount
  end

  return true, nil
end

---Format package validation counters into summary fields
---@param validPackageCount integer Number of packages accepted for execution
---@param totalPackageCount integer Total package templates evaluated
---@param totalTargets integer Total target count assigned to accepted packages
---@param skippedPackageCount integer Number of packages skipped by validation
---@return string # Package validation summary
local function formatPackageValidationSummary(validPackageCount, totalPackageCount, totalTargets, skippedPackageCount)
  return string.format(
    "packagesValid=%d packagesTotal=%d targets=%d packagesSkipped=%d",
    validPackageCount,
    totalPackageCount,
    totalTargets,
    skippedPackageCount
  )
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
-- Flight Time Calculation
-- ============================================================================

---Get the operational reference point for one mission zone
---Reads patrolZone first and falls back to zone
---@param missionCreationParams SBJ__MissionCreationParams Mission creation parameters
---@return CMO__Location|nil # Zone reference point coordinates or nil if unavailable
local function getMissionZonePoint(missionCreationParams)
  local opts = missionCreationParams and missionCreationParams.opts
  if not opts then
    return nil
  end

  local zone = opts.PatrolZone or opts.Zone
  if not zone or #zone == 0 then
    return nil
  end

  local point = GameApi.ScenEdit_GetReferencePoint({ side = constants.SIDES.ENEMY, name = zone[1] })
  if not point then
    return nil
  end

  return { latitude = point.latitude, longitude = point.longitude }
end

---Get normalized mission parameters for one role
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param role string Role name
---@return SBJ__MissionCreationParams[] # Mission parameter array
local function getRoleMissionCreationParams(missionRole, role)
  if role == "tanker" then
    local result = TankerMission.normalizeCreationParams(missionRole.missionCreationParams)
    return result
  end

  if not missionRole.missionCreationParams then
    return {}
  end

  return { missionRole.missionCreationParams }
end

---Calculate flight time in seconds from distance in nautical miles
---@param distance number Distance in nautical miles
---@param role? string Role name; "tanker" uses tanker cruise speed, others use fighter speed
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer # Flight time in seconds, rounded up
local function calculateFlightTimeFromDistance(distance, role, timingConfig)
  local speed = role == "tanker" and
      timingConfig.cruiseSpeed.tanker or
      timingConfig.cruiseSpeed.combatAircraft
  return math.ceil((distance / speed) * 3600)
end

---Estimate the longest flight time from a support role's base to its operational zones
---@param packageData SBJ__PackageTemplate Package configuration containing role data
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer|nil # Flight time in seconds, or nil if role/base/zone/distance unavailable
local function estimateSupportRoleFlightTime(packageData, role, timingConfig)
  ---@type SBJ__MissionDeploymentDescriptor|nil
  local missionRole = packageData[role]
  if not missionRole or not missionRole.baseGUID then
    return nil
  end

  local maxFlightTime = nil
  local missionParamsList = getRoleMissionCreationParams(missionRole, role)

  for _, missionCreationParams in ipairs(missionParamsList) do
    local targetPoint = getMissionZonePoint(missionCreationParams)

    if targetPoint then
      local distance = GameApi.Tool_Range(missionRole.baseGUID, targetPoint)

      if distance and distance > 0 then
        local flightTime = calculateFlightTimeFromDistance(distance, role, timingConfig)
        if not maxFlightTime or flightTime > maxFlightTime then
          maxFlightTime = flightTime
        end
      end
    end
  end

  return maxFlightTime
end

---Estimate striker flight time to the weapon release point
---@param packageData SBJ__PackageTemplate Package data containing striker baseGUID, weaponDBID, and target list
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer|nil # Flight time in seconds, or nil when required range data is unavailable
local function estimateStrikerFlightTime(packageData, timingConfig)
  if not packageData.striker or not packageData.striker.baseGUID or
      not packageData.striker.weaponDBID or
      not packageData.target or not packageData.target.list or #packageData.target.list == 0 then
    return nil
  end

  local weaponInfo = GameApi.ScenEdit_QueryDB("weapon", packageData.striker.weaponDBID)
  local weaponRange = tonumber(weaponInfo and weaponInfo.ranges and weaponInfo.ranges.land and weaponInfo.ranges.land
    .max)

  if not weaponRange then
    return nil
  end

  local targetRange = tonumber(GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1]))

  if not targetRange then
    return nil
  end

  local distance = targetRange - weaponRange

  if not distance or distance <= 0 then
    return nil
  end

  return calculateFlightTimeFromDistance(distance, nil, timingConfig)
end

-- ============================================================================
-- Package Timing
-- ============================================================================

---Add the configured safety margin to one flight-time estimate
---@param flightTime number Estimated flight time in seconds
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Conservative flight time in seconds
local function addFlightTimeSafetyMargin(flightTime, timingConfig)
  return flightTime + (timingConfig.flightTimeSafetyMargin or 0)
end

---Resolve conservative flight time for one package role
---@param packageData SBJ__PackageTemplate Package containing role and target data
---@param role string Package role name
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Conservative flight time in seconds
local function resolveRoleFlightTime(packageData, role, timingConfig)
  local estimatedFlightTime
  local fallbackFlightTime
  if role == "striker" then
    estimatedFlightTime = estimateStrikerFlightTime(packageData, timingConfig)
    fallbackFlightTime = timingConfig.unresolvedFlightTime.striker
  else
    estimatedFlightTime = estimateSupportRoleFlightTime(packageData, role, timingConfig)
    fallbackFlightTime = timingConfig.unresolvedFlightTime.support
  end

  return addFlightTimeSafetyMargin(estimatedFlightTime or fallbackFlightTime, timingConfig)
end

---Find one tanker mission configuration by mission name
---@param packageData SBJ__PackageTemplate Package containing tanker configuration
---@param missionName string Tanker mission name
---@return SBJ__MissionCreationParams|nil # Matching tanker mission parameters
local function findTankerMissionParams(packageData, missionName)
  if not packageData.tanker then
    return nil
  end

  local missionParamsList = getRoleMissionCreationParams(packageData.tanker, "tanker")
  for _, missionParams in ipairs(missionParamsList) do
    if missionParams.name == missionName then
      return missionParams
    end
  end

  return nil
end

---Calculate the earliest receiver arrival at any configured tanker zone
---@param packageData SBJ__PackageTemplate Package containing receiver and tanker missions
---@param roleTimings table<string, SBJ__RoleTiming> Calculated non-tanker role timings
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Earliest receiver arrival timestamp, or nil when unresolved
local function calculateEarliestReceiverArrival(packageData, roleTimings, timingConfig)
  local earliestArrival = nil

  for _, role in ipairs({ "striker", "escort", "wildWeasel", "jammer" }) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local receiver = packageData[role]
    local receiverTiming = roleTimings[role]
    local opts = receiver and receiver.missionCreationParams and receiver.missionCreationParams.opts

    if receiver and receiverTiming and opts and opts.TankerMissionList then
      for _, tankerMissionName in ipairs(opts.TankerMissionList) do
        local tankerMissionParams = findTankerMissionParams(packageData, tankerMissionName)
        local tankerZonePoint = tankerMissionParams and getMissionZonePoint(tankerMissionParams)

        if tankerZonePoint then
          local distance = GameApi.Tool_Range(receiver.baseGUID, tankerZonePoint)
          if distance and distance > 0 then
            local transitTime = calculateFlightTimeFromDistance(distance, role, timingConfig)
            local arrivalTime = receiverTiming.startTime + addFlightTimeSafetyMargin(transitTime, timingConfig)

            if not earliestArrival or arrivalTime < earliestArrival then
              earliestArrival = arrivalTime
            end
          end
        end
      end
    end
  end

  return earliestArrival
end

---Build one role timing from its planned on-station time
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param plannedTimeOnStation number Planned on-station timestamp
---@param flightTime number Conservative flight time in seconds
---@param duration number Mission duration in seconds
---@return SBJ__RoleTiming # Calculated role timing
local function buildRoleTiming(missionRole, plannedTimeOnStation, flightTime, duration)
  local usesTakeoffTime = missionRole.startTime ~= nil and missionRole.timeOnStation == nil
  local startTime = usesTakeoffTime and
      Utils.parseDatetimeToTimestamp(missionRole.startTime) or
      plannedTimeOnStation - flightTime
  local timeOnStation = nil
  if not usesTakeoffTime then
    timeOnStation = plannedTimeOnStation
  end

  return {
    startTime = startTime,
    timeOnStation = timeOnStation,
    endTime = (usesTakeoffTime and startTime or plannedTimeOnStation) + duration
  }
end

---Build role timings relative to one striker TOT anchor
---@param packageData SBJ__PackageTemplate Package configuration
---@param strikerTimeOnTarget number Striker TOT timestamp
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return table<string, SBJ__RoleTiming> # Role timings indexed by role name
local function buildRoleTimings(packageData, strikerTimeOnTarget, timingConfig)
  local roleTimings = {}
  local strikerDuration = packageData.tanker and
      timingConfig.missionDuration.tanker or
      timingConfig.missionDuration.standard

  roleTimings.striker = buildRoleTiming(
    packageData.striker,
    strikerTimeOnTarget,
    resolveRoleFlightTime(packageData, "striker", timingConfig),
    strikerDuration
  )

  for _, role in ipairs({ "escort", "wildWeasel", "jammer" }) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]
    if missionRole then
      local leadTime = timingConfig.supportLeadTime[role] or 0
      local timeOnStation = strikerTimeOnTarget - leadTime
      roleTimings[role] = buildRoleTiming(
        missionRole,
        timeOnStation,
        resolveRoleFlightTime(packageData, role, timingConfig),
        timingConfig.missionDuration.standard
      )
    end
  end

  if packageData.tanker then
    local earliestReceiverArrival = calculateEarliestReceiverArrival(packageData, roleTimings, timingConfig)
    local timeOnStation = earliestReceiverArrival and
        earliestReceiverArrival - timingConfig.tankerSetupTime or
        strikerTimeOnTarget - timingConfig.tankerUnresolvedArrivalLeadTime
    roleTimings.tanker = buildRoleTiming(
      packageData.tanker,
      timeOnStation,
      resolveRoleFlightTime(packageData, "tanker", timingConfig),
      timingConfig.missionDuration.tanker
    )
  end

  return roleTimings
end

---Shift all calculated package timings by one delta
---@param roleTimings table<string, SBJ__RoleTiming> Role timings indexed by role name
---@param delta number Shift amount in seconds
local function shiftRoleTimings(roleTimings, delta)
  if delta <= 0 then
    return
  end

  for _, timing in pairs(roleTimings) do
    timing.startTime = timing.startTime + delta
    timing.endTime = timing.endTime + delta
    if timing.timeOnStation then
      timing.timeOnStation = timing.timeOnStation + delta
    end
  end
end

---Get the earliest planned takeoff from calculated role timings
---@param roleTimings table<string, SBJ__RoleTiming> Role timings indexed by role name
---@return number # Earliest planned takeoff timestamp
local function getEarliestTakeoff(roleTimings)
  local earliestTakeoff = nil
  for _, timing in pairs(roleTimings) do
    if not earliestTakeoff or timing.startTime < earliestTakeoff then
      earliestTakeoff = timing.startTime
    end
  end

  return earliestTakeoff or GameApi.ScenEdit_CurrentTime()
end

---Infer the striker TOT represented by one package schedule
---@param packageData SBJ__PackageTemplate Package configuration
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Striker TOT timestamp, or nil when no schedule exists
local function inferStrikerTimeOnTarget(packageData, timingConfig)
  if packageData.striker.timeOnStation then
    return Utils.parseDatetimeToTimestamp(packageData.striker.timeOnStation)
  end

  if packageData.striker.startTime then
    return Utils.parseDatetimeToTimestamp(packageData.striker.startTime) +
        resolveRoleFlightTime(packageData, "striker", timingConfig)
  end

  return nil
end

---Resolve the striker TOT anchor implied by one package's scheduling mode
---@param packageData SBJ__PackageTemplate Package configuration
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Striker TOT anchor timestamp
local function resolveStrikerTimeOnTargetAnchor(packageData, timingConfig)
  return inferStrikerTimeOnTarget(packageData, timingConfig) or GameApi.ScenEdit_CurrentTime()
end

---Format and apply calculated role timing to a package descriptor
---@param missionRole SBJ__MissionDeploymentDescriptor Mission role to update
---@param timing SBJ__RoleTiming Calculated role timing
local function applyRoleTiming(missionRole, timing)
  missionRole.startTime = os.date(constants.DATE_FORMAT, timing.startTime) --[[@as string]]
  if timing.timeOnStation then
    missionRole.timeOnStation = os.date(constants.DATE_FORMAT, timing.timeOnStation) --[[@as string]]
  else
    missionRole.timeOnStation = nil
  end
  missionRole.endTime = os.date(constants.DATE_FORMAT, timing.endTime) --[[@as string]]
end

---Create a single package with proper timing
---Converts package template to executable package with calculated timings for all roles
---@param packageData SBJ__PackageTemplate Package template configuration
---@param config SBJ__Config Global configuration
---@param previousPackage SBJ__Package|nil Previous executable package for sequential timing, nil for first valid package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return SBJ__Package # Executable package with complete timing and loadout status
local function createPackageWithTiming(packageData, config, previousPackage, strikeInterval)
  local timingConfig = config.c.air.timing
  local strikerTimeOnTarget = resolveStrikerTimeOnTargetAnchor(packageData, timingConfig)
  local roleTimings = buildRoleTimings(packageData, strikerTimeOnTarget, timingConfig)
  local earliestAllowedTakeoff = GameApi.ScenEdit_CurrentTime() +
      packageData.timeToReady + timingConfig.assignmentSafetyMargin
  local readinessShift = earliestAllowedTakeoff - getEarliestTakeoff(roleTimings)
  local intervalShift = 0

  if previousPackage then
    local previousTimeOnTarget = inferStrikerTimeOnTarget(previousPackage, timingConfig)
    if previousTimeOnTarget then
      intervalShift = previousTimeOnTarget + strikeInterval - strikerTimeOnTarget
    end
  end

  local scheduleShift = math.max(0, readinessShift, intervalShift)
  shiftRoleTimings(roleTimings, scheduleShift)

  for _, role in ipairs(PACKAGE_ROLES) do
    local missionRole = packageData[role]
    if missionRole and roleTimings[role] then
      applyRoleTiming(missionRole, roleTimings[role])
    end
  end

  ---@cast packageData SBJ__Package
  packageData.loadoutStatus = {
    isLoadoutInitiated = false,
    loadoutInitiatedTime = nil,
    expectedReadyTime = nil,
    loadoutStartTime = nil
  }
  packageData.hasLaunched = false

  return packageData
end

---Build executable package templates from evaluated targets and aircraft validation
---Mutates copied package templates with target lists and resolved baseGUID values.
---@param config SBJ__Config Global configuration
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@return SBJ__PackageTemplate[] validPackages Array of validated packages with assigned targets
---@return string statusSummary Human-readable summary of validation results
local function buildExecutablePackages(config, saveData, waveTemplate, targetsByPackageIndex)
  local validPackages = {}
  local assignedAircraft = collectAssignedAircraft(saveData)
  local totalTargets = 0
  local previousPackage = nil
  local validationErrors = {}

  for packageIndex, packageTemplate in ipairs(waveTemplate.packages) do
    local strikeTargets = targetsByPackageIndex[packageIndex]

    if strikeTargets then
      local isValid, validationError = validateIndividualPackage(packageTemplate, packageIndex, assignedAircraft)

      if isValid then
        packageTemplate.target.list = strikeTargets
        local package = createPackageWithTiming(packageTemplate, config, previousPackage, waveTemplate.strikeInterval)
        table.insert(validPackages, package)
        previousPackage = package
        totalTargets = totalTargets + #strikeTargets
      elseif validationError then
        table.insert(validationErrors, validationError)
      end
    end
  end

  local summary = formatPackageValidationSummary(
    #validPackages,
    #waveTemplate.packages,
    totalTargets,
    #waveTemplate.packages - #validPackages
  )
  if #validationErrors > 0 then
    summary = summary .. " validationErrors=" .. table.concat(validationErrors, ";")
  end

  return validPackages, summary
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

---Collect package role timing entries for consolidated log output
---@param wave SBJ__Wave Wave structure with calculated package timings
---@return string[] # Package timing log entries
local function collectWaveTimingLogEntries(wave)
  local timingLogEntries = {}

  for packageIndex, packageData in ipairs(wave.packages) do
    for _, role in ipairs(ALL_ROLES) do
      local roleData = packageData[role] --[[@as SBJ__MissionDeploymentDescriptor]]

      if roleData then
        local msg = string.format(
          "wave=%s package=%d role=%s startTime=%q timeOnStation=%q endTime=%q",
          LogFormat.value(wave.name),
          packageIndex,
          LogFormat.value(role),
          roleData.startTime or "unknown",
          roleData.timeOnStation or "unknown",
          roleData.endTime or "unknown"
        )
        table.insert(timingLogEntries, LogFormat.entry("OK", msg))
      end
    end
  end

  return timingLogEntries
end

---Create actual ATO wave from template and evaluation results
---Constructs executable packages, calculates timing, and inserts the wave.
---@param config SBJ__Config Global configuration
---@param saveData SBJ__SaveData Persistent save data for ATO insertion
---@param waveTemplate SBJ__WaveTemplate Template defining ATO wave and package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@param reconType string Reconnaissance type identifier used for wave naming
---@return boolean success True if ATO wave was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string statusSummary Package validation summary
---@return {waveName: string, timingLogEntries: string[]}|nil details Additional operation details for logging
local function createAndInsertATOWaveFromTemplate(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    reconType)
  local validPackages, statusSummary = buildExecutablePackages(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex
  )

  if #validPackages == 0 then
    return false, PROCESS_REASON.NO_VALID_PACKAGES, statusSummary, nil
  end

  local waveName = DynamicState.generateUniqueAirOperationName(waveTemplate.name, reconType, saveData)
  local wave = buildATOWave(waveTemplate, waveName, validPackages)
  local timingLogEntries = collectWaveTimingLogEntries(wave)

  saveData.c.air.airTaskingOrder[wave.name] = wave
  DynamicState.registerGeneratedOperation("air", wave.name, saveData)

  return true, nil, statusSummary, { waveName = waveName, timingLogEntries = timingLogEntries }
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
    return false, PROCESS_REASON.MISSING_TEMPLATE, nil, nil
  end

  if not saveData.c.air.airTaskingOrder then
    return false, PROCESS_REASON.INSERTION_FAILED, nil, nil
  end

  local waveTemplate = Utils.deepCopy(operation.template)
  local targetsByPackageIndex = evaluateTargetsFromTemplate(
    config,
    saveData,
    contacts,
    operation.template
  )

  if not next(targetsByPackageIndex) then
    local totalPackageCount = #waveTemplate.packages
    local statusSummary = formatPackageValidationSummary(0, totalPackageCount, 0, totalPackageCount)
    return false, PROCESS_REASON.NO_VALID_PACKAGES, statusSummary, nil
  end

  return createAndInsertATOWaveFromTemplate(
    config,
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    reconEntry.type
  )
end

---Classify a processed air operation result into a log outcome
---@param success boolean Whether the operation inserted an ATO wave
---@param reason? string Process reason from PROCESS_REASON
---@return string # Operation outcome from OPERATION_OUTCOME
local function classifyOperationOutcome(success, reason)
  if success then
    return OPERATION_OUTCOME.OK
  end

  if reason == PROCESS_REASON.NO_VALID_PACKAGES then
    return OPERATION_OUTCOME.SKIP
  end

  if reason == PROCESS_REASON.MISSING_TEMPLATE then
    return OPERATION_OUTCOME.MISSING_TEMPLATE
  end

  return OPERATION_OUTCOME.FAIL
end

---Format one processed air operation result into a log line
---@param result table Processed operation result
---@return string level Log entry level
---@return string message Log-safe operation result message
local function formatProcessedResultLine(result)
  local context = string.format(
    "operation=%s operationBatchTime=%q operationBatchType=%s",
    LogFormat.value(result.operationName),
    result.operationBatchTime,
    LogFormat.value(result.operationBatchType)
  )

  if result.outcome == OPERATION_OUTCOME.OK then
    return "OK", string.format(
      "%s wave=%s %s",
      context,
      LogFormat.value(result.waveName),
      result.statusSummary or "status=none"
    )
  end

  if result.outcome == OPERATION_OUTCOME.SKIP then
    return "SKIP", string.format(
      "%s reason=no_valid_packages %s",
      context,
      result.statusSummary or "status=none"
    )
  end

  if result.outcome == OPERATION_OUTCOME.MISSING_TEMPLATE then
    return "ERROR", context .. " reason=missing_wave_template"
  end

  return "FAIL", string.format(
    "%s reason=%s %s",
    context,
    LogFormat.value(string.lower(result.reason or "unknown")),
    result.statusSummary or "status=none"
  )
end

---Emit consolidated logs for processed air operation results
---@param processedResults table[] Processed operation results accumulated in one tick
local function emitProcessedResultsLog(processedResults)
  if #processedResults == 0 then
    return
  end

  local infoLines = {}
  local errorLines = {}
  local timingLines = {}

  for _, result in ipairs(processedResults) do
    local level, message = formatProcessedResultLine(result)
    local line = LogFormat.entry(level, message)

    if level == "ERROR" or level == "FAIL" then
      table.insert(errorLines, line)
    else
      table.insert(infoLines, line)
    end

    if result.timingLogEntries then
      for _, entry in ipairs(result.timingLogEntries) do
        table.insert(timingLines, entry)
      end
    end
  end

  if #infoLines > 0 then
    Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary(
      "scope", "dynamicAirOperations", "Process operations", infoLines)
    )
  end

  if #timingLines > 0 then
    Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary(
      "scope", "dynamicAirTiming", "Build ATO wave timing", timingLines)
    )
  end

  if #errorLines > 0 then
    Logger.error(LogFormat.summary(
      "scope", "dynamicAirOperations", "Process operations", errorLines)
    )
  end
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

  local reconTriggeredOperations = saveData.c.dynamicOperations.reconTriggeredOperations
  if not reconTriggeredOperations or #reconTriggeredOperations == 0 then
    return false
  end

  local airOperations = DynamicState.filterOperationsByType(reconTriggeredOperations, "air")
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
      local success, reason, statusSummary, details = processAirOperation(
        config,
        saveData,
        contacts,
        operationBatch,
        operation
      )
      local outcome = classifyOperationOutcome(success, reason)

      if reason ~= PROCESS_REASON.MISSING_TEMPLATE then
        DynamicState.markOperationExecuted(operationBatch, operation, true)
      end

      if success then
        hasExecutedAny = true
      end

      table.insert(processedResults, {
        operationName = operationName,
        operationBatchTime = operationBatch.time,
        operationBatchType = operationBatch.type,
        outcome = outcome,
        reason = reason,
        statusSummary = statusSummary,
        waveName = details and details.waveName or nil,
        timingLogEntries = details and details.timingLogEntries or nil
      })
    end
  end

  emitProcessedResultsLog(processedResults)
  return hasExecutedAny
end

return AtoBuilder
