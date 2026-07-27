local DynamicState = {}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Ensure generatedOperations table exists in saveData
---@param saveData SBJ__SaveData Game save data
local function ensureGeneratedOperations(saveData)
  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end
end

---Generate unique operation name by checking registry and existing plan table
---@param operationType string Type label for the name (e.g., "AIR/STRIKE/AB/W", "GND/STRIKE/INFRA/ALL")
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
---@param operationBatch SBJ__ReconTriggeredOperationBatch Operation batch with operations array
---@return boolean # Whether all operations are completed
function DynamicState.checkOperationBatchCompleted(operationBatch)
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

---Update completion status for all reconnaissance-triggered operation batches
---@param saveData SBJ__SaveData Game save data
function DynamicState.updateReconTriggeredOperationStatus(saveData)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.reconTriggeredOperationBatches then
    return
  end

  for _, reconEntry in ipairs(saveData.c.dynamicOperations.reconTriggeredOperationBatches) do
    if not reconEntry.executed then
      DynamicState.checkOperationBatchCompleted(reconEntry)
    end
  end
end

-- ============================================================================
-- Operation Filtering
-- ============================================================================

---Filter operations by type from reconnaissance-triggered operation batches
---@param operationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@param operationType string Operation type to filter ("air" or "ground")
---@return SBJ__BatchedOperation[] # Matching operations paired with their parent batches
function DynamicState.filterOperationsByType(operationBatches, operationType)
  local batchedOperations = {}

  for _, operationBatch in ipairs(operationBatches) do
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

---Mark operation as executed and update parent operation batch status
---@param reconEntry SBJ__ReconTriggeredOperationBatch Parent operation batch
---@param operation SBJ__Operation Operation that was executed
---@param success boolean Whether the operation was successful
function DynamicState.markOperationExecuted(reconEntry, operation, success)
  operation.executed = true
  operation.executionResult = success

  DynamicState.checkOperationBatchCompleted(reconEntry)
end

-- ============================================================================
-- Operation Name Generation
-- ============================================================================

---Generate unique operation name with dynamic prefix for air operations (ATO waves)
---@param operationType string Type of the operation (e.g., "AIR/STRIKE/AB/W")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name
function DynamicState.generateUniqueAirOperationName(operationType, reconType, saveData)
  ensureGeneratedOperations(saveData)
  return generateUniqueOperationName(
    operationType, reconType,
    saveData.c.dynamicOperations.generatedOperations.air,
    saveData.c.air.airTaskingOrder
  )
end

---Generate unique operation name with dynamic prefix for ground operations (FSEMs)
---@param operationType string Type of the operation (e.g., "GND/STRIKE/INFRA/ALL", "GND/ASUW/SHIP")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name
function DynamicState.generateUniqueGroundOperationName(operationType, reconType, saveData)
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
function DynamicState.registerGeneratedOperation(operationType, operationName, saveData)
  ensureGeneratedOperations(saveData)
  saveData.c.dynamicOperations.generatedOperations[operationType][operationName] = true
end

return DynamicState
