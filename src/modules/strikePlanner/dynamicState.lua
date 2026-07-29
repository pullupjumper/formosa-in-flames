local constants = require("src.core.constants")

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

---Abbreviate a reconnaissance source for use in a dynamic instance tag
---Falls back to the uppercased reconType when the source is not mapped.
---@param reconType string Reconnaissance source (e.g., "satellite", "UAV", "SIGINT")
---@return string # Short uppercase source code (e.g., "SAT", "UAV", "SIGINT")
local function abbreviateReconSource(reconType)
  return constants.RECON_SOURCE_ABBREVIATIONS[reconType] or string.upper(reconType)
end

---Generate a unique operation name by appending a dynamic instance tag to the template name.
---The template name (wave-stage number included) is kept verbatim as the prefix so downstream
---wave-number parsing stays intact; the appended "/DYN-<source>-NN" segment uses "-" separators
---to stay visually distinct from the "/" taxonomy path.
---Example: template "AIR/STRIKE/AB/W/2" + "satellite" -> "AIR/STRIKE/AB/W/2/DYN-SAT-01"
---@param templateName string Full operation template name, wave-stage number included (e.g. "AIR/STRIKE/AB/W/2")
---@param reconType string Reconnaissance source that triggered the operation (e.g., "satellite", "UAV", "SIGINT")
---@param registry table<string, boolean> Generated operations registry to check
---@param existingPlan table<string, any>|nil Existing plan table to check for conflicts
---@return string # Generated unique operation name
local function generateUniqueOperationName(templateName, reconType, registry, existingPlan)
  local instancePrefix = templateName .. "/DYN-" .. abbreviateReconSource(reconType) .. "-"
  local sequence = 1

  local operationName
  repeat
    operationName = instancePrefix .. string.format("%02d", sequence)
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

---Generate a unique air-operation (ATO wave) name from a template name and recon source
---@param templateName string Full wave template name, wave-stage number included (e.g. "AIR/STRIKE/AB/W/2")
---@param reconType string Reconnaissance source (e.g., "satellite", "UAV", "SIGINT")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name (e.g. "AIR/STRIKE/AB/W/2/DYN-SAT-01")
function DynamicState.generateUniqueAirOperationName(templateName, reconType, saveData)
  ensureGeneratedOperations(saveData)
  return generateUniqueOperationName(
    templateName, reconType,
    saveData.c.dynamicOperations.generatedOperations.air,
    saveData.c.air.airTaskingOrder
  )
end

---Generate a unique ground-operation (FSEM) name from a template name and recon source
---@param templateName string Full FSEM template name, wave-stage number included (e.g. "GND/STRIKE/INFRA/ALL/1")
---@param reconType string Reconnaissance source (e.g., "satellite", "UAV", "SIGINT")
---@param saveData SBJ__SaveData Game save data
---@return string # Generated unique operation name (e.g. "GND/STRIKE/INFRA/ALL/1/DYN-SAT-01")
function DynamicState.generateUniqueGroundOperationName(templateName, reconType, saveData)
  ensureGeneratedOperations(saveData)
  return generateUniqueOperationName(
    templateName, reconType,
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
