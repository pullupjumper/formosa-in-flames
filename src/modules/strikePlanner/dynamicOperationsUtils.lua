local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")

local DynamicOperationsUtils = {}

---Check if all operations in a reconnaissance entry are completed
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry with operations array
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
  Logger.log("dynamicOperations", "Reconnaissance entry at " .. reconEntry.time .. " fully completed")
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
---@param reconSchedule SBJ__ReconScheduleEntry[] Array of reconnaissance schedule entries
---@param operationType string Operation type to filter ("air" or "ground")
---@return table<number, {reconEntry: SBJ__ReconScheduleEntry, operation: SBJ__Operation}> filteredOperations Array of matching operations with their parent entries
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
---@param reconEntry SBJ__ReconScheduleEntry Parent reconnaissance entry
---@param operation SBJ__Operation Operation that was executed
---@param success boolean Whether the operation was successful
function DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, success)
  operation.executed = true
  operation.executionResult = success

  Logger.log("dynamicOperations",
    "Operation " .. operation.type .. " executed " .. (success and "successfully" or "with failure") ..
    " for reconnaissance at " .. reconEntry.time)

  -- Check if all operations in this reconnaissance entry are now completed
  DynamicOperationsUtils.checkReconEntryCompleted(reconEntry)
end

---Generate unique operation name with dynamic prefix for air operations (ATO waves)
---@param operationType string Type of the operation (e.g., "air", "ground")
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
  Logger.log("dynamicOperations", "Registered generated " .. operationType .. " operation: " .. operationName)
end

---Get operations from most recent reconnaissance entry (based on current game time) classified by type and next reconnaissance time
---Uses current game time to find the most recent recon entry whose time has passed, regardless of executed status
---@param reconSchedule SBJ__ReconScheduleEntry[] Array of reconnaissance schedule entries (may not be in time order)
---@return {air: SBJ__Operation[], ground: SBJ__Operation[], nextReconTime: string|nil} result Operations classified by type and next recon time
function DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconSchedule)
  local result = {
    air = {},
    ground = {},
    nextReconTime = nil
  }

  if not reconSchedule or #reconSchedule == 0 then
    return result
  end

  -- Get current game time (returns timestamp as integer)
  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  if not currentTimestamp then
    Logger.error("Failed to get current game time")
    return result
  end

  -- Find the entry with time <= current time and most recent (latest time in the past)
  local mostRecentEntry = nil
  for _, reconEntry in ipairs(reconSchedule) do
    local entryTimestamp = Utils.parseDatetimeToTimestamp(reconEntry.time)

    if entryTimestamp <= currentTimestamp then
      if not mostRecentEntry then
        mostRecentEntry = reconEntry
      else
        local mostRecentTimestamp = Utils.parseDatetimeToTimestamp(mostRecentEntry.time)
        if entryTimestamp > mostRecentTimestamp then
          mostRecentEntry = reconEntry
        end
      end
    end
  end

  -- Extract and classify operations from most recent entry
  if mostRecentEntry and mostRecentEntry.operations then
    for _, operation in ipairs(mostRecentEntry.operations) do
      if operation.type == "air" then
        table.insert(result.air, operation)
      elseif operation.type == "ground" then
        table.insert(result.ground, operation)
      end
    end
  end

  -- Find the next entry with time > current time (earliest future entry)
  local nextEntry = nil
  for _, reconEntry in ipairs(reconSchedule) do
    local entryTimestamp = Utils.parseDatetimeToTimestamp(reconEntry.time)

    if entryTimestamp > currentTimestamp then
      if not nextEntry then
        nextEntry = reconEntry
      else
        local nextTimestamp = Utils.parseDatetimeToTimestamp(nextEntry.time)
        if entryTimestamp < nextTimestamp then
          nextEntry = reconEntry
        end
      end
    end
  end

  if nextEntry then
    result.nextReconTime = nextEntry.time
  end

  -- Format current timestamp for logging
  local currentTimeStr = os.date("%Y-%m-%d %H:%M:%S", currentTimestamp)

  if mostRecentEntry then
    Logger.log("dynamicOperations", "Retrieved " .. #result.air .. " air operations and " .. #result.ground ..
      " ground operations from most recent recon at " .. mostRecentEntry.time ..
      " (current time: " .. currentTimeStr .. ")" ..
      (result.nextReconTime and (", next recon at " .. result.nextReconTime) or ", no more scheduled recon"))
  else
    Logger.log("dynamicOperations", "No reconnaissance entries found before current time: " .. currentTimeStr ..
      (result.nextReconTime and (", next recon at " .. result.nextReconTime) or ", no scheduled recon"))
  end

  return result
end

---Check if an operation with specific template name and type exists in reconnaissance schedule
---@param reconSchedule SBJ__ReconScheduleEntry[] Array of reconnaissance schedule entries
---@param templateName string Template name to search for (e.g., "STRIKE/AB/W/1")
---@param operationType string Operation type ("air" or "ground")
---@return boolean exists Whether the operation exists in the schedule
---@return SBJ__Operation|nil operation The operation object if found, nil otherwise
---@return SBJ__ReconScheduleEntry|nil reconEntry The parent reconnaissance entry if found, nil otherwise
function DynamicOperationsUtils.hasOperation(reconSchedule, templateName, operationType)
  -- Input validation
  if not reconSchedule or not templateName or not operationType then
    return false, nil, nil
  end

  -- Check if this is a prefix search (ends with /)
  -- User requested: "STRIKE/AB/W/" should find "STRIKE/AB/W/3" (max number, latest time)
  local isPrefixSearch = templateName:sub(-1) == "/"

  if isPrefixSearch then
    local bestOp = nil
    local bestEntry = nil
    local maxNumber = -1
    local maxTime = -1

    for _, reconEntry in ipairs(reconSchedule) do
      if reconEntry.operations then
        for _, operation in ipairs(reconEntry.operations) do
          if operation.type == operationType and operation.template and operation.template.name then
            local name = operation.template.name
            -- Check if name starts with the prefix
            if name:sub(1, #templateName) == templateName then
              -- Extract the number part
              local numberPart = name:sub(#templateName + 1)
              local number = tonumber(numberPart)

              if number then
                local entryTime = Utils.parseDatetimeToTimestamp(reconEntry.time)

                -- Update if we found a higher number, or same number with later time
                if number > maxNumber then
                  maxNumber = number
                  maxTime = entryTime
                  bestOp = operation
                  bestEntry = reconEntry
                elseif number == maxNumber then
                  if entryTime > maxTime then
                    maxTime = entryTime
                    bestOp = operation
                    bestEntry = reconEntry
                  end
                end
              end
            end
          end
        end
      end
    end

    if bestOp then
      return true, bestOp, bestEntry
    else
      return false, nil, nil
    end
  else
    -- Original exact match logic
    for _, reconEntry in ipairs(reconSchedule) do
      if reconEntry.operations then
        for _, operation in ipairs(reconEntry.operations) do
          -- Match both template name and operation type
          if operation.type == operationType
              and operation.template
              and operation.template.name == templateName then
            -- Operation found
            return true, operation, reconEntry
          end
        end
      end
    end

    return false, nil, nil
  end
end

---Generate next operation based on given operation by incrementing template number
--- Parses template name, increments number, finds next template in config
--- If next template not found, reuses current template
---@param operation SBJ__Operation Original operation object
---@param config SBJ__CONFIG Configuration data
---@return SBJ__Operation newOperation New operation object (reuses current template if next not found)
function DynamicOperationsUtils.generateNextOperation(operation, config)
  -- Extract base name and number from template.name
  -- Example: "STRIKE/AB/W/1" -> "STRIKE/AB/W/" + 1
  -- Example: "INFRASTRUCTURE/2" -> "INFRASTRUCTURE/" + 2
  local templateName = operation.template.name
  local baseName, currentNumber = templateName:match("^(.+/)(%d+)$")

  if not baseName or not currentNumber then
    Logger.error("Cannot parse template name: " .. templateName)
    -- Return deep copy of original operation
    return Utils.deepCopy(operation)
  end

  local nextNumber = tonumber(currentNumber) + 1
  local nextName = baseName .. nextNumber

  -- Convert "/" to "_" to build config key
  -- "STRIKE/AB/W/2" -> "STRIKE_AB_W_2"
  local configKey = nextName:gsub("/", "_")

  -- Find new template based on operation.type
  local newTemplate = nil
  if operation.type == "air" then
    newTemplate = config.c.packageTemplate[configKey]
  elseif operation.type == "ground" then
    newTemplate = config.c.FSTTemplate[configKey]
  else
    Logger.error("Unknown operation type: " .. tostring(operation.type))
    return Utils.deepCopy(operation)
  end

  -- If new template not found, reuse current template
  local finalName = nextName
  if not newTemplate then
    Logger.log("dynamicOperations", "Template not found: " .. configKey .. ", reusing current template: " .. templateName)
    -- Reuse current template but keep original name
    if operation.type == "air" then
      newTemplate = operation.template.packages
    elseif operation.type == "ground" then
      newTemplate = operation.template.FSTs
    end
    finalName = templateName -- Keep original name when reusing
  else
    Logger.log("dynamicOperations", "Found next template: " .. configKey)
  end

  -- Create new operation object
  local newOperation = {
    type = operation.type,
    executed = false,
    template = {}
  }

  -- Set template properties
  newOperation.template.name = finalName

  if operation.type == "air" then
    newOperation.template.isFirstWave = false -- Subsequent waves are not first wave
    newOperation.template.strikeInterval = operation.template.strikeInterval
    newOperation.template.packages = newTemplate
  elseif operation.type == "ground" then
    newOperation.template.strikeInterval = operation.template.strikeInterval or 0
    newOperation.template.isFirstWave = false
    newOperation.template.FSTs = newTemplate
  end

  return newOperation
end

return DynamicOperationsUtils
