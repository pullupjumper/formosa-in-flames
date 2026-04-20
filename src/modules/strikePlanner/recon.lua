local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local Recon = {}


local ENTRY_TYPE = {
  UAV = "UAV",
  SATELLITE = "satellite",
  SIGINT = "SIGINT"
}

local LAUNCH_STATUS = {
  LAUNCHED = "launched",
  NOT_READY = "not_ready",
  FAILED = "failed",
}

local TRACKING_STATUS = {
  UPDATED = "updated",
  NO_TARGET_GUID = "no_target_guid",
  NO_SPEED = "no_speed",
  TARGET_LOST = "target_lost",
}

local MISSION_RESULT = {
  SUCCESS = "success",
  FAILED = "failed",
  ALREADY_FINISHED = "already_finished",
}

local MAX_TRACKING_DISTANCE = 1000
local WZ8_INITIAL_ALTITUDE = 20574
local WZ8_INITIAL_HEADING = 180
local WZ8_INITIAL_SPEED = 3300

-- ============================================================================
-- Unit Launch
-- ============================================================================

---Launch units from a base with specified parameters
---@param baseGUID string The base GUID to launch units from
---@param course CMO__Waypoint[] The course waypoints for launched units
---@param unitCount number The number of units to launch
---@param unitDBID number The unit database ID to filter by
---@param unitType string The unit type to launch (e.g., 'Aircraft' or 'Boats')
---@return string[] # Returns array of launched unit GUIDs (empty if none launched)
local function launchUnits(baseGUID, course, unitCount, unitDBID, unitType)
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

  if not base then
    base = GameApi.ScenEdit_GetUnit(baseGUID, constants.SIDES.ENEMY)
  end

  if not base then
    return {}
  end

  local count = 0
  local temp = {}
  if #base.embarkedUnits[unitType] == 0 then
    return {}
  end

  for _, guid in ipairs(base.embarkedUnits[unitType]) do
    local actualUnit = GameApi.ScenEdit_GetUnit(guid)

    if actualUnit and actualUnit.dbid == unitDBID and actualUnit.readytime_v == 0 and count < unitCount then
      GameApi.ScenEdit_SetDoctrine({ guid = actualUnit.guid, }, { automatic_evasion = false })
      actualUnit:Launch(true)
      actualUnit.course = course
      count = count + 1
      table.insert(temp, actualUnit.guid)
    end

    if count >= unitCount then
      break
    end
  end

  return temp
end

---Launch WZ-8 reconnaissance drone from H-6N bomber
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__Waypoint[] The reconnaissance course for WZ-8
---@return CMO__Unit|nil # Returns the WZ-8 unit if successfully launched, nil otherwise
function Recon.launchWZ8(h6n, course)
  local wz8 = GameApi.ScenEdit_AddUnit({
    side = "China",
    type = "Aircraft",
    name = "WZ-8",
    dbid = constants.PLATFORMS.WZ8,
    latitude = h6n.latitude,
    longitude = h6n.longitude,
    loadoutid = constants.LOADOUTS.WZ8_RECON,
    altitude = WZ8_INITIAL_ALTITUDE,
    heading = WZ8_INITIAL_HEADING,
    speed = WZ8_INITIAL_SPEED
  })
  if not wz8 then return end

  local updatedUnit = GameApi.ScenEdit_UpdateUnit({
    guid = wz8.guid,
    mode = "add_sensor",
    dbid = constants.SENSORS.WZ8_RADAR,
    arc_detect = constants.SENSOR_ARCS,
    arc_track = constants.SENSOR_ARCS
  })

  if not updatedUnit then return end
  GameApi.ScenEdit_SetUnit({ guid = wz8.guid, base = constants.BASES.LONGTIAN_AAB })
  local result = GameApi.ScenEdit_SetEMCON("Unit", wz8.guid, "Radar=Active")
  if not result then return end
  wz8.course = course
  h6n:RTB(true)
  return wz8
end

-- ============================================================================
-- Dynamic Operations Scheduling
-- ============================================================================

---Find matching strike mappings for a reconnaissance queue entry from the strike matrix
---@param strikeMatrix table<string, SBJ__ReconStrikeMapping[]> Strike matrix keyed by platform name
---@param entry SBJ__ReconQueueEntry Queue entry to find mappings for
---@return SBJ__ReconStrikeMapping[]|nil # Matching strike mappings or nil if not found
local function findStrikeMappingsForEntry(strikeMatrix, entry)
  for platformName, strikeMappings in pairs(strikeMatrix) do
    local dbid = constants.PLATFORMS[platformName]
    if entry.unitDBID == dbid then
      return strikeMappings
    end
  end
  return nil
end

---Build a single operation from a strike mapping configuration
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping definition
---@param config SBJ__Config Configuration data
---@param LACMContext SBJ__LACMContext LACM context data
---@return SBJ__Operation|nil operation Built operation or nil if skipped
---@return string logEntry Log entry describing the result
local function buildOperationFromMapping(strikeMapping, config, LACMContext)
  if strikeMapping.name == "STRIKE/AB/E/1" and not LACMContext.enabled then
    return nil, string.format("[SKIP] %s | LACM not activated", strikeMapping.name)
  end

  local newOperation = {
    type = strikeMapping.type,
    executed = false,
    template = {
      name = strikeMapping.name,
      isFirstWave = true,
    }
  }

  if strikeMapping.type == "air" then
    newOperation.template.packages = config.c.packageTemplates[string.gsub(strikeMapping.name, "/", "_")]
    newOperation.template.strikeInterval = 30 * 60
  elseif strikeMapping.type == "ground" then
    newOperation.template.fireSupportTasks = config.c.fireSupportTaskTemplates
        [string.gsub(strikeMapping.name, "/", "_")]
    newOperation.template.strikeInterval = 0
  end

  return newOperation, string.format("[NEW] %s (%s)", strikeMapping.name, strikeMapping.type)
end

---Try to generate a next operation from an existing prefix-matched operation
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping with template name
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param config SBJ__Config Configuration data
---@return SBJ__Operation|nil nextOperation Generated next operation or nil
---@return string|nil logEntry Log entry describing the result
local function tryGenerateNextOperation(strikeMapping, reconSchedule, config)
  local baseName = strikeMapping.name:match("^(.+/)%d+$")
  if not baseName then
    return nil, nil
  end

  local existing, operation = DynamicOperationsUtils.hasOperation(reconSchedule, baseName, strikeMapping.type)
  if not existing or not operation then
    return nil, nil
  end

  local nextOperation, status = DynamicOperationsUtils.generateNextOperation(operation, config)
  local logEntry = string.format("[NEXT] %s -> %s (%s)",
    operation.template.name, nextOperation.template.name, status)
  return nextOperation, logEntry
end

---Get platform-specific operations for BZK-005 (C2 strike) and WZ-8 (anti-ship/airbase strike)
---Each UAV platform triggers different specialized operations based on successful reconnaissance
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
---@return SBJ__Operation[] operations Array of special operations to add
---@return string[] logEntries Array of log entry strings for batched output
local function getPlatformSpecialOperations(config, reconSchedule, entry, LACMContext)
  local operations = {}
  local logEntries = {}
  local strikeMatrix = config.c.recon.reconStrikeMatrix[entry.type]

  if not strikeMatrix then
    table.insert(logEntries, string.format("  [ERROR] No strike mappings found for platform type: %s",
      tostring(entry.type)))
    return operations, logEntries
  end

  local strikeMappings = findStrikeMappingsForEntry(strikeMatrix, entry)
  if not strikeMappings then
    return operations, logEntries
  end

  for _, strikeMapping in ipairs(strikeMappings) do
    local skipMapping = false

    if not DynamicOperationsUtils.hasOperation(reconSchedule, strikeMapping.name, strikeMapping.type) then
      local newOp, logEntry = buildOperationFromMapping(strikeMapping, config, LACMContext)
      table.insert(logEntries, "  " .. logEntry)
      if newOp then
        table.insert(operations, newOp)
      else
        skipMapping = true
      end
    end

    if not skipMapping then
      local nextOp, nextLog = tryGenerateNextOperation(strikeMapping, reconSchedule, config)
      if nextOp then
        table.insert(operations, nextOp)
        table.insert(logEntries, "  " .. nextLog)
      end
    end
  end

  return operations, logEntries
end

---Schedule dynamic operations for next wave based on completed reconnaissance
---Only called when UAV completes successfully (reached endTime with complete intelligence)
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
local function scheduleDynamicReconOperations(config, reconSchedule, entry, LACMContext)
  local reconResult = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconSchedule)

  -- Generate next wave operations
  local operations = {}

  -- Add platform-specific operations
  local specialOps, logEntries = getPlatformSpecialOperations(config, reconSchedule, entry, LACMContext)
  for _, op in ipairs(specialOps) do
    table.insert(operations, op)
  end

  -- Add to reconnaissance schedule if there are operations
  if #operations > 0 then
    table.insert(reconSchedule, {
      time = entry.endTime,
      type = entry.type,
      delay = 0,
      executed = false,
      operations = operations
    })
  end

  -- Batched log output
  local infoLines = {}

  table.insert(infoLines, string.format("  recon context: most recent=%s, next=%s, air=%d, ground=%d",
    reconResult.mostRecentTime or "none",
    reconResult.nextReconTime or "none",
    #reconResult.air,
    #reconResult.ground))

  for _, logEntry in ipairs(logEntries) do
    table.insert(infoLines, logEntry)
  end

  if #operations > 0 then
    table.insert(infoLines, string.format("  [RESULT] Scheduled %d operations for recon at %s",
      #operations, entry.endTime))
  else
    table.insert(infoLines, "  [RESULT] No operations to schedule")
  end

  Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, string.format(
    "Dynamic recon scheduling for %s (%s)\n%s", entry.type, entry.endTime, table.concat(infoLines, "\n")))
end

-- ============================================================================
-- Recon Flight Management
-- ============================================================================

---Handle reconnaissance launch phase
---@param entry SBJ__ReconQueueEntryUAV Queue entry to process (UAV only)
---@return string status Launch status from LAUNCH_STATUS
---@return string message Human-readable status description
local function handleReconLaunch(entry)
  if entry.hasLaunched or not GameUtils.isAfterStartTime(entry.takeoffTime) then
    return LAUNCH_STATUS.NOT_READY, string.format("Not ready for launch (base %s)", entry.baseGUID)
  end

  local units = launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, "Aircraft")

  if #units > 0 then
    entry.unitGUID = units[1]
    entry.hasLaunched = true
    return LAUNCH_STATUS.LAUNCHED, string.format("Launched unit %s from base %s", units[1], entry.baseGUID)
  else
    return LAUNCH_STATUS.FAILED, string.format("Failed to launch from base %s", entry.baseGUID)
  end
end

---Handle reconnaissance tracking mode - continuously update course to track moving target
---@param entry SBJ__ReconQueueEntryUAV Queue entry (UAV only)
---@param actualUnit CMO__Unit The reconnaissance unit
---@return string status Tracking status from TRACKING_STATUS
---@return string message Human-readable status description
local function handleReconTracking(entry, actualUnit)
  if not entry.trackingTargetGUID then
    return TRACKING_STATUS.NO_TARGET_GUID,
        string.format("No tracking assignment for unit %s", actualUnit.guid)
  end

  if not entry.speed then
    return TRACKING_STATUS.NO_SPEED,
        string.format("No speed configured for unit %s", actualUnit.guid)
  end

  local target = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, entry.trackingTargetGUID)

  if not target then
    return TRACKING_STATUS.TARGET_LOST,
        string.format("Tracking target lost: %s", entry.trackingTargetGUID)
  end

  -- Update course to target position (continuous tracking for missile guidance)
  actualUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = entry.speed,
    presetThrottle = "Military"
  } }

  return TRACKING_STATUS.UPDATED,
      string.format("Tracking updated for unit %s -> target %s", actualUnit.guid, entry.trackingTargetGUID)
end

---Finish reconnaissance mission and conditionally schedule next operations
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry
---@param LACMContext SBJ__LACMContext LACM context data
---@param success boolean Mission success status
---@return string # Mission result from MISSION_RESULT
local function finishReconMission(config, reconSchedule, entry, LACMContext, success)
  -- Prevent double execution
  if entry.isFinished then
    return MISSION_RESULT.ALREADY_FINISHED
  end

  entry.isFinished = true

  if success then
    -- Mission successful: intelligence data is complete, schedule next wave operations
    scheduleDynamicReconOperations(config, reconSchedule, entry, LACMContext)
    return MISSION_RESULT.SUCCESS
  else
    -- Mission failed: intelligence data is incomplete, skip scheduling
    return MISSION_RESULT.FAILED
  end
end

---Determine outcome when UAV is destroyed or missing
---@param entry SBJ__ReconQueueEntryUAV Queue entry
---@param isEndTimeReached boolean Whether endTime was reached before destruction
---@return boolean success Whether mission should be considered successful
---@return string message Status description
local function handleUAVDestroyed(entry, isEndTimeReached)
  if isEndTimeReached then
    return true, string.format("Unit %s destroyed after endTime, mission successful", tostring(entry.unitGUID))
  else
    return false, string.format("Unit %s destroyed before endTime, mission failed", tostring(entry.unitGUID))
  end
end

---Handle mission completion when UAV has finished course and endTime
---@param entry SBJ__ReconQueueEntryUAV Queue entry
---@param actualUnit CMO__Unit The reconnaissance unit
---@return string|nil trackStatus Tracking status if in tracking mode, nil for normal completion
---@return string message Status description
local function handleMissionCompletion(entry, actualUnit)
  if entry.isTracking and entry.trackingTargetGUID then
    local status, message = handleReconTracking(entry, actualUnit)
    return status, message
  else
    return nil, string.format("Mission completed for %s", actualUnit.name)
  end
end

---Process a single UAV reconnaissance queue entry through its full lifecycle
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntryUAV UAV queue entry to process
---@param LACMContext SBJ__LACMContext LACM context data
---@return string|nil tag Semantic log tag ([OK], [SKIP], [FAIL]) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processUAVEntry(config, reconSchedule, entry, LACMContext)
  -- Phase 1: Launch reconnaissance units when time comes
  if not entry.hasLaunched then
    local status, message = handleReconLaunch(entry)
    if status == LAUNCH_STATUS.LAUNCHED then
      return "[OK]", message
    elseif status == LAUNCH_STATUS.NOT_READY then
      return "[SKIP]", message
    else
      return "[FAIL]", message
    end
  end

  -- Already finished, skip
  if entry.isFinished then
    return nil, nil
  end

  -- Phase 2: In-flight management
  local actualUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  -- Phase 2a: UAV destroyed or missing
  if not actualUnit then
    local success, message = handleUAVDestroyed(entry, isEndTimeReached)
    finishReconMission(config, reconSchedule, entry, LACMContext, success)
    local tag = success and "[OK]" or "[FAIL]"
    return tag, message
  end

  -- Phase 2b: Still flying course
  if #actualUnit.course > 0 then
    return "[SKIP]", string.format("Unit %s still flying course", actualUnit.name)
  end

  -- Phase 2c: Course complete but endTime not reached
  if not isEndTimeReached then
    return "[SKIP]", string.format("Unit %s completed course, waiting for endTime %s",
      actualUnit.name, entry.endTime)
  end

  -- Phase 2d: Mission completion
  local trackStatus, message = handleMissionCompletion(entry, actualUnit)

  if trackStatus == TRACKING_STATUS.UPDATED then
    return "[OK]", message
  end

  if trackStatus then
    -- Tracking failed but recon completed successfully
    finishReconMission(config, reconSchedule, entry, LACMContext, true)
    return "[FAIL]", string.format("Tracking failed for %s, mission completed", actualUnit.name)
  end

  -- Normal reconnaissance completion
  finishReconMission(config, reconSchedule, entry, LACMContext, true)
  return "[OK]", message
end

---Process a single satellite reconnaissance queue entry
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Satellite queue entry to process
---@param LACMContext SBJ__LACMContext LACM context data
---@return string|nil tag Semantic log tag ([OK], [SKIP]) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processSatelliteEntry(config, reconSchedule, entry, LACMContext)
  if entry.isFinished then
    return nil, nil
  end

  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  if not isEndTimeReached then
    return "[SKIP]", string.format("Satellite waiting for endTime %s", entry.endTime)
  end

  finishReconMission(config, reconSchedule, entry, LACMContext, true)
  return "[OK]", string.format("Satellite mission completed at %s", entry.endTime)
end

-- ============================================================================
-- Target Tracking
-- ============================================================================

---Check if any UAV in the queue is already tracking the specified target
---@param queue SBJ__ReconQueueEntry[] Reconnaissance queue entries
---@param targetGUID string Target contact GUID to check
---@return boolean # True if target is already being tracked by an active UAV
local function isTargetAlreadyTracked(queue, targetGUID)
  for _, entry in ipairs(queue) do
    if entry.type == ENTRY_TYPE.UAV and entry.trackingTargetGUID == targetGUID and entry.unitGUID then
      local unit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
      if unit then return true end
    end
  end
  return false
end

---Find the closest available UAV of specified type within tracking distance
---@param units CMO__SideUnit[] Side units collection to search
---@param UAVDBID number UAV platform database ID to filter by
---@param target CMO__Contact Target contact to measure distance from
---@return CMO__Unit|nil # Closest available UAV or nil if none found
local function findClosestUAV(units, UAVDBID, target)
  local UAV = nil
  local minDistance = MAX_TRACKING_DISTANCE

  for _, u in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit and actualUnit.dbid == UAVDBID and actualUnit.condition == "Airborne" then
      local distance = GameApi.Tool_Range(
        { latitude = actualUnit.latitude, longitude = actualUnit.longitude }, target.guid
      )

      if distance and distance < minDistance then
        minDistance = distance
        UAV = actualUnit
      end
    end
  end

  return UAV
end

---Find a queue entry by its assigned unit GUID
---@param queue SBJ__ReconQueueEntry[] Reconnaissance queue entries
---@param unitGUID string Unit GUID to search for
---@return SBJ__ReconQueueEntryUAV|nil # Matching queue entry or nil
local function findQueueEntryByUnitGUID(queue, unitGUID)
  for _, entry in ipairs(queue) do
    if entry.type == ENTRY_TYPE.UAV and entry.unitGUID == unitGUID then
      return entry
    end
  end
  return nil
end

---Assign a tracking mission to a queue entry
---@param queueEntry SBJ__ReconQueueEntryUAV Queue entry to assign tracking to
---@param targetGUID string Target contact GUID to track
local function assignTrackingMission(queueEntry, targetGUID)
  queueEntry.isTracking = true
  queueEntry.trackingTargetGUID = targetGUID
  queueEntry.isFinished = false
end

-- ============================================================================
-- Public API
-- ============================================================================

---Process reconnaissance queue managing UAV launch, flight monitoring, and mission completion
---Success requires UAV to complete course and reach endTime; failure if destroyed before endTime
---@param config SBJ__Config Configuration data for platform DBIDs
---@param reconContext SBJ__ReconContext Reconnaissance context
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule containing assigned missions
---@param LACMContext SBJ__LACMContext LACM context data
function Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)
  local infoLines = {}
  local errorLines = {}

  for _, entry in ipairs(reconContext.queue) do
    local tag, message

    if entry.type == ENTRY_TYPE.UAV then
      tag, message = processUAVEntry(config, reconSchedule, entry, LACMContext)
    elseif entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      tag, message = processSatelliteEntry(config, reconSchedule, entry, LACMContext)
    end

    if tag and message then
      local line = string.format("  %s %s | %s", tag, entry.type, message)
      if tag == "[FAIL]" or tag == "[ERROR]" then
        table.insert(errorLines, line)
      else
        table.insert(infoLines, line)
      end
    end
  end

  if #infoLines > 0 then
    Logger.log(constants.TAGS.RECON, string.format(
      "Recon queue processed: %d items\n%s", #infoLines, table.concat(infoLines, "\n")))
  end

  if #errorLines > 0 then
    Logger.error(string.format(
      "Recon queue errors: %d items\n%s", #errorLines, table.concat(errorLines, "\n")))
  end
end

---Assign UAV to track a specific target contact
---Finds available UAV of specified type and assigns it to continuously track the target
---@param reconContext SBJ__ReconContext Reconnaissance context for tracking UAV assignments
---@param units CMO__SideUnit[] Side units collection to search for available UAVs
---@param UAVDBID number UAV platform database ID to filter by
---@param target CMO__Contact Target contact to track
---@return boolean # True if UAV was assigned to track target, false otherwise
function Recon.trackTarget(reconContext, units, UAVDBID, target)
  if isTargetAlreadyTracked(reconContext.queue, target.guid) then
    return true
  end

  local UAV = findClosestUAV(units, UAVDBID, target)
  if not UAV then
    return false
  end

  local queueEntry = findQueueEntryByUnitGUID(reconContext.queue, UAV.guid)
  if not queueEntry then
    Logger.log(constants.TAGS.RECON,
      string.format("UAV %s (GUID: %s) is not in reconnaissance queue. Cannot assign tracking mission.", UAV.name,
        UAV.guid))
    return false
  end

  assignTrackingMission(queueEntry, target.guid)
  Logger.log(constants.TAGS.RECON, string.format("Assigned UAV %s to track target %s", UAV.name, target.guid))
  return true
end

---Initialize reconnaissance queue entries
---@param reconConfig SBJ__ReconConfig Reconnaissance configuration for tracking UAV assignments
---@param reconContext SBJ__ReconContext Reconnaissance context for tracking UAV assignments
function Recon.initReconQueueEntries(reconConfig, reconContext)
  local entries = Utils.deepCopy(reconConfig.queue)

  for _, entry in ipairs(entries) do
    if entry.type == ENTRY_TYPE.UAV then
      ---@cast entry SBJ__ReconQueueEntry
      entry.hasLaunched = false
      entry.isFinished = false
    end

    if entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      entry.isFinished = false
    end
  end

  reconContext.queue = entries
end

return Recon
