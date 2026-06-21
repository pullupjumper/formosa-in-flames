local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")

local DynamicOperationsUtils = {}


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
-- Internal Helpers
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

---Ensure generatedOperations table exists in saveData
---@param saveData SBJ__SaveData Game save data
local function ensureGeneratedOperations(saveData)
  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end
end

---Generate unique operation name by checking registry and existing plan table
---@param operationType string Type label for the name (e.g., "STRIKE/AB/W", "INFRASTRUCTURE")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param registry table<string, boolean> Generated operations registry to check
---@param existingPlan table<string, any>|nil Existing plan table to check for conflicts
---@return string # Generated unique operation name
local function generateUniqueOperationName(operationType, reconType, registry, existingPlan)
  local sequence = 1
  local baseName = "DYNAMIC/" .. string.upper(reconType) .. "/" .. operationType

  local operationName
  repeat
    operationName = baseName .. "/" .. sequence
    sequence = sequence + 1
  until not registry[operationName] and not (existingPlan and existingPlan[operationName])

  return operationName
end

-- ============================================================================
-- Operation Batch Status
-- ============================================================================

---Check if all operations in a reconnaissance-triggered batch are completed
---@param reconEntry SBJ__ReconTriggeredOperationBatch Operation batch with operations array
---@return boolean # Whether all operations are completed
function DynamicOperationsUtils.checkOperationBatchCompleted(reconEntry)
  if not reconEntry.operations then
    return true
  end

  for _, operation in ipairs(reconEntry.operations) do
    if not operation.executed then
      return false
    end
  end

  reconEntry.executed = true
  return true
end

---Update completion status for all reconnaissance-triggered operation batches
---@param saveData SBJ__SaveData Game save data
function DynamicOperationsUtils.updateReconTriggeredOperationStatus(saveData)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.reconTriggeredOperations then
    return
  end

  for _, reconEntry in ipairs(saveData.c.dynamicOperations.reconTriggeredOperations) do
    if not reconEntry.executed then
      DynamicOperationsUtils.checkOperationBatchCompleted(reconEntry)
    end
  end
end

-- ============================================================================
-- Operation Filtering
-- ============================================================================

---Filter operations by type from reconnaissance-triggered operation batches
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param operationType string Operation type to filter ("air" or "ground")
---@return table<number, {operationBatch: SBJ__ReconTriggeredOperationBatch, operation: SBJ__Operation}> # Array of matching operations with their parent batches
function DynamicOperationsUtils.filterOperationsByType(operationBatches, operationType)
  local filteredOperations = {}

  for _, operationBatch in ipairs(operationBatches) do
    if not operationBatch.executed and operationBatch.operations then
      for _, operation in ipairs(operationBatch.operations) do
        if operation.type == operationType and not operation.executed then
          table.insert(filteredOperations, {
            operationBatch = operationBatch,
            operation = operation
          })
        end
      end
    end
  end

  return filteredOperations
end

---Mark operation as executed and update parent operation batch status
---@param reconEntry SBJ__ReconTriggeredOperationBatch Parent operation batch
---@param operation SBJ__Operation Operation that was executed
---@param success boolean Whether the operation was successful
function DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, success)
  operation.executed = true
  operation.executionResult = success

  DynamicOperationsUtils.checkOperationBatchCompleted(reconEntry)
end

-- ============================================================================
-- Operation Name Generation
-- ============================================================================

---Generate unique operation name with dynamic prefix for air operations (ATO waves)
---@param operationType string Type of the operation (e.g., "STRIKE/AB/W")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name
function DynamicOperationsUtils.generateUniqueAirOperationName(operationType, reconType, saveData)
  ensureGeneratedOperations(saveData)
  return generateUniqueOperationName(
    operationType, reconType,
    saveData.c.dynamicOperations.generatedOperations.air,
    saveData.c.air.airTaskingOrder
  )
end

---Generate unique operation name with dynamic prefix for ground operations (FSEMs)
---@param operationType string Type of the operation (e.g., "INFRASTRUCTURE", "ANTISHIP")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name
function DynamicOperationsUtils.generateUniqueGroundOperationName(operationType, reconType, saveData)
  ensureGeneratedOperations(saveData)
  return generateUniqueOperationName(
    operationType, reconType,
    saveData.c.dynamicOperations.generatedOperations.ground,
    saveData.c.ground.fireSupportPlan
  )
end

---Register a generated operation name to prevent conflicts
---@param operationType string "air" or "ground"
---@param operationName string The generated operation name
---@param saveData SBJ__SaveData Game save data
function DynamicOperationsUtils.registerGeneratedOperation(operationType, operationName, saveData)
  ensureGeneratedOperations(saveData)
  saveData.c.dynamicOperations.generatedOperations[operationType][operationName] = true
end

-- ============================================================================
-- Recon-Triggered Operation Query
-- ============================================================================

---Get operations from most recent reconnaissance-triggered batch classified by type
---Uses current game time to find the most recent batch whose time has passed.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[]|nil Operation batches triggered by reconnaissance
---@return {air: SBJ__Operation[], ground: SBJ__Operation[], nextOperationBatchTime: string|nil, mostRecentTime: string|nil} # Operations classified by type, next recon time, and most recent entry time
function DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(operationBatches)
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

  -- Single pass: find most recent past entry and earliest future entry
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

  -- Extract and classify operations from most recent entry
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

-- ============================================================================
-- Operation Search
-- ============================================================================

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

---Find prefix match operation with highest number suffix (latest time as tiebreaker)
---Only consumed operations (executed == true) are eligible as prefix bases; unconsumed
---ones (e.g. ground operations still inside their observation window) are skipped to
---prevent generateNextOperation from producing /N+1 before the prior wave is settled.
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

---Check if an operation with specific template name and type exists in triggered batches
---Supports exact match and prefix search (templateName ending with "/")
---@param operationBatches SBJ__ReconTriggeredOperationBatch[]|nil Operation batches triggered by reconnaissance
---@param templateName string Template name to search for (e.g., "STRIKE/AB/W/1" or "STRIKE/AB/W/" for prefix)
---@param operationType string Operation type ("air" or "ground")
---@return boolean exists Whether the operation exists in the schedule
---@return SBJ__Operation|nil operation The operation object if found, nil otherwise
---@return SBJ__ReconTriggeredOperationBatch|nil reconEntry The parent batch if found, nil otherwise
function DynamicOperationsUtils.hasOperation(operationBatches, templateName, operationType)
  if not operationBatches then
    return false, nil, nil
  end

  if templateName:sub(-1) == "/" then
    return findPrefixMatch(operationBatches, templateName, operationType)
  end
  return findExactMatch(operationBatches, templateName, operationType)
end

---Check whether an unexecuted operation with the given template name and type already exists
---Used to prevent scheduling a duplicate next wave while a prior one is still pending.
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param templateName string Exact template name to match (e.g. "STRIKE/C2/N/2")
---@param operationType string Operation type to match ("air" or "ground")
---@return boolean # True if a matching unexecuted operation is already scheduled
function DynamicOperationsUtils.hasPendingOperation(operationBatches, templateName, operationType)
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
---Parses template name, increments number, finds next template in config
---If next template not found, reuses current template
---@param operation SBJ__Operation Original operation object
---@param config SBJ__Config Configuration data
---@return SBJ__Operation newOperation New operation object (reuses current template if next not found)
---@return string status "FOUND_NEXT"|"REUSED_CURRENT"|"PARSE_ERROR"|"UNKNOWN_TYPE"
function DynamicOperationsUtils.generateNextOperation(operation, config)
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

return DynamicOperationsUtils
