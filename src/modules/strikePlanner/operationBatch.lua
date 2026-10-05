local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Utils = require("src.utils.utils")

local OperationBatch = {}

-- Written straight into reason=<token> when an operation outlives its observation window.
local REASON_OBSERVATION_WINDOW_EXPIRED = "observation_window_expired"

---Observation window state of an operation inside its recon-triggered batch
local OBSERVATION_STATE = {
  PRE_TRIGGER = "pre_trigger",
  IN_WINDOW   = "in_window",
  EXPIRED     = "expired",
}

-- ============================================================================
-- Batch Traversal
-- ============================================================================

---Iterate all operations across reconnaissance-triggered operation batches
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param callback fun(operation: SBJ__Operation, operationBatch: SBJ__ReconTriggeredOperationBatch)
local function forEachOperation(batches, callback)
  for _, operationBatch in ipairs(batches) do
    if operationBatch.operations then
      for _, operation in ipairs(operationBatch.operations) do
        callback(operation, operationBatch)
      end
    end
  end
end

---Return the first operation across all batches that satisfies the predicate
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param predicate fun(operation: SBJ__Operation): boolean
---@return SBJ__Operation|nil # First matching operation, or nil when none matches
local function findFirstOperation(batches, predicate)
  local found

  forEachOperation(batches, function(operation)
    if found then return end
    if predicate(operation) then
      found = operation
    end
  end)

  return found
end

---Test whether an operation carries the given template name and type
---@param operation SBJ__Operation
---@param templateName string
---@param operationType string
---@return boolean # True when both the type and the template name match
local function isTemplateMatch(operation, templateName, operationType)
  return operation.type == operationType
      and operation.template ~= nil
      and operation.template.name == templateName
end

---Collect the unexecuted operations of one type, each paired with its parent batch
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param operationType string Operation type to filter ("air" or "ground")
---@return SBJ__BatchedOperation[] # Matching operations paired with their parent batches
local function filterOperationsByType(batches, operationType)
  local batchedOperations = {}

  for _, operationBatch in ipairs(batches) do
    if not operationBatch.executed and operationBatch.operations then
      for _, operation in ipairs(operationBatch.operations) do
        if operation.type == operationType and not operation.executed then
          table.insert(batchedOperations, {
            operationBatch = operationBatch,
            operation = operation
          })
        end
      end
    end
  end

  return batchedOperations
end

-- ============================================================================
-- Batch Status
-- ============================================================================

---Close a batch once every operation in it has executed
---A batch emptied by abandonment counts as completed.
---Side effect: sets operationBatch.executed = true when completed.
---@param operationBatch SBJ__ReconTriggeredOperationBatch
---@return boolean # Whether all operations are completed
local function settleBatch(operationBatch)
  if not operationBatch.operations then
    return true
  end

  for _, operation in ipairs(operationBatch.operations) do
    if not operation.executed then
      return false
    end
  end

  operationBatch.executed = true
  return true
end

---Mark operation as executed and update parent operation batch status
---Executed means the plan was inserted; failures go through abandonOperation instead.
---@param operationBatch SBJ__ReconTriggeredOperationBatch
---@param operation SBJ__Operation
local function setOperationExecuted(operationBatch, operation)
  operation.executed = true

  settleBatch(operationBatch)
end

---Drop an operation the builder has given up on from its parent batch
---Removing rather than marking lets OperationScheduler re-open the same wave later.
---@param operationBatch SBJ__ReconTriggeredOperationBatch
---@param operation SBJ__Operation
---@return boolean # True when the operation was found and removed
local function abandonOperation(operationBatch, operation)
  if not operationBatch.operations then
    return false
  end

  -- Located by identity rather than a cached index: one pass may abandon several
  -- operations of the same batch, and every removal shifts the ones behind it.
  for index, candidate in ipairs(operationBatch.operations) do
    if candidate == operation then
      table.remove(operationBatch.operations, index)
      settleBatch(operationBatch)
      return true
    end
  end

  return false
end

---Evaluate the observation window state of a recon-triggered operation batch
---Opens at operationBatch.time + delay; air and ground builders share the schedule.
---@param currentTime integer
---@param operationBatch SBJ__ReconTriggeredOperationBatch
---@param windowSec number
---@return string # Observation state from OBSERVATION_STATE
local function evaluateObservationWindow(currentTime, operationBatch, windowSec)
  local triggerTime = Utils.parseDatetimeToTimestamp(operationBatch.time) + (operationBatch.delay or 0)

  if currentTime < triggerTime then
    return OBSERVATION_STATE.PRE_TRIGGER
  end
  if currentTime > triggerTime + windowSec then
    return OBSERVATION_STATE.EXPIRED
  end

  return OBSERVATION_STATE.IN_WINDOW
end

-- ============================================================================
-- Scheduling
-- ============================================================================

---Append a batch of operations unlocked by one completed reconnaissance entry
---The batch is stamped with the entry's end time and type; builders label rows with type@time.
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param reconEntry SBJ__ReconQueueEntry
---@param operations SBJ__Operation[]
function OperationBatch.add(batches, reconEntry, operations)
  table.insert(batches, {
    time = reconEntry.endTime,
    type = reconEntry.type,
    delay = 0,
    executed = false,
    operations = operations
  })
end

-- ============================================================================
-- Execution
-- ============================================================================

---Run one tick over the pending operations of one type
---Each due operation is handed to params.tryInsert. Success marks it executed, a
---retryable reason keeps it pending inside the window, anything else drops it from its
---batch so OperationScheduler re-opens the same wave instead of advancing past it.
---Operations not yet due are skipped silently and produce no entry.
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param operationType SBJ__OperationType
---@param params SBJ__OperationBatchRunParams Tick inputs and the builder's insertion attempt
---@return SBJ__OperationBatchRunResult # Whether anything executed, plus one entry per attempted operation
function OperationBatch.process(batches, operationType, params)
  ---@type SBJ__OperationBatchRunResult
  local result = { hasExecutedAny = false, entries = {} }

  for _, batchedOp in ipairs(filterOperationsByType(batches, operationType)) do
    local operationBatch = batchedOp.operationBatch
    local operation = batchedOp.operation
    local windowState = evaluateObservationWindow(params.currentTime, operationBatch, params.windowSec)

    -- PRE_TRIGGER: silent skip, the operation is simply not due yet.
    if windowState ~= OBSERVATION_STATE.PRE_TRIGGER then
      ---@type SBJ__OperationProcessResult
      local outcome
      if windowState == OBSERVATION_STATE.EXPIRED then
        outcome = { success = false, tag = "WARN", reason = REASON_OBSERVATION_WINDOW_EXPIRED }
      else
        outcome = params.tryInsert(batchedOp)
      end

      local fields = LogFormat.merge({
        operation = (operation.template and operation.template.name) or "unknown",
        batch = operationBatch.type .. "@" .. operationBatch.time
      }, outcome.fields)
      fields.reason = outcome.reason

      if outcome.success then
        setOperationExecuted(operationBatch, operation)
        result.hasExecutedAny = true
      elseif params.retryableReasonSet[outcome.reason] then
        -- Retryable operations stay pending inside the window and re-report the
        -- blocking counters every tick, so the log shows what is holding them back.
        fields.state = "observing"
      else
        -- Everything else, including an unknown reason, is dropped from the batch so
        -- OperationScheduler re-opens the same wave instead of advancing past it.
        abandonOperation(operationBatch, operation)
        fields.state = "abandoned"
      end

      table.insert(result.entries, { tag = outcome.tag, fields = fields, outcome = outcome })
    end
  end

  return result
end

-- ============================================================================
-- Queries
-- ============================================================================

---Check whether the exact template name is already in the batches, executed or not
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param templateName string
---@param operationType string Operation type ("air" or "ground")
---@return boolean # True when the operation has been scheduled at some point
function OperationBatch.isScheduled(batches, templateName, operationType)
  return findFirstOperation(batches, function(operation)
    return isTemplateMatch(operation, templateName, operationType)
  end) ~= nil
end

---Check whether the exact template name is scheduled but has not executed yet
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param templateName string
---@param operationType string Operation type ("air" or "ground")
---@return boolean # True when a matching unexecuted operation is already queued
function OperationBatch.isPending(batches, templateName, operationType)
  return findFirstOperation(batches, function(operation)
    return not operation.executed and isTemplateMatch(operation, templateName, operationType)
  end) ~= nil
end

---Find the highest-numbered executed operation of a numbered series
---Ties on wave number fall back to the later batch time.
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@param seriesPrefix string Template name prefix ending with "/", e.g. "AIR/STRIKE/AB/W/"
---@param operationType string Operation type ("air" or "ground")
---@return SBJ__Operation|nil # Latest executed operation, or nil when the series has none
function OperationBatch.findLatestExecuted(batches, seriesPrefix, operationType)
  local bestOperation, bestBatch
  -- Parsing a batch timestamp costs an os.time/os.date/os.difftime round trip, so
  -- bestTimestamp stays nil until a wave-number tie actually forces the comparison.
  local bestWaveNumber, bestTimestamp = -1, nil

  forEachOperation(batches, function(operation, operationBatch)
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

---Snapshot the most recent batch's operations by type and the next batch time
---Selects by elapsed batch time only; execution status is deliberately not consulted.
---@param batches SBJ__ReconTriggeredOperationBatch[]
---@return SBJ__OperationBatchSnapshot # Operations classified by type, next batch time, and most recent batch time
function OperationBatch.findMostRecentSnapshot(batches)
  ---@type SBJ__OperationBatchSnapshot
  local snapshot = {
    air = {},
    ground = {},
    nextOperationBatchTime = nil,
    mostRecentTime = nil
  }

  if #batches == 0 then
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

  for _, operationBatch in ipairs(batches) do
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

return OperationBatch
