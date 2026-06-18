local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local AssignMission = require("src.modules.assignMission")
local Recon = require("src.modules.strikePlanner.recon")
local constants = require("src.core.constants")

local AirTaskingOrder = {}

local ADVANCE_SECONDS = 300
local LOADOUT_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }

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
---@return boolean # True if current time has reached or passed the loadout start time
local function isTimeToStartLoadout(packageData)
  local loadoutStatus = packageData.loadoutStatus
  if not (loadoutStatus and loadoutStatus.loadoutStartTime) then
    return false
  end

  return GameUtils.isAfterStartTime(loadoutStatus.loadoutStartTime, ADVANCE_SECONDS)
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
    if unit and unit.dbid == targetUnitDBID then
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

---Creates a mission for a specific role if it doesn't exist
---@param packageData SBJ__Package The strike package containing mission parameters
---@param role string The role identifier
---@return boolean # True if mission exists or was successfully created
local function createMission(packageData, role)
  ---@type SBJ__MissionDeploymentDescriptor
  local missionRole = packageData[role]
  local mission = GameApi.ScenEdit_GetMission(constants.SIDES.ENEMY, missionRole.missionCreationParams.name)

  if not mission then
    mission = GameUtils.createMission(
      constants.SIDES.ENEMY,
      missionRole.missionCreationParams.name,
      missionRole.missionCreationParams.type,
      missionRole.missionCreationParams.opts,
      missionRole.emcon
    )

    if mission and missionRole.endTime then
      mission.OnDeactivateDelete = true
      mission.OnDeactivateRTB = true

      if missionRole.startTime then
        mission.TakeOffTime = missionRole.startTime .. constants.TIME_FORMATS
      end

      mission.endtime = missionRole.endTime .. constants.TIME_FORMATS

      if missionRole.timeOnStation then
        mission.TimeOnTargetStation = missionRole.timeOnStation .. constants.TIME_FORMATS
      end

      if missionRole.missionCreationParams.type == "strike" then
        GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.ENEMY, mission = mission.name },
          { automatic_evasion = false })
      end
    end
  end

  return mission ~= nil
end

-- ============================================================================
-- Target Assignment
-- ============================================================================

---Assign targets to strike mission
---@param packageData SBJ__Package Package data with target list
---@return boolean # True if targets successfully assigned
local function assignTargetsToMission(packageData)
  local evaluatedTargetlist = packageData.target.list

  if #evaluatedTargetlist < packageData.target.minTargetCount then
    return false
  end

  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    evaluatedTargetlist,
    packageData.striker.missionCreationParams.name
  )

  return targetsAssigned ~= nil
end

-- ============================================================================
-- Unit Assignment
-- ============================================================================

---Assigns all units in the package to their respective missions
---@param packageData SBJ__Package The strike package containing unit assignment data
---@return boolean # True if the primary striker units were successfully assigned
local function assignUnits(packageData)
  local strikerAssigned = false

  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole then
      local result = AssignMission.assignEmbarkedUnitToStrikeMission(
        missionRole.baseGUID,
        missionRole.unitCount,
        missionRole.weaponDBID,
        missionRole.unitDBID,
        missionRole.missionCreationParams.name,
        false
      )
      if role ~= "tanker" and role ~= "striker" then
        GameApi.ScenEdit_CreateMissionFlightPlan(constants.SIDES.ENEMY, missionRole.missionCreationParams.name, {})
      end

      if role == "striker" and result and #result > 0 then
        strikerAssigned = true
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
    local takeoffTimeStr = os.date("!%Y-%m-%d %H:%M:%S", takeoffTime) --[[@as string]]
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
---@return boolean # True if all critical missions created successfully
local function createAllMissions(packageData)
  for _, role in ipairs(LOADOUT_ROLES) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local missionRole = packageData[role]

    if missionRole then
      local missionCreated = createMission(packageData, role)

      if role == "striker" and not missionCreated then
        return false
      end
    end
  end

  return true
end

---Processes a single strike package through its complete lifecycle
---Returns structured status for centralized logging in the public API
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO state
---@param packageData SBJ__Package The strike package data to process
---@return boolean launched Whether package was successfully launched
---@return string|nil status Log message (nil = nothing to log)
---@return string|nil tag Status tag for log formatting (e.g. "LAUNCH", "LOADOUT", "ERROR")
local function processPackage(config, saveData, packageData)
  ensureLoadoutStartTime(packageData)

  if not isTimeToStartLoadout(packageData) then
    return false, nil
  end

  if not packageData.loadoutStatus.isLoadoutInitiated then
    initiateLoadoutForPackage(packageData)
    local readyTimeStr = os.date("!%Y-%m-%d %H:%M:%S", packageData.loadoutStatus.expectedReadyTime)
    return false, "loadout initiated, ready at " .. readyTimeStr, "LOADOUT"
  end

  if not isLoadoutReady(packageData) then
    return false, nil
  end

  local earliestRole = findEarliestRole(packageData)
  if not (earliestRole and GameUtils.isAfterStartTime(earliestRole.startTime, ADVANCE_SECONDS)) then
    return false, nil
  end

  if not createAllMissions(packageData) then
    return false, "striker mission creation failed", "ERROR"
  end

  local reconUAVEntry = scheduleReconUAV(config, saveData, packageData)

  if not assignTargetsToMission(packageData) then
    local targetList = packageData.target.list
    if #targetList < packageData.target.minTargetCount then
      return false, string.format("insufficient targets (%d/%d required)",
        #targetList, packageData.target.minTargetCount), "PENDING"
    end
    return false, nil
  end

  if not assignUnits(packageData) then
    return false, "failed to assign striker units", "ERROR"
  end

  -- Build launch summary
  local details = { #packageData.target.list .. " targets" }
  if reconUAVEntry then
    table.insert(details, "recon UAV at " .. reconUAVEntry.takeoffTime)
  end
  return true, "launched (" .. table.concat(details, ", ") .. ")", "LAUNCH"
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
---Returns log entries for centralized logging in the public API
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data
---@param waveData SBJ__Wave The wave containing strike packages
---@return {msg: string, tag: string}[] # Log entries from processed packages
local function processWave(config, saveData, waveData)
  local logEntries = {}

  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      local launched, status, tag = processPackage(config, saveData, packageData)

      if launched then
        packageData.hasLaunched = true
      end

      if status then
        local msg = string.format("%s | %s", packageData.striker.missionCreationParams.name, status)
        table.insert(logEntries, { msg = msg, tag = tag })
      end

      if launched then
        break
      end
    end
  end

  return logEntries
end

-- ============================================================================
-- Public API
-- ============================================================================

---The main entry point for air strikes
---Iterates through ATO waves and packages, processing each strike package sequentially
---@param config SBJ__Config The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO waves and packages
function AirTaskingOrder.airStrike(config, saveData)
  local infoLines = {}
  local errorLines = {}

  for _, waveData in pairs(saveData.c.air.airTaskingOrder) do
    if waveData.isActivated and not waveData.hasLaunched then
      local logEntries = processWave(config, saveData, waveData)

      for _, entry in ipairs(logEntries) do
        local line = string.format("  [%s] %s", entry.tag, entry.msg)
        if entry.tag == "ERROR" then
          table.insert(errorLines, line)
        else
          table.insert(infoLines, line)
        end
      end

      if isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end

  if #infoLines > 0 then
    Logger.log(constants.TAGS.AIR, string.format(
      "Air tasking order: %d items\n%s", #infoLines, table.concat(infoLines, "\n")))
  end

  if #errorLines > 0 then
    Logger.error(string.format(
      "Air tasking order errors: %d items\n%s", #errorLines, table.concat(errorLines, "\n")))
  end
end

return AirTaskingOrder
