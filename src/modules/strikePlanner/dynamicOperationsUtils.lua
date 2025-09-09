local Logger = require("src.utils.logger")

---@class DynamicOperationsUtils
local DynamicOperationsUtils = {}

---Check if all operations in a reconnaissance entry are completed
---@param reconEntry table Reconnaissance schedule entry with operations array
---@return boolean completed Whether all operations are completed
function DynamicOperationsUtils.checkReconEntryCompleted(reconEntry)
  if not reconEntry.operations then
    return true
  end

  for _, operation in ipairs(reconEntry.operations) do
    if not operation.executed then
      return false
    end
  end

  reconEntry.executed = true
  Logger.log("Reconnaissance entry at " .. reconEntry.time .. " fully completed")
  return true
end

---Update completion status for all reconnaissance schedule entries
---@param saveData SBJ__SaveData Game save data
function DynamicOperationsUtils.updateReconScheduleStatus(saveData)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.reconSchedule then
    return
  end

  for _, reconEntry in ipairs(saveData.c.dynamicOperations.reconSchedule) do
    if not reconEntry.executed then
      DynamicOperationsUtils.checkReconEntryCompleted(reconEntry)
    end
  end
end

---Filter operations by type from reconnaissance schedule
---@param reconSchedule table[] Array of reconnaissance schedule entries
---@param operationType string Operation type to filter ("air" or "ground")
---@return table[] filteredOperations Array of matching operations with their parent entries
function DynamicOperationsUtils.filterOperationsByType(reconSchedule, operationType)
  local filteredOperations = {}

  for _, reconEntry in ipairs(reconSchedule) do
    if not reconEntry.executed and reconEntry.operations then
      for _, operation in ipairs(reconEntry.operations) do
        if operation.type == operationType and not operation.executed then
          table.insert(filteredOperations, {
            reconEntry = reconEntry,
            operation = operation
          })
        end
      end
    end
  end

  return filteredOperations
end

---Mark operation as executed and update parent reconnaissance entry status
---@param reconEntry table Parent reconnaissance entry
---@param operation table Operation that was executed
---@param success boolean Whether the operation was successful
function DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, success)
  operation.executed = true
  operation.executionResult = success

  Logger.log("Operation " .. operation.type .. " executed " .. (success and "successfully" or "with failure") ..
    " for reconnaissance at " .. reconEntry.time)

  -- Check if all operations in this reconnaissance entry are now completed
  DynamicOperationsUtils.checkReconEntryCompleted(reconEntry)
end

---Generate unique operation name with dynamic prefix for air operations (ATO waves)
---@param operationType string Type of the operation (e.g., "STRIKE", "SEAD")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string uniqueName Generated unique operation name
function DynamicOperationsUtils.generateUniqueAirOperationName(operationType, reconType, saveData)
  local sequence = 1
  local baseName = "DYNAMIC/" .. string.upper(reconType) .. "/" .. operationType

  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end

  -- Find next available sequence number
  local operationName
  repeat
    operationName = baseName .. "/" .. sequence
    sequence = sequence + 1
  until not saveData.c.dynamicOperations.generatedOperations.air[operationName] and
    not (saveData.c.air.ATO and saveData.c.air.ATO[operationName])

  return operationName
end

---Generate unique operation name with dynamic prefix for ground operations (FSEMs)
---@param operationType string Type of the operation (e.g., "INFRASTRUCTURE", "ANTISHIP")
---@param reconType string Reconnaissance type (e.g., "satellite", "aircraft")
---@param saveData SBJ__SaveData Game save data
---@return string uniqueName Generated unique operation name
function DynamicOperationsUtils.generateUniqueGroundOperationName(operationType, reconType, saveData)
  local sequence = 1
  local baseName = "DYNAMIC/" .. string.upper(reconType) .. "/" .. operationType

  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end

  -- Find next available sequence number
  local operationName
  repeat
    operationName = baseName .. "/" .. sequence
    sequence = sequence + 1
  until not saveData.c.dynamicOperations.generatedOperations.ground[operationName] and
    not (saveData.c.ground.FSP and saveData.c.ground.FSP[operationName])

  return operationName
end

---Register a generated operation name to prevent conflicts
---@param operationType string "air" or "ground"
---@param operationName string The generated operation name
---@param saveData SBJ__SaveData Game save data
function DynamicOperationsUtils.registerGeneratedOperation(operationType, operationName, saveData)
  if not saveData.c.dynamicOperations.generatedOperations then
    saveData.c.dynamicOperations.generatedOperations = { air = {}, ground = {} }
  end

  saveData.c.dynamicOperations.generatedOperations[operationType][operationName] = true
  Logger.log("Registered generated " .. operationType .. " operation: " .. operationName)
end

return DynamicOperationsUtils
