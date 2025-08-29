local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")

---@class DynamicATOInsertion
local DynamicATOInsertion = {}

-- Time constants
local TIME_CONSTANTS = {
  ESCORT_ADVANCE_TIME = 20 * 60, -- 護航提前20分鐘
  MISSION_DURATION = 40 * 60,    -- 一般任務持續40分鐘
  TANKER_DURATION = 120 * 60,    -- 加油機任務持續120分鐘
  TANKER_ADVANCE_TIME = 0 * 60   -- 加油機提前0分鐘
}

-- Local helper functions (private)


---Collect all currently assigned aircraft GUIDs from active ATO waves
---@param saveData SBJ__SaveData
---@return table<string, number> assignedAircraft Map of base GUID to assigned aircraft count
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
---@param baseGUID string The GUID of the air base
---@param requiredUnitDBID number The required aircraft unit database ID
---@return number availableCount Number of available aircraft of the specified type
local function getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
  -- Try to get the base unit
  local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)

  if not baseUnit then
    Logger.error("Cannot find air base with GUID: " .. tostring(baseGUID))
    return 0
  end

  if not baseUnit.embarkedUnits or not baseUnit.embarkedUnits.Aircraft then
    Logger.log("Air base " .. baseUnit.name .. " has no embarked aircraft")
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

  Logger.log(
    "Base " .. baseUnit.name .. " has " .. availableCount ..
    " available aircraft of type DBID " .. tostring(requiredUnitDBID)
  )

  return availableCount
end

---Check if individual package has sufficient targets and resources
---@param packageData table Package configuration
---@param packageTargets CMO__Contact[] Targets found for this package
---@param packageIndex number Index of the package
---@param assignedAircraft table<string, number> Currently assigned aircraft
---@return boolean isValid, string reason
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

  -- Check striker availability
  if packageData.striker then
    local baseGUID = packageData.striker.baseGUID
    local requiredCount = packageData.striker.unitCount or 0
    local assignedCount = assignedAircraft[baseGUID] or 0
    local requiredUnitDBID = packageData.striker.unitDBID

    local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
    if availableCount - assignedCount < requiredCount then
      return false, "Package " .. packageIndex .. " insufficient striker aircraft at base " ..
          (baseGUID or "unknown") .. " (available: " .. availableCount ..
          ", assigned: " .. assignedCount .. ", required: " .. requiredCount .. ")"
    end
  end

  -- Check escort availability
  if packageData.escort then
    local baseGUID = packageData.escort.baseGUID
    local requiredCount = packageData.escort.unitCount or 0
    local assignedCount = assignedAircraft[baseGUID] or 0
    local requiredUnitDBID = packageData.escort.unitDBID

    local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
    if availableCount - assignedCount < requiredCount then
      return false, "Package " .. packageIndex .. " insufficient escort aircraft at base " ..
          (baseGUID or "unknown") .. " (available: " .. availableCount ..
          ", assigned: " .. assignedCount .. ", required: " .. requiredCount .. ")"
    end
  end

  -- Check wildWeasel availability
  if packageData.wildWeasel then
    local baseGUID = packageData.wildWeasel.baseGUID
    local requiredCount = packageData.wildWeasel.unitCount or 0
    local assignedCount = assignedAircraft[baseGUID] or 0
    local requiredUnitDBID = packageData.wildWeasel.unitDBID

    local availableCount = getBaseAircraftCapacity(baseGUID, requiredUnitDBID)
    if availableCount - assignedCount < requiredCount then
      return false, "Package " .. packageIndex .. " insufficient SEAD aircraft at base " ..
          (baseGUID or "unknown") .. " (available: " .. availableCount ..
          ", assigned: " .. assignedCount .. ", required: " .. requiredCount .. ")"
    end
  end

  return true, "Package " .. packageIndex .. " validated successfully"
end


---Process dynamic targets using filter functions
---@param packageData table Package configuration
---@param contacts CMO__Contact[] Available contacts
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param packageIndex number Package index for logging
---@return CMO__Contact[] targets
local function processDynamicTargets(packageData, contacts, config, saveData, packageIndex)
  local strikeTargets = {}

  Logger.log(
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
        Logger.log("Package " .. packageIndex .. " filter " .. filterName .. " found " .. #targets .. " targets")
      end
    else
      Logger.error("Unknown target filtering function: " .. filterName)
    end
  end

  return strikeTargets
end

---Process fixed targets using BDA assessment
---@param packageData table Package configuration
---@param saveData SBJ__SaveData
---@param isFirstWave boolean
---@param packageIndex number Package index for logging
---@return CMO__Contact[] targets
local function processFixedTargets(packageData, saveData, isFirstWave, packageIndex)
  local strikeTargets = {}

  Logger.log("Package " .. packageIndex .. " using fixed target list for BDA assessment")

  if not packageData.target.objs then
    return strikeTargets
  end

  local filteredTargets = TargetingProcess.selectTargetsByQueryParams({
    targetlist = saveData.c.targetlist,
    queryParams = packageData.target.objs
  })

  if filteredTargets and #filteredTargets > 0 then
    Logger.log("Package " .. packageIndex .. " filtered " .. #filteredTargets .. " candidate targets")
    local task = { target = { list = filteredTargets, contactAge = packageData.target.contactAge } }
    strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
  end

  return strikeTargets
end

---Process targets for a single package
---@param packageData table Package configuration
---@param contacts CMO__Contact[] Available contacts
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param isFirstWave boolean
---@param packageIndex number Package index for logging
---@return CMO__Contact[] targets Found targets for this package
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
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param atoTemplate SBJ__ATOTemplate
---@param isFirstWave boolean
---@return table validPackages Array of valid packages with targets
local function processATOTemplateWithValidation(config, saveData, contacts, atoTemplate, isFirstWave)
  local copyPackages = Utils.deepCopy(atoTemplate.packages)
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
      Logger.log("Package " .. packageIndex .. " validated: " .. #strikeTargets .. " targets, " .. reason)
    else
      Logger.log("Package " .. packageIndex .. " skipped: " .. reason)
    end
  end

  return validPackages
end

---Generate unique wave name with dynamic prefix
---@param waveType string Type of the wave (e.g., "STRIKE", "SEAD")
---@param saveData SBJ__SaveData
---@return string uniqueWaveName
local function generateDynamicWaveName(waveType, saveData)
  local sequence = 1
  local baseName = "DYNAMIC/SATELLITE/" .. waveType

  if not saveData.c.air.dynamicATO.generatedWaves then
    saveData.c.air.dynamicATO.generatedWaves = {}
  end

  -- Find next available sequence number
  local waveName
  repeat
    waveName = baseName .. "/" .. sequence
    sequence = sequence + 1
  until not saveData.c.air.dynamicATO.generatedWaves[waveName] and not saveData.c.air.ATO[waveName]

  return waveName
end

---Calculate mission timing for a package
---@param packageData table Package configuration
---@param packageIndex number Index of the package
---@param previousPackage SBJ__ATOPackage|nil Previous package for timing reference
---@param strikeInterval number Interval between strikes
---@return table timingData Calculated timing information
local function calculatePackageTiming(packageData, packageIndex, previousPackage, strikeInterval)
  local timing = {}

  -- Calculate striker timing
  if not packageData.striker.startTime then
    if packageIndex == 1 then
      -- 檢查是否有支援角色
      local hasSupportRoles = packageData.escort or packageData.wildWeasel or packageData.jammer
      local advanceTime = hasSupportRoles and TIME_CONSTANTS.ESCORT_ADVANCE_TIME or 0

      ---@type string
      timing.strikerStart = os.date(
        "%Y-%m-%d %H:%M:%S",
        Utils.roundToNearestMinutes(
          GameApi.ScenEdit_CurrentTime() + (packageData.timeToReady or 5) + advanceTime,
          5
        )
      )
    else
      local previousStartTime = Utils.parseDatetimeToTimestamp(previousPackage.striker.startTime)
      timing.strikerStart = os.date("%Y-%m-%d %H:%M:%S", previousStartTime + strikeInterval)
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
---@param strikerStartTime string Striker start time
---@param role string Role name
---@return table roleTiming Start and end times for the role
local function calculateRoleTiming(strikerStartTime, role)
  local strikerTimestamp = Utils.parseDatetimeToTimestamp(strikerStartTime)
  local timing = {}

  -- Calculate start time based on role
  local advanceTime = (role == "tanker") and TIME_CONSTANTS.TANKER_ADVANCE_TIME or TIME_CONSTANTS.ESCORT_ADVANCE_TIME
  ---@type string
  timing.startTime = os.date("%Y-%m-%d %H:%M:%S", strikerTimestamp - advanceTime)

  -- Calculate end time based on role
  local startTimestamp = Utils.parseDatetimeToTimestamp(timing.startTime)
  local duration = (role == "tanker") and TIME_CONSTANTS.TANKER_DURATION or TIME_CONSTANTS.MISSION_DURATION
  timing.endTime = os.date("%Y-%m-%d %H:%M:%S", startTimestamp + duration)

  return timing
end

---Create a single package with proper timing
---@param packageData table Package configuration
---@param packageIndex number Index of the package
---@param previousPackage table|nil Previous package for timing reference
---@param strikeInterval number Interval between strikes
---@return SBJ__Package newPackage Created package
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
        local roleTiming = calculateRoleTiming(packageData.striker.startTime, role)
        packageData[role].startTime = packageData[role].startTime or roleTiming.startTime
        packageData[role].endTime = packageData[role].endTime or roleTiming.endTime
      end
    end
  end

  -- Create package structure
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
---@param saveData SBJ__SaveData
---@param packageTemplate SBJ__ATOTemplate
---@return boolean success
local function insertATOWave(saveData, packageTemplate)
  if not saveData.c.air.ATO then
    Logger.error("ATO structure not initialized")
    return false
  end

  local waveName = generateDynamicWaveName(packageTemplate.targetType, saveData)

  -- Create wave structure
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
  saveData.c.air.dynamicATO.generatedWaves[waveName] = true
  return true
end

---Process reconnaissance schedule and generate ATO waves
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@return boolean success True if any recon event was processed successfully, false otherwise
local function processReconSchedule(config, saveData, contacts)
  local reconSchedule = saveData.c.air.dynamicATO.reconSchedule
  if not reconSchedule or #reconSchedule == 0 then
    Logger.log("No reconnaissance schedule found")
    return false
  end

  local anyProcessed = false
  local anyTriggered = false

  for _, reconEvent in ipairs(reconSchedule) do
    if not reconEvent.executed then
      local scheduledTimestamp = Utils.parseDatetimeToTimestamp(reconEvent.time)

      if reconEvent.delay then
        scheduledTimestamp = scheduledTimestamp + reconEvent.delay
      end

      if GameUtils.isAfterStartTime(scheduledTimestamp) then
        anyTriggered = true
        Logger.log(
          "Reconnaissance trigger activated: " ..
          reconEvent.type .. " at timestamp " ..
          tostring(scheduledTimestamp)
        )

        if reconEvent.packageTemplate then
          local validPackages = processATOTemplateWithValidation(
            config,
            saveData,
            contacts,
            reconEvent.packageTemplate,
            reconEvent.packageTemplate.isFirstWave
          )

          if #validPackages > 0 then
            local totalValidTargets = 0
            local modifiedTemplate = Utils.deepCopy(reconEvent.packageTemplate)
            modifiedTemplate.packages = {}

            for _, validPackage in ipairs(validPackages) do
              totalValidTargets = totalValidTargets + #(validPackage.target.list or {})
              table.insert(modifiedTemplate.packages, validPackage)
            end

            Logger.log(
              "Found " .. #validPackages .. " valid packages out of " ..
              #reconEvent.packageTemplate.packages .. " total packages (" ..
              totalValidTargets .. " targets)"
            )

            local success = insertATOWave(saveData, modifiedTemplate)

            if success then
              reconEvent.executed = true
              anyProcessed = true
              Logger.log(
                "Dynamic ATO wave successfully inserted: " .. reconEvent.packageTemplate.name ..
                " with " .. #validPackages .. " packages"
              )
            else
              Logger.error("Failed to insert dynamic ATO wave: " .. reconEvent.packageTemplate.name)
            end
          else
            Logger.log("No valid packages found, ATO generation skipped")
          end
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
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@return boolean success True if processing was successful, false otherwise
function DynamicATOInsertion.process(config, saveData, contacts)
  if not config or not saveData then
    Logger.error("Dynamic ATO Insertion: Invalid config or saveData")
    return false
  end

  -- Check if dynamicATO is configured and enabled
  if not saveData.c.air.dynamicATO then
    return false
  end

  if not saveData.c.air.dynamicATO.enabled then
    Logger.log("Dynamic ATO not enabled, skipping")
    return false
  end

  -- Update last evaluation time
  local currentTime = GameApi.ScenEdit_CurrentTime()

  if not currentTime then
    Logger.error("Failed to get current game time")
    return false
  end

  saveData.c.air.dynamicATO.lastEvaluationTime = currentTime

  -- Process reconnaissance schedule
  return processReconSchedule(config, saveData, contacts)
end

return DynamicATOInsertion
