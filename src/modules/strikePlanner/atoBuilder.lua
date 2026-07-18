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

  if not saveData.c.air.airTaskingOrder then
    return assignedAircraft
  end

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

---Check if individual package has sufficient aircraft resources
---Target sufficiency is evaluated before package construction.
---@param packageData SBJ__PackageTemplate Package configuration with target and role requirements
---@param packageIndex integer Index of the package for logging
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count
---@return boolean success true if package is valid and can be executed
---@return string|nil reason Reason string (error message on failure, success message on pass)
local function validateIndividualPackage(packageData, packageIndex, assignedAircraft)
  local tankerValid, tankerError = validateTankerMissionConfig(packageData.tanker, packageIndex)
  if not tankerValid then
    return false, tankerError
  end

  for _, role in ipairs(PACKAGE_ROLES) do
    local isValid, errorMessage = validateAircraftRole(packageData[role], role, packageIndex, assignedAircraft)

    if not isValid then
      return false, errorMessage
    end
  end

  local msg = string.format("package=%d status=valid", packageIndex)
  return true, msg
end

---Get minimum target count for one package template
---@param packageData SBJ__PackageTemplate Package configuration with target requirements
---@return integer # Minimum target count required for this package
local function getPackageMinTargetCount(packageData)
  if packageData.target and packageData.target.minTargetCount then
    return packageData.target.minTargetCount
  end

  return 1
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
---@return table<integer, string[]> targetsByPackageIndex Evaluated targets grouped by package index
---@return integer targetQualifiedPackageCount Number of package templates with enough targets
---@return integer targetSkippedPackageCount Number of package templates skipped by target sufficiency
local function evaluateTargetsFromTemplate(config, saveData, contacts, waveTemplate)
  local targetsByPackageIndex = {}
  local targetQualifiedPackageCount = 0
  local targetSkippedPackageCount = 0

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
    local requiredCount = getPackageMinTargetCount(packageData)

    if targetCount >= requiredCount then
      targetsByPackageIndex[packageIndex] = packageTargets
      targetQualifiedPackageCount = targetQualifiedPackageCount + 1
    else
      targetSkippedPackageCount = targetSkippedPackageCount + 1
    end
  end

  return targetsByPackageIndex, targetQualifiedPackageCount, targetSkippedPackageCount
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

---Compute the longest flight time from a role's base to its operational zones
---@param packageData SBJ__PackageTemplate Package configuration containing role data
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return integer|nil # Flight time in seconds, or nil if role/base/zone/distance unavailable
local function computeRoleFlightTime(packageData, role)
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
        local flightTime = calculateFlightTimeFromDistance(distance, role)
        if not maxFlightTime or flightTime > maxFlightTime then
          maxFlightTime = flightTime
        end
      end
    end
  end

  return maxFlightTime
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
      not packageData.striker.weaponDBID or
      not packageData.target or not packageData.target.list or #packageData.target.list == 0 then
    return TIME_CONSTANTS.MISSION_DURATION
  end

  local weaponInfo = GameApi.ScenEdit_QueryDB("weapon", packageData.striker.weaponDBID)
  local weaponRange = tonumber(weaponInfo and weaponInfo.ranges and weaponInfo.ranges.land and weaponInfo.ranges.land
    .max)

  if not weaponRange then
    return TIME_CONSTANTS.MISSION_DURATION
  end

  local targetRange = tonumber(GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1]))

  if not targetRange then
    return TIME_CONSTANTS.MISSION_DURATION
  end

  local distance = targetRange - weaponRange

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
---@param previousPackage SBJ__Package|nil Previous executable package for sequential timing, nil for first valid package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return {strikerStart: string, strikerEnd: string} # Table with striker start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculatePackageTiming(packageData, previousPackage, strikeInterval)
  local timing = {}
  -- Calculate striker timing
  if not packageData.striker.startTime then
    if not previousPackage then
      -- Check if there are support roles
      local hasSupportRoles = packageData.escort or packageData.wildWeasel or packageData.jammer
      local advanceTime = 0

      if hasSupportRoles then
        advanceTime = calculateSupportAdvanceTime(packageData)
      end

      local delayTime = advanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0
      local startTime = GameApi.ScenEdit_CurrentTime() + advanceTime - delayTime + (packageData.timeToReady or (5 * 60))
      timing.strikerStart = os.date(constants.DATE_FORMAT, startTime) --[[@as string]]
    else
      if previousPackage and previousPackage.striker.startTime then
        local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
        timing.strikerStart = os.date(constants.DATE_FORMAT, previousStartTime + strikeInterval) --[[@as string]]
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
  timing.strikerEnd = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]
  return timing
end

---Calculate mission timing for a package
---Determines striker start and end times based on support advance time and strike intervals
---@param packageData SBJ__PackageTemplate Package configuration with role and timing information
---@param previousPackage SBJ__Package|nil Previous executable package for sequential timing, nil for first valid package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return {startTime: string, timeOnTarget: string, endTime: string} # Table with TOT start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculateStrikerTimeOnTarget(packageData, previousPackage, strikeInterval)
  local timing = {}

  if not previousPackage then
    -- Check if there are support roles
    local hasSupportRoles = packageData.escort or packageData.wildWeasel or packageData.jammer
    local advanceTime = 0

    if hasSupportRoles then
      advanceTime = calculateSupportAdvanceTime(packageData)
    end

    local delayTime = advanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0
    local strikerFlightTime = calculateStrikerFlightTime(packageData)
    local startTime = GameApi.ScenEdit_CurrentTime() + advanceTime - delayTime + (packageData.timeToReady or (5 * 60))
    local timeOnTarget = startTime + strikerFlightTime + 20 * 60
    timing.startTime = os.date(constants.DATE_FORMAT, startTime) --[[@as string]]
    timing.timeOnTarget = os.date(constants.DATE_FORMAT, timeOnTarget) --[[@as string]]
  else
    if previousPackage and previousPackage.striker.timeOnStation then
      local previousTOT = Utils.parseDatetimeToTimestamp(previousPackage.striker.timeOnStation)
      timing.timeOnTarget = os.date(constants.DATE_FORMAT, previousTOT + strikeInterval) --[[@as string]]
    end

    if previousPackage and previousPackage.striker.startTime then
      local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
      timing.startTime = os.date(constants.DATE_FORMAT, previousStartTime + strikeInterval) --[[@as string]]
    end
  end
  -- Calculate striker end time
  local timeOnTarget = Utils.parseDatetimeToTimestamp(timing.timeOnTarget)
  local missionDuration = packageData.tanker and TIME_CONSTANTS.TANKER_DURATION or TIME_CONSTANTS.MISSION_DURATION
  local endTime = timeOnTarget + missionDuration
  timing.endTime = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]
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
  timing.startTime = os.date(constants.DATE_FORMAT, startTime) --[[@as string]]
  local strikerFlightTime = calculateStrikerFlightTime(packageData)
  local duration = maxAdvanceTime + strikerFlightTime + 10 * 60
  local endTime = role == "tanker" and (startTime + duration - TIME_CONSTANTS.ELAPSED_TIME) or startTime + duration
  timing.endTime = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]
  return timing
end

---Calculate support role timing (escort, wildWeasel, jammer, tanker)
---Computes when support aircraft should launch to arrive before striker
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@param packageData SBJ__PackageTemplate Package data containing striker timing and role configurations
---@return {startTime: string|nil, endTime: string, timeOnStation: string|nil} # Table with startTime, endTime, and timeOnStation in "YYYY-MM-DD HH:MM:SS" format
local function calculateRoleTimeOnStation(role, packageData)
  local strikerTimestamp = Utils.parseDatetimeToTimestamp(packageData.striker.timeOnStation)
  local startTimestamp = Utils.parseDatetimeToTimestamp(packageData.striker.startTime)
  local timing = {}

  -- Calculate start time based on role
  local advanceTime = calculateRoleAdvanceTime(packageData, role)
  local maxAdvanceTime = calculateSupportAdvanceTime(packageData)
  -- Setting delay time based on max advance time and role
  local delayTime = maxAdvanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0
  local timeOnStation = strikerTimestamp + delayTime - calculateStrikerFlightTime(packageData) +
      (packageData.timeToReady or (5 * 60)) - (role == "tanker" and 30 * 60 or 0)
  local startTime = startTimestamp - (role == "tanker" and maxAdvanceTime or advanceTime) + delayTime +
      (packageData.timeToReady or (5 * 60))
  timing.timeOnStation = os.date(constants.DATE_FORMAT, timeOnStation) --[[@as string]]
  timing.startTime = os.date(constants.DATE_FORMAT, startTime) --[[@as string]]
  local strikerFlightTime = calculateStrikerFlightTime(packageData)
  local duration = maxAdvanceTime + strikerFlightTime + 10 * 60
  local endTime = role == "tanker" and (timeOnStation + duration - TIME_CONSTANTS.ELAPSED_TIME) or
      timeOnStation + duration
  timing.endTime = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]

  return timing
end

---Create a single package with proper timing
---Converts package template to executable package with calculated timings for all roles
---@param packageData SBJ__PackageTemplate Package template configuration
---@param previousPackage SBJ__Package|nil Previous executable package for sequential timing, nil for first valid package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return SBJ__Package # Executable package with complete timing and loadout status
local function createPackageWithTiming(packageData, previousPackage, strikeInterval)
  -- Calculate main timing
  -- local timing = calculatePackageTiming(packageData, previousPackage, strikeInterval)
  local timing = calculateStrikerTimeOnTarget(packageData, previousPackage, strikeInterval)

  -- Set striker timing
  -- if not packageData.striker.startTime then
  --   packageData.striker.startTime = timing.strikerStart
  -- end

  -- if not packageData.striker.endTime then
  --   packageData.striker.endTime = timing.strikerEnd
  -- end

  if not packageData.striker.startTime then
    packageData.striker.startTime = timing.startTime
  end

  if not packageData.striker.timeOnStation then
    packageData.striker.timeOnStation = timing.timeOnTarget
  end

  if not packageData.striker.endTime then
    packageData.striker.endTime = timing.endTime
  end

  -- Set support role timing
  for _, role in ipairs(SUPPORT_ROLES) do
    local missionRole = packageData[role]

    if not missionRole then
      goto continue
    end

    -- if not missionRole.startTime or not missionRole.endTime then
    --   local roleTiming = calculateRoleTiming(role, packageData)
    --   missionRole.startTime = missionRole.startTime or roleTiming.startTime
    --   missionRole.endTime = missionRole.endTime or roleTiming.endTime

    --   if roleTiming.timeOnStation then
    --     missionRole.timeOnStation = roleTiming.timeOnStation
    --   end
    -- end
    if not missionRole.timeOnStation or not missionRole.endTime or not missionRole.startTime then
      local roleTiming = calculateRoleTimeOnStation(role, packageData)
      missionRole.timeOnStation = missionRole.timeOnStation or roleTiming.timeOnStation
      missionRole.endTime = missionRole.endTime or roleTiming.endTime
      missionRole.startTime = missionRole.startTime or roleTiming.startTime
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

---Build executable package templates from evaluated targets and aircraft validation
---Mutates copied package templates with target lists and resolved baseGUID values.
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@param targetSkippedPackageCount integer Number of packages already skipped by target sufficiency
---@return SBJ__PackageTemplate[] validPackages Array of validated packages with assigned targets
---@return string statusSummary Human-readable summary of validation results
local function buildExecutablePackages(saveData, waveTemplate, targetsByPackageIndex, targetSkippedPackageCount)
  -- local copyPackages = Utils.deepCopy(waveTemplate.packages)
  local validPackages = {}
  local assignedAircraft = collectAssignedAircraft(saveData)
  local totalTargets = 0
  local aircraftSkippedPackageCount = 0
  local previousPackage = nil

  for packageIndex, packageTemplate in ipairs(waveTemplate.packages) do
    local strikeTargets = targetsByPackageIndex[packageIndex]

    if strikeTargets then
      local isValid = validateIndividualPackage(packageTemplate, packageIndex, assignedAircraft)

      if isValid then
        local package = Utils.deepCopy(packageTemplate)
        package.target.list = strikeTargets
        package = createPackageWithTiming(package, previousPackage, waveTemplate.strikeInterval or 0)
        table.insert(validPackages, package)
        previousPackage = package
        totalTargets = totalTargets + #strikeTargets
      else
        aircraftSkippedPackageCount = aircraftSkippedPackageCount + 1
      end
    end
  end

  local summary = formatPackageValidationSummary(
    #validPackages,
    #waveTemplate.packages,
    totalTargets,
    targetSkippedPackageCount + aircraftSkippedPackageCount
  )
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
    isFirstWave = waveTemplate.isFirstWave or false,
    hasLaunched = false,
    strikeInterval = waveTemplate.strikeInterval or 0,
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

---Insert ATO wave into saveData and register as generated operation
---@param saveData SBJ__SaveData Persistent save data to insert wave into
---@param wave SBJ__Wave Complete wave structure ready for insertion
---@return boolean # True if wave was successfully inserted
local function insertWave(saveData, wave)
  saveData.c.air.airTaskingOrder[wave.name] = wave
  DynamicState.registerGeneratedOperation("air", wave.name, saveData)
  return true
end

---Generate wave name from template and reconnaissance type
---@param waveTemplate SBJ__WaveTemplate Template used for name source
---@param reconType string Reconnaissance type identifier
---@param saveData SBJ__SaveData Persistent save data for uniqueness check
---@return string # Generated unique wave name
local function buildWaveName(waveTemplate, reconType, saveData)
  return DynamicState.generateUniqueAirOperationName(waveTemplate.name, reconType, saveData)
end

---Create actual ATO wave from template and evaluation results
---Constructs executable packages, calculates timing, and inserts the wave.
---@param saveData SBJ__SaveData Persistent save data for ATO insertion
---@param waveTemplate SBJ__WaveTemplate Template defining ATO wave and package configurations
---@param targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@param targetSkippedPackageCount integer Number of packages skipped by target sufficiency
---@param reconType string Reconnaissance type identifier used for wave naming
---@return boolean success True if ATO wave was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string statusSummary Package validation summary
---@return {waveName: string, timingLogEntries: string[]}|nil details Additional operation details for logging
local function createAndInsertATOWaveFromTemplate(
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    targetSkippedPackageCount,
    reconType)
  local validPackages, statusSummary = buildExecutablePackages(
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    targetSkippedPackageCount
  )

  if #validPackages == 0 then
    return false, PROCESS_REASON.NO_VALID_PACKAGES, statusSummary, nil
  end

  if not saveData.c.air.airTaskingOrder then
    return false, PROCESS_REASON.INSERTION_FAILED, statusSummary, { waveName = nil, timingLogEntries = {} }
  end

  -- local executableTemplate = Utils.deepCopy(waveTemplate)
  -- executableTemplate.packages = validPackages
  local waveName = buildWaveName(waveTemplate, reconType, saveData)
  local wave = buildATOWave(waveTemplate, waveName, validPackages)
  local timingLogEntries = collectWaveTimingLogEntries(wave)

  if not insertWave(saveData, wave) then
    return false, PROCESS_REASON.INSERTION_FAILED, statusSummary, {
      waveName = waveName,
      timingLogEntries = timingLogEntries or {}
    }
  end

  return true, nil, statusSummary, { waveName = waveName, timingLogEntries = timingLogEntries or {} }
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

  local waveTemplate = Utils.deepCopy(operation.template)
  local targetsByPackageIndex, targetQualifiedPackageCount, targetSkippedPackageCount = evaluateTargetsFromTemplate(
    config,
    saveData,
    contacts,
    operation.template
  )

  if targetQualifiedPackageCount == 0 then
    local statusSummary = formatPackageValidationSummary(0, #waveTemplate.packages, 0, targetSkippedPackageCount)
    return false, PROCESS_REASON.NO_VALID_PACKAGES, statusSummary, nil
  end

  return createAndInsertATOWaveFromTemplate(
    saveData,
    waveTemplate,
    targetsByPackageIndex,
    targetSkippedPackageCount,
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
  if result.outcome == OPERATION_OUTCOME.OK then
    local msg = string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s wave=%s %s",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType),
      LogFormat.value(result.waveName),
      result.statusSummary or "status=none"
    )
    return "OK", msg
  end

  if result.outcome == OPERATION_OUTCOME.SKIP then
    local msg = string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s reason=no_valid_packages %s",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType),
      result.statusSummary or "status=none"
    )
    return "SKIP", msg
  end

  if result.outcome == OPERATION_OUTCOME.MISSING_TEMPLATE then
    local msg = string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s reason=missing_wave_template",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType)
    )
    return "ERROR", msg
  end

  local msg = string.format(
    "operation=%s operationBatchTime=%q operationBatchType=%s reason=%s %s",
    LogFormat.value(result.operationName),
    result.operationBatchTime,
    LogFormat.value(result.operationBatchType),
    LogFormat.value(string.lower(result.reason or "unknown")),
    result.statusSummary or "status=none"
  )
  return "FAIL", msg
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
