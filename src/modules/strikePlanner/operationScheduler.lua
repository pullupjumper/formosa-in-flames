local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local OperationScheduler = {}

local LOG_SCOPE = "dynamicOperationScheduling"

---Per-operation-type facts letting the builders stay generic over air and ground
---Air waves stagger by the configured interval, ground FSEMs are TOT-oriented.
local OPERATION_TYPE_TRAITS = {
  air = {
    templateSource = "packageTemplates",
    templateField = "packages",
    resolveDefaultInterval = function(config) return config.strikeInterval end,
  },
  ground = {
    templateSource = "fireSupportTaskTemplates",
    templateField = "fireSupportTasks",
    resolveDefaultInterval = function() return 0 end,
  }
}

-- Public contract of buildNextOperation, distinct from log tags: the emit
-- path lowercases these into the status field.
local NEXT_OPERATION_STATUS = {
  FOUND_NEXT = "FOUND_NEXT",
  REUSED_CURRENT = "REUSED_CURRENT",
  PARSE_ERROR = "PARSE_ERROR",
  UNKNOWN_TYPE = "UNKNOWN_TYPE",
}


-- ============================================================================
-- Operation Search Helpers
-- ============================================================================

---Convert an operation template name into its config table key
---@param templateName string Slash-separated template name, e.g. "AIR/STRIKE/AB/W/1"
---@return string # Underscore-separated config key, e.g. "AIR_STRIKE_AB_W_1"
local function buildTemplateKey(templateName)
  return (templateName:gsub("/", "_"))
end

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

---Return the first operation across all batches that satisfies the predicate
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param predicate fun(operation: SBJ__Operation): boolean Match test applied to each operation
---@return SBJ__Operation|nil # First matching operation, or nil when none matches
local function findFirstOperation(operationBatches, predicate)
  local found

  forEachOperation(operationBatches, function(operation)
    if found then return end
    if predicate(operation) then
      found = operation
    end
  end)

  return found
end

---Test whether an operation carries the given template name and type
---@param operation SBJ__Operation Operation to test
---@param templateName string Exact template name to match
---@param operationType string Operation type to match
---@return boolean # True when both the type and the template name match
local function isTemplateMatch(operation, templateName, operationType)
  return operation.type == operationType
      and operation.template ~= nil
      and operation.template.name == templateName
end

-- ============================================================================
-- Operation Query
-- ============================================================================

---Get operations from most recent reconnaissance-triggered batch classified by type
---Selects by elapsed batch time only; execution status is deliberately not consulted.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@return {air: SBJ__Operation[], ground: SBJ__Operation[], nextOperationBatchTime: string|nil, mostRecentTime: string|nil} # Operations classified by type, next recon time, and most recent entry time
function OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)
  local snapshot = {
    air = {},
    ground = {},
    nextOperationBatchTime = nil,
    mostRecentTime = nil
  }

  if #operationBatches == 0 then
    return snapshot
  end

  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  if not currentTimestamp then
    return snapshot
  end

  local mostRecentBatch = nil
  local mostRecentTimestamp = -1
  local nextBatch = nil
  local nextTimestamp = math.huge

  for _, operationBatch in ipairs(operationBatches) do
    local batchTimestamp = Utils.parseDatetimeToTimestamp(operationBatch.time)

    if batchTimestamp <= currentTimestamp and batchTimestamp > mostRecentTimestamp then
      mostRecentBatch = operationBatch
      mostRecentTimestamp = batchTimestamp
    elseif batchTimestamp > currentTimestamp and batchTimestamp < nextTimestamp then
      nextBatch = operationBatch
      nextTimestamp = batchTimestamp
    end
  end

  if mostRecentBatch then
    snapshot.mostRecentTime = mostRecentBatch.time
    if mostRecentBatch.operations then
      for _, operation in ipairs(mostRecentBatch.operations) do
        if operation.type == "air" then
          table.insert(snapshot.air, operation)
        elseif operation.type == "ground" then
          table.insert(snapshot.ground, operation)
        end
      end
    end
  end

  if nextBatch then
    snapshot.nextOperationBatchTime = nextBatch.time
  end

  return snapshot
end

---Check whether the exact template name is already in the batches, executed or not
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match
---@param operationType string Operation type ("air" or "ground")
---@return boolean # True when the operation has been scheduled at some point
function OperationScheduler.isOperationScheduled(operationBatches, templateName, operationType)
  return findFirstOperation(operationBatches, function(operation)
    return isTemplateMatch(operation, templateName, operationType)
  end) ~= nil
end

---Check whether the exact template name is scheduled but has not executed yet
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match
---@param operationType string Operation type ("air" or "ground")
---@return boolean # True when a matching unexecuted operation is already queued
function OperationScheduler.isOperationPending(operationBatches, templateName, operationType)
  return findFirstOperation(operationBatches, function(operation)
    return not operation.executed and isTemplateMatch(operation, templateName, operationType)
  end) ~= nil
end

---Find the highest-numbered executed operation of a numbered series
---Ties on wave number fall back to the later batch time.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param seriesPrefix string Template name prefix ending with "/", e.g. "AIR/STRIKE/AB/W/"
---@param operationType string Operation type ("air" or "ground")
---@return SBJ__Operation|nil # Latest executed operation, or nil when the series has none
function OperationScheduler.findLatestExecutedOperation(operationBatches, seriesPrefix, operationType)
  local bestOperation, bestBatch
  -- Parsing a batch timestamp costs an os.time/os.date/os.difftime round trip, so
  -- bestTimestamp stays nil until a wave-number tie actually forces the comparison.
  local bestWaveNumber, bestTimestamp = -1, nil

  forEachOperation(operationBatches, function(operation, operationBatch)
    if not operation.executed then
      return
    end
    if operation.type ~= operationType or not operation.template or not operation.template.name then
      return
    end

    local operationName = operation.template.name
    if operationName:sub(1, #seriesPrefix) ~= seriesPrefix then
      return
    end

    local waveNumber = tonumber(operationName:sub(#seriesPrefix + 1))
    if not waveNumber then
      return
    end

    if waveNumber > bestWaveNumber then
      bestWaveNumber = waveNumber
      bestTimestamp = nil
      bestOperation = operation
      bestBatch = operationBatch
    elseif waveNumber == bestWaveNumber then
      bestTimestamp = bestTimestamp or Utils.parseDatetimeToTimestamp(bestBatch.time)
      local batchTimestamp = Utils.parseDatetimeToTimestamp(operationBatch.time)
      if batchTimestamp > bestTimestamp then
        bestTimestamp = batchTimestamp
        bestOperation = operation
        bestBatch = operationBatch
      end
    end
  end)

  return bestOperation
end

-- ============================================================================
-- Next Operation Generation
-- ============================================================================

---Generate the next operation from the given one by incrementing its wave number
---Falls back to reusing the current template when no next template is configured.
---@param operation SBJ__Operation Source operation to advance from
---@param config SBJ__Config Configuration data
---@return SBJ__Operation nextOperation Operation for the next wave
---@return string status "FOUND_NEXT"|"REUSED_CURRENT"|"PARSE_ERROR"|"UNKNOWN_TYPE"
function OperationScheduler.buildNextOperation(operation, config)
  local templateName = operation.template.name
  local baseName, currentWaveNumber = templateName:match("^(.+/)(%d+)$")

  if not baseName or not currentWaveNumber then
    return Utils.deepCopy(operation), NEXT_OPERATION_STATUS.PARSE_ERROR
  end

  local typeTraits = OPERATION_TYPE_TRAITS[operation.type]
  if not typeTraits then
    return Utils.deepCopy(operation), NEXT_OPERATION_STATUS.UNKNOWN_TYPE
  end

  local nextName = baseName .. (tonumber(currentWaveNumber) + 1)

  ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]|nil
  local resolvedTemplate = config.c[typeTraits.templateSource][buildTemplateKey(nextName)]
  local resolvedName = nextName
  local status = NEXT_OPERATION_STATUS.FOUND_NEXT

  if not resolvedTemplate then
    ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]
    resolvedTemplate = operation.template[typeTraits.templateField]
    resolvedName = templateName
    status = NEXT_OPERATION_STATUS.REUSED_CURRENT
  end

  local nextOperation = {
    type = operation.type,
    executed = false,
    template = {
      name = resolvedName,
      isFirstWave = false,
      strikeInterval = operation.template.strikeInterval or typeTraits.resolveDefaultInterval(config),
      [typeTraits.templateField] = resolvedTemplate
    }
  }
  ---@cast nextOperation SBJ__Operation

  return nextOperation, status
end

-- ============================================================================
-- Operation Building
-- ============================================================================

---Build a single first-wave operation from a strike mapping configuration
---Rejects an unresolved template: downstream builders iterate the array unconditionally.
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping definition
---@param processingCtx SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil operation Built operation, or nil when it cannot be resolved
---@return SBJ__LogResult result Deferred log result describing the outcome
local function buildFirstWaveOperation(strikeMapping, processingCtx)
  local typeTraits = OPERATION_TYPE_TRAITS[strikeMapping.type]
  if not typeTraits then
    return nil, {
      tag = "ERROR",
      fields = {
        operation = strikeMapping.name,
        type = strikeMapping.type,
        reason = "unknown_operation_type"
      }
    }
  end

  local config = processingCtx.config
  local template = config.c[typeTraits.templateSource][buildTemplateKey(strikeMapping.name)]
  if not template then
    return nil, {
      tag = "ERROR",
      fields = {
        operation = strikeMapping.name,
        type = strikeMapping.type,
        reason = "template_not_found"
      }
    }
  end

  local newOperation = {
    type = strikeMapping.type,
    executed = false,
    template = {
      name = strikeMapping.name,
      isFirstWave = true,
      strikeInterval = typeTraits.resolveDefaultInterval(config),
      [typeTraits.templateField] = template
    }
  }
  ---@cast newOperation SBJ__Operation

  return newOperation, {
    tag = "OK",
    fields = {
      operation = strikeMapping.name,
      type = strikeMapping.type,
      action = "schedule_new"
    }
  }
end

---Advance an existing strike series to its next wave
---Every path reports a result, so the caller never has to infer silence.
---@param strikeMapping SBJ__ReconStrikeMapping Strike mapping with template name
---@param processingCtx SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil nextOperation Generated next operation, or nil when none applies
---@return SBJ__LogResult result Deferred log result describing the outcome
local function buildNextWaveOperation(strikeMapping, processingCtx)
  local baseName = strikeMapping.name:match("^(.+/)%d+$")
  if not baseName then
    return nil, {
      tag = "SKIP",
      fields = {
        operation = strikeMapping.name,
        type = strikeMapping.type,
        action = "schedule_next",
        reason = "unnumbered_template"
      }
    }
  end

  local previousOperation = OperationScheduler.findLatestExecutedOperation(
    processingCtx.reconTriggeredOperationBatches,
    baseName,
    strikeMapping.type
  )
  -- Only executed operations qualify, so a nil here means the series is scheduled
  -- but has not fired yet; there is nothing to advance from.
  if not previousOperation then
    return nil, {
      tag = "SKIP",
      fields = {
        operation = strikeMapping.name,
        type = strikeMapping.type,
        action = "schedule_next",
        reason = "no_executed_predecessor"
      }
    }
  end

  local nextOperation, status = OperationScheduler.buildNextOperation(
    previousOperation,
    processingCtx.config
  )

  -- PARSE_ERROR and UNKNOWN_TYPE hand back a copy of the source operation, which would
  -- re-queue an already-executed wave. Report the miss instead of scheduling the duplicate.
  if status ~= NEXT_OPERATION_STATUS.FOUND_NEXT and status ~= NEXT_OPERATION_STATUS.REUSED_CURRENT then
    return nil, {
      tag = "WARN",
      fields = {
        operation = previousOperation.template.name,
        type = strikeMapping.type,
        action = "schedule_next",
        reason = string.lower(status)
      }
    }
  end

  -- Blocks a second pending copy of the same wave, which would double the strike
  -- package. REUSED_CURRENT reuses the executed source's name, and isOperationPending
  -- ignores executed operations, so the wave still re-queues once the copy has fired.
  if OperationScheduler.isOperationPending(
        processingCtx.reconTriggeredOperationBatches,
        nextOperation.template.name,
        strikeMapping.type
      ) then
    return nil, {
      tag = "SKIP",
      fields = {
        operation = nextOperation.template.name,
        type = strikeMapping.type,
        reason = "already_pending"
      }
    }
  end

  return nextOperation, {
    tag = "OK",
    fields = {
      operation = previousOperation.template.name,
      nextOperation = nextOperation.template.name,
      type = strikeMapping.type,
      action = "schedule_next",
      status = string.lower(status)
    }
  }
end

---Build follow-on operations unlocked by a completed reconnaissance objective
---Each objective maps to zero or more air/ground operations.
---@param processingCtx SBJ__ReconQueueProcessingContext Shared processing context
---@param reconEntry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@return SBJ__Operation[] operations Operations to add to the batch
---@return SBJ__LogResult[] results Per-mapping scheduling results for batched output
local function buildOperationsForReconObjective(processingCtx, reconEntry)
  local operations = {}
  local results = {}

  if not reconEntry.reconObjectiveId then
    table.insert(results, {
      tag = "SKIP",
      fields = {
        type = reconEntry.type,
        reason = "recon_objective_not_assigned"
      }
    })
    return operations, results
  end

  local strikeMappings = processingCtx.config.c.recon.strikeMappingsByReconObjective[reconEntry.reconObjectiveId]
  if not strikeMappings then
    table.insert(results, {
      tag = "SKIP",
      fields = {
        type = reconEntry.type,
        objective = reconEntry.reconObjectiveId,
        reason = "strike_mapping_not_found"
      }
    })
    return operations, results
  end

  strikeMappings = FrontlineRedirect.updateMappings(
    processingCtx.config,
    processingCtx.reconCtx,
    strikeMappings
  )

  for _, strikeMapping in ipairs(strikeMappings) do
    -- Sits at mapping level, not inside the builder, so the first wave and every
    -- follow-on wave share one LACM check.
    if strikeMapping.requiresLACM and not processingCtx.lacmCtx.enabled then
      table.insert(results, {
        tag = "SKIP",
        fields = {
          operation = strikeMapping.name,
          type = strikeMapping.type,
          reason = "lacm_not_committed"
        }
      })
      -- Conserves SRBM stock while fire support is on hold
    elseif processingCtx.fireSupportOnHold and strikeMapping.name:find("^GND/STRIKE/INFRA/") then
      table.insert(results, {
        tag = "HOLD",
        fields = {
          operation = strikeMapping.name,
          type = strikeMapping.type,
          reason = "fire_support_on_hold"
        }
      })
      -- A mapping either opens its first wave or advances an existing series, never both.
    elseif not OperationScheduler.isOperationScheduled(
          processingCtx.reconTriggeredOperationBatches,
          strikeMapping.name,
          strikeMapping.type
        ) then
      local operation, result = buildFirstWaveOperation(strikeMapping, processingCtx)
      table.insert(results, result)
      if operation then
        table.insert(operations, operation)
      end
    else
      local operation, result = buildNextWaveOperation(strikeMapping, processingCtx)
      table.insert(results, result)
      if operation then
        table.insert(operations, operation)
      end
    end
  end

  return operations, results
end

-- ============================================================================
-- Logging
-- ============================================================================

---Emit batched scheduling logs, routing failures to the error sink
---Batch-level metadata lives in the report action so the rollup stays per-mapping.
---@param reconEntry SBJ__ReconQueueEntry Queue entry that triggered scheduling
---@param batchSnapshot {air: SBJ__Operation[], ground: SBJ__Operation[], nextOperationBatchTime: string|nil, mostRecentTime: string|nil} Scheduler state snapshot taken before insertion
---@param operations SBJ__Operation[] Operations added to the batch
---@param results SBJ__LogResult[] Per-mapping scheduling results
local function logSchedule(reconEntry, batchSnapshot, operations, results)
  local action = "Schedule dynamic operations " .. LogFormat.fields({
    endTime = reconEntry.endTime,
    scheduled = #operations,
    mostRecentTime = batchSnapshot.mostRecentTime or "none",
    nextOperationBatchTime = batchSnapshot.nextOperationBatchTime or "none",
    airOps = #batchSnapshot.air,
    groundOps = #batchSnapshot.ground
  })

  local report = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, action)

  if #results == 0 then
    report.add("SKIP", { reason = "no_operations_to_schedule" })
  else
    report.addAll(results)
  end

  report.emit()
end

-- ============================================================================
-- Public API
-- ============================================================================

---Schedule dynamic operations for next wave based on completed reconnaissance
---Only called when reconnaissance completes successfully with complete intelligence.
---@param processingCtx SBJ__ReconQueueProcessingContext Shared processing context
---@param reconEntry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
function OperationScheduler.schedule(processingCtx, reconEntry)
  local operationBatches = processingCtx.reconTriggeredOperationBatches
  -- Taken before insertion so the log reports the state this scheduling run saw
  local batchSnapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

  local operations, results = buildOperationsForReconObjective(processingCtx, reconEntry)

  if #operations > 0 then
    table.insert(operationBatches, {
      time = reconEntry.endTime,
      type = reconEntry.type,
      delay = 0,
      executed = false,
      operations = operations
    })
  end

  logSchedule(reconEntry, batchSnapshot, operations, results)
end

return OperationScheduler
