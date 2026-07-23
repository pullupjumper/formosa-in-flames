local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local AssignMission = require("src.modules.assignMission")
local Recon = require("src.modules.strikePlanner.recon")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local constants = require("src.core.constants")

local AirTaskingOrder = {}

local LOADOUT_ROLES = { "tanker", "striker", "escort", "wildWeasel", "jammer", }
local ATO_OUTCOME = {
  OK = "ok",
  SKIP = "skip",
  FAIL = "fail",
  ERROR = "error"
}

---@alias SBJ__ATOPackageProcessOutcome
---| "ok"
---| "skip"
---| "fail"
---| "error"

---@class SBJ__ATOPackageProcessResult
---@field outcome SBJ__ATOPackageProcessOutcome Processing outcome used for log classification
---@field missionName string Strike mission name used as log identity
---@field waveName? string Wave name added by processWave before log emission
---@field action? string Successful action token, such as "initiate_loadout" or "launch"
---@field reason? string Failure or skip reason token
---@field readyTime? string UTC ready time for loadout completion
---@field reconUavTakeoff? string UTC recon UAV takeoff time when scheduled
---@field targets? integer Number of targets available or assigned
---@field required? integer Minimum target count required

-- ============================================================================
-- Loadout Timing
-- ============================================================================

---Calculate the start time for weapon loading
---@param packageData SBJ__Package The strike package containing flight group data
---@return number|nil # Unix timestamp for when loadout should start, or nil if cannot be calculated
local function calculateLoadoutStartTime(packageData)
  local earliestStartTime = nil

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole and missionRole.startTime then
      local startTimeTimestamp = Utils.parseDatetimeToTimestamp(missionRole.startTime)
      if not earliestStartTime or startTimeTimestamp < earliestStartTime then
        earliestStartTime = startTimeTimestamp
      end
    end
  end

  if not earliestStartTime then
    return nil
  end

  local timeToReady = packageData.timeToReady or (9 * 60)
  return earliestStartTime - timeToReady
end

---Ensure loadout start time is calculated and cached
---@param packageData SBJ__Package The strike package to initialize
local function ensureLoadoutStartTime(packageData)
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    return
  end

  if not loadoutStatus.loadoutStartTime then
    loadoutStatus.loadoutStartTime = calculateLoadoutStartTime(packageData)
  end
end

---Check if it's time to start weapon loading
---@param packageData SBJ__Package The strike package to check
---@param assignmentSafetyMargin number Seconds reserved before planned takeoff
---@return boolean # True if current time has reached or passed the loadout start time
local function isTimeToStartLoadout(packageData, assignmentSafetyMargin)
  local loadoutStatus = packageData.loadoutStatus
  if not (loadoutStatus and loadoutStatus.loadoutStartTime) then
    return false
  end

  return GameUtils.isAfterStartTime(loadoutStatus.loadoutStartTime, assignmentSafetyMargin)
end

-- ============================================================================
-- Loadout Execution
-- ============================================================================

---Set loadout for a single role's aircraft at their base
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param timeToReady number Time to ready in seconds
local function setLoadoutForRole(missionRole, timeToReady)
  local loadoutID = missionRole.loadoutID
  local unitCount = missionRole.unitCount
  local targetUnitDBID = missionRole.unitDBID

  if not targetUnitDBID then
    return
  end

  local base = GameApi.ScenEdit_GetUnit(missionRole.baseGUID)
  if not (base and #base.embarkedUnits.Aircraft > 0) then
    return
  end

  local unitsProcessed = 0

  for _, unitGUID in ipairs(base.embarkedUnits.Aircraft) do
    if unitsProcessed >= unitCount then
      break
    end

    local unit = GameApi.ScenEdit_GetUnit(unitGUID)
    if unit and unit.dbid == targetUnitDBID and unit.mission == nil then
      local result = GameApi.ScenEdit_SetLoadout({
        unitname = unit.name,
        LoadoutID = loadoutID,
        TimeToReady_Minutes = timeToReady / 60
      })

      if result then
        unitsProcessed = unitsProcessed + 1
      end
    end
  end
end

---Set weapon loadouts for all flight groups and update loadout status
---@param packageData SBJ__Package The strike package containing flight group configurations
local function initiateLoadoutForPackage(packageData)
  local timeToReady = packageData.timeToReady or (9 * 60)

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole and missionRole.loadoutID then
      setLoadoutForRole(missionRole, timeToReady)
    end
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local loadoutStatus = packageData.loadoutStatus
  loadoutStatus.isLoadoutInitiated = true
  loadoutStatus.loadoutInitiatedTime = currentTime
  loadoutStatus.expectedReadyTime = currentTime + timeToReady
end

---Check if weapon loading is complete
---@param packageData SBJ__Package The strike package to check
---@return boolean # True if loadout has been initiated and expected ready time has passed
local function isLoadoutReady(packageData)
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    return false
  end

  if not (loadoutStatus.isLoadoutInitiated and loadoutStatus.expectedReadyTime) then
    return false
  end

  return GameUtils.isAfterStartTime(loadoutStatus.expectedReadyTime, 5)
end

-- ============================================================================
-- Mission Creation
-- ============================================================================

---Create one unscheduled mission for a package role
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param missionCreationParams SBJ__MissionCreationParams Mission creation parameters
---@return CMO__Mission|nil # Created mission object, or nil on failure
local function createMission(missionRole, missionCreationParams)
  local mission = GameUtils.createMission(
    constants.SIDES.ENEMY,
    missionCreationParams.name,
    missionCreationParams.type,
    missionCreationParams.opts,
    missionRole.emcon
  )

  if mission and missionCreationParams.type == "strike" then
    GameApi.ScenEdit_SetDoctrine(
      { side = constants.SIDES.ENEMY, mission = mission.name },
      { automatic_evasion = false }
    )
  end

  return mission
end

---Apply one role schedule after aircraft assignment has completed
---@param mission CMO__Mission Mission object to schedule
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
local function applyMissionSchedule(mission, missionRole)
  mission.OnDeactivateDelete = true
  mission.OnDeactivateRTB = true

  if missionRole.endTime then
    mission.endtime = missionRole.endTime .. constants.TIME_FORMATS
  end

  if missionRole.timeOnStation then
    mission.TakeOffTime = nil
    mission.TimeOnTargetStation = missionRole.timeOnStation .. constants.TIME_FORMATS
  elseif missionRole.startTime then
    mission.TimeOnTargetStation = nil
    mission.TakeOffTime = missionRole.startTime .. constants.TIME_FORMATS
  end
end

-- ============================================================================
-- Target Assignment
-- ============================================================================

---Assign targets to strike mission
---@param packageData SBJ__Package Package data with target list
---@return boolean # True if targets successfully assigned
local function assignTargetsToMission(packageData)
  local evaluatedTargetlist = packageData.target.list
  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    evaluatedTargetlist,
    packageData.striker.missionCreationParams.name
  )
  return targetsAssigned ~= nil
end

-- ============================================================================
-- Unit Assignment
-- ============================================================================

---Assign units from one role to one mission
---@param missionRole SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param missionName string Mission name
---@param unitCount integer Number of units to assign
---@return string[]|nil # Assigned unit GUIDs
local function assignRoleUnitsToMission(missionRole, missionName, unitCount)
  return AssignMission.assignEmbarkedUnitToStrikeMission(
    missionRole.baseGUID,
    unitCount,
    missionRole.weaponDBID,
    missionRole.unitDBID,
    missionName,
    false
  )
end

---Assign tanker units evenly across all configured tanker missions
---@param missionRole SBJ__TankerMissionDeploymentDescriptor Tanker deployment descriptor
local function assignTankerUnits(missionRole)
  local missionParamsList = TankerMission.normalizeCreationParams(missionRole.missionCreationParams)
  local missionCount = #missionParamsList

  if missionCount == 0 or missionRole.unitCount % missionCount ~= 0 then
    return
  end

  local unitCountPerMission = missionRole.unitCount / missionCount

  for _, missionParams in ipairs(missionParamsList) do
    assignRoleUnitsToMission(missionRole, missionParams.name, unitCountPerMission)
  end
end

---Assigns all units in the package to their respective missions
---@param packageData SBJ__Package The strike package containing unit assignment data
---@return boolean # True if the primary striker units were successfully assigned
local function assignUnits(packageData)
  local strikerAssigned = false

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole then
      if role == "tanker" then
        assignTankerUnits(missionRole --[[@as SBJ__TankerMissionDeploymentDescriptor]])
      else
        local result = assignRoleUnitsToMission(
          missionRole,
          missionRole.missionCreationParams.name,
          missionRole.unitCount
        )

        if role ~= "striker" then
          GameApi.ScenEdit_CreateMissionFlightPlan(constants.SIDES.ENEMY, missionRole.missionCreationParams.name, {})
        end

        if role == "striker" and result and #result > 0 then
          strikerAssigned = true
        end
      end
    end
  end

  return strikerAssigned
end

-- ============================================================================
-- Recon UAV Scheduling
-- ============================================================================

---Schedule reconnaissance UAV if configured in package
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param packageData SBJ__Package Package data with optional reconUAV
---@return SBJ__ReconQueueEntryUAV|nil # The inserted entry, or nil if no entry was inserted
local function scheduleReconUAV(config, saveData, packageData)
  if not packageData.reconUAV then
    return
  end

  if not packageData.reconUAV.takeoffTime then
    local _, flightTime = GameUtils.calculatePathDistanceAndTime(packageData.reconUAV.course, packageData.reconUAV.speed)
    local takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) + config.c.ground.srbm.reloadTime -
        flightTime
    local takeoffTimeStr = os.date(constants.DATE_FORMAT, takeoffTime) --[[@as string]]
    return Recon.insertEntry(saveData.c.recon, packageData.reconUAV, takeoffTimeStr)
  end

  return nil
end

-- ============================================================================
-- Package Lifecycle
-- ============================================================================

---Find the earliest departing flight group
---@param packageData SBJ__Package The strike package containing flight groups
---@return SBJ__MissionDeploymentDescriptor|nil # The flight group with the earliest start time
local function findEarliestRole(packageData)
  local earliestRole = nil
  local earliestTime = nil

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole and missionRole.startTime then
      local startTime = Utils.parseDatetimeToTimestamp(missionRole.startTime)
      if not earliestTime or startTime < earliestTime then
        earliestTime = startTime
        earliestRole = missionRole
      end
    end
  end

  return earliestRole
end

---Create all missions for a package, abort if striker creation fails
---@param packageData SBJ__Package Package data
---@return boolean success True if all critical missions created successfully
---@return table<string, CMO__Mission> missions Created missions indexed by mission name
local function createAllMissions(packageData)
  local missions = {}

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole then
      if role == "tanker" then
        local tankerMissionParams = TankerMission.normalizeCreationParams(missionRole.missionCreationParams)

        for _, missionCreationParams in ipairs(tankerMissionParams) do
          local mission = createMission(missionRole, missionCreationParams)
          if mission then
            missions[missionCreationParams.name] = mission
          end
        end
      else
        local mission = createMission(missionRole, missionRole.missionCreationParams)

        if role == "striker" and not mission then
          return false, missions
        end

        if mission then
          missions[missionRole.missionCreationParams.name] = mission
        end
      end
    end
  end

  return true, missions
end

---Apply schedules to all created missions after unit assignment
---@param packageData SBJ__Package Package data
---@param missions table<string, CMO__Mission> Created missions indexed by mission name
local function applyPackageMissionSchedules(packageData, missions)
  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole then
      local missionParamsList = role == "tanker" and
          TankerMission.normalizeCreationParams(missionRole.missionCreationParams) or
          { missionRole.missionCreationParams }

      for _, missionCreationParams in ipairs(missionParamsList) do
        local mission = missions[missionCreationParams.name]
        if mission then
          applyMissionSchedule(mission, missionRole)
        end
      end
    end
  end
end

---Processes a single strike package through its complete lifecycle
---Returns structured status for centralized logging in the public API
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO state
---@param packageData SBJ__Package The strike package data to process
---@return boolean launched Whether package was successfully launched
---@return SBJ__ATOPackageProcessResult|nil result Processed package result, or nil when nothing should be logged
local function processPackage(config, saveData, packageData)
  if not packageData.target.list or #packageData.target.list == 0 then
    return false, {
      outcome = ATO_OUTCOME.SKIP,
      missionName = packageData.striker.missionCreationParams.name,
      reason = "invalid_package_targets",
      targets = 0,
      required = packageData.target.minTargetCount
    }
  end

  ensureLoadoutStartTime(packageData)
  local assignmentSafetyMargin = config.c.air and config.c.air.timing and
      config.c.air.timing.assignmentSafetyMargin or (5 * 60)

  if not isTimeToStartLoadout(packageData, assignmentSafetyMargin) then
    return false, nil
  end

  if not packageData.loadoutStatus.isLoadoutInitiated then
    initiateLoadoutForPackage(packageData)
    local readyTimeStr = os.date(constants.DATE_FORMAT, packageData.loadoutStatus.expectedReadyTime)
    return false, {
      outcome = ATO_OUTCOME.OK,
      missionName = packageData.striker.missionCreationParams.name,
      action = "initiate_loadout",
      readyTime = readyTimeStr
    }
  end

  if not isLoadoutReady(packageData) then
    return false, nil
  end

  local earliestRole = findEarliestRole(packageData)
  if not (earliestRole and GameUtils.isAfterStartTime(earliestRole.startTime, assignmentSafetyMargin)) then
    return false, nil
  end

  local missionsCreated, missions = createAllMissions(packageData)
  if not missionsCreated then
    return false, {
      outcome = ATO_OUTCOME.FAIL,
      missionName = packageData.striker.missionCreationParams.name,
      reason = "striker_mission_creation_failed"
    }
  end

  if not assignTargetsToMission(packageData) then
    local targetList = packageData.target.list

    return false, {
      outcome = ATO_OUTCOME.FAIL,
      missionName = packageData.striker.missionCreationParams.name,
      reason = "target_assignment_failed",
      targets = #targetList,
      required = packageData.target.minTargetCount
    }
  end

  if not assignUnits(packageData) then
    return false, {
      outcome = ATO_OUTCOME.FAIL,
      missionName = packageData.striker.missionCreationParams.name,
      reason = "striker_assignment_failed"
    }
  end

  applyPackageMissionSchedules(packageData, missions)
  local reconUAVEntry = scheduleReconUAV(config, saveData, packageData)

  ---@type SBJ__ATOPackageProcessResult
  local result = {
    outcome = ATO_OUTCOME.OK,
    missionName = packageData.striker.missionCreationParams.name,
    action = "launch",
    targets = #packageData.target.list
  }

  if reconUAVEntry then
    result.reconUavTakeoff = reconUAVEntry.takeoffTime
  end

  return true, result
end

-- ============================================================================
-- Wave Management
-- ============================================================================

---Checks if all packages in a wave have been launched
---@param waveData SBJ__Wave The wave containing multiple strike packages
---@return boolean # True if all packages in the wave have been launched
local function isWaveFinished(waveData)
  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      return false
    end
  end
  return true
end

---Process packages in a wave, launching at most one per tick
---Returns processed package results for centralized logging in the public API
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data
---@param waveName string The wave identifier used for logging
---@param waveData SBJ__Wave The wave containing strike packages
---@return SBJ__ATOPackageProcessResult[] # Processed package results from this wave
local function processWave(config, saveData, waveName, waveData)
  ---@type SBJ__ATOPackageProcessResult[]
  local processedResults = {}

  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      local launched, result = processPackage(config, saveData, packageData)

      if launched then
        packageData.hasLaunched = true
      end

      if result then
        result.waveName = waveName
        table.insert(processedResults, result)
      end

      if launched then
        break
      end
    end
  end

  return processedResults
end

---Append optional target count fields to a log message
---@param message string Base log message
---@param result SBJ__ATOPackageProcessResult Processed package result
---@return string # Log message with target fields when present
local function appendTargetFields(message, result)
  if result.targets ~= nil then
    message = message .. string.format(" targets=%d", result.targets)
  end

  if result.required ~= nil then
    message = message .. string.format(" required=%d", result.required)
  end

  return message
end

---Format one processed ATO package result into a log line
---@param result SBJ__ATOPackageProcessResult Processed package result
---@return string level Log entry level
---@return string message Log-safe package result message
local function formatProcessedResultLine(result)
  local prefix = string.format(
    "wave=%s mission=%s",
    LogFormat.value(result.waveName or "unknown"),
    LogFormat.value(result.missionName or "unknown")
  )

  if result.outcome == ATO_OUTCOME.OK then
    local msg = string.format("%s action=%s", prefix, LogFormat.value(result.action or "unknown"))

    if result.readyTime then
      msg = msg .. string.format(" readyTime=%q", result.readyTime)
    end

    msg = appendTargetFields(msg, result)

    if result.reconUavTakeoff then
      msg = msg .. string.format(" reconUavTakeoff=%q", result.reconUavTakeoff)
    end

    return "OK", msg
  end

  local msg = string.format(
    "%s reason=%s",
    prefix,
    LogFormat.value(result.reason or "unknown")
  )
  msg = appendTargetFields(msg, result)

  if result.outcome == ATO_OUTCOME.SKIP then
    return "SKIP", msg
  end

  if result.outcome == ATO_OUTCOME.ERROR then
    return "ERROR", msg
  end

  return "FAIL", msg
end

---Emit consolidated logs for processed ATO package results
---@param processedResults SBJ__ATOPackageProcessResult[] Processed package results accumulated in one tick
local function emitProcessedResultsLog(processedResults)
  if #processedResults == 0 then
    return
  end

  local infoLines = {}
  local errorLines = {}

  for _, result in ipairs(processedResults) do
    local level, message = formatProcessedResultLine(result)
    local line = LogFormat.entry(level, message)

    if level == "ERROR" or level == "FAIL" then
      table.insert(errorLines, line)
    else
      table.insert(infoLines, line)
    end
  end

  if #infoLines > 0 then
    Logger.log(constants.TAGS.AIR, LogFormat.summary(
      "scope", "airTaskingOrder", "Execute packages", infoLines))
  end

  if #errorLines > 0 then
    Logger.error(LogFormat.summary(
      "scope", "airTaskingOrder", "Execute packages", errorLines))
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---The main entry point for air strikes
---Iterates through ATO waves and packages, processing each strike package sequentially
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO waves and packages
function AirTaskingOrder.airStrike(config, saveData)
  ---@type SBJ__ATOPackageProcessResult[]
  local processedResults = {}

  for waveName, waveData in pairs(saveData.c.air.airTaskingOrder) do
    if waveData.isActivated and not waveData.hasLaunched then
      local waveResults = processWave(config, saveData, waveName, waveData)

      for _, result in ipairs(waveResults) do
        table.insert(processedResults, result)
      end

      if isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end

  emitProcessedResultsLog(processedResults)
end

return AirTaskingOrder
