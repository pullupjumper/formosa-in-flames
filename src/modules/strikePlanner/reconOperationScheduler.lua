local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")

local ReconOperationScheduler = {}

-- ============================================================================
-- Operation Building
-- ============================================================================

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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil operation Built operation or nil if skipped
---@return string logEntry Log entry describing the result
local function buildOperationFromMapping(strikeMapping, processingContext)
  if strikeMapping.name == "STRIKE/AB/E/1" and not processingContext.LACMContext.enabled then
    local msg = string.format(
      "operation=%s type=%s reason=lacm_not_active",
      LogFormat.value(strikeMapping.name),
      LogFormat.value(strikeMapping.type)
    )
    return nil, LogFormat.entry("SKIP", msg)
  end

  local newOperation = {
    type = strikeMapping.type,
    executed = false,
    template = {
      name = strikeMapping.name,
      isFirstWave = true,
    }
  }

  local key = string.gsub(strikeMapping.name, "/", "_")

  if strikeMapping.type == "air" then
    newOperation.template.packages = processingContext.config.c.packageTemplates[key]
    newOperation.template.strikeInterval = 30 * 60
  elseif strikeMapping.type == "ground" then
    newOperation.template.fireSupportTasks = processingContext.config.c.fireSupportTaskTemplates[key]
    newOperation.template.strikeInterval = 0
  end

  local msg = string.format(
    "operation=%s type=%s action=schedule_new",
    LogFormat.value(strikeMapping.name),
    LogFormat.value(strikeMapping.type)
  )
  return newOperation, LogFormat.entry("OK", msg)
end

---Try to generate a next operation from an existing prefix-matched operation
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping with template name
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil nextOperation Generated next operation or nil
---@return string|nil logEntry Log entry describing the result
local function tryGenerateNextOperation(strikeMapping, processingContext)
  local baseName = strikeMapping.name:match("^(.+/)%d+$")
  if not baseName then
    return nil, nil
  end

  local existing, operation = DynamicOperationsUtils.hasOperation(
    processingContext.reconTriggeredOperations,
    baseName,
    strikeMapping.type
  )
  if not existing or not operation then
    return nil, nil
  end

  local nextOperation, status = DynamicOperationsUtils.generateNextOperation(operation, processingContext.config)

  -- Skip if an equivalent next wave is already scheduled but not yet executed; otherwise the same
  -- /N+1 would be queued again from a later recon completion and double the strike package.
  -- REUSED_CURRENT (no next-wave template; reuses the already-executed /N) is intentionally kept.
  if status == "FOUND_NEXT"
      and DynamicOperationsUtils.hasPendingOperation(
        processingContext.reconTriggeredOperations,
        nextOperation.template.name,
        strikeMapping.type
      ) then
    local msg = string.format(
      "operation=%s type=%s reason=already_pending",
      LogFormat.value(nextOperation.template.name),
      LogFormat.value(strikeMapping.type)
    )
    return nil, LogFormat.entry("SKIP", msg)
  end

  local msg = string.format(
    "operation=%s nextOperation=%s type=%s action=schedule_next status=%s",
    LogFormat.value(operation.template.name),
    LogFormat.value(nextOperation.template.name),
    LogFormat.value(strikeMapping.type),
    LogFormat.value(status)
  )
  return nextOperation, LogFormat.entry("OK", msg)
end

---Build follow-on operations unlocked by a completed reconnaissance objective
---Each objective maps to zero or more air/ground operations.
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@return SBJ__Operation[] operations Array of special operations to add
---@return string[] logEntries Array of log entry strings for batched output
local function buildOperationsForReconObjective(processingContext, entry)
  local operations = {}
  local logEntries = {}
  local strikeMappingsByReconObjective = processingContext.config.c.recon.strikeMappingsByReconObjective

  if not strikeMappingsByReconObjective then
    local msg = string.format(
      "type=%s reason=strike_mappings_by_recon_objective_not_found",
      LogFormat.value(entry.type)
    )
    table.insert(logEntries, LogFormat.entry("ERROR", msg))
    return operations, logEntries
  end

  if not entry.reconObjectiveId then
    local msg = string.format(
      "type=%s reason=recon_objective_not_assigned",
      LogFormat.value(entry.type)
    )
    table.insert(logEntries, LogFormat.entry("SKIP", msg))
    return operations, logEntries
  end

  local strikeMappings = findStrikeMappingsForReconObjective(strikeMappingsByReconObjective, entry)
  if not strikeMappings then
    local msg = string.format(
      "type=%s objective=%s reason=strike_mapping_not_found",
      LogFormat.value(entry.type),
      LogFormat.value(entry.reconObjectiveId)
    )
    table.insert(logEntries, LogFormat.entry("SKIP", msg))
    return operations, logEntries
  end

  strikeMappings = FrontlineRedirect.applyMappings(
    processingContext.config,
    processingContext.reconContext,
    strikeMappings
  )

  for _, strikeMapping in ipairs(strikeMappings) do
    -- Gate: SRBM mappings (STRIKE/INFRASTRUCTURE/*) skipped while fire support is on hold.
    if processingContext.fireSupportOnHold and strikeMapping.name:find("^STRIKE/INFRASTRUCTURE/") then
      local msg = string.format(
        "operation=%s type=%s reason=fire_support_on_hold",
        LogFormat.value(strikeMapping.name),
        LogFormat.value(strikeMapping.type)
      )
      table.insert(logEntries, LogFormat.entry("HOLD", msg))
    else
      local skipMapping = false

      if not DynamicOperationsUtils.hasOperation(
            processingContext.reconTriggeredOperations,
            strikeMapping.name,
            strikeMapping.type
          ) then
        local newOp, logEntry = buildOperationFromMapping(strikeMapping, processingContext)
        table.insert(logEntries, logEntry)
        if newOp then
          table.insert(operations, newOp)
        else
          skipMapping = true
        end
      end

      if not skipMapping then
        local nextOp, nextLog = tryGenerateNextOperation(strikeMapping, processingContext)
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

-- ============================================================================
-- Public API
-- ============================================================================

---Schedule dynamic operations for next wave based on completed reconnaissance
---Only called when reconnaissance completes successfully with complete intelligence.
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
function ReconOperationScheduler.schedule(processingContext, entry)
  local reconTriggeredOperations = processingContext.reconTriggeredOperations
  local reconResult = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconTriggeredOperations)

  local operations = {}
  local reconTriggeredOps, logEntries = buildOperationsForReconObjective(processingContext, entry)

  for _, op in ipairs(reconTriggeredOps) do
    table.insert(operations, op)
  end

  if #operations > 0 then
    table.insert(reconTriggeredOperations, {
      time = entry.endTime,
      type = entry.type,
      delay = 0,
      executed = false,
      operations = operations
    })
  end

  local infoLines = {}
  local msg = string.format(
    "state=context mostRecentTime=%q nextOperationBatchTime=%q airOps=%d groundOps=%d",
    tostring(reconResult.mostRecentTime or "none"),
    tostring(reconResult.nextOperationBatchTime or "none"),
    #reconResult.air,
    #reconResult.ground
  )
  table.insert(infoLines, LogFormat.entry("OK", msg))

  for _, logEntry in ipairs(logEntries) do
    table.insert(infoLines, logEntry)
  end

  if #operations > 0 then
    local submsg = string.format(
      "action=schedule_operations scheduled=%d endTime=%q",
      #operations,
      entry.endTime
    )
    table.insert(infoLines, LogFormat.entry("OK", submsg))
  else
    local submsg = string.format(
      "reason=no_operations_to_schedule endTime=%q",
      entry.endTime
    )
    table.insert(infoLines, LogFormat.entry("SKIP", submsg))
  end

  local summaryMsg = string.format("Schedule dynamic operations endTime=%q", entry.endTime)
  Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, LogFormat.summary(
    "reconType",
    entry.type,
    summaryMsg,
    infoLines
  ))
end

return ReconOperationScheduler
