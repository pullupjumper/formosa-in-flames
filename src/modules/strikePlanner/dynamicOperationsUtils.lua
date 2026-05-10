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

---Iterate all operations across reconnaissance schedule entries with their parent entry
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule entries
---@param callback fun(operation: SBJ__Operation, reconEntry: SBJ__ReconScheduleEntry) Called for each operation
local function forEachOperation(reconSchedule, callback)
  for _, reconEntry in ipairs(reconSchedule) do
    if reconEntry.operations then
      for _, operation in ipairs(reconEntry.operations) do
        callback(operation, reconEntry)
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
-- Recon Entry Status
-- ============================================================================

---Check if all operations in a reconnaissance entry are completed
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry with operations array
---@return boolean # Whether all operations are completed
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

-- ============================================================================
-- Operation Filtering
-- ============================================================================

---Filter operations by type from reconnaissance schedule
---@param reconSchedule SBJ__ReconScheduleEntry[] Array of reconnaissance schedule entries
---@param operationType string Operation type to filter ("air" or "ground")
---@return table<number, {reconEntry: SBJ__ReconScheduleEntry, operation: SBJ__Operation}> # Array of matching operations with their parent entries
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

  DynamicOperationsUtils.checkReconEntryCompleted(reconEntry)
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
-- Recon Schedule Query
-- ============================================================================

---Get operations from most recent reconnaissance entry classified by type and next reconnaissance time
---Uses current game time to find the most recent recon entry whose time has passed
---@param reconSchedule SBJ__ReconScheduleEntry[]|nil Array of reconnaissance schedule entries (may not be in time order)
---@return {air: SBJ__Operation[], ground: SBJ__Operation[], nextReconTime: string|nil, mostRecentTime: string|nil} # Operations classified by type, next recon time, and most recent entry time
function DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconSchedule)
  local result = {
    air = {},
    ground = {},
    nextReconTime = nil,
    mostRecentTime = nil
  }

  if not reconSchedule or #reconSchedule == 0 then
    return result
  end

  local currentTimestamp = GameApi.ScenEdit_CurrentTime()
  if not currentTimestamp then
    return result
  end

  -- Single pass: find most recent past entry and earliest future entry
  local mostRecentEntry = nil
  local mostRecentTimestamp = -1
  local nextEntry = nil
  local nextTimestamp = math.huge

  for _, reconEntry in ipairs(reconSchedule) do
    local entryTimestamp = Utils.parseDatetimeToTimestamp(reconEntry.time)

    if entryTimestamp <= currentTimestamp and entryTimestamp > mostRecentTimestamp then
      mostRecentEntry = reconEntry
      mostRecentTimestamp = entryTimestamp
    elseif entryTimestamp > currentTimestamp and entryTimestamp < nextTimestamp then
      nextEntry = reconEntry
      nextTimestamp = entryTimestamp
    end
  end

  -- Extract and classify operations from most recent entry
  if mostRecentEntry then
    result.mostRecentTime = mostRecentEntry.time
    if mostRecentEntry.operations then
      for _, operation in ipairs(mostRecentEntry.operations) do
        if operation.type == "air" then
          table.insert(result.air, operation)
        elseif operation.type == "ground" then
          table.insert(result.ground, operation)
        end
      end
    end
  end

  if nextEntry then
    result.nextReconTime = nextEntry.time
  end

  return result
end

-- ============================================================================
-- Operation Search
-- ============================================================================

---Find exact match operation by template name and type
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule entries
---@param templateName string Exact template name to match
---@param operationType string Operation type to match
---@return boolean exists Whether the operation was found
---@return SBJ__Operation|nil operation Found operation
---@return SBJ__ReconScheduleEntry|nil reconEntry Parent entry
local function findExactMatch(reconSchedule, templateName, operationType)
  local foundOp, foundEntry

  forEachOperation(reconSchedule, function(operation, reconEntry)
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
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule entries
---@param prefix string Template name prefix ending with "/"
---@param operationType string Operation type to match
---@return boolean exists Whether a matching operation was found
---@return SBJ__Operation|nil operation Best matching operation
---@return SBJ__ReconScheduleEntry|nil reconEntry Parent entry
local function findPrefixMatch(reconSchedule, prefix, operationType)
  local bestOp, bestEntry
  local maxNumber, maxTime = -1, -1

  forEachOperation(reconSchedule, function(operation, reconEntry)
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

---Check if an operation with specific template name and type exists in reconnaissance schedule
---Supports exact match and prefix search (templateName ending with "/")
---@param reconSchedule SBJ__ReconScheduleEntry[]|nil Array of reconnaissance schedule entries
---@param templateName string Template name to search for (e.g., "STRIKE/AB/W/1" or "STRIKE/AB/W/" for prefix)
---@param operationType string Operation type ("air" or "ground")
---@return boolean exists Whether the operation exists in the schedule
---@return SBJ__Operation|nil operation The operation object if found, nil otherwise
---@return SBJ__ReconScheduleEntry|nil reconEntry The parent reconnaissance entry if found, nil otherwise
function DynamicOperationsUtils.hasOperation(reconSchedule, templateName, operationType)
  if not reconSchedule then
    return false, nil, nil
  end

  if templateName:sub(-1) == "/" then
    return findPrefixMatch(reconSchedule, templateName, operationType)
  end
  return findExactMatch(reconSchedule, templateName, operationType)
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
