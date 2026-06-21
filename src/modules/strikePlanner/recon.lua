local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
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
-- Airbase Attrition
-- ============================================================================

---Calculate aggregated aircraft attrition across multiple configured airbases
---Aircraft count as combat-capable iff both they and their home base are alive (airborne included); destroyed base zeroes the wing.
---@param deployments SBJ__AirbaseDeploymentDescriptor[] Airbase deployment descriptors
---@param baseNames string[] Airbase names to query (empty array yields a zero summary)
---@param side? string Side name to enumerate aircraft from (default: constants.SIDES.ENEMY)
---@return SBJ__AirbaseAttritionSummary # Per-base details and overall attrition summary
function Recon.calculateAirbaseAttrition(deployments, baseNames, side)
  side = side or constants.SIDES.ENEMY

  -- Phase 1: Build lookup tables.
  -- descriptorByName: translate user-supplied baseName -> descriptor.
  -- baseAcc: GUID-keyed accumulator for aircraft attribution (stable identity).
  local descriptorByName = {}
  for _, descriptor in ipairs(deployments) do
    if descriptor.name then
      descriptorByName[descriptor.name] = descriptor
    end
  end

  ---@type SBJ__AirbaseAttritionSummary
  local summary = {
    queriedBaseNames = Utils.deepCopy(baseNames),
    expectedTotal = 0,
    currentTotal = 0,
    lossTotal = 0,
    attritionPct = 0,
    bases = {},
    missingBases = {}
  }

  ---@type table<string, table>
  local baseAcc = {}
  -- Preserve query order so summary.bases output is deterministic.
  local orderedGUIDs = {}

  for _, baseName in ipairs(baseNames) do
    local descriptor = descriptorByName[baseName]
    if not descriptor or not descriptor.baseGUID then
      table.insert(summary.missingBases, baseName)
    else
      local expectedByDBID = {}
      local expectedTotal = 0

      for _, group in ipairs(descriptor.embarkedUnits or {}) do
        local groupExpected = 0
        for _, loadout in ipairs(group.loadouts or {}) do
          groupExpected = groupExpected + (loadout.num or 0)
        end

        if group.dbid and groupExpected > 0 then
          expectedByDBID[group.dbid] = (expectedByDBID[group.dbid] or 0) + groupExpected
          expectedTotal = expectedTotal + groupExpected
        end
      end

      baseAcc[descriptor.baseGUID] = {
        baseName = baseName,
        baseGUID = descriptor.baseGUID,
        expectedByDBID = expectedByDBID,
        expectedTotal = expectedTotal,
        actualByDBID = {},
        currentTotal = 0,
        isDestroyed = false
      }
      table.insert(orderedGUIDs, descriptor.baseGUID)
    end
  end

  -- Phase 2: Detect destroyed airbases.
  -- A destroyed base means the wing is combat-incapable (no ground crew/runway/refuel),
  -- so currentTotal stays at 0 even if some of its aircraft are still airborne.
  for _, baseGUID in ipairs(orderedGUIDs) do
    local base = baseAcc[baseGUID]
    local baseUnit = GameApi.ScenEdit_GetUnit(baseGUID)
    if not baseUnit then
      base.isDestroyed = true
    end
  end

  -- Phase 3: Enumerate side-wide aircraft and attribute by aircraft.base.guid.
  -- This counts both grounded and airborne aircraft as long as their home base is alive.
  local sideObj = GameApi.VP_GetSide({ side = side })
  if sideObj then
    local aircraftList = sideObj:unitsBy(constants.UNIT_TYPES.AIRCRAFT) or {}
    for _, entry in ipairs(aircraftList) do
      local aircraft = GameApi.ScenEdit_GetUnit(entry.guid)
      if aircraft and aircraft.dbid and aircraft.base and aircraft.base.guid then
        local base = baseAcc[aircraft.base.guid]
        if base and not base.isDestroyed and base.expectedByDBID[aircraft.dbid] then
          base.actualByDBID[aircraft.dbid] = (base.actualByDBID[aircraft.dbid] or 0) + 1
          base.currentTotal = base.currentTotal + 1
        end
      end
    end
  end

  -- Phase 4: Per-base settlement and aggregate.
  for _, baseGUID in ipairs(orderedGUIDs) do
    local base = baseAcc[baseGUID]
    local lossTotal = math.max(base.expectedTotal - base.currentTotal, 0)
    local attritionPct = 0
    if base.expectedTotal > 0 then
      attritionPct = (lossTotal / base.expectedTotal) * 100
    end

    local details = {}
    for dbid, expected in pairs(base.expectedByDBID) do
      local current = base.actualByDBID[dbid] or 0
      table.insert(details, {
        dbid = dbid,
        expected = expected,
        current = current,
        loss = math.max(expected - current, 0)
      })
    end
    table.sort(details, function(a, b) return a.dbid < b.dbid end)

    table.insert(summary.bases, {
      baseName = base.baseName,
      baseGUID = base.baseGUID,
      expectedTotal = base.expectedTotal,
      currentTotal = base.currentTotal,
      lossTotal = lossTotal,
      attritionPct = attritionPct,
      isDestroyed = base.isDestroyed,
      details = details
    })

    summary.expectedTotal = summary.expectedTotal + base.expectedTotal
    summary.currentTotal = summary.currentTotal + base.currentTotal
    summary.lossTotal = summary.lossTotal + lossTotal
  end

  if summary.expectedTotal > 0 then
    summary.attritionPct = (summary.lossTotal / summary.expectedTotal) * 100
  end

  return summary
end

-- ============================================================================
-- Dynamic Operations Scheduling
-- ============================================================================

---Decide whether frontline strike packages should be redirected to rear bases with AAR
---Sticky: mutates reconContext.frontlineRedirected on first trigger; skips recompute thereafter and defers logging to caller.
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (mutated when redirect triggers)
---@return boolean isRedirected Whether redirect is active after this evaluation
---@return string|nil activationMessage Non-nil only on the tick redirect just activated; caller should log it
local function shouldRedirectFrontlineStrike(config, reconContext)
  if reconContext.frontlineRedirected then
    return true, nil
  end

  local cfg = config.c.recon.frontlineRedirect
  if not cfg or not cfg.enabled then
    return false, nil
  end

  local summary = Recon.calculateAirbaseAttrition(config.c.air.landBased.deployedACs, cfg.frontlineBaseNames)

  if summary.attritionPct >= cfg.attritionThresholdPct then
    reconContext.frontlineRedirected = true
    return true, string.format(
      "action=activate reason=attrition_threshold_reached attritionPct=%.1f thresholdPct=%.1f expected=%d current=%d",
      summary.attritionPct, cfg.attritionThresholdPct, summary.expectedTotal, summary.currentTotal)
  end

  return false, nil
end

---Apply mapping name rewrites for frontline redirect
---Returns a deep-copied list to avoid mutating shared strike mappings in config.
---@param strikeMappings SBJ__ReconStrikeMapping[] Original mapping list (not mutated)
---@param rules SBJ__StrikeMappingRewriteRule[] Rewrite rules
---@return SBJ__ReconStrikeMapping[] # Copy with names rewritten where applicable
local function rewriteStrikeMappings(strikeMappings, rules)
  local result = Utils.deepCopy(strikeMappings)
  for _, m in ipairs(result) do
    for _, rule in ipairs(rules) do
      if m.type == rule.type and m.name:sub(1, #rule.fromPrefix) == rule.fromPrefix then
        m.name = rule.toPrefix .. m.name:sub(#rule.fromPrefix + 1)
        break
      end
    end
  end
  return result
end

---Find strike mappings for a completed reconnaissance objective
---@param strikeMappingsByReconObjective table<string, SBJ__ReconStrikeMapping[]> Strike mappings indexed by reconObjectiveId
---@param entry SBJ__ReconQueueEntry Queue entry to find mappings for
---@return SBJ__ReconStrikeMapping[]|nil # Matching strike mappings or nil if not found
local function findStrikeMappingsForReconObjective(strikeMappingsByReconObjective, entry)
  if not entry.reconObjectiveId then return nil end
  return strikeMappingsByReconObjective[entry.reconObjectiveId]
end

---Build a single operation from a strike mapping configuration
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping definition
---@param config SBJ__Config Configuration data
---@param LACMContext SBJ__LACMContext LACM context data
---@return SBJ__Operation|nil operation Built operation or nil if skipped
---@return string logEntry Log entry describing the result
local function buildOperationFromMapping(strikeMapping, config, LACMContext)
  if strikeMapping.name == "STRIKE/AB/E/1" and not LACMContext.enabled then
    return nil, LogFormat.entry("SKIP", string.format("operation=%s type=%s reason=lacm_not_active",
      LogFormat.value(strikeMapping.name),
      LogFormat.value(strikeMapping.type)
    ))
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

  return newOperation, LogFormat.entry("OK", string.format("operation=%s type=%s action=schedule_new",
    LogFormat.value(strikeMapping.name),
    LogFormat.value(strikeMapping.type)
  ))
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

  -- Skip if an equivalent next wave is already scheduled but not yet executed; otherwise the same
  -- /N+1 would be queued again from a later recon completion and double the strike package.
  -- REUSED_CURRENT (no next-wave template; reuses the already-executed /N) is intentionally kept.
  if status == "FOUND_NEXT"
      and DynamicOperationsUtils.hasPendingOperation(reconSchedule, nextOperation.template.name, strikeMapping.type) then
    return nil, LogFormat.entry("SKIP", string.format("operation=%s type=%s reason=already_pending",
      LogFormat.value(nextOperation.template.name),
      LogFormat.value(strikeMapping.type)
    ))
  end

  local logEntry = LogFormat.entry("OK", string.format(
    "operation=%s nextOperation=%s type=%s action=schedule_next status=%s",
    LogFormat.value(operation.template.name),
    LogFormat.value(nextOperation.template.name),
    LogFormat.value(strikeMapping.type),
    LogFormat.value(status)
  ))
  return nextOperation, logEntry
end

---Build follow-on operations unlocked by a completed reconnaissance objective
---Each objective maps to zero or more air/ground operations.
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (consulted for sticky redirect flag)
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
---@param fireSupportOnHold boolean Whether SRBM-driven mappings (STRIKE/INFRASTRUCTURE/*) should be skipped to conserve ammo
---@return SBJ__Operation[] operations Array of special operations to add
---@return string[] logEntries Array of log entry strings for batched output
local function buildOperationsForReconObjective(config, reconContext, reconSchedule, entry, LACMContext,
                                                fireSupportOnHold)
  local operations = {}
  local logEntries = {}
  local strikeMappingsByReconObjective = config.c.recon.strikeMappingsByReconObjective

  if not strikeMappingsByReconObjective then
    table.insert(logEntries, LogFormat.entry("ERROR", string.format(
      "type=%s reason=strike_mappings_by_recon_objective_not_found", LogFormat.value(entry.type))
    ))
    return operations, logEntries
  end

  if not entry.reconObjectiveId then
    table.insert(logEntries, LogFormat.entry("SKIP", string.format(
      "type=%s reason=recon_objective_not_assigned", LogFormat.value(entry.type))
    ))
    return operations, logEntries
  end

  local strikeMappings = findStrikeMappingsForReconObjective(strikeMappingsByReconObjective, entry)
  if not strikeMappings then
    table.insert(logEntries, LogFormat.entry("SKIP", string.format(
      "type=%s objective=%s reason=strike_mapping_not_found",
      LogFormat.value(entry.type),
      LogFormat.value(entry.reconObjectiveId))
    ))
    return operations, logEntries
  end

  -- Apply frontline redirect if sticky flag is set (set by handleReconQueue tick or earlier scheduling pass)
  if reconContext.frontlineRedirected and
      config.c.recon.frontlineRedirect and
      config.c.recon.frontlineRedirect.mappings then
    strikeMappings = rewriteStrikeMappings(strikeMappings, config.c.recon.frontlineRedirect.mappings)
  end

  for _, strikeMapping in ipairs(strikeMappings) do
    -- Gate: SRBM mappings (STRIKE/INFRASTRUCTURE/*) skipped while fire support is on hold
    if fireSupportOnHold and strikeMapping.name:find("^STRIKE/INFRASTRUCTURE/") then
      table.insert(logEntries, LogFormat.entry("HOLD", string.format(
        "operation=%s type=%s reason=fire_support_on_hold",
        LogFormat.value(strikeMapping.name),
        LogFormat.value(strikeMapping.type))
      ))
    else
      local skipMapping = false

      if not DynamicOperationsUtils.hasOperation(reconSchedule, strikeMapping.name, strikeMapping.type) then
        local newOp, logEntry = buildOperationFromMapping(strikeMapping, config, LACMContext)
        table.insert(logEntries, logEntry)
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
          table.insert(logEntries, nextLog)
        elseif nextLog then
          table.insert(logEntries, nextLog)
        end
      end
    end
  end

  return operations, logEntries
end

---Schedule dynamic operations for next wave based on completed reconnaissance
---Only called when UAV completes successfully (reached endTime with complete intelligence)
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (consulted for sticky redirect flag)
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
---@param fireSupportOnHold boolean Whether SRBM-driven mappings should be skipped to conserve ammo
local function scheduleDynamicReconOperations(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
  local reconResult = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconSchedule)

  -- Generate next wave operations
  local operations = {}

  -- Add operations unlocked by the completed reconnaissance objective.
  local reconTriggeredOps, logEntries = buildOperationsForReconObjective(
    config, reconContext, reconSchedule,
    entry, LACMContext, fireSupportOnHold
  )
  for _, op in ipairs(reconTriggeredOps) do
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

  table.insert(infoLines, LogFormat.entry("OK", string.format(
    "state=context mostRecentTime=%q nextReconTime=%q airOps=%d groundOps=%d",
    tostring(reconResult.mostRecentTime or "none"),
    tostring(reconResult.nextReconTime or "none"),
    #reconResult.air,
    #reconResult.ground)
  ))

  for _, logEntry in ipairs(logEntries) do
    table.insert(infoLines, logEntry)
  end

  if #operations > 0 then
    table.insert(infoLines, LogFormat.entry("OK", string.format(
      "action=schedule_operations scheduled=%d endTime=%q",
      #operations, entry.endTime)
    ))
  else
    table.insert(infoLines, LogFormat.entry("SKIP", string.format(
      "reason=no_operations_to_schedule endTime=%q", entry.endTime
    )))
  end

  Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary("reconType", entry.type,
    string.format("Schedule dynamic operations endTime=%q", entry.endTime), infoLines
  ))
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
    return LAUNCH_STATUS.NOT_READY, string.format(
      "base=%s reason=takeoff_time_not_reached",
      LogFormat.value(entry.baseGUID)
    )
  end

  local units = launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, "Aircraft")

  if #units > 0 then
    entry.unitGUID = units[1].guid
    entry.hasLaunched = true
    return LAUNCH_STATUS.LAUNCHED, string.format(
      "unit=%q base=%s action=launch", LogFormat.readable(units[1].name), LogFormat.value(entry.baseGUID))
  else
    return LAUNCH_STATUS.FAILED, string.format(
      "base=%s reason=launch_failed", LogFormat.value(entry.baseGUID))
  end
end

---Handle reconnaissance tracking mode - continuously update course to track moving target
---@param entry SBJ__ReconQueueEntryUAV Queue entry (UAV only)
---@param actualUnit CMO__Unit The reconnaissance unit
---@return string status Tracking status from TRACKING_STATUS
---@return string message Human-readable status description
local function handleReconTracking(entry, actualUnit)
  if not entry.trackingTargetGUID then
    return TRACKING_STATUS.NO_TARGET_GUID, string.format("unit=%q reason=tracking_target_not_assigned",
      LogFormat.readable(actualUnit.name))
  end

  if not entry.speed then
    return TRACKING_STATUS.NO_SPEED, string.format("unit=%q reason=speed_not_configured",
      LogFormat.readable(actualUnit.name))
  end

  local target = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, entry.trackingTargetGUID)

  if not target then
    return TRACKING_STATUS.TARGET_LOST, string.format("target=%s reason=tracking_target_lost",
      LogFormat.value(entry.trackingTargetGUID))
  end

  -- Update course to target position (continuous tracking for missile guidance)
  actualUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = entry.speed,
    presetThrottle = "Military"
  } }

  return TRACKING_STATUS.UPDATED, string.format("unit=%q target=%s action=update_tracking",
    LogFormat.readable(actualUnit.name), LogFormat.value(entry.trackingTargetGUID))
end

---Settle reconnaissance mission and conditionally schedule next operations
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (consulted for sticky redirect flag)
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry
---@param LACMContext SBJ__LACMContext LACM context data
---@param fireSupportOnHold boolean Whether SRBM-driven mappings should be skipped to conserve ammo
---@param success boolean Mission success status
---@return string # Mission result from MISSION_RESULT
local function settleReconMission(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold, success)
  -- Prevent double execution
  if entry.isFinished then
    return MISSION_RESULT.ALREADY_FINISHED
  end

  entry.isFinished = true

  if success then
    -- Mission successful: intelligence data is complete, schedule next wave operations
    scheduleDynamicReconOperations(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
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
    return true, string.format(
      "unit=%s state=destroyed result=success reason=end_time_reached", LogFormat.value(entry.unitGUID))
  else
    return false, string.format(
      "unit=%s state=destroyed result=failed reason=destroyed_before_end_time", LogFormat.value(entry.unitGUID))
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

  return POST_COURSE_ACTION.COMPLETE_MISSION,
      string.format("unit=%q action=complete_mission", LogFormat.readable(actualUnit.name))
end

---Process a single UAV reconnaissance queue entry through its full lifecycle
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (consulted for sticky redirect flag)
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntryUAV UAV queue entry to process
---@param LACMContext SBJ__LACMContext LACM context data
---@param fireSupportOnHold boolean Whether SRBM-driven mappings should be skipped to conserve ammo
---@return string|nil tag Semantic log tag (OK/SKIP/FAIL) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processUAVEntry(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
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
    settleReconMission(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold, success)
    local tag = success and "OK" or "FAIL"
    return tag, message
  end

  -- Phase 2b: Still flying course
  if #actualUnit.course > 0 then
    return "SKIP", string.format("unit=%q state=in_flight reason=course_not_completed",
      LogFormat.readable(actualUnit.name))
  end

  -- Phase 2c: Course complete but endTime not reached
  if not isEndTimeReached then
    return "SKIP", string.format("unit=%q state=waiting_end_time endTime=%q",
      LogFormat.readable(actualUnit.name), entry.endTime)
  end

  -- Phase 2d: Mission completion or continued tracking
  local postCourseAction, message = resolvePostCourseUAVAction(entry, actualUnit)

  if postCourseAction == POST_COURSE_ACTION.CONTINUE_TRACKING then
    return "OK", message
  end

  if postCourseAction == POST_COURSE_ACTION.TRACKING_FAILED then
    -- Tracking failed but recon completed successfully
    settleReconMission(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold, true)
    return "FAIL", string.format("unit=%q reason=tracking_failed missionStatus=completed",
      LogFormat.readable(actualUnit.name))
  end

  -- Normal reconnaissance completion
  settleReconMission(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold, true)
  return "OK", message
end

---Process a single satellite reconnaissance queue entry
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (consulted for sticky redirect flag)
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Satellite queue entry to process
---@param LACMContext SBJ__LACMContext LACM context data
---@param fireSupportOnHold boolean Whether SRBM-driven mappings should be skipped to conserve ammo
---@return string|nil tag Semantic log tag (OK/SKIP) or nil if no logging needed
---@return string|nil message Human-readable log message
local function processSatelliteEntry(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
  if entry.isFinished then
    return nil, nil
  end

  local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

  if not isEndTimeReached then
    return "SKIP", string.format("type=%s state=waiting_end_time endTime=%q",
      LogFormat.value(entry.type), entry.endTime)
  end

  settleReconMission(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold, true)
  return "OK", string.format("type=%s action=complete_mission endTime=%q",
    LogFormat.value(entry.type), entry.endTime)
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
---@param fireSupportOnHold boolean Whether SRBM-driven mappings (STRIKE/INFRASTRUCTURE/*) should be skipped to conserve ammo
function Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext, fireSupportOnHold)
  -- Proactively evaluate frontline-redirect sticky flag once per tick so the rewrite
  -- becomes effective on the next recon completion even if the queue is otherwise quiet.
  -- Activation log is captured here (instead of inside the helper) so handleReconQueue owns all log emission.
  local _, activationMessage = shouldRedirectFrontlineStrike(config, reconContext)
  if activationMessage then
    Logger.log(constants.TAGS.RECON, LogFormat.event("scope", "frontlineRedirect", "RESUME", activationMessage))
  end

  local infoLines = {}
  local errorLines = {}

  for _, entry in ipairs(reconContext.queue) do
    local tag, message

    if entry.type == ENTRY_TYPE.UAV then
      tag, message = processUAVEntry(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
    elseif entry.type == ENTRY_TYPE.SATELLITE or entry.type == ENTRY_TYPE.SIGINT then
      tag, message = processSatelliteEntry(config, reconContext, reconSchedule, entry, LACMContext, fireSupportOnHold)
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
    Logger.log(constants.TAGS.RECON, LogFormat.event(
      "scope", "targetTracking", "SKIP",
      string.format("target=%s platformDBID=%s reason=no_available_uav",
        LogFormat.value(target.guid), LogFormat.value(UAVDBID))))
    return false
  end

  local queueEntry = findQueueEntryByUnitGUID(reconContext.queue, UAV.guid)
  if not queueEntry then
    Logger.log(constants.TAGS.RECON, LogFormat.event(
      "scope", "targetTracking", "FAIL",
      string.format("uav=%s guid=%s target=%s reason=uav_not_in_recon_queue",
        LogFormat.readable(UAV.name),
        LogFormat.value(UAV.guid),
        LogFormat.value(target.guid))))
    return false
  end

  assignTrackingMission(queueEntry, target.guid)
  Logger.log(constants.TAGS.RECON, LogFormat.event(
    "scope", "targetTracking", "OK",
    string.format("uav=%s target=%s action=assign_tracking",
      LogFormat.readable(UAV.name), LogFormat.value(target.guid))))
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
