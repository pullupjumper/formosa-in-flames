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

local MAX_TRACKING_DISTANCE_NM = 1000
local WZ8_INITIAL_ALTITUDE = 20574
local WZ8_INITIAL_HEADING = 180
local WZ8_INITIAL_SPEED = 3300

-- ============================================================================
-- Unit Launch
-- ============================================================================

---Launch units from a base with specified parameters
---@param params SBJ__LaunchUnitsParams
---@return CMO__Unit[] # Returns array of launched unit objects (empty if none launched)
local function launchUnits(params)
  local baseGUID, course, unitCount = params.baseGUID, params.course, params.unitCount
  local unitDBID, unitType = params.unitDBID, params.unitType
  -- Single lookup: the wrapper already falls back to a name lookup on constants.SIDES.RED.
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

  if not base then
    return {}
  end

  local count = 0
  local launched = {}

  -- An empty hangar may expose no embarkedUnits table; indexing it would throw, and
  -- processQueue runs unprotected, so one bad base aborts the tick before saveData is saved.
  local embarked = base.embarkedUnits and base.embarkedUnits[unitType]
  if not embarked or #embarked == 0 then
    return {}
  end

  for _, guid in ipairs(embarked) do
    local candidate = GameApi.ScenEdit_GetUnit(guid)

    if candidate and candidate.dbid == unitDBID and candidate.readytime_v == 0 then
      GameApi.ScenEdit_SetDoctrine({ guid = candidate.guid, }, { automatic_evasion = false })
      candidate:Launch(true)
      candidate.course = course
      count = count + 1
      table.insert(launched, candidate)
    end

    if count >= unitCount then
      break
    end
  end

  return launched
end

---Remove a partially configured WZ-8 and report why it was abandoned
---A drone that never received its course would otherwise fly on at its spawn speed.
---@param wz8GUID string
---@param reason string
---@return nil # Always nil, so callers can tail-return it
local function abortWZ8Launch(wz8GUID, reason)
  GameApi.ScenEdit_DeleteUnit({ guid = wz8GUID })
  Logger.error(LogFormat.line("FAIL", {
    module = constants.TAGS.RECON,
    scope = "launchWZ8",
    guid = wz8GUID,
    action = "abort_launch",
    reason = reason
  }))
  return nil
end

---Create a fully configured WZ-8 reconnaissance drone at the H-6N's position
---Any failure after the unit exists deletes it; the H-6N only hands off on success.
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__Waypoint[]
---@return CMO__Unit|nil # Returns the WZ-8 unit if successfully launched, nil otherwise
local function createWZ8(h6n, course)
  local wz8 = GameApi.ScenEdit_AddUnit({
    side = constants.SIDES.RED,
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
  if not wz8 then return nil end

  local updatedUnit = GameApi.ScenEdit_UpdateUnit({
    guid = wz8.guid,
    mode = "add_sensor",
    dbid = constants.SENSORS.WZ8_RADAR,
    arc_detect = constants.SENSOR_ARCS,
    arc_track = constants.SENSOR_ARCS
  })
  if not updatedUnit then return abortWZ8Launch(wz8.guid, "add_sensor_failed") end

  -- Return value deliberately unchecked: ScenEdit_SetUnit is a pass-through wrapper whose
  -- success value is not guaranteed truthy, so gating deletion on it could bin a good drone.
  GameApi.ScenEdit_SetUnit({ guid = wz8.guid, base = constants.BASES.LONGTIAN_AAB })

  if not GameApi.ScenEdit_SetEMCON("Unit", wz8.guid, "Radar=Active") then
    return abortWZ8Launch(wz8.guid, "set_emcon_failed")
  end

  wz8.course = course
  h6n:RTB(true)
  return wz8
end

---Release a WZ-8 from an H-6N flying a recon entry and hand the entry over to it
---Only the unsettled entry is matched: a settled entry may still hold this airframe's
---GUID from an earlier sortie whose WZ-8 release failed.
---@param reconCtx SBJ__ReconContext
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@return CMO__Unit|nil # The launched WZ-8, or nil when no entry is flying this H-6N or the launch failed
function Recon.launchWZ8(reconCtx, h6n)
  for _, entry in ipairs(reconCtx.queue) do
    if entry.type == ENTRY_TYPE.UAV and entry.unitGUID == h6n.guid and not entry.isFinished then
      local wz8 = createWZ8(h6n, constants.COURSES.WZ8)

      if wz8 then
        entry.unitGUID = wz8.guid
      end

      return wz8
    end
  end

  return nil
end

-- ============================================================================
-- Recon Flight Management
-- ============================================================================

---Run phase 1 of an entry: send its aircraft up once takeoff time has passed
---@param entry SBJ__ReconUAVEntry Queue entry to process (UAV only)
---@return SBJ__LogResult # Launch outcome row
local function startLaunchPhase(entry)
  if not GameUtils.isAfterStartTime(entry.takeoffTime) then
    return { tag = "SKIP", fields = { base = entry.baseGUID, reason = "takeoff_time_not_reached" } }
  end

  local launchedUnit = launchUnits({
    baseGUID = entry.baseGUID,
    course = entry.course,
    unitCount = 1,
    unitDBID = entry.unitDBID,
    unitType = "Aircraft"
  })[1]

  if not launchedUnit then
    return { tag = "FAIL", fields = { base = entry.baseGUID, reason = "launch_failed" } }
  end

  entry.unitGUID = launchedUnit.guid
  entry.hasLaunched = true
  return { tag = "OK", fields = { unit = launchedUnit.name, base = entry.baseGUID, action = "launch" } }
end

---Point a shadowing UAV at its target's latest known position
---The course holds a single waypoint, so the next update waits until the UAV reaches it.
---@param entry SBJ__ReconUAVEntry Queue entry (UAV only, tracking target assigned)
---@param reconUnit CMO__Unit
---@return boolean isUpdated Whether the course was successfully updated
---@return SBJ__LogResult result Tracking outcome row
local function updateTrackingCourse(entry, reconUnit)
  -- WZ8_RECON_ISLAND launches an H-6N but shadows with the WZ-8 it releases, so the
  -- tracking speed is a separate field from the one driving flight-time estimation.
  local trackingSpeed = entry.trackingSpeed or entry.speed

  if not trackingSpeed then
    return false, {
      tag = "FAIL",
      fields = { unit = reconUnit.name, reason = "speed_not_configured" }
    }
  end

  local target = GameApi.ScenEdit_GetContact(constants.SIDES.RED, entry.trackingTargetGUID)

  if not target then
    return false, {
      tag = "FAIL",
      fields = { target = entry.trackingTargetGUID, reason = "tracking_target_lost" }
    }
  end

  reconUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = trackingSpeed,
    presetThrottle = "Military"
  } }

  return true, {
    tag = "OK",
    fields = {
      unit = reconUnit.name,
      target = entry.trackingTargetGUID,
      action = "update_tracking"
    }
  }
end

---Settle reconnaissance mission and conditionally schedule next operations
---Scheduling fires at most once per entry, gated by hasScheduledOperations.
---@param processingCtx SBJ__ReconQueueProcessingContext
---@param entry SBJ__ReconQueueEntry
---@param success boolean
local function settleReconMission(processingCtx, entry, success)
  if entry.isFinished then
    return
  end

  entry.isFinished = true

  -- Never cleared, unlike isFinished: a re-tracked entry that settles again must not
  -- re-queue its wave and walk the /N strike counter forward.
  if success and not entry.hasScheduledOperations then
    entry.hasScheduledOperations = true
    OperationScheduler.schedule(processingCtx, entry)
  end
end

---Determine outcome when UAV is destroyed or missing
---@param entry SBJ__ReconUAVEntry
---@param isEndTimeReached boolean Whether endTime was reached before destruction
---@return boolean success Whether mission should be considered successful
---@return SBJ__LogResult result Destruction outcome row
local function resolveDestroyedUAVOutcome(entry, isEndTimeReached)
  if isEndTimeReached then
    return true, {
      tag = "OK",
      fields = { guid = entry.unitGUID, state = "destroyed", result = "success", reason = "end_time_reached" }
    }
  else
    return false, {
      tag = "FAIL",
      fields = { guid = entry.unitGUID, state = "destroyed", result = "failed", reason = "destroyed_before_end_time" }
    }
  end
end

---Resolve the next action after a UAV has finished its course and reached endTime
---A tracking failure still settles the mission: the recon leg itself succeeded.
---@param entry SBJ__ReconUAVEntry
---@param reconUnit CMO__Unit
---@return boolean shouldSettle Whether the mission should be settled as successful
---@return SBJ__LogResult result Post-course outcome row
local function resolvePostCourseUAVAction(entry, reconUnit)
  if entry.isTracking and entry.trackingTargetGUID then
    local isUpdated, trackingResult = updateTrackingCourse(entry, reconUnit)

    if isUpdated then
      return false, trackingResult
    end

    trackingResult.fields.unit = trackingResult.fields.unit or reconUnit.name
    trackingResult.fields.state = "tracking_failed"
    trackingResult.fields.missionStatus = "completed"
    return true, trackingResult
  end

  return true, {
    tag = "OK",
    fields = { unit = reconUnit.name, action = "complete_mission" }
  }
end

---Process a single UAV reconnaissance queue entry through its full lifecycle
---@param processingCtx SBJ__ReconQueueProcessingContext
---@param entry SBJ__ReconUAVEntry
---@return SBJ__LogResult|nil # Outcome row, or nil if no logging needed
local function processUAVEntry(processingCtx, entry)
  -- Phase 1: Launch reconnaissance units when time comes
  if not entry.hasLaunched then
    return startLaunchPhase(entry)
  end

  if entry.isFinished then
    return nil
  end

  -- Phase 2: In-flight management
  local reconUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  -- Phase 2a: UAV destroyed or missing
  if not reconUnit then
    local success, result = resolveDestroyedUAVOutcome(entry, isEndTimeReached)
    settleReconMission(processingCtx, entry, success)
    return result
  end

  -- Phase 2b: Still flying course
  if #reconUnit.course > 0 then
    return {
      tag = "SKIP",
      fields = { unit = reconUnit.name, state = "in_flight", reason = "course_not_completed" }
    }
  end

  -- Phase 2c: Course complete but endTime not reached
  if not isEndTimeReached then
    return {
      tag = "SKIP",
      fields = { unit = reconUnit.name, state = "waiting_end_time", endTime = entry.endTime }
    }
  end

  -- Phase 2d: Mission completion or continued tracking
  local shouldSettle, result = resolvePostCourseUAVAction(entry, reconUnit)

  if shouldSettle then
    settleReconMission(processingCtx, entry, true)
  end

  return result
end

---Process a single satellite or SIGINT queue entry, which settles purely on the clock
---@param processingCtx SBJ__ReconQueueProcessingContext
---@param entry SBJ__ReconPassiveEntry
---@return SBJ__LogResult|nil # Outcome row, or nil if no logging needed
local function processPassiveEntry(processingCtx, entry)
  if entry.isFinished then
    return nil
  end

  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  if not isEndTimeReached then
    return { tag = "SKIP", fields = { state = "waiting_end_time", endTime = entry.endTime } }
  end

  settleReconMission(processingCtx, entry, true)
  return { tag = "OK", fields = { action = "complete_mission", endTime = entry.endTime } }
end

-- ============================================================================
-- Target Tracking
-- ============================================================================

---Check if any UAV in the queue is already tracking the specified target
---A settled entry does not count: processQueue skips it, so its GUID is stale.
---@param queue SBJ__ReconQueueEntry[]
---@param targetGUID string
---@return boolean # True if target is already being tracked by an active UAV
local function isTargetAlreadyTracked(queue, targetGUID)
  for _, entry in ipairs(queue) do
    if entry.type == ENTRY_TYPE.UAV and
        entry.trackingTargetGUID == targetGUID and
        entry.unitGUID and
        not entry.isFinished then
      local unit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
      if unit then return true end
    end
  end
  return false
end

---Find a queue entry by its assigned unit GUID
---@param queue SBJ__ReconQueueEntry[]
---@param unitGUID string
---@return SBJ__ReconUAVEntry|nil # Matching queue entry or nil
local function findQueueEntryByUnitGUID(queue, unitGUID)
  for _, entry in ipairs(queue) do
    if entry.type == ENTRY_TYPE.UAV and entry.unitGUID == unitGUID then
      return entry
    end
  end
  return nil
end

---Check whether one UAV is already shadowing a target
---A settled entry does not count: its airframe is free to take a new target.
---@param queue SBJ__ReconQueueEntry[]
---@param unitGUID string
---@return boolean # True when the UAV is committed to an active tracking target
local function isUAVAlreadyTracking(queue, unitGUID)
  local entry = findQueueEntryByUnitGUID(queue, unitGUID)
  return entry ~= nil and entry.trackingTargetGUID ~= nil and not entry.isFinished
end

---Find the closest available UAV of specified type within tracking distance
---A UAV shadowing another target is skipped: assignTrackingMission would drop it.
---@param queue SBJ__ReconQueueEntry[]
---@param sideUnits CMO__SideUnit[]
---@param uavDBID number
---@param target CMO__Contact
---@return CMO__Unit|nil # Closest available UAV or nil if none found
local function findClosestUAV(queue, sideUnits, uavDBID, target)
  local uav = nil
  local minDistance = MAX_TRACKING_DISTANCE_NM

  for _, sideUnit in ipairs(sideUnits) do
    local candidate = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    if candidate and candidate.dbid == uavDBID and candidate.condition == "Airborne"
        and not isUAVAlreadyTracking(queue, candidate.guid) then
      local distance = GameApi.Tool_Range({
        latitude = candidate.latitude,
        longitude = candidate.longitude
      }, target.guid)

      if distance and distance < minDistance then
        minDistance = distance
        uav = candidate
      end
    end
  end

  return uav
end

---Assign a tracking mission to a queue entry
---Clears isFinished to resume the entry; hasScheduledOperations is left set on purpose.
---@param queueEntry SBJ__ReconUAVEntry
---@param targetGUID string
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
---@param processingCtx SBJ__ReconQueueProcessingContext
function Recon.processQueue(processingCtx)
  local config = processingCtx.config
  local reconCtx = processingCtx.reconCtx

  -- Evaluated every tick so a quiet queue still activates the rewrite in time; the
  -- activation row is emitted here so processQueue owns all log output.
  local _, activationFields = FrontlineRedirect.evaluate(config, reconCtx)
  if activationFields then
    Logger.log(constants.TAGS.RECON,
      LogFormat.line("RESUME", LogFormat.merge({ scope = "frontlineRedirect" }, activationFields)))
  end

  local report = LogFormat.report(constants.TAGS.RECON, "reconQueue", "Process queue")

  for _, entry in ipairs(reconCtx.queue) do
    local result

    if entry.type == ENTRY_TYPE.UAV then
      result = processUAVEntry(processingCtx, entry)
    elseif entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      result = processPassiveEntry(processingCtx, entry)
    end

    if result then
      result.fields.entryType = entry.type
      report.add(result.tag, result.fields)
    end
  end

  report.emit()
end

---Assign UAV to track a specific target contact
---Finds available UAV of specified type and assigns it to shadow the target
---Callers must skip targets that are already tracked (see isTargetAlreadyTracked).
---@param reconCtx SBJ__ReconContext
---@param sideUnits CMO__SideUnit[]
---@param uavDBID number
---@param target CMO__Contact
---@return boolean # True if UAV was assigned to track target, false otherwise
local function trackTarget(reconCtx, sideUnits, uavDBID, target)
  local uav = findClosestUAV(reconCtx.queue, sideUnits, uavDBID, target)
  if not uav then
    Logger.log(constants.TAGS.RECON, LogFormat.line("SKIP", {
      scope = "targetTracking",
      target = target.guid,
      platformDBID = uavDBID,
      reason = "no_available_uav"
    }))
    return false
  end

  local queueEntry = findQueueEntryByUnitGUID(reconCtx.queue, uav.guid)
  if not queueEntry then
    Logger.error(LogFormat.line("FAIL", {
      module = constants.TAGS.RECON,
      scope = "targetTracking",
      unit = uav.name,
      guid = uav.guid,
      target = target.guid,
      reason = "uav_not_in_recon_queue"
    }))
    return false
  end

  assignTrackingMission(queueEntry, target.guid)
  Logger.log(constants.TAGS.RECON, LogFormat.line("OK", {
    scope = "targetTracking",
    unit = uav.name,
    target = target.guid,
    action = "assign_tracking"
  }))
  return true
end

---Serve the tracking requests raised by target filters
---Each target is checked against the queue before the side sweep, and the sweep runs at most
---once per call: the atoBuilder observation window re-evaluates targets every tick, so an
---already-shadowed target must cost nothing.
---@param reconCtx SBJ__ReconContext
---@param requests SBJ__TrackingRequestEntry[]
function Recon.trackTargets(reconCtx, requests)
  local aircraft
  for _, request in ipairs(requests) do
    if not isTargetAlreadyTracked(reconCtx.queue, request.target.guid) then
      if aircraft == nil then
        local side = GameApi.VP_GetSide({ side = constants.SIDES.RED })
        aircraft = side and side:unitsBy(constants.UNIT_TYPES.AIRCRAFT) or false
      end
      if not aircraft then
        return
      end

      trackTarget(reconCtx, aircraft, request.platformDBID, request.target)
    end
  end
end

---Turn the configured queue plans into runtime entries
---Deep-copied so the config table stays pristine across scenario reloads.
---@param reconConfig SBJ__ReconConfig
---@param reconCtx SBJ__ReconContext
function Recon.initQueue(reconConfig, reconCtx)
  local entries = Utils.deepCopy(reconConfig.queue)

  for _, entry in ipairs(entries) do
    -- The cast is this loop's whole job: a plan becomes an entry once the run-state
    -- flags below are set, which is exactly what SBJ__ReconQueueEntry adds over the plan.
    ---@cast entry SBJ__ReconQueueEntry
    entry.hasScheduledOperations = false
    entry.isFinished = false

    if entry.type == ENTRY_TYPE.UAV then
      entry.hasLaunched = false
    end
  end

  reconCtx.queue = entries
end

---Locate the queue entries bracketing current time by endTime
---Scans the reconnaissance queue for the entry whose endTime most recently passed and the next upcoming one.
---@param reconCtx SBJ__ReconContext
---@return SBJ__ReconQueueEntry|nil mostRecentEntry Entry with the latest endTime at or before current time
---@return SBJ__ReconQueueEntry|nil nextEntry Entry with the earliest endTime after current time
local function findSatellitePassWindow(reconCtx)
  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  local mostRecentEntry = nil
  local mostRecentTimestamp = -1
  local nextEntry = nil
  local nextTimestamp = math.huge

  for _, entry in ipairs(reconCtx.queue) do
    -- Only satellite passes anchor the gap window. Dynamically inserted UAVs (and SIGINT
    -- entries) must be excluded, or a prior UAV would skew the boundary and let duplicates in.
    if entry.type == ENTRY_TYPE.SATELLITE then
      ---@type integer
      local entryTimestamp = Utils.parseDatetimeToTimestamp(entry.endTime)

      if entryTimestamp <= currentTimestamp and entryTimestamp > mostRecentTimestamp then
        mostRecentEntry = entry
        mostRecentTimestamp = entryTimestamp
      elseif entryTimestamp > currentTimestamp and entryTimestamp < nextTimestamp then
        nextEntry = entry
        nextTimestamp = entryTimestamp
      end
    end
  end

  return mostRecentEntry, nextEntry
end

---Find an unfinished UAV entry from the same template already covering the time window
---The window spans (mostRecentEntry.endTime, nextEntry.endTime]; both takeoffTime and endTime must fall within it.
---@param reconCtx SBJ__ReconContext
---@param templateId string
---@param mostRecentEntry SBJ__ReconQueueEntry|nil Entry bounding the window start (nil treats start as unbounded)
---@param nextEntry SBJ__ReconQueueEntry
---@return SBJ__ReconQueueEntry|nil entry Matching UAV entry or nil if none covers the window
local function findMatchingUAVEntry(reconCtx, templateId, mostRecentEntry, nextEntry)
  -- Window bounds are loop invariants and parseDatetimeToTimestamp is not cheap.
  local mostRecentTimestamp = mostRecentEntry and Utils.parseDatetimeToTimestamp(mostRecentEntry.endTime) or -1
  local nextTimestamp = Utils.parseDatetimeToTimestamp(nextEntry.endTime)

  for _, entry in ipairs(reconCtx.queue) do
    if not entry.isFinished and entry.type == ENTRY_TYPE.UAV
        and entry.templateId == templateId then
      local takeoffTimestamp = Utils.parseDatetimeToTimestamp(entry.takeoffTime)
      local endTimestamp = Utils.parseDatetimeToTimestamp(entry.endTime)

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
---@param reconCtx SBJ__ReconContext
---@param entryTemplate SBJ__ReconUAVTemplate
---@param startTime string|nil Timestamp or datetime string for the start time of the entry
---@return SBJ__ReconUAVEntry|nil # The inserted entry, or nil if no entry was inserted
function Recon.addEntry(reconCtx, entryTemplate, startTime)
  local entry = Utils.deepCopy(entryTemplate)
  ---@cast entry SBJ__ReconUAVEntry
  local _, flightTime = GameUtils.calculatePathDistanceAndTime(entry.course, entry.speed)
  local startTimestamp = startTime and Utils.parseDatetimeToTimestamp(startTime) or GameApi.ScenEdit_CurrentTime()
  local endTime = startTimestamp + flightTime
  local mostRecentEntry, nextEntry = findSatellitePassWindow(reconCtx)

  if not nextEntry then
    return nil
  end

  local matchingUAVEntry = findMatchingUAVEntry(reconCtx, entryTemplate.templateId, mostRecentEntry,
    nextEntry)

  if not matchingUAVEntry then
    local nextEntryTimestamp = Utils.parseDatetimeToTimestamp(nextEntry.endTime)

    if endTime <= nextEntryTimestamp then
      entry.takeoffTime = os.date(constants.DATE_FORMAT, startTimestamp) --[[@as string]]
      entry.endTime = os.date(constants.DATE_FORMAT, endTime) --[[@as string]]
      entry.hasLaunched = false
      entry.isFinished = false
      entry.hasScheduledOperations = false
      entry.trackingTargetGUID = nil
      table.insert(reconCtx.queue, entry)
      return entry
    end
  end

  return nil
end

return Recon
