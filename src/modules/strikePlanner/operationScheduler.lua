local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local OperationScheduler = {}

---Type-specific configuration lookup for generateNextOperation
local TYPE_CONFIG = {
  air = {
    configTable = "packageTemplates",
    templateKey = "packages",
    defaultInterval = nil,
  },
  ground = {
    configTable = "fireSupportTaskTemplates",
    templateKey = "fireSupportTasks",
    defaultInterval = 0,
  }
}

-- ============================================================================
-- Operation Search Helpers
-- ============================================================================

---Iterate all operations across reconnaissance-triggered operation batches
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param callback fun(operation: SBJ__Operation, operationBatch: SBJ__ReconTriggeredOperationBatch) Called for each operation
local function forEachOperation(operationBatches, callback)
  for _, operationBatch in ipairs(operationBatches) do
    if operationBatch.operations then
      for _, operation in ipairs(operationBatch.operations) do
        callback(operation, operationBatch)
      end
    end
  end
end

---Find exact match operation by template name and type
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match
---@param operationType string Operation type to match
---@return boolean exists Whether the operation was found
---@return SBJ__Operation|nil operation Found operation
---@return SBJ__ReconTriggeredOperationBatch|nil reconEntry Parent batch
local function findExactMatch(operationBatches, templateName, operationType)
  local foundOp, foundEntry

  forEachOperation(operationBatches, function(operation, reconEntry)
    if foundOp then return end
    if operation.type == operationType
        and operation.template
        and operation.template.name == templateName then
      foundOp = operation
      foundEntry = reconEntry
    end
  end)

  if foundOp then
    return true, foundOp, foundEntry
  end
  return false, nil, nil
end

---Find prefix match operation with highest number suffix
---Only executed operations are eligible as prefix bases.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param prefix string Template name prefix ending with "/"
---@param operationType string Operation type to match
---@return boolean exists Whether a matching operation was found
---@return SBJ__Operation|nil operation Best matching operation
---@return SBJ__ReconTriggeredOperationBatch|nil reconEntry Parent batch
local function findPrefixMatch(operationBatches, prefix, operationType)
  local bestOp, bestEntry
  local maxNumber, maxTime = -1, -1

  forEachOperation(operationBatches, function(operation, reconEntry)
    if not operation.executed then
      return
    end
    if operation.type ~= operationType or not operation.template or not operation.template.name then
      return
    end

    local name = operation.template.name
    if name:sub(1, #prefix) ~= prefix then
      return
    end

    local number = tonumber(name:sub(#prefix + 1))
    if not number then
      return
    end

    local entryTime = Utils.parseDatetimeToTimestamp(reconEntry.time)
    if number > maxNumber or (number == maxNumber and entryTime > maxTime) then
      maxNumber = number
      maxTime = entryTime
      bestOp = operation
      bestEntry = reconEntry
    end
  end)

  if bestOp then
    return true, bestOp, bestEntry
  end
  return false, nil, nil
end

-- ============================================================================
-- Operation Query
-- ============================================================================

---Get operations from most recent reconnaissance-triggered batch classified by type
---Uses current game time to find the most recent batch whose time has passed.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[]|nil Operation batches triggered by reconnaissance
---@return {air: SBJ__Operation[], ground: SBJ__Operation[], nextOperationBatchTime: string|nil, mostRecentTime: string|nil} # Operations classified by type, next recon time, and most recent entry time
function OperationScheduler.getLastExecutedOperationsAndNextTime(operationBatches)
  local result = {
    air = {},
    ground = {},
    nextOperationBatchTime = nil,
    mostRecentTime = nil
  }

  if not operationBatches or #operationBatches == 0 then
    return result
  end

  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  if not currentTimestamp then
    return result
  end

  local mostRecentBatch = nil
  local mostRecentTimestamp = -1
  local nextBatch = nil
  local nextTimestamp = math.huge

  for _, operationBatch in ipairs(operationBatches) do
    local timestamp = Utils.parseDatetimeToTimestamp(operationBatch.time)

    if timestamp <= currentTimestamp and timestamp > mostRecentTimestamp then
      mostRecentBatch = operationBatch
      mostRecentTimestamp = timestamp
    elseif timestamp > currentTimestamp and timestamp < nextTimestamp then
      nextBatch = operationBatch
      nextTimestamp = timestamp
    end
  end

  if mostRecentBatch then
    result.mostRecentTime = mostRecentBatch.time
    if mostRecentBatch.operations then
      for _, operation in ipairs(mostRecentBatch.operations) do
        if operation.type == "air" then
          table.insert(result.air, operation)
        elseif operation.type == "ground" then
          table.insert(result.ground, operation)
        end
      end
    end
  end

  if nextBatch then
    result.nextOperationBatchTime = nextBatch.time
  end

  return result
end

---Check if an operation with specific template name and type exists in triggered batches
---Supports exact match and prefix search (templateName ending with "/").
---@param operationBatches SBJ__ReconTriggeredOperationBatch[]|nil Operation batches triggered by reconnaissance
---@param templateName string Template name to search for
---@param operationType string Operation type ("air" or "ground")
---@return boolean exists Whether the operation exists in the schedule
---@return SBJ__Operation|nil operation The operation object if found, nil otherwise
---@return SBJ__ReconTriggeredOperationBatch|nil reconEntry The parent batch if found
function OperationScheduler.hasOperation(operationBatches, templateName, operationType)
  if not operationBatches then
    return false, nil, nil
  end

  if templateName:sub(-1) == "/" then
    return findPrefixMatch(operationBatches, templateName, operationType)
  end
  return findExactMatch(operationBatches, templateName, operationType)
end

---Check whether an unexecuted operation with the given template name and type already exists
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match
---@param operationType string Operation type to match ("air" or "ground")
---@return boolean # True if a matching unexecuted operation is already scheduled
function OperationScheduler.hasPendingOperation(operationBatches, templateName, operationType)
  local found = false
  forEachOperation(operationBatches, function(operation)
    if found then return end
    if not operation.executed and
        operation.type == operationType and
        operation.template and
        operation.template.name == templateName then
      found = true
    end
  end)
  return found
end

-- ============================================================================
-- Next Operation Generation
-- ============================================================================

---Generate next operation based on given operation by incrementing template number
---If next template not found, reuses current template.
---@param operation SBJ__Operation Original operation object
---@param config SBJ__Config Configuration data
---@return SBJ__Operation newOperation New operation object
---@return string status "FOUND_NEXT"|"REUSED_CURRENT"|"PARSE_ERROR"|"UNKNOWN_TYPE"
function OperationScheduler.generateNextOperation(operation, config)
  local templateName = operation.template.name
  local baseName, currentNumber = templateName:match("^(.+/)(%d+)$")

  if not baseName or not currentNumber then
    return Utils.deepCopy(operation), "PARSE_ERROR"
  end

  local typeConfig = TYPE_CONFIG[operation.type]
  if not typeConfig then
    return Utils.deepCopy(operation), "UNKNOWN_TYPE"
  end

  local nextNumber = tonumber(currentNumber) + 1
  local nextName = baseName .. nextNumber
  local configKey = nextName:gsub("/", "_")

  ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]|nil
  local newTemplate = config.c[typeConfig.configTable][configKey]
  local finalName = nextName
  local status = "FOUND_NEXT"

  if not newTemplate then
    ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]
    newTemplate = operation.template[typeConfig.templateKey]
    finalName = templateName
    status = "REUSED_CURRENT"
  end

  local newOperation = {
    type = operation.type,
    executed = false,
    template = {
      name = finalName,
      isFirstWave = false,
      strikeInterval = operation.template.strikeInterval or typeConfig.defaultInterval,
      [typeConfig.templateKey] = newTemplate
    }
  }
  ---@cast newOperation SBJ__Operation

  return newOperation, status
end

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
  if strikeMapping.name == "AIR/STRIKE/AB/E/1" and not processingContext.LACMContext.enabled then
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
    newOperation.template.strikeInterval = processingContext.config.strikeInterval
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

  local existing, operation = OperationScheduler.hasOperation(
    processingContext.reconTriggeredOperationBatches,
    baseName,
    strikeMapping.type
  )
  if not existing or not operation then
    return nil, nil
  end

  local nextOperation, status = OperationScheduler.generateNextOperation(operation, processingContext.config)

  -- Skip if an equivalent next wave is already scheduled but not yet executed; otherwise the same
  -- /N+1 would be queued again from a later recon completion and double the strike package.
  -- REUSED_CURRENT (no next-wave template; reuses the already-executed /N) is intentionally kept.
  if status == "FOUND_NEXT"
      and OperationScheduler.hasPendingOperation(
        processingContext.reconTriggeredOperationBatches,
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
    -- Gate: SRBM mappings (GND/STRIKE/INFRA/*) skipped while fire support is on hold.
    if processingContext.fireSupportOnHold and strikeMapping.name:find("^GND/STRIKE/INFRA/") then
      local msg = string.format(
        "operation=%s type=%s reason=fire_support_on_hold",
        LogFormat.value(strikeMapping.name),
        LogFormat.value(strikeMapping.type)
      )
      table.insert(logEntries, LogFormat.entry("HOLD", msg))
    else
      local skipMapping = false

      if not OperationScheduler.hasOperation(
            processingContext.reconTriggeredOperationBatches,
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
function OperationScheduler.schedule(processingContext, entry)
  local reconTriggeredOperationBatches = processingContext.reconTriggeredOperationBatches
  local reconResult = OperationScheduler.getLastExecutedOperationsAndNextTime(reconTriggeredOperationBatches)

  local operations = {}
  local reconTriggeredOps, logEntries = buildOperationsForReconObjective(processingContext, entry)

  for _, op in ipairs(reconTriggeredOps) do
    table.insert(operations, op)
  end

  if #operations > 0 then
    table.insert(reconTriggeredOperationBatches, {
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

return OperationScheduler
