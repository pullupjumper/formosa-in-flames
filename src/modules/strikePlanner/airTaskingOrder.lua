local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local AssignMission = require("src.modules.assignMission")
local Recon = require("src.modules.strikePlanner.recon")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local constants = require("src.core.constants")

local AirTaskingOrder = {}

-- Tanker missions must be prepared before receiver missions.
local PACKAGE_ROLE_ORDER = { "tanker", "striker", "escort", "wildWeasel", "jammer" }

-- Scope and action values for the report this module emits
local LOG_SCOPE = "airTaskingOrder"
local LOG_ACTION = "Execute packages"

-- ============================================================================
-- Loadout Timing
-- ============================================================================

---Calculate the start time for weapon loading
---@param packageData SBJ__Package The strike package containing flight group data
---@return number|nil # Unix timestamp for when loadout should start, or nil if cannot be calculated
local function calculateLoadoutStartTime(packageData)
  local earliestStartTimestamp = nil

  for _, role in ipairs(PACKAGE_ROLE_ORDER) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]

    if roleData and roleData.startTime then
      local startTimeTimestamp = Utils.parseDatetimeToTimestamp(roleData.startTime)
      if not earliestStartTimestamp or startTimeTimestamp < earliestStartTimestamp then
        earliestStartTimestamp = startTimeTimestamp
      end
    end
  end

  if not earliestStartTimestamp then
    return nil
  end

  local timeToReady = packageData.timeToReady or (9 * 60)
  return earliestStartTimestamp - timeToReady
end

---Ensure loadout start time is calculated and cached
---@param packageData SBJ__Package The strike package to initialize
local function ensureLoadoutStartTime(packageData)
  local loadoutStatus = packageData.loadoutStatus
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
  if not loadoutStatus.loadoutStartTime then
    return false
  end

  return GameUtils.isAfterStartTime(loadoutStatus.loadoutStartTime, assignmentSafetyMargin)
end

---Resolve the assignment safety margin with legacy fallback
---@param config SBJ__Config Global configuration
---@return number # Assignment safety margin in seconds
local function resolveAssignmentSafetyMargin(config)
  local airConfig = config.c.air
  local timingConfig = airConfig and airConfig.timing
  return timingConfig and timingConfig.assignmentSafetyMargin or (5 * 60)
end

-- ============================================================================
-- Loadout Execution
-- ============================================================================

---Set loadout for a single role's aircraft at their base
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param timeToReady number Time to ready in seconds
local function setLoadoutForRole(roleData, timeToReady)
  local loadoutID = roleData.loadoutID
  local unitCount = roleData.unitCount
  local requiredUnitDBID = roleData.unitDBID

  if not requiredUnitDBID then
    return
  end

  local baseUnit = GameApi.ScenEdit_GetUnit(roleData.baseGUID)
  if not (baseUnit and #baseUnit.embarkedUnits.Aircraft > 0) then
    return
  end

  local processedUnitCount = 0

  for _, unitGUID in ipairs(baseUnit.embarkedUnits.Aircraft) do
    if processedUnitCount >= unitCount then
      break
    end

    local unit = GameApi.ScenEdit_GetUnit(unitGUID)
    if unit and unit.dbid == requiredUnitDBID and unit.mission == nil then
      local loadoutUpdated = GameApi.ScenEdit_SetLoadout({
        unitname = unit.name,
        LoadoutID = loadoutID,
        TimeToReady_Minutes = timeToReady / 60
      })

      if loadoutUpdated then
        processedUnitCount = processedUnitCount + 1
      end
    end
  end
end

---Set weapon loadouts for all flight groups and update loadout status
---@param packageData SBJ__Package The strike package containing flight group configurations
local function initiateLoadoutForPackage(packageData)
  local timeToReady = packageData.timeToReady or (9 * 60)

  for _, role in ipairs(PACKAGE_ROLE_ORDER) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]

    if roleData and roleData.loadoutID then
      setLoadoutForRole(roleData, timeToReady)
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
  if not (loadoutStatus.isLoadoutInitiated and loadoutStatus.expectedReadyTime) then
    return false
  end

  return GameUtils.isAfterStartTime(loadoutStatus.expectedReadyTime, 5)
end

-- ============================================================================
-- Mission Creation
-- ============================================================================

---Create one unscheduled mission for a package role
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param missionCreationParams SBJ__MissionCreationParams Mission creation parameters
---@return CMO__Mission|nil # Created mission object, or nil on failure
local function createPackageMission(roleData, missionCreationParams)
  local mission = GameUtils.createMission(
    constants.SIDES.ENEMY,
    missionCreationParams.name,
    missionCreationParams.type,
    missionCreationParams.opts,
    roleData.emcon
  )

  if mission and missionCreationParams.type == "strike" then
    GameApi.ScenEdit_SetDoctrine(
      { side = constants.SIDES.ENEMY, mission = mission.name },
      { automatic_evasion = false }
    )
  end

  return mission
end

---Store a created mission by its configured name
---@param createdMissions table<string, CMO__Mission> Mission registry
---@param missionCreationParams SBJ__MissionCreationParams Mission creation parameters
---@param mission CMO__Mission|nil Created mission, if any
local function storeCreatedMission(createdMissions, missionCreationParams, mission)
  if not mission then
    return
  end

  createdMissions[missionCreationParams.name] = mission
end

---Create and register all missions configured for a tanker role
---@param roleData SBJ__TankerMissionDeploymentDescriptor Tanker deployment descriptor
---@param createdMissions table<string, CMO__Mission> Mission registry
local function createTankerMissions(roleData, createdMissions)
  local missionParamsList = TankerMission.normalizeCreationParams(roleData.missionCreationParams)

  for _, missionCreationParams in ipairs(missionParamsList) do
    local mission = createPackageMission(roleData, missionCreationParams)
    storeCreatedMission(createdMissions, missionCreationParams, mission)
  end
end

---Create and register one non-tanker role mission
---@param role string Package role name
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param createdMissions table<string, CMO__Mission> Mission registry
---@return boolean # True when mission creation may continue
local function createNonTankerMission(role, roleData, createdMissions)
  local missionCreationParams = roleData.missionCreationParams
  local mission = createPackageMission(roleData, missionCreationParams)
  storeCreatedMission(createdMissions, missionCreationParams, mission)

  if role == "striker" and not mission then
    return false
  end

  return true
end

---Create missions for one package role
---@param role string Package role name
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param createdMissions table<string, CMO__Mission> Mission registry
---@return boolean # True when critical mission creation succeeded
local function createMissionsForRole(role, roleData, createdMissions)
  if role == "tanker" then
    createTankerMissions(roleData --[[@as SBJ__TankerMissionDeploymentDescriptor]], createdMissions)
    return true
  end

  return createNonTankerMission(role, roleData, createdMissions)
end

---Create all missions for a package, abort if striker creation fails
---@param packageData SBJ__Package Package data
---@return boolean success True if all critical missions created successfully
---@return table<string, CMO__Mission> createdMissions Created missions indexed by mission name
local function createPackageMissions(packageData)
  local createdMissions = {}

  for _, role in ipairs(PACKAGE_ROLE_ORDER) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]

    if roleData and not createMissionsForRole(role, roleData, createdMissions) then
      return false, createdMissions
    end
  end

  return true, createdMissions
end

-- ============================================================================
-- Mission Scheduling
-- ============================================================================

---Apply one role schedule after aircraft assignment has completed
---@param mission CMO__Mission Mission object to schedule
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
local function applyMissionSchedule(mission, roleData)
  mission.OnDeactivateDelete = true
  mission.OnDeactivateRTB = true

  if roleData.endTime then
    mission.endtime = roleData.endTime .. constants.TIME_FORMATS
  end

  if roleData.timeOnStation then
    mission.TakeOffTime = nil
    mission.TimeOnTargetStation = roleData.timeOnStation .. constants.TIME_FORMATS
  elseif roleData.startTime then
    mission.TimeOnTargetStation = nil
    mission.TakeOffTime = roleData.startTime .. constants.TIME_FORMATS
  end
end

---Apply schedules to all created missions after unit assignment
---@param packageData SBJ__Package Package data
---@param createdMissions table<string, CMO__Mission> Created missions indexed by mission name
local function applyPackageMissionSchedules(packageData, createdMissions)
  for _, role in ipairs(PACKAGE_ROLE_ORDER) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]

    if roleData then
      local missionParamsList = role == "tanker" and
          TankerMission.normalizeCreationParams(roleData.missionCreationParams) or
          { roleData.missionCreationParams }

      for _, missionCreationParams in ipairs(missionParamsList) do
        local mission = createdMissions[missionCreationParams.name]
        if mission then
          applyMissionSchedule(mission, roleData)
        end
      end
    end
  end
end

-- ============================================================================
-- Target Assignment
-- ============================================================================

---Validate package target data before lifecycle processing
---@param packageData SBJ__Package Package data
---@return SBJ__LogResult|nil # Validation failure row, or nil when valid
local function validatePackageTargets(packageData)
  local targetList = packageData.target.list

  if targetList and #targetList > 0 then
    return nil
  end

  return {
    tag = "SKIP",
    fields = {
      mission = packageData.striker.missionCreationParams.name,
      targets = 0,
      required = packageData.target.minTargetCount,
      reason = "invalid_package_targets"
    }
  }
end

---Assign targets to strike mission
---@param packageData SBJ__Package Package data with target list
---@return boolean # True if targets successfully assigned
local function assignTargetsToMission(packageData)
  local targetList = packageData.target.list
  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    targetList,
    packageData.striker.missionCreationParams.name
  )
  return targetsAssigned ~= nil
end

-- ============================================================================
-- Unit Assignment
-- ============================================================================

---Assign units from one role to one mission
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param missionName string Mission name
---@param unitCount integer Number of units to assign
---@return string[]|nil # Assigned unit GUIDs
local function assignRoleUnitsToMission(roleData, missionName, unitCount)
  return AssignMission.assignEmbarkedUnitToStrikeMission(
    roleData.baseGUID,
    unitCount,
    roleData.weaponDBID,
    roleData.unitDBID,
    missionName,
    false
  )
end

---Assign tanker units evenly across all configured tanker missions
---@param roleData SBJ__TankerMissionDeploymentDescriptor Tanker deployment descriptor
local function assignTankerUnitsToMissions(roleData)
  local missionParamsList = TankerMission.normalizeCreationParams(roleData.missionCreationParams)
  local missionCount = #missionParamsList

  if missionCount == 0 or roleData.unitCount % missionCount ~= 0 then
    return
  end

  local unitCountPerMission = roleData.unitCount / missionCount

  for _, missionCreationParams in ipairs(missionParamsList) do
    assignRoleUnitsToMission(roleData, missionCreationParams.name, unitCountPerMission)
  end
end

---Assign units for a non-tanker role and prepare support flight plans
---@param role string Package role name
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@return boolean # True when striker units were assigned
local function assignNonTankerUnitsToMission(role, roleData)
  local assignedUnitGUIDs = assignRoleUnitsToMission(
    roleData,
    roleData.missionCreationParams.name,
    roleData.unitCount
  )

  if role ~= "striker" then
    GameApi.ScenEdit_CreateMissionFlightPlan(
      constants.SIDES.ENEMY,
      roleData.missionCreationParams.name,
      {}
    )
  end

  return role == "striker" and assignedUnitGUIDs and #assignedUnitGUIDs > 0 or false
end

---Assign units for one package role
---@param role string Package role name
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@return boolean # True when striker units were assigned
local function assignUnitsForRole(role, roleData)
  if role == "tanker" then
    assignTankerUnitsToMissions(roleData --[[@as SBJ__TankerMissionDeploymentDescriptor]])
    return false
  end

  return assignNonTankerUnitsToMission(role, roleData)
end

---Assign all units in the package to their respective missions
---@param packageData SBJ__Package The strike package containing unit assignment data
---@return boolean # True if the primary striker units were successfully assigned
local function assignPackageUnits(packageData)
  local isStrikerAssigned = false

  for _, role in ipairs(PACKAGE_ROLE_ORDER) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]

    if roleData and assignUnitsForRole(role, roleData) then
      isStrikerAssigned = true
    end
  end

  return isStrikerAssigned
end

-- ============================================================================
-- Recon UAV Scheduling
-- ============================================================================

---Schedule reconnaissance UAV if configured in package
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param packageData SBJ__Package Package data with optional reconUAV
---@return SBJ__ReconUAVEntry|nil # The inserted entry, or nil if no entry was inserted
local function scheduleReconUAV(config, saveData, packageData)
  if not packageData.reconUAV then
    return
  end

  local _, flightTime = GameUtils.calculatePathDistanceAndTime(packageData.reconUAV.course, packageData.reconUAV.speed)
  local takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) + config.c.ground.srbm.reloadTime -
      flightTime
  local takeoffTimeStr = os.date(constants.DATE_FORMAT, takeoffTime) --[[@as string]]
  return Recon.insertEntry(saveData.c.recon, packageData.reconUAV, takeoffTimeStr)
end

-- ============================================================================
-- Package Lifecycle
-- ============================================================================

---Advance package preparation until mission assignment may begin
---@param packageData SBJ__Package Package data
---@param assignmentSafetyMargin number Assignment safety margin in seconds
---@return boolean isReadyForAssignment Whether mission assignment may begin
---@return SBJ__LogResult|nil preparationResult Interim row, or nil while waiting
local function advancePackagePreparation(packageData, assignmentSafetyMargin)
  ensureLoadoutStartTime(packageData)

  if not isTimeToStartLoadout(packageData, assignmentSafetyMargin) then
    return false, nil
  end

  if not packageData.loadoutStatus.isLoadoutInitiated then
    initiateLoadoutForPackage(packageData)
    local readyTime = os.date(constants.DATE_FORMAT, packageData.loadoutStatus.expectedReadyTime)

    return false, {
      tag = "OK",
      fields = {
        mission = packageData.striker.missionCreationParams.name,
        action = "initiate_loadout",
        readyTime = readyTime
      }
    }
  end

  if not isLoadoutReady(packageData) then
    return false, nil
  end

  -- No separate pre-takeoff gate: isTimeToStartLoadout advances the loadout start by
  -- assignmentSafetyMargin, so loadout readiness already lands that margin ahead of the
  -- earliest planned takeoff, reserving it for the assignment performed next.
  return true, nil
end

---Create missions and assign package targets and units
---@param packageData SBJ__Package Package data
---@return table<string, CMO__Mission>|nil createdMissions Created missions, or nil on failure
---@return SBJ__LogResult|nil failureResult Failure row, or nil on success
local function createAndAssignPackageMissions(packageData)
  local missionName = packageData.striker.missionCreationParams.name
  local missionsCreated, createdMissions = createPackageMissions(packageData)

  if not missionsCreated then
    return nil, {
      tag = "FAIL",
      fields = { mission = missionName, reason = "striker_mission_creation_failed" }
    }
  end

  if not assignTargetsToMission(packageData) then
    return nil, {
      tag = "FAIL",
      fields = {
        mission = missionName,
        targets = #packageData.target.list,
        required = packageData.target.minTargetCount,
        reason = "target_assignment_failed"
      }
    }
  end

  if not assignPackageUnits(packageData) then
    return nil, {
      tag = "FAIL",
      fields = { mission = missionName, reason = "striker_assignment_failed" }
    }
  end

  return createdMissions, nil
end

---Apply schedules and build a successful package launch result
---@param config SBJ__Config Global configuration
---@param saveData SBJ__SaveData Persistent save data
---@param packageData SBJ__Package Package data
---@param createdMissions table<string, CMO__Mission> Created missions
---@return SBJ__LogResult # Successful launch row
local function finalizePackageLaunch(config, saveData, packageData, createdMissions)
  applyPackageMissionSchedules(packageData, createdMissions)
  local reconUAVEntry = scheduleReconUAV(config, saveData, packageData)

  ---@type SBJ__LogResult
  local launchResult = {
    tag = "OK",
    fields = {
      mission = packageData.striker.missionCreationParams.name,
      action = "launch",
      targets = #packageData.target.list
    }
  }

  if reconUAVEntry then
    launchResult.fields.reconUavTakeoff = reconUAVEntry.takeoffTime
  end

  return launchResult
end

---Processes a single strike package through its complete lifecycle
---Returns structured status for centralized logging in the public API
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO state
---@param packageData SBJ__Package The strike package data to process
---@return boolean launched Whether package was successfully launched
---@return SBJ__LogResult|nil result Processed package row, or nil when nothing should be logged
local function processPackage(config, saveData, packageData)
  local validationResult = validatePackageTargets(packageData)
  if validationResult then
    return false, validationResult
  end

  local assignmentSafetyMargin = resolveAssignmentSafetyMargin(config)
  local isReadyForAssignment, preparationResult = advancePackagePreparation(packageData, assignmentSafetyMargin)

  if not isReadyForAssignment then
    return false, preparationResult
  end

  local createdMissions, failureResult = createAndAssignPackageMissions(packageData)
  if not createdMissions then
    return false, failureResult
  end

  local launchResult = finalizePackageLaunch(config, saveData, packageData, createdMissions)
  return true, launchResult
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
---@return SBJ__LogResult[] # Processed package rows from this wave
local function processWave(config, saveData, waveName, waveData)
  ---@type SBJ__LogResult[]
  local processedResults = {}

  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      local launched, packageResult = processPackage(config, saveData, packageData)

      if launched then
        packageData.hasLaunched = true
      end

      if packageResult then
        packageResult.fields.wave = waveName
        table.insert(processedResults, packageResult)
      end

      if launched then
        break
      end
    end
  end

  return processedResults
end

-- ============================================================================
-- Public API
-- ============================================================================

---The main entry point for air strikes
---Iterates through ATO waves and packages, processing each strike package sequentially
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO waves and packages
function AirTaskingOrder.airStrike(config, saveData)
  local report = LogFormat.report(constants.TAGS.AIR, LOG_SCOPE, LOG_ACTION)

  for waveName, waveData in pairs(saveData.c.air.airTaskingOrder) do
    if waveData.isActivated and not waveData.hasLaunched then
      report.addAll(processWave(config, saveData, waveName, waveData))

      if isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end

  report.emit()
end

return AirTaskingOrder
