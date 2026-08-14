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

-- Public contract of generateNextOperation, distinct from log tags: the emit
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
local function toTemplateKey(templateName)
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

---Find exact match operation by template name and type
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match
---@param operationType string Operation type to match
---@return boolean exists Whether the operation was found
---@return SBJ__Operation|nil operation Found operation
---@return SBJ__ReconTriggeredOperationBatch|nil operationBatch Parent batch
local function findExactMatch(operationBatches, templateName, operationType)
  local foundOperation, foundBatch

  forEachOperation(operationBatches, function(operation, operationBatch)
    if foundOperation then return end
    if operation.type == operationType and operation.template and operation.template.name == templateName then
      foundOperation = operation
      foundBatch = operationBatch
    end
  end)

  if foundOperation then
    return true, foundOperation, foundBatch
  end
  return false, nil, nil
end

---Find prefix match operation with the highest wave number
---Only executed operations are eligible as prefix bases.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param prefix string Template name prefix ending with "/"
---@param operationType string Operation type to match
---@return boolean exists Whether a matching operation was found
---@return SBJ__Operation|nil operation Best matching operation
---@return SBJ__ReconTriggeredOperationBatch|nil operationBatch Parent batch
local function findPrefixMatch(operationBatches, prefix, operationType)
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
    if operationName:sub(1, #prefix) ~= prefix then
      return
    end

    local waveNumber = tonumber(operationName:sub(#prefix + 1))
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

  if bestOperation then
    return true, bestOperation, bestBatch
  end
  return false, nil, nil
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

---Check if an operation with specific template name and type exists in triggered batches
---Supports exact match and prefix search (templateName ending with "/").
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Template name to search for
---@param operationType string Operation type ("air" or "ground")
---@return boolean exists Whether the operation exists in the schedule
---@return SBJ__Operation|nil operation The operation object if found, nil otherwise
---@return SBJ__ReconTriggeredOperationBatch|nil operationBatch The parent batch if found
function OperationScheduler.hasOperation(operationBatches, templateName, operationType)
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

---Generate the next operation from the given one by incrementing its wave number
---Falls back to reusing the current template when no next template is configured.
---@param operation SBJ__Operation Source operation to advance from
---@param config SBJ__Config Configuration data
---@return SBJ__Operation nextOperation Operation for the next wave
---@return string status "FOUND_NEXT"|"REUSED_CURRENT"|"PARSE_ERROR"|"UNKNOWN_TYPE"
function OperationScheduler.generateNextOperation(operation, config)
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
  local resolvedTemplate = config.c[typeTraits.templateSource][toTemplateKey(nextName)]
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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil operation Built operation, or nil when it cannot be resolved
---@return SBJ__LogResult result Deferred log result describing the outcome
local function buildFirstWaveOperation(strikeMapping, processingContext)
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

  local config = processingContext.config
  local template = config.c[typeTraits.templateSource][toTemplateKey(strikeMapping.name)]
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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@return SBJ__Operation|nil nextOperation Generated next operation, or nil when none applies
---@return SBJ__LogResult result Deferred log result describing the outcome
local function buildNextWaveOperation(strikeMapping, processingContext)
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

  local exists, previousOperation = OperationScheduler.hasOperation(
    processingContext.reconTriggeredOperationBatches,
    baseName,
    strikeMapping.type
  )
  -- Prefix matching only accepts executed operations, so the series is scheduled
  -- but has not fired yet; there is nothing to advance from.
  if not exists or not previousOperation then
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

  local nextOperation, status = OperationScheduler.generateNextOperation(
    previousOperation,
    processingContext.config
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
  -- package. REUSED_CURRENT reuses the executed source's name, and hasPendingOperation
  -- ignores executed operations, so the wave still re-queues once the copy has fired.
  if OperationScheduler.hasPendingOperation(
        processingContext.reconTriggeredOperationBatches,
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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param reconEntry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@return SBJ__Operation[] operations Operations to add to the batch
---@return SBJ__LogResult[] results Per-mapping scheduling results for batched output
local function buildOperationsForReconObjective(processingContext, reconEntry)
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

  local strikeMappings = processingContext.config.c.recon.strikeMappingsByReconObjective[reconEntry.reconObjectiveId]
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

  strikeMappings = FrontlineRedirect.applyMappings(
    processingContext.config,
    processingContext.reconContext,
    strikeMappings
  )

  for _, strikeMapping in ipairs(strikeMappings) do
    -- Sits at mapping level, not inside the builder, so the first wave and every
    -- follow-on wave share one LACM check.
    if strikeMapping.requiresLACM and not processingContext.LACMContext.enabled then
      table.insert(results, {
        tag = "SKIP",
        fields = {
          operation = strikeMapping.name,
          type = strikeMapping.type,
          reason = "lacm_not_committed"
        }
      })
      -- Conserves SRBM stock while fire support is on hold
    elseif processingContext.fireSupportOnHold and strikeMapping.name:find("^GND/STRIKE/INFRA/") then
      table.insert(results, {
        tag = "HOLD",
        fields = {
          operation = strikeMapping.name,
          type = strikeMapping.type,
          reason = "fire_support_on_hold"
        }
      })
      -- A mapping either opens its first wave or advances an existing series, never both.
    elseif not OperationScheduler.hasOperation(
          processingContext.reconTriggeredOperationBatches,
          strikeMapping.name,
          strikeMapping.type
        ) then
      local operation, result = buildFirstWaveOperation(strikeMapping, processingContext)
      table.insert(results, result)
      if operation then
        table.insert(operations, operation)
      end
    else
      local operation, result = buildNextWaveOperation(strikeMapping, processingContext)
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
local function emitScheduleLog(reconEntry, batchSnapshot, operations, results)
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
---@param processingContext SBJ__ReconQueueProcessingContext Shared processing context
---@param reconEntry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
function OperationScheduler.schedule(processingContext, reconEntry)
  local operationBatches = processingContext.reconTriggeredOperationBatches
  -- Taken before insertion so the log reports the state this scheduling run saw
  local batchSnapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

  local operations, results = buildOperationsForReconObjective(processingContext, reconEntry)

  if #operations > 0 then
    table.insert(operationBatches, {
      time = reconEntry.endTime,
      type = reconEntry.type,
      delay = 0,
      executed = false,
      operations = operations
    })
  end

  emitScheduleLog(reconEntry, batchSnapshot, operations, results)
end

return OperationScheduler
