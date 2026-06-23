local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local ReconOperationScheduler = require("src.modules.strikePlanner.reconOperationScheduler")
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

local POST_COURSE_ACTION = {
  COMPLETE_MISSION = "complete_mission",
  CONTINUE_TRACKING = "continue_tracking",
  TRACKING_FAILED = "tracking_failed",
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
---@return CMO__Unit[] # Returns array of launched unit objects (empty if none launched)
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
      table.insert(temp, actualUnit)
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
    side = constants.SIDES.ENEMY,
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
-- Recon Flight Management
-- ============================================================================

---Handle reconnaissance launch phase
---@param entry SBJ__ReconQueueEntryUAV Queue entry to process (UAV only)
---@return string status Launch status from LAUNCH_STATUS
---@return string message Human-readable status description
local function handleReconLaunch(entry)
  if entry.hasLaunched or not GameUtils.isAfterStartTime(entry.takeoffTime) then
    local message = string.format(
      "base=%s reason=takeoff_time_not_reached",
      LogFormat.value(entry.baseGUID)
    )
    return LAUNCH_STATUS.NOT_READY, message
  end

  local units = launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, "Aircraft")

  if #units > 0 then
    entry.unitGUID = units[1].guid
    entry.hasLaunched = true
    local message = string.format(
      "unit=%q base=%s action=launch",
      LogFormat.readable(units[1].name),
      LogFormat.value(entry.baseGUID)
    )
    return LAUNCH_STATUS.LAUNCHED, message
  else
    local message = string.format("base=%s reason=launch_failed", LogFormat.value(entry.baseGUID))
    return LAUNCH_STATUS.FAILED, message
  end
end

---Handle reconnaissance tracking mode - continuously update course to track moving target
---@param entry SBJ__ReconQueueEntryUAV Queue entry (UAV only)
---@param actualUnit CMO__Unit The reconnaissance unit
---@return string status Tracking status from TRACKING_STATUS
---@return string message Human-readable status description
local function handleReconTracking(entry, actualUnit)
  if not entry.trackingTargetGUID then
    local message = string.format("unit=%q reason=tracking_target_not_assigned", LogFormat.readable(actualUnit.name))
    return TRACKING_STATUS.NO_TARGET_GUID, message
  end

  if not entry.speed then
    local message = string.format("unit=%q reason=speed_not_configured", LogFormat.readable(actualUnit.name))
    return TRACKING_STATUS.NO_SPEED, message
  end

  local target = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, entry.trackingTargetGUID)

  if not target then
    local message = string.format("target=%s reason=tracking_target_lost", LogFormat.value(entry.trackingTargetGUID))
    return TRACKING_STATUS.TARGET_LOST, message
  end

  -- Update course to target position (continuous tracking for missile guidance)
  actualUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = entry.speed,
    presetThrottle = "Military"
  } }

  local message = string.format(
    "unit=%q target=%s action=update_tracking",
    LogFormat.readable(actualUnit.name),
    LogFormat.value(entry.trackingTargetGUID)
  )
  return TRACKING_STATUS.UPDATED, message
end

---Settle reconnaissance mission and conditionally schedule next operations
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Queue entry
---@param success boolean Mission success status
---@return string # Mission result from MISSION_RESULT
local function settleReconMission(processingContext, entry, success)
  -- Prevent double execution
  if entry.isFinished then
    return MISSION_RESULT.ALREADY_FINISHED
  end

  entry.isFinished = true

  if success then
    -- Mission successful: intelligence data is complete, schedule next wave operations
    ReconOperationScheduler.schedule(processingContext, entry)
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
    local message = string.format(
      "unit=%s state=destroyed result=success reason=end_time_reached",
      LogFormat.value(entry.unitGUID)
    )
    return true, message
  else
    local message = string.format(
      "unit=%s state=destroyed result=failed reason=destroyed_before_end_time",
      LogFormat.value(entry.unitGUID)
    )
    return false, message
  end
end

---Resolve the next action after a UAV has finished its course and reached endTime
---@param entry SBJ__ReconQueueEntryUAV Queue entry
---@param actualUnit CMO__Unit The reconnaissance unit
---@return string action Post-course action from POST_COURSE_ACTION
---@return string message Status description
local function resolvePostCourseUAVAction(entry, actualUnit)
  if entry.isTracking and entry.trackingTargetGUID then
    local trackingStatus, message = handleReconTracking(entry, actualUnit)

    if trackingStatus == TRACKING_STATUS.UPDATED then
      return POST_COURSE_ACTION.CONTINUE_TRACKING, message
    end

    return POST_COURSE_ACTION.TRACKING_FAILED, message
  end

  local message = string.format("unit=%q action=complete_mission", LogFormat.readable(actualUnit.name))
  return POST_COURSE_ACTION.COMPLETE_MISSION, message
end

---Process a single UAV reconnaissance queue entry through its full lifecycle
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntryUAV UAV queue entry to process
---@return string|nil tag Semantic log tag (OK/SKIP/FAIL) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processUAVEntry(processingContext, entry)
  -- Phase 1: Launch reconnaissance units when time comes
  if not entry.hasLaunched then
    local status, message = handleReconLaunch(entry)
    if status == LAUNCH_STATUS.LAUNCHED then
      return "OK", message
    elseif status == LAUNCH_STATUS.NOT_READY then
      return "SKIP", message
    else
      return "FAIL", message
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
    settleReconMission(processingContext, entry, success)
    local tag = success and "OK" or "FAIL"
    return tag, message
  end

  -- Phase 2b: Still flying course
  if #actualUnit.course > 0 then
    local message = string.format(
      "unit=%q state=in_flight reason=course_not_completed",
      LogFormat.readable(actualUnit.name)
    )
    return "SKIP", message
  end

  -- Phase 2c: Course complete but endTime not reached
  if not isEndTimeReached then
    local message = string.format(
      "unit=%q state=waiting_end_time endTime=%q",
      LogFormat.readable(actualUnit.name),
      entry.endTime
    )
    return "SKIP", message
  end

  -- Phase 2d: Mission completion or continued tracking
  local postCourseAction, message = resolvePostCourseUAVAction(entry, actualUnit)

  if postCourseAction == POST_COURSE_ACTION.CONTINUE_TRACKING then
    return "OK", message
  end

  if postCourseAction == POST_COURSE_ACTION.TRACKING_FAILED then
    -- Tracking failed but recon completed successfully
    settleReconMission(processingContext, entry, true)
    local msg = string.format(
      "unit=%q reason=tracking_failed missionStatus=completed",
      LogFormat.readable(actualUnit.name)
    )
    return "FAIL", msg
  end

  -- Normal reconnaissance completion
  settleReconMission(processingContext, entry, true)
  return "OK", message
end

---Process a single satellite reconnaissance queue entry
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Satellite or SIGINT queue entry to process
---@return string|nil tag Semantic log tag (OK/SKIP) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processSatelliteEntry(processingContext, entry)
  if entry.isFinished then
    return nil, nil
  end

  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  if not isEndTimeReached then
    local message = string.format(
      "type=%s state=waiting_end_time endTime=%q",
      LogFormat.value(entry.type),
      entry.endTime
    )
    return "SKIP", message
  end

  settleReconMission(processingContext, entry, true)
  local message = string.format(
    "type=%s action=complete_mission endTime=%q",
    LogFormat.value(entry.type),
    entry.endTime
  )
  return "OK", message
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
      local distance = GameApi.Tool_Range({
        latitude = actualUnit.latitude,
        longitude = actualUnit.longitude
      }, target.guid)

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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
function Recon.processQueue(processingContext)
  local config = processingContext.config
  local reconContext = processingContext.reconContext

  -- Proactively evaluate frontline-redirect sticky flag once per tick so the rewrite
  -- becomes effective on the next recon completion even if the queue is otherwise quiet.
  -- Activation log is captured here (instead of inside the helper) so processQueue owns all log emission.
  local _, activationMessage = FrontlineRedirect.evaluate(config, reconContext)
  if activationMessage then
    Logger.log(constants.TAGS.RECON, LogFormat.event("scope", "frontlineRedirect", "RESUME", activationMessage))
  end

  local infoLines = {}
  local errorLines = {}

  for _, entry in ipairs(reconContext.queue) do
    local tag, message

    if entry.type == ENTRY_TYPE.UAV then
      tag, message = processUAVEntry(processingContext, entry)
    elseif entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      tag, message = processSatelliteEntry(processingContext, entry)
    end

    if tag and message then
      local line = LogFormat.entry(tag, string.format("entryType=%s %s", LogFormat.value(entry.type), message))

      if tag == "FAIL" or tag == "ERROR" then
        table.insert(errorLines, line)
      else
        table.insert(infoLines, line)
      end
    end
  end

  if #infoLines > 0 then
    Logger.log(constants.TAGS.RECON, LogFormat.summary("scope", "reconQueue", "Process queue", infoLines))
  end

  if #errorLines > 0 then
    Logger.error(LogFormat.summary("scope", "reconQueue", "Process queue", errorLines))
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
    local msg = string.format(
      "target=%s platformDBID=%s reason=no_available_uav",
      LogFormat.value(target.guid),
      LogFormat.value(UAVDBID)
    )
    Logger.log(constants.TAGS.RECON, LogFormat.event("scope", "targetTracking", "SKIP", msg))
    return false
  end

  local queueEntry = findQueueEntryByUnitGUID(reconContext.queue, UAV.guid)
  if not queueEntry then
    local msg = string.format(
      "uav=%s guid=%s target=%s reason=uav_not_in_recon_queue",
      LogFormat.readable(UAV.name),
      LogFormat.value(UAV.guid),
      LogFormat.value(target.guid)
    )
    Logger.log(constants.TAGS.RECON, LogFormat.event("scope", "targetTracking", "FAIL", msg))
    return false
  end

  assignTrackingMission(queueEntry, target.guid)
  local msg = string.format(
    "uav=%s target=%s action=assign_tracking",
    LogFormat.readable(UAV.name),
    LogFormat.value(target.guid)
  )
  Logger.log(constants.TAGS.RECON, LogFormat.event("scope", "targetTracking", "OK", msg))
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

---Locate the queue entries bracketing current time by endTime
---Scans the reconnaissance queue for the entry whose endTime most recently passed and the next upcoming one.
---@param reconContext SBJ__ReconContext Reconnaissance context containing the queue
---@return SBJ__ReconQueueEntry|nil mostRecentEntry Entry with the latest endTime at or before current time
---@return SBJ__ReconQueueEntry|nil nextEntry Entry with the earliest endTime after current time
local function findMatchingSatelliteEntry(reconContext)
  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  local mostRecentEntry = nil
  local mostRecentTimestamp = -1
  local nextEntry = nil
  local nextTimestamp = math.huge

  for _, element in ipairs(reconContext.queue) do
    -- Only satellite passes anchor the gap window. Dynamically inserted UAVs (and SIGINT
    -- entries) must be excluded, or a prior UAV would skew the boundary and let duplicates in.
    if element.type == ENTRY_TYPE.SATELLITE then
      ---@type integer
      local elementTimestamp = Utils.parseDatetimeToTimestamp(element.endTime)

      if elementTimestamp <= currentTimestamp and elementTimestamp > mostRecentTimestamp then
        mostRecentEntry = element
        mostRecentTimestamp = elementTimestamp
      elseif elementTimestamp > currentTimestamp and elementTimestamp < nextTimestamp then
        nextEntry = element
        nextTimestamp = elementTimestamp
      end
    end
  end

  return mostRecentEntry, nextEntry
end

---Find an unfinished UAV entry from the same template already covering the time window
---The window spans (mostRecentEntry.endTime, nextEntry.endTime]; both takeoffTime and endTime must fall within it.
---@param reconContext SBJ__ReconContext Reconnaissance context containing the queue
---@param entryTemplate SBJ__ReconQueueEntryTemplateUAV UAV entry template whose templateId is matched against
---@param mostRecentEntry SBJ__ReconQueueEntry|nil Entry bounding the window start (nil treats start as unbounded)
---@param nextEntry SBJ__ReconQueueEntry Entry bounding the window end
---@return SBJ__ReconQueueEntry|nil entry Matching UAV entry or nil if none covers the window
local function findMatchingUAVEntry(reconContext, entryTemplate, mostRecentEntry, nextEntry)
  for _, entry in ipairs(reconContext.queue) do
    if not entry.isFinished and entry.type == ENTRY_TYPE.UAV
        and entryTemplate.templateId ~= nil and entry.templateId == entryTemplate.templateId then
      local takeoffTimestamp = Utils.parseDatetimeToTimestamp(entry.takeoffTime)
      local endTimestamp = Utils.parseDatetimeToTimestamp(entry.endTime)
      local mostRecentTimestamp = mostRecentEntry and Utils.parseDatetimeToTimestamp(mostRecentEntry.endTime) or -1
      local nextTimestamp = Utils.parseDatetimeToTimestamp(nextEntry.endTime)

      if takeoffTimestamp > mostRecentTimestamp and
          takeoffTimestamp <= nextTimestamp and
          endTimestamp > mostRecentTimestamp and
          endTimestamp <= nextTimestamp then
        return entry
      end
    end
  end

  return nil
end

---Insert a UAV reconnaissance entry from a template if no equivalent entry covers the window
---Skips insertion when a matching UAV already exists, or when the flight would end after the next scheduled endTime.
---@param reconContext SBJ__ReconContext Reconnaissance context (queue mutated on success)
---@param entryTemplate SBJ__ReconQueueEntryTemplateUAV UAV entry template to instantiate
---@param startTime string|nil Timestamp or datetime string for the start time of the entry
---@return SBJ__ReconQueueEntryUAV|nil # The inserted entry, or nil if no entry was inserted
function Recon.insertEntry(reconContext, entryTemplate, startTime)
  local entry = Utils.deepCopy(entryTemplate)
  ---@cast entry SBJ__ReconQueueEntry
  local _, flightTime = GameUtils.calculatePathDistanceAndTime(entry.course, entry.speed)
  local startTimestamp = startTime and Utils.parseDatetimeToTimestamp(startTime) or GameApi.ScenEdit_CurrentTime()
  local endTime = startTimestamp + flightTime
  local mostRecentEntry, nextEntry = findMatchingSatelliteEntry(reconContext)

  if not nextEntry then
    return nil
  end

  local matchingUAVEntry = findMatchingUAVEntry(reconContext, entryTemplate, mostRecentEntry, nextEntry)

  if not matchingUAVEntry then
    local nextEntryTimestamp = Utils.parseDatetimeToTimestamp(nextEntry.endTime)

    if endTime <= nextEntryTimestamp then
      entry.takeoffTime = os.date("!%Y-%m-%d %H:%M:%S", startTimestamp) --[[@as string]]
      entry.endTime = os.date("!%Y-%m-%d %H:%M:%S", endTime) --[[@as string]]
      entry.hasLaunched = false
      entry.isFinished = false
      entry.trackingTargetGUID = nil
      table.insert(reconContext.queue, entry)
      return entry
    end
  end

  return nil
end

return Recon
