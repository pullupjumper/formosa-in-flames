local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local OperationScheduler = require("src.modules.strikePlanner.operationScheduler")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local Recon = {}


local ENTRY_TYPE = {
  UAV = "UAV",
  SATELLITE = "satellite",
  SIGINT = "SIGINT"
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
---@return SBJ__LogResult # Launch outcome row
local function handleReconLaunch(entry)
  if entry.hasLaunched or not GameUtils.isAfterStartTime(entry.takeoffTime) then
    return { tag = "SKIP", fields = { base = entry.baseGUID, reason = "takeoff_time_not_reached" } }
  end

  local units = launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, "Aircraft")

  if #units > 0 then
    entry.unitGUID = units[1].guid
    entry.hasLaunched = true
    return { tag = "OK", fields = { unit = units[1].name, base = entry.baseGUID, action = "launch" } }
  else
    return { tag = "FAIL", fields = { base = entry.baseGUID, reason = "launch_failed" } }
  end
end

---Handle reconnaissance tracking mode - continuously update course to track moving target
---Caller must have already established that entry.trackingTargetGUID is set; a
---missing GUID is treated as "not tracking" one level up and completes normally.
---@param entry SBJ__ReconQueueEntryUAV Queue entry (UAV only, tracking target assigned)
---@param actualUnit CMO__Unit The reconnaissance unit
---@return boolean isUpdated Whether the course was successfully retargeted
---@return SBJ__LogResult result Tracking outcome row
local function handleReconTracking(entry, actualUnit)
  if not entry.speed then
    return false, {
      tag = "FAIL",
      fields = { unit = actualUnit.name, reason = "speed_not_configured" }
    }
  end

  local target = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, entry.trackingTargetGUID)

  if not target then
    return false, {
      tag = "FAIL",
      fields = { target = entry.trackingTargetGUID, reason = "tracking_target_lost" }
    }
  end

  -- Update course to target position (continuous tracking for missile guidance)
  actualUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = entry.speed,
    presetThrottle = "Military"
  } }

  return true, {
    tag = "OK",
    fields = {
      unit = actualUnit.name,
      target = entry.trackingTargetGUID,
      action = "update_tracking"
    }
  }
end

---Settle reconnaissance mission and conditionally schedule next operations
---Idempotent: a settled entry is left untouched.
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Queue entry
---@param success boolean Mission success status
local function settleReconMission(processingContext, entry, success)
  -- Prevent double execution
  if entry.isFinished then
    return
  end

  entry.isFinished = true

  if success then
    -- Mission successful: intelligence data is complete, schedule next wave operations
    OperationScheduler.schedule(processingContext, entry)
  end
end

---Determine outcome when UAV is destroyed or missing
---@param entry SBJ__ReconQueueEntryUAV Queue entry
---@param isEndTimeReached boolean Whether endTime was reached before destruction
---@return boolean success Whether mission should be considered successful
---@return SBJ__LogResult result Destruction outcome row
local function handleUAVDestroyed(entry, isEndTimeReached)
  if isEndTimeReached then
    return true, {
      tag = "OK",
      fields = { unit = entry.unitGUID, state = "destroyed", result = "success", reason = "end_time_reached" }
    }
  else
    return false, {
      tag = "FAIL",
      fields = { unit = entry.unitGUID, state = "destroyed", result = "failed", reason = "destroyed_before_end_time" }
    }
  end
end

---Resolve the next action after a UAV has finished its course and reached endTime
---A tracking failure still settles the mission: the recon leg itself succeeded,
---so the row keeps the specific tracking reason plus missionStatus=completed.
---@param entry SBJ__ReconQueueEntryUAV Queue entry
---@param actualUnit CMO__Unit The reconnaissance unit
---@return boolean shouldSettle Whether the mission should be settled as successful
---@return SBJ__LogResult result Post-course outcome row
local function resolvePostCourseUAVAction(entry, actualUnit)
  if entry.isTracking and entry.trackingTargetGUID then
    local isUpdated, trackingResult = handleReconTracking(entry, actualUnit)

    if isUpdated then
      return false, trackingResult
    end

    trackingResult.fields.unit = trackingResult.fields.unit or actualUnit.name
    trackingResult.fields.state = "tracking_failed"
    trackingResult.fields.missionStatus = "completed"
    return true, trackingResult
  end

  return true, {
    tag = "OK",
    fields = { unit = actualUnit.name, action = "complete_mission" }
  }
end

---Process a single UAV reconnaissance queue entry through its full lifecycle
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntryUAV UAV queue entry to process
---@return SBJ__LogResult|nil # Outcome row, or nil if no logging needed
local function processUAVEntry(processingContext, entry)
  -- Phase 1: Launch reconnaissance units when time comes
  if not entry.hasLaunched then
    return handleReconLaunch(entry)
  end

  -- Already finished, skip
  if entry.isFinished then
    return nil
  end

  -- Phase 2: In-flight management
  local actualUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  -- Phase 2a: UAV destroyed or missing
  if not actualUnit then
    local success, result = handleUAVDestroyed(entry, isEndTimeReached)
    settleReconMission(processingContext, entry, success)
    return result
  end

  -- Phase 2b: Still flying course
  if #actualUnit.course > 0 then
    return {
      tag = "SKIP",
      fields = { unit = actualUnit.name, state = "in_flight", reason = "course_not_completed" }
    }
  end

  -- Phase 2c: Course complete but endTime not reached
  if not isEndTimeReached then
    return {
      tag = "SKIP",
      fields = { unit = actualUnit.name, state = "waiting_end_time", endTime = entry.endTime }
    }
  end

  -- Phase 2d: Mission completion or continued tracking
  local shouldSettle, result = resolvePostCourseUAVAction(entry, actualUnit)

  if shouldSettle then
    settleReconMission(processingContext, entry, true)
  end

  return result
end

---Process a single satellite reconnaissance queue entry
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Satellite or SIGINT queue entry to process
---@return SBJ__LogResult|nil # Outcome row, or nil if no logging needed
local function processSatelliteEntry(processingContext, entry)
  if entry.isFinished then
    return nil
  end

  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  if not isEndTimeReached then
    return { tag = "SKIP", fields = { state = "waiting_end_time", endTime = entry.endTime } }
  end

  settleReconMission(processingContext, entry, true)
  return { tag = "OK", fields = { action = "complete_mission", endTime = entry.endTime } }
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
  local _, activationFields = FrontlineRedirect.evaluate(config, reconContext)
  if activationFields then
    Logger.log(constants.TAGS.RECON,
      LogFormat.line("RESUME", LogFormat.merge({ scope = "frontlineRedirect" }, activationFields)))
  end

  local report = LogFormat.report(constants.TAGS.RECON, "reconQueue", "Process queue")

  for _, entry in ipairs(reconContext.queue) do
    local result

    if entry.type == ENTRY_TYPE.UAV then
      result = processUAVEntry(processingContext, entry)
    elseif entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      result = processSatelliteEntry(processingContext, entry)
    end

    if result then
      result.fields.entryType = entry.type
      report.add(result.tag, result.fields)
    end
  end

  report.emit()
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
    Logger.log(constants.TAGS.RECON, LogFormat.line("SKIP", {
      scope = "targetTracking",
      target = target.guid,
      platformDBID = UAVDBID,
      reason = "no_available_uav"
    }))
    return false
  end

  local queueEntry = findQueueEntryByUnitGUID(reconContext.queue, UAV.guid)
  if not queueEntry then
    Logger.error(LogFormat.line("FAIL", {
      scope = "targetTracking",
      uav = UAV.name,
      guid = UAV.guid,
      target = target.guid,
      reason = "uav_not_in_recon_queue"
    }))
    return false
  end

  assignTrackingMission(queueEntry, target.guid)
  Logger.log(constants.TAGS.RECON, LogFormat.line("OK", {
    scope = "targetTracking",
    uav = UAV.name,
    target = target.guid,
    action = "assign_tracking"
  }))
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
      entry.takeoffTime = os.date(constants.DATE_FORMAT, startTimestamp) --[[@as string]]
      entry.endTime = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]
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
