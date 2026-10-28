local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
local OperationType = require("src.modules.strikePlanner.operationType")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local OperationScheduler = {}

local LOG_SCOPE = "dynamicOperationScheduling"

-- Public contract of buildNextOperation, distinct from log tags: the emit
-- path lowercases these into the status field.
local NEXT_OPERATION_STATUS = {
  FOUND_NEXT = "FOUND_NEXT",
  REUSED_CURRENT = "REUSED_CURRENT",
  PARSE_ERROR = "PARSE_ERROR",
  UNKNOWN_TYPE = "UNKNOWN_TYPE",
}


-- ============================================================================
-- Template Helpers
-- ============================================================================

---Convert an operation template name into its config table key
---@param templateName string Slash-separated template name, e.g. "AIR/STRIKE/AB/W/1"
---@return string # Underscore-separated config key, e.g. "AIR_STRIKE_AB_W_1"
local function buildTemplateKey(templateName)
  return (templateName:gsub("/", "_"))
end

-- ============================================================================
-- Next Operation Generation
-- ============================================================================

---Generate the next operation from the given one by incrementing its wave number
---Falls back to reusing the current template when no next template is configured.
---@param operation SBJ__Operation
---@param config SBJ__Config
---@return SBJ__Operation nextOperation Operation for the next wave
---@return string status "FOUND_NEXT"|"REUSED_CURRENT"|"PARSE_ERROR"|"UNKNOWN_TYPE"
local function buildNextOperation(operation, config)
  local templateName = operation.template.name
  local baseName, currentWaveNumber = templateName:match("^(.+/)(%d+)$")

  if not baseName or not currentWaveNumber then
    return Utils.deepCopy(operation), NEXT_OPERATION_STATUS.PARSE_ERROR
  end

  local typeProfile = OperationType.resolve(operation.type)
  if not typeProfile then
    return Utils.deepCopy(operation), NEXT_OPERATION_STATUS.UNKNOWN_TYPE
  end

  local nextName = baseName .. (tonumber(currentWaveNumber) + 1)

  ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]|nil
  local resolvedTemplate = config.red[typeProfile.templateSource][buildTemplateKey(nextName)]
  local resolvedName = nextName
  local status = NEXT_OPERATION_STATUS.FOUND_NEXT

  if not resolvedTemplate then
    ---@type SBJ__PackageTemplate[]|SBJ__FireSupportTaskTemplate[]
    resolvedTemplate = operation.template[typeProfile.templateField]
    resolvedName = templateName
    status = NEXT_OPERATION_STATUS.REUSED_CURRENT
  end

  local nextOperation = {
    type = operation.type,
    executed = false,
    template = {
      name = resolvedName,
      isFirstWave = false,
      strikeInterval = operation.template.strikeInterval or typeProfile.resolveDefaultInterval(config),
      [typeProfile.templateField] = resolvedTemplate
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
---@param strikeMapping SBJ__ReconStrikeMapping
---@param processingCtx SBJ__ReconQueueProcessingContext
---@return SBJ__Operation|nil operation Built operation, or nil when it cannot be resolved
---@return SBJ__LogResult result Deferred log result describing the outcome
local function buildFirstWaveOperation(strikeMapping, processingCtx)
  local typeProfile = OperationType.resolve(strikeMapping.type)
  if not typeProfile then
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
  local template = config.red[typeProfile.templateSource][buildTemplateKey(strikeMapping.name)]
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
      strikeInterval = typeProfile.resolveDefaultInterval(config),
      [typeProfile.templateField] = template
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
---@param strikeMapping SBJ__ReconStrikeMapping
---@param processingCtx SBJ__ReconQueueProcessingContext
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

  local previousOperation = OperationBatch.findLatestExecuted(
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

  local nextOperation, status = buildNextOperation(
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
  -- package. REUSED_CURRENT reuses the executed source's name, and OperationBatch.isPending
  -- ignores executed operations, so the wave still re-queues once the copy has fired.
  if OperationBatch.isPending(
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
---@param processingCtx SBJ__ReconQueueProcessingContext
---@param reconEntry SBJ__ReconQueueEntry
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

  local strikeMappings = processingCtx.config.red.recon.strikeMappings[reconEntry.reconObjectiveId]
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
    processingCtx.reconState,
    strikeMappings
  )

  for _, strikeMapping in ipairs(strikeMappings) do
    -- Sits at mapping level, not inside the builder, so the first wave and every
    -- follow-on wave share one LACM check.
    if strikeMapping.requiresLACM and not processingCtx.lacmState.enabled then
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
    elseif not OperationBatch.isScheduled(
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
---@param reconEntry SBJ__ReconQueueEntry
---@param batchSnapshot SBJ__OperationBatchSnapshot Scheduler state snapshot taken before insertion
---@param operations SBJ__Operation[]
---@param results SBJ__LogResult[]
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
---@param processingCtx SBJ__ReconQueueProcessingContext
---@param reconEntry SBJ__ReconQueueEntry
function OperationScheduler.schedule(processingCtx, reconEntry)
  local operationBatches = processingCtx.reconTriggeredOperationBatches
  -- Taken before insertion so the log reports the state this scheduling run saw
  local batchSnapshot = OperationBatch.findMostRecentSnapshot(operationBatches)

  local operations, results = buildOperationsForReconObjective(processingCtx, reconEntry)

  if #operations > 0 then
    OperationBatch.add(operationBatches, reconEntry, operations)
  end

  logSchedule(reconEntry, batchSnapshot, operations, results)
end

return OperationScheduler
