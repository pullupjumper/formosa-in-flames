local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")

local DynamicATOInsertion = {}
local DYNAMIC_OPS_LOG_TAG = "dynamicOperations"

-- Time constants
local TIME_CONSTANTS = {
  ESCORT_ADVANCE_TIME = 20 * 60, -- Escort advance 20 minutes
  MISSION_DURATION = 40 * 60,    -- General mission duration 40 minutes
  TANKER_DURATION = 120 * 60,    -- Tanker mission duration 120 minutes
  TANKER_ADVANCE_TIME = 0 * 60,  -- Tanker advance 0 minutes
  ELAPSED_TIME = 30 * 60,
  MAX_SPEED = 470,
  MIN_SPEED = 430,
  MAX_DISTANCE = 450,
  MAX_FLIGHT_TIME = 60 * 60
}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "tanker" }
local SUPPORT_ROLES = { "escort", "wildWeasel", "jammer" }

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

---Validate aircraft availability for a specific role
---Checks if base has sufficient aircraft after accounting for existing assignments
---@param roleData SBJ__MissionDeploymentDescriptor Role configuration containing baseGUID, unitCount, and unitDBID
---@param roleName string Role name for error messages (e.g., "striker", "escort", "SEAD")
---@param packageIndex integer Package index for error messages
---@param assignedAircraft table<string, integer> Map of base GUID to currently assigned aircraft count
---@return boolean success true if sufficient aircraft available
---@return string|nil errorMessage Error message if validation fails, nil on success
local function validateAircraftRole(roleData, roleName, packageIndex, assignedAircraft)
  if not roleData then
    return true, nil
  end

  local baseGUID = roleData.baseGUID
  local requiredCount = roleData.unitCount or 0
  local assignedCount = assignedAircraft[baseGUID] or 0
  local requiredUnitDBID = roleData.unitDBID

  local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
  if availableCount - assignedCount < requiredCount then
    return false, "Package " .. packageIndex .. " insufficient " .. roleName .. " aircraft at base " ..
        (baseGUID or "unknown") .. " (available: " .. availableCount ..
        ", assigned: " .. assignedCount .. ", required: " .. requiredCount .. ")"
  end

  return true, nil
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
    return false, "Package " .. packageIndex .. " has insufficient targets (" ..
        targetCount .. " < " .. minTargetCount .. ")"
  end

  -- Check aircraft availability for all roles
  local roles = {
    { data = packageData.striker,    name = "striker" },
    { data = packageData.escort,     name = "escort" },
    { data = packageData.wildWeasel, name = "SEAD" }
  }

  for _, role in ipairs(roles) do
    local isValid, errorMessage = validateAircraftRole(role.data, role.name, packageIndex, assignedAircraft)
    if not isValid then
      return false, errorMessage
    end
  end

  return true, "Package " .. packageIndex .. " validated successfully"
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

  local summary = string.format("valid=%d/%d, targets=%d", #validPackages, #copyPackages, totalTargets)
  if #skippedReasons > 0 then
    summary = summary .. ", skipped: [" .. table.concat(skippedReasons, "; ") .. "]"
  end

  return validPackages, summary
end

-- ============================================================================
-- Flight Time Calculation
-- ============================================================================

---Get patrol zone reference point coordinates from package escort configuration
---@param packageData SBJ__PackageTemplate Package configuration containing escort patrol zone
---@return CMO__Location|nil # Patrol zone point coordinates or nil if unavailable
local function getPatrolZonePoint(packageData)
  local patrolZone = packageData.escort and packageData.escort.missionCreationParams and
      packageData.escort.missionCreationParams.opts and
      packageData.escort.missionCreationParams.opts.patrolZone

  if not patrolZone or #patrolZone == 0 then
    return nil
  end

  local point = GameApi.ScenEdit_GetReferencePoint({ side = "China", name = patrolZone[1] })
  if not point then
    return nil
  end

  return { latitude = point.latitude, longitude = point.longitude }
end

---Calculate flight time in seconds from distance in nautical miles
---@param distance number Distance in nautical miles
---@return integer # Flight time in seconds, rounded up
local function calculateFlightTimeFromDistance(distance)
  local speed = TIME_CONSTANTS.MAX_SPEED
  if distance >= TIME_CONSTANTS.MAX_DISTANCE then
    speed = TIME_CONSTANTS.MIN_SPEED
  end
  return math.ceil((distance / speed) * 3600)
end

---Calculate advance time for a specific role based on distance to patrol zone
---@param packageData SBJ__PackageTemplate Package configuration containing role data and patrol zone
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return integer # Flight time in seconds for the role to reach patrol zone
local function calculateRoleAdvanceTime(packageData, role)
  ---@type SBJ__MissionDeploymentDescriptor|nil
  local missionRole = packageData[role]
  if not missionRole or not missionRole.baseGUID then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  local targetPoint = getPatrolZonePoint(packageData)
  if not targetPoint then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  local distance = GameApi.Tool_Range(missionRole.baseGUID, targetPoint)
  if not distance or distance <= 0 then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  return calculateFlightTimeFromDistance(distance)
end


---Calculate support advance time based on furthest base distance
---Finds the furthest support base from patrol zone and calculates required advance time
---@param packageData SBJ__PackageTemplate Package configuration containing all support roles
---@return integer # Flight time in seconds for furthest support base to reach patrol zone
local function calculateSupportAdvanceTime(packageData)
  local targetPoint = getPatrolZonePoint(packageData)
  if not targetPoint then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  local maxDistance = 0
  local furthestRole = nil

  for _, role in ipairs(SUPPORT_ROLES) do
    local missionRole = packageData[role]
    if missionRole and missionRole.baseGUID then
      local distance = GameApi.Tool_Range(missionRole.baseGUID, targetPoint)
      if distance and distance > maxDistance then
        maxDistance = distance
        furthestRole = role
      end
    end
  end

  if not furthestRole or maxDistance <= 0 then
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  return calculateFlightTimeFromDistance(maxDistance)
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

      timing.strikerStart = os.date("%Y-%m-%d %H:%M:%S",
        GameApi.ScenEdit_CurrentTime() + (packageData.timeToReady or 5) + advanceTime -
        (advanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0)
      ) --[[@as string]]
    else
      if previousPackage and previousPackage.striker.startTime then
        local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
        timing.strikerStart = os.date("%Y-%m-%d %H:%M:%S", previousStartTime + strikeInterval) --[[@as string]]
      end
    end
  else
    -- Use existing startTime
    timing.strikerStart = packageData.striker.startTime
  end

  -- Calculate striker end time
  local strikerStartTime = Utils.parseDatetimeToTimestamp(timing.strikerStart)
  local missionDuration = packageData.tanker and TIME_CONSTANTS.TANKER_DURATION or TIME_CONSTANTS.MISSION_DURATION
  timing.strikerEnd = os.date("%Y-%m-%d %H:%M:%S", strikerStartTime + missionDuration) --[[@as string]]
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

  timing.startTime = os.date(
    "%Y-%m-%d %H:%M:%S",
    strikerTimestamp - advanceTime + 61 + (packageData.timeToReady or 5) +
    (maxAdvanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0)
  ) --[[@as string]]
  local startTimestamp = Utils.parseDatetimeToTimestamp(timing.startTime)
  local strikerFlightTime = calculateStrikerFlightTime(packageData)
  local duration = maxAdvanceTime + strikerFlightTime + 10 * 60

  timing.endTime = os.date("%Y-%m-%d %H:%M:%S",
    (role == "tanker") and (startTimestamp + duration - TIME_CONSTANTS.ELAPSED_TIME) or startTimestamp + duration
  )
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
  local supportRoles = { "escort", "wildWeasel", "jammer", "tanker" }
  for _, role in ipairs(supportRoles) do
    local missionRole = packageData[role]

    if missionRole then
      if not missionRole.startTime or not missionRole.endTime then
        local roleTiming = calculateRoleTiming(role, packageData)

        if role ~= "tanker" then
          missionRole.startTime = missionRole.startTime or roleTiming.startTime
        end

        missionRole.endTime = missionRole.endTime or roleTiming.endTime

        if roleTiming.timeOnStation then
          missionRole.timeOnStation = roleTiming.timeOnStation
        end
      end
    end
  end

  -- Create package structure
  ---@type SBJ__Package
  return {
    timeToReady = packageData.timeToReady or 5,
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
---@return SBJ__Wave # Wave structure with all packages and timing applied
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
  for packageIndex, packageData in ipairs(waveTemplate.packages) do
    local newPackage = createPackageWithTiming(
      packageData,
      packageIndex,
      previousPackage,
      waveTemplate.strikeInterval or 0
    )
    table.insert(newWave.packages, newPackage)
    previousPackage = packageData
  end

  return newWave
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
---@param reconType string Reconnaissance type identifier used for wave naming
---@return boolean # True if wave was successfully inserted, false on failure
local function insertATOWave(saveData, waveTemplate, reconType)
  if not saveData.c.air.airTaskingOrder then
    return false
  end

  local waveName = DynamicOperationsUtils.generateUniqueAirOperationName(waveTemplate.name, reconType, saveData)
  local wave = buildATOWave(waveTemplate, waveName)
  return insertWave(saveData, wave)
end

-- ============================================================================
-- Recon Schedule Orchestration
-- ============================================================================

---Check whether recon trigger time is reached for processing
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry
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
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry triggering this operation
---@param operation SBJ__Operation Air operation containing wave template
---@return boolean success True if ATO wave was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string|nil statusSummary Package validation summary
local function processAirOperation(config, saveData, contacts, reconEntry, operation)
  if not operation.template then
    return false, "MISSING_TEMPLATE", nil
  end

  local validPackages, statusSummary = processATOTemplateWithValidation(
    config, saveData, contacts, operation.template, operation.template.isFirstWave
  )

  if #validPackages == 0 then
    return false, "NO_VALID_PACKAGES", statusSummary
  end

  local modifiedTemplate = Utils.deepCopy(operation.template)
  modifiedTemplate.packages = validPackages

  local success = insertATOWave(saveData, modifiedTemplate, reconEntry.type)
  if not success then
    return false, "INSERTION_FAILED", statusSummary
  end

  return true, nil, statusSummary
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

  local reconSchedule = saveData.c.dynamicOperations.reconSchedule
  if not reconSchedule or #reconSchedule == 0 then
    return false
  end

  local airOperations = DynamicOperationsUtils.filterOperationsByType(reconSchedule, "air")
  if #airOperations == 0 then
    return false
  end

  local hasExecutedAny = false

  for _, item in ipairs(airOperations) do
    local reconEntry = item.reconEntry
    local operation = item.operation

    if isReconTriggered(reconEntry) then
      local success, reason, statusSummary = processAirOperation(config, saveData, contacts, reconEntry, operation)

      if reason == "MISSING_TEMPLATE" then
        Logger.error(string.format("Air operation missing template, reconnaissance time: %s", reconEntry.time))
      else
        DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, true)

        if success then
          hasExecutedAny = true
          Logger.log(DYNAMIC_OPS_LOG_TAG, string.format(
            "Successfully inserted dynamic ATO wave: %s, reconnaissance time: %s, %s",
            operation.template.name, reconEntry.time, statusSummary or "none"))
        elseif reason == "NO_VALID_PACKAGES" then
          Logger.log(DYNAMIC_OPS_LOG_TAG, string.format(
            "Skipped dynamic ATO due to no valid packages, reconnaissance time: %s, %s",
            reconEntry.time, statusSummary or "none"))
        elseif reason == "INSERTION_FAILED" then
          Logger.error(string.format(
            "Failed to insert dynamic ATO wave: %s, reason: %s, reconnaissance time: %s, %s",
            operation.template.name, reason, reconEntry.time, statusSummary or "none"))
        end
      end
    end
  end

  return hasExecutedAny
end

return DynamicATOInsertion
