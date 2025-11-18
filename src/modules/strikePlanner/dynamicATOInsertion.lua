local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")

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
  MAX_DISTANCE = 450,
  MAX_FLIGHT_TIME = 60 * 60
}

-- Local helper functions (private)


---Collect all currently assigned aircraft from active ATO waves
--- Counts aircraft already assigned to missions across all active ATO waves to prevent over-allocation
---@param saveData SBJ__SaveData The persistent save data containing ATO wave information
---@return table<string, number> # Map of base GUID to assigned aircraft count
local function collectAssignedAircraft(saveData)
  local assignedAircraft = {}

  if not saveData.c.air.ATO then
    return assignedAircraft
  end

  for _, wave in pairs(saveData.c.air.ATO) do
    if wave.isActivated and not wave.hasLaunched and wave.packages then
      for _, package in ipairs(wave.packages) do
        if not package.hasLaunched then
          -- Count striker aircraft
          if package.striker and package.striker.baseGUID then
            assignedAircraft[package.striker.baseGUID] =
                (assignedAircraft[package.striker.baseGUID] or 0) + (package.striker.unitCount or 0)
          end

          -- Count escort aircraft
          if package.escort and package.escort.baseGUID then
            assignedAircraft[package.escort.baseGUID] =
                (assignedAircraft[package.escort.baseGUID] or 0) + (package.escort.unitCount or 0)
          end

          -- Count wildWeasel aircraft
          if package.wildWeasel and package.wildWeasel.baseGUID then
            assignedAircraft[package.wildWeasel.baseGUID] =
                (assignedAircraft[package.wildWeasel.baseGUID] or 0) + (package.wildWeasel.unitCount or 0)
          end

          -- Count tanker aircraft
          if package.tanker and package.tanker.baseGUID then
            assignedAircraft[package.tanker.baseGUID] =
                (assignedAircraft[package.tanker.baseGUID] or 0) + (package.tanker.unitCount or 0)
          end
        end
      end
    end
  end

  return assignedAircraft
end

---Get available aircraft count at a specific base for a specific unit type
--- Counts embarked aircraft matching the required DBID that are not assigned to missions
---@param baseGUID string The GUID of the air base to check
---@param requiredUnitDBID number The required aircraft unit database ID (DBID) to filter by
---@return number # Number of available unassigned aircraft of the specified type
local function getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
  -- Try to get the base unit
  local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)

  if not baseUnit then
    Logger.error("Cannot find air base with GUID: " .. tostring(baseGUID))
    return 0
  end

  if not baseUnit.embarkedUnits or not baseUnit.embarkedUnits.Aircraft then
    Logger.log("dynamicOperations", "Air base " .. baseUnit.name .. " has no embarked aircraft")
    return 0
  end

  local availableCount = 0

  -- Count aircraft matching the required unitDBID
  for _, aircraftGUID in ipairs(baseUnit.embarkedUnits.Aircraft) do
    local aircraft = GameApi.ScenEdit_GetUnit(aircraftGUID)

    if aircraft and aircraft.dbid == requiredUnitDBID then
      -- Check if aircraft is available (not assigned to mission, not damaged, etc.)
      if aircraft.mission == "" or aircraft.mission == nil then
        availableCount = availableCount + 1
      end
    end
  end

  Logger.log("dynamicOperations",
    "Base " .. baseUnit.name .. " has " .. availableCount ..
    " available aircraft of type DBID " .. tostring(requiredUnitDBID)
  )

  return availableCount
end

---Validate aircraft availability for a specific role
--- Checks if base has sufficient aircraft after accounting for existing assignments
---@param roleData table Role configuration containing baseGUID, unitCount, and unitDBID
---@param roleName string Role name for error messages (e.g., "striker", "escort", "SEAD")
---@param packageIndex number Package index for error messages
---@param assignedAircraft table<string, number> Map of base GUID to currently assigned aircraft count
---@return boolean # true if sufficient aircraft available
---@return string|nil # Error message if validation fails, nil on success
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
--- Validates both target count meets minimum requirements and all roles have available aircraft
---@param packageData SBJ__PackageTemplate Package configuration with target and role requirements
---@param packageTargets string[] Array of target GUIDs found for this package
---@param packageIndex number Index of the package for logging
---@param assignedAircraft table<string, number> Map of base GUID to currently assigned aircraft count
---@return boolean # true if package is valid and can be executed
---@return string|nil # Reason string (error message on failure, success message on pass)
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


---Process dynamic targets using filter functions
--- Applies configured targeting filters (e.g., naval, radar) to find valid strike targets
---@param packageData SBJ__PackageTemplate Package configuration with target filter definitions
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data for tracking
---@param packageIndex number Package index for logging
---@return string[] # Array of target GUIDs matching the filter criteria
local function processDynamicTargets(packageData, contacts, config, saveData, packageIndex)
  local strikeTargets = {}

  Logger.log("dynamicOperations",
    "Package " .. packageIndex .. " using dynamic target filtering, filters: " ..
    table.concat(packageData.target.filterNames, ", ")
  )

  local shouldTrack = packageData.target.filterNames[1] == "findNavalTargets" or
      packageData.target.filterNames[1] == "findRadioDirection"

  local filterOpts = {
    contacts = contacts,
    task = { target = { areas = packageData.target.areas, contactAge = packageData.target.contactAge } },
    config = config,
    saveData = saveData,
    shouldTrack = shouldTrack
  }

  for _, filterName in ipairs(packageData.target.filterNames) do
    local targetingFunction = TargetingProcess[filterName]

    if targetingFunction then
      local targets = targetingFunction(filterOpts)
      if targets and #targets > 0 then
        Utils.insertList(strikeTargets, targets)
        Logger.log("dynamicOperations",
          "Package " .. packageIndex .. " filter " .. filterName .. " found " .. #targets .. " targets")
      end
    else
      Logger.error("Unknown target filtering function: " .. filterName)
    end
  end

  return strikeTargets
end

---Process fixed targets using BDA assessment
--- Filters pre-defined target lists and assesses their damage status
---@param packageData SBJ__PackageTemplate Package configuration with fixed target definitions
---@param saveData SBJ__SaveData Persistent save data containing target list
---@param isFirstWave boolean Whether this is the first wave (affects BDA assessment)
---@param packageIndex number Package index for logging
---@return string[] # Array of target GUIDs that passed BDA assessment
local function processFixedTargets(packageData, saveData, isFirstWave, packageIndex)
  local strikeTargets = {}

  Logger.log("dynamicOperations", "Package " .. packageIndex .. " using fixed target list for BDA assessment")

  if not packageData.target.objs then
    return strikeTargets
  end

  local filteredTargets = TargetingProcess.filterTargetsByTypeAndBase(
    saveData.c.targetlist,
    packageData.target.objs
  )

  if filteredTargets and #filteredTargets > 0 then
    Logger.log("dynamicOperations",
      "Package " .. packageIndex .. " filtered " .. #filteredTargets .. " candidate targets")
    local task = { target = { list = filteredTargets, contactAge = packageData.target.contactAge } }
    strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
  end

  return strikeTargets
end

---Process targets for a single package
--- Routes to dynamic or fixed target processing based on package configuration
---@param packageData SBJ__PackageTemplate Package configuration with target definitions
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param isFirstWave boolean Whether this is the first wave
---@param packageIndex number Package index for logging
---@return string[] # Array of target GUIDs found for this package
local function processPackageTargets(packageData, contacts, config, saveData, isFirstWave, packageIndex)
  local strikeTargets = {}

  if not packageData.target then
    Logger.error("Package " .. packageIndex .. " missing target configuration")
    return strikeTargets
  end

  -- Dynamic target filtering (radar, naval targets, etc.)
  if type(packageData.target.filterNames) == "table" and #packageData.target.filterNames > 0 then
    strikeTargets = processDynamicTargets(packageData, contacts, config, saveData, packageIndex)
  else
    -- Fixed target lists (airport facilities, etc.)
    strikeTargets = processFixedTargets(packageData, saveData, isFirstWave, packageIndex)
  end

  return strikeTargets
end

---Process ATO template with integrated validation - single pass through packages
--- Processes all packages in wave template, finding targets and validating resources in one pass
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing ATO and target information
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param waveTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param isFirstWave boolean Whether this is the first wave (affects BDA assessment)
---@return SBJ__PackageTemplate[] # Array of validated packages with assigned targets
local function processATOTemplateWithValidation(config, saveData, contacts, waveTemplate, isFirstWave)
  local copyPackages = Utils.deepCopy(waveTemplate.packages)
  local validPackages = {}
  local assignedAircraft = collectAssignedAircraft(saveData)

  for packageIndex, packageData in ipairs(copyPackages) do
    -- Step 1: Process targets
    local strikeTargets = processPackageTargets(packageData, contacts, config, saveData, isFirstWave, packageIndex)

    -- Step 2: Validate package
    local isValid, reason = validateIndividualPackage(packageData, strikeTargets, packageIndex, assignedAircraft)

    -- Step 3: Handle validation result
    if isValid then
      if packageData.target then
        packageData.target.list = strikeTargets
      end
      table.insert(validPackages, packageData)
      Logger.log("dynamicOperations",
        "Package " .. packageIndex .. " validated: " .. #strikeTargets .. " targets, " .. reason)
    else
      Logger.log("dynamicOperations", "Package " .. packageIndex .. " skipped: " .. reason)
    end
  end

  return validPackages
end

---Calculate advance time for a specific role based on distance to patrol zone
--- Computes flight time from role's base to patrol zone using distance-based speed calculation
---@param packageData SBJ__PackageTemplate Package configuration containing role data and patrol zone
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@return number # Flight time in seconds for the role to reach patrol zone
local function calculateRoleAdvanceTime(packageData, role)
  -- Validate role exists in package
  if not packageData[role] or not packageData[role].baseGUID then
    Logger.log("dynamicOperations", "Role " .. role .. " not found in package or missing baseGUID")
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  -- Get patrol zone reference point (using escort's patrol zone as reference)
  local patrolZone = packageData.escort and packageData.escort.missionParams and
      packageData.escort.missionParams.opts and
      packageData.escort.missionParams.opts.patrolZone

  if not patrolZone or #patrolZone == 0 then
    Logger.log("dynamicOperations", "No patrol zone found for advance time calculation")
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  local rp = patrolZone[1]
  local point = GameApi.ScenEdit_GetReferencePoint({ side = 'China', name = rp })

  if not point then
    Logger.log("dynamicOperations", "Reference point not found: " .. tostring(rp))
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  -- Calculate distance from role's base to patrol zone
  local distance = GameApi.Tool_Range(
    packageData[role].baseGUID,
    { latitude = point.latitude, longitude = point.longitude }
  )

  if not distance or distance <= 0 then
    Logger.log("dynamicOperations", "Invalid distance calculated for role " .. role)
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  -- Calculate speed based on distance
  local speed = TIME_CONSTANTS.MAX_SPEED
  if distance >= TIME_CONSTANTS.MAX_DISTANCE then
    speed = TIME_CONSTANTS.MIN_SPEED
  end

  -- Calculate flight time: distance(nm) / speed(knots) * 3600 seconds
  local flightTime = (distance / speed) * 3600

  Logger.log("dynamicOperations", string.format(
    "Calculated %s advance time: %.1f minutes (%.1f nm distance)",
    role, flightTime / 60, distance
  ))

  return math.ceil(flightTime)
end

---Calculate support advance time based on furthest base distance
--- Finds the furthest support base from patrol zone and calculates required advance time
---@param packageData SBJ__PackageTemplate Package configuration containing all support roles (escort, wildWeasel, jammer)
---@return number # Flight time in seconds for furthest support base to reach patrol zone
local function calculateSupportAdvanceTime(packageData)
  -- Collect all support bases
  local supportBases = {}
  if packageData.escort and packageData.escort.baseGUID then
    table.insert(supportBases, { role = "escort", baseGUID = packageData.escort.baseGUID })
  end
  if packageData.wildWeasel and packageData.wildWeasel.baseGUID then
    table.insert(supportBases, { role = "wildWeasel", baseGUID = packageData.wildWeasel.baseGUID })
  end
  if packageData.jammer and packageData.jammer.baseGUID then
    table.insert(supportBases, { role = "jammer", baseGUID = packageData.jammer.baseGUID })
  end

  -- If no support bases found, return default
  if #supportBases == 0 then
    Logger.log("dynamicOperations", "No support bases found for advance time calculation")
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  -- Find the furthest base
  local maxDistance = 0
  local furthestBase = nil

  local rp = packageData.escort.missionParams.opts.patrolZone[1]
  local point = GameApi.ScenEdit_GetReferencePoint({ side = 'China', name = rp })

  for _, base in ipairs(supportBases) do
    -- local distance = GameApi.Tool_Range(base.baseGUID, targetGUIDs[1])
    local distance = GameApi.Tool_Range(
      base.baseGUID, { latitude = point.latitude, longitude = point.longitude }
    )

    if distance and distance > maxDistance then
      maxDistance = distance
      furthestBase = base
    end
  end

  -- Validate distance calculation
  if not furthestBase or maxDistance <= 0 then
    Logger.log("dynamicOperations", "Invalid distance calculated between support bases and target")
    return TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  end

  local speed = TIME_CONSTANTS.MAX_SPEED

  if maxDistance >= TIME_CONSTANTS.MAX_DISTANCE then
    speed = TIME_CONSTANTS.MIN_SPEED
  end

  -- Calculate flight time: distance(nm) / speed(480 knots) * 3600 seconds
  local flightTime = (maxDistance / speed) * 3600

  Logger.log("dynamicOperations", string.format(
    "Calculated support advance time: %.1f minutes (%.1f nm distance from %s base)",
    flightTime / 60, maxDistance, furthestBase.role
  ))

  return math.ceil(flightTime) -- Round up to nearest second
end


---Calculate striker flight time to target
--- Computes flight time from striker base to target accounting for weapon range
---@param packageData table Package data containing striker baseGUID, weaponDBID, and target list
---@return number # Flight time in seconds from base to weapon release point
local function calculateStrikerFlightTime(packageData)
  if not packageData.striker or not packageData.striker.baseGUID or
      not packageData.target or not packageData.target.list or #packageData.target.list == 0 then
    Logger.log("dynamicOperations", "Invalid striker flight time calculation - using fallback duration")
    return TIME_CONSTANTS.MISSION_DURATION -- fallback to constant
  end

  local range = GameApi.ScenEdit_QueryDB('weapon', packageData.striker.weaponDBID).ranges.land.max
  local distance = GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1]) - range
  -- local distance = GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1])

  if not distance or distance <= 0 then
    Logger.log("dynamicOperations", "Invalid distance calculated for striker flight time - using fallback duration")
    return TIME_CONSTANTS.MISSION_DURATION -- fallback
  end

  local speed = TIME_CONSTANTS.MAX_SPEED

  if distance >= TIME_CONSTANTS.MAX_DISTANCE then
    speed = TIME_CONSTANTS.MIN_SPEED
  end

  -- Calculate flight time: distance(nm) / speed(480 knots) * 3600 seconds
  local flightTime = (distance / speed) * 3600

  Logger.log("dynamicOperations", string.format(
    "Calculated striker flight time: %.1f minutes (%.1f nm distance)",
    flightTime / 60, distance
  ))

  return math.ceil(flightTime)
end

---Calculate mission timing for a package
--- Determines striker start and end times based on support advance time and strike intervals
---@param packageData SBJ__PackageTemplate Package configuration with role and timing information
---@param packageIndex number Index of the package (1-based)
---@param previousPackage SBJ__PackageTemplate|nil Previous package for sequential timing, nil for first package
---@param strikeInterval number Time interval in seconds between consecutive strikes
---@return {strikerStart: string, strikerEnd: string} # Table with striker start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculatePackageTiming(packageData, packageIndex, previousPackage, strikeInterval)
  local timing = {}

  -- Calculate striker timing
  if not packageData.striker.startTime then
    if packageIndex == 1 then
      -- Check if there are support roles
      local hasSupportRoles = packageData.escort or packageData.wildWeasel or packageData.jammer
      local advanceTime = 0
      -- local flightTime = calculateStrikerFlightTime(packageData) * 2 / 3

      if hasSupportRoles then
        advanceTime = calculateSupportAdvanceTime(packageData)
      end

      ---@type string
      -- timing.strikerStart = os.date(
      --   "%Y-%m-%d %H:%M:%S",
      --   Utils.roundToNearestMinutes(
      --     GameApi.ScenEdit_CurrentTime() + (packageData.timeToReady or 5) + advanceTime + TIME_CONSTANTS.ELAPSED_TIME -
      --     flightTime,
      --     5
      --   )
      -- )
      timing.strikerStart = os.date("%Y-%m-%d %H:%M:%S",
        GameApi.ScenEdit_CurrentTime() + (packageData.timeToReady or 5) + advanceTime -
        (advanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0)
      )
    else
      if previousPackage and previousPackage.striker.startTime then
        local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
        timing.strikerStart = os.date("%Y-%m-%d %H:%M:%S", previousStartTime + strikeInterval)
      end
    end
  else
    -- Use existing startTime
    timing.strikerStart = packageData.striker.startTime
  end

  -- Calculate striker end time
  local strikerStartTime = Utils.parseDatetimeToTimestamp(timing.strikerStart)
  local missionDuration = packageData.tanker and TIME_CONSTANTS.TANKER_DURATION or TIME_CONSTANTS.MISSION_DURATION
  timing.strikerEnd = os.date("%Y-%m-%d %H:%M:%S", strikerStartTime + missionDuration)
  return timing
end


---Calculate support role timing (escort, wildWeasel, jammer, tanker)
--- Computes when support aircraft should launch to arrive before striker
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@param packageData SBJ__PackageTemplate Package data containing striker timing and role configurations
---@return {startTime: string, endTime: string} # Table with start/end times in "YYYY-MM-DD HH:MM:SS" format
local function calculateRoleTiming(role, packageData)
  local strikerTimestamp = Utils.parseDatetimeToTimestamp(packageData.striker.startTime)
  local timing = {}

  -- Calculate start time based on role
  local advanceTime = calculateRoleAdvanceTime(packageData, role)
  local maxAdvanceTime = calculateSupportAdvanceTime(packageData)

  -- local advanceTime = calculateSupportAdvanceTime(packageData)
  -- local flightTime = calculateStrikerFlightTime(packageData) * 2 / 3

  ---@type string
  -- timing.startTime = os.date("%Y-%m-%d %H:%M:%S", strikerTimestamp - advanceTime + (packageData.timeToReady or 5))
  -- timing.startTime = os.date(
  --   "%Y-%m-%d %H:%M:%S",
  --   Utils.roundToNearestMinutes(strikerTimestamp - advanceTime - TIME_CONSTANTS.ELAPSED_TIME + flightTime, 5)
  -- )
  timing.startTime = os.date(
    "%Y-%m-%d %H:%M:%S",
    strikerTimestamp - advanceTime + 61 + (packageData.timeToReady or 5) +
    (maxAdvanceTime >= TIME_CONSTANTS.MAX_FLIGHT_TIME and TIME_CONSTANTS.ELAPSED_TIME or 0)
  )

  local startTimestamp = Utils.parseDatetimeToTimestamp(timing.startTime)
  local strikerFlightTime = calculateStrikerFlightTime(packageData)
  local duration = maxAdvanceTime + strikerFlightTime + 10 * 60

  -- if role == 'escort' or role == 'wildWeasel' or role == 'jammer' then
  --   -- local onStationTimestemp = startTimestamp + advanceTime + 10 * 60
  --   local onStationTimestemp = startTimestamp + advanceTime
  --   timing.timeOnStation = os.date("%Y-%m-%d %H:%M:%S", onStationTimestemp)
  -- end

  timing.endTime = os.date("%Y-%m-%d %H:%M:%S",
    (role == "tanker") and (startTimestamp + duration - TIME_CONSTANTS.ELAPSED_TIME) or startTimestamp + duration
  )
  return timing
end

---Create a single package with proper timing
--- Converts package template to executable package with calculated timings for all roles
---@param packageData SBJ__PackageTemplate Package template configuration
---@param packageIndex number Index of the package (1-based)
---@param previousPackage SBJ__PackageTemplate|nil Previous package for sequential timing, nil for first package
---@param strikeInterval number Time interval in seconds between consecutive strikes
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
    if packageData[role] then
      if not packageData[role].startTime or not packageData[role].endTime then
        local roleTiming = calculateRoleTiming(role, packageData)

        if role ~= "tanker" then
          packageData[role].startTime = packageData[role].startTime or roleTiming.startTime
        end

        packageData[role].endTime = packageData[role].endTime or roleTiming.endTime

        if roleTiming.timeOnStation then
          packageData[role].timeOnStation = roleTiming.timeOnStation
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
    isFinished = false,
    striker = packageData.striker,
    escort = packageData.escort,
    wildWeasel = packageData.wildWeasel,
    jammer = packageData.jammer,
    tanker = packageData.tanker,
    reconUAV = packageData.reconUAV,
    target = packageData.target
  }
end

---Insert ATO wave into saveData maintaining data structure integrity
--- Creates new wave structure with all packages and registers it in the ATO system
---@param saveData SBJ__SaveData Persistent save data to insert wave into
---@param packageTemplate SBJ__WaveTemplate Wave template containing package configurations
---@param reconType string Reconnaissance type identifier used for wave naming
---@return boolean # true if wave was successfully inserted, false on failure
local function insertATOWave(saveData, packageTemplate, reconType)
  if not saveData.c.air.ATO then
    Logger.error("ATO structure not initialized")
    return false
  end

  local waveName = DynamicOperationsUtils.generateUniqueAirOperationName(
    packageTemplate.name,
    reconType,
    saveData
  )

  -- Create wave structure
  ---@type SBJ__Wave
  local newWave = {
    name = waveName,
    isActivated = true,
    isFirstWave = packageTemplate.isFirstWave or false,
    isFinished = false,
    hasLaunched = false,
    strikeInterval = packageTemplate.strikeInterval or 0,
    packages = {}
  }

  -- Process each package
  local previousPackage = nil
  for packageIndex, packageData in ipairs(packageTemplate.packages) do
    local newPackage = createPackageWithTiming(
      packageData,
      packageIndex,
      previousPackage,
      packageTemplate.strikeInterval or 0
    )

    table.insert(newWave.packages, newPackage)
    previousPackage = packageData
  end

  -- Insert into ATO and track
  saveData.c.air.ATO[waveName] = newWave
  DynamicOperationsUtils.registerGeneratedOperation("air", waveName, saveData)
  return true
end

---Process reconnaissance schedule and generate ATO waves for air operations
--- Checks recon schedule for triggered events and generates corresponding ATO waves
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing recon schedule
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@return boolean # true if any recon event was triggered and processed, false if none ready or failed
local function processReconSchedule(config, saveData, contacts)
  local reconSchedule = saveData.c.dynamicOperations.reconSchedule

  if not reconSchedule or #reconSchedule == 0 then
    Logger.log("dynamicOperations", "No reconnaissance schedule found")
    return false
  end

  -- Filter air operations that need processing
  local airOperations = DynamicOperationsUtils.filterOperationsByType(reconSchedule, "air")

  if #airOperations == 0 then
    Logger.log("dynamicOperations", "No air operations pending")
    return false
  end

  local anyProcessed = false
  local anyTriggered = false

  for _, item in ipairs(airOperations) do
    local reconEntry = item.reconEntry
    local operation = item.operation

    local scheduledTimestamp = Utils.parseDatetimeToTimestamp(reconEntry.time)

    if reconEntry.delay then
      scheduledTimestamp = scheduledTimestamp + reconEntry.delay
    end

    if GameUtils.isAfterStartTime(scheduledTimestamp) then
      anyTriggered = true
      Logger.log("dynamicOperations",
        "Air reconnaissance trigger activated: " ..
        reconEntry.type .. " at timestamp " ..
        tostring(scheduledTimestamp)
      )

      if operation.template then
        local validPackages = processATOTemplateWithValidation(
          config,
          saveData,
          contacts,
          operation.template,
          operation.template.isFirstWave
        )

        if #validPackages > 0 then
          local totalValidTargets = 0
          local modifiedTemplate = Utils.deepCopy(operation.template)
          modifiedTemplate.packages = {}

          for _, validPackage in ipairs(validPackages) do
            totalValidTargets = totalValidTargets + #(validPackage.target.list or {})
            table.insert(modifiedTemplate.packages, validPackage)
          end

          Logger.log("dynamicOperations",
            "Found " .. #validPackages .. " valid packages out of " ..
            #operation.template.packages .. " total packages (" ..
            totalValidTargets .. " targets)"
          )

          local success = insertATOWave(saveData, modifiedTemplate, reconEntry.type)

          if success then
            DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, true)
            anyProcessed = true
            Logger.log("dynamicOperations",
              "Dynamic ATO wave successfully inserted: " .. operation.template.name ..
              " with " .. #validPackages .. " packages"
            )
          else
            Logger.error("Failed to insert dynamic ATO wave: " .. operation.template.name)
          end
        else
          Logger.log("dynamicOperations", "No valid packages found, ATO generation skipped")
        end
      end
    end
  end

  -- Return false if no events were triggered (time not reached)
  if not anyTriggered then
    return false
  end

  return anyProcessed
end


---Main processing function for Dynamic ATO Insertion
--- Entry point for dynamic ATO system, validates configuration and processes recon schedule
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data with dynamic operations configuration
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@return boolean # true if processing completed successfully, false if disabled or failed
function DynamicATOInsertion.process(config, saveData, contacts)
  if not config or not saveData then
    Logger.error("Dynamic ATO Insertion: Invalid config or saveData")
    return false
  end

  -- Check if dynamicOperations is configured and enabled
  if not saveData.c.dynamicOperations then
    return false
  end

  if not saveData.c.dynamicOperations.enabled then
    Logger.log("dynamicOperations", "Dynamic Operations not enabled, skipping")
    return false
  end

  -- Update last evaluation time
  local currentTime = GameApi.ScenEdit_CurrentTime()

  if not currentTime then
    Logger.error("Failed to get current game time")
    return false
  end

  saveData.c.dynamicOperations.lastEvaluationTime = currentTime

  -- Process reconnaissance schedule
  return processReconSchedule(config, saveData, contacts)
end

return DynamicATOInsertion
