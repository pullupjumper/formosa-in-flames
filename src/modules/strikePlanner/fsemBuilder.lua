local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local constants = require("src.core.constants")

local FsemBuilder = {}
local FIRING_UNIT_STATUS = {
  AVAILABLE = "available",
  MISSING_NAME = "missing_name",
  ASSIGNED = "assigned",
  UNIT_NOT_FOUND = "unit_not_found",
  CONTEXT_NOT_FOUND = "context_not_found",
  BAD_STATE = "bad_state",
  LOW_AMMO = "low_ammo"
}

local FIRING_UNIT_STATUS_LOG_FIELD = {
  [FIRING_UNIT_STATUS.AVAILABLE] = "firingAvailable",
  [FIRING_UNIT_STATUS.MISSING_NAME] = "firingMissingName",
  [FIRING_UNIT_STATUS.ASSIGNED] = "firingAssigned",
  [FIRING_UNIT_STATUS.UNIT_NOT_FOUND] = "firingUnitNotFound",
  [FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND] = "firingContextNotFound",
  [FIRING_UNIT_STATUS.BAD_STATE] = "firingBadState",
  [FIRING_UNIT_STATUS.LOW_AMMO] = "firingLowAmmo",
}

local PROCESS_REASON = {
  MISSING_TEMPLATE = "missing_template",
  INSUFFICIENT_TARGETS = "insufficient_targets",
  NO_AVAILABLE_FIRING_UNITS = "no_available_firing_units",
  NO_VALID_TASKS = "no_valid_tasks"
}

local OPERATION_OUTCOME = {
  OK = "ok",
  WAIT = "wait",
  TIMEOUT = "timeout",
  MISSING_TEMPLATE = "missing_template",
  FAIL = "fail"
}

---Observation window state for a ground operation in a recon-triggered batch
local OBSERVATION_STATE = {
  PRE_TRIGGER = "pre_trigger",
  IN_WINDOW   = "in_window",
  EXPIRED     = "expired",
}

---@alias SBJ__FiringUnitStatusCounter table<string, number>

-- ============================================================================
-- Firing Unit Status
-- ============================================================================

---Create a new status counter table initialized with zero counts for each firing unit status
---@return SBJ__FiringUnitStatusCounter # Status counter table for firing unit filtering
local function createFiringUnitStatusCounter()
  return {
    [FIRING_UNIT_STATUS.AVAILABLE] = 0,
    [FIRING_UNIT_STATUS.MISSING_NAME] = 0,
    [FIRING_UNIT_STATUS.ASSIGNED] = 0,
    [FIRING_UNIT_STATUS.UNIT_NOT_FOUND] = 0,
    [FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND] = 0,
    [FIRING_UNIT_STATUS.BAD_STATE] = 0,
    [FIRING_UNIT_STATUS.LOW_AMMO] = 0
  }
end

---Increment the count for a specific firing unit status
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Status counter table
---@param status string Firing unit status
local function countFiringUnitStatus(firingUnitStatusCounter, status)
  if firingUnitStatusCounter[status] ~= nil then
    firingUnitStatusCounter[status] = firingUnitStatusCounter[status] + 1
  end
end

---Format status counter into top-level key=value fields
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Status counter table
---@return string # Printable status summary fields
local function formatFiringUnitStatusCounter(firingUnitStatusCounter)
  local statusOrder = {
    FIRING_UNIT_STATUS.AVAILABLE,
    FIRING_UNIT_STATUS.MISSING_NAME,
    FIRING_UNIT_STATUS.ASSIGNED,
    FIRING_UNIT_STATUS.UNIT_NOT_FOUND,
    FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND,
    FIRING_UNIT_STATUS.BAD_STATE,
    FIRING_UNIT_STATUS.LOW_AMMO
  }
  local fragments = {}

  for _, status in ipairs(statusOrder) do
    local count = firingUnitStatusCounter[status] or 0
    if count > 0 then
      table.insert(fragments, FIRING_UNIT_STATUS_LOG_FIELD[status] .. "=" .. count)
    end
  end

  if #fragments == 0 then
    return "firingUnits=none"
  end

  return table.concat(fragments, " ")
end

-- ============================================================================
-- Firing Unit Availability
-- ============================================================================

---Collect all currently assigned battery names from active FSEMs
---Scans all active FSEMs to identify batteries already assigned to prevent double allocation
---@param saveData SBJ__SaveData Persistent save data containing FSP (Fire Support Plan) information
---@return table<string, boolean> # Map of firing unit name to true (assigned status)
local function collectAssignedFiringUnitNames(saveData)
  if not saveData.c.ground.fireSupportPlan then
    return {}
  end

  local assignedFiringUnitNames = {}

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and matrix.fireSupportTasks then
      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished and task.firingUnits then
          for _, firingUnit in ipairs(task.firingUnits) do
            if firingUnit.name then
              assignedFiringUnitNames[firingUnit.name] = true
            end
          end
        end
      end
    end
  end

  return assignedFiringUnitNames
end

---Get firing unit runtime context from save data
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM")
---@param firingUnitName string Firing unit name used as context key
---@return SBJ__FiringUnitContext|nil # Firing unit runtime context, or nil when missing
local function getFiringUnitContext(saveData, missileSystem, firingUnitName)
  local missileSystemLower = string.lower(missileSystem)
  local missileSystemCtx = saveData.c.ground[missileSystemLower]
  return missileSystemCtx and missileSystemCtx.firingUnits and missileSystemCtx.firingUnits[firingUnitName]
end

---Validate individual firing unit status and readiness
---Checks if firing unit exists, is in HIDE state, and has sufficient ammunition
---@param assignedFiringUnitNames table<string, boolean> Map of already assigned firing unit names
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit runtime context
---@return string # Firing unit status code from FIRING_UNIT_STATUS
local function validateFiringUnitStatus(assignedFiringUnitNames, firingUnitCtx)
  local firingUnitName = firingUnitCtx.name

  if assignedFiringUnitNames[firingUnitName] then
    return FIRING_UNIT_STATUS.ASSIGNED
  end

  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  if not actualUnit then
    return FIRING_UNIT_STATUS.UNIT_NOT_FOUND
  end

  local isInGoodState = firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE
  if not isInGoodState then
    return FIRING_UNIT_STATUS.BAD_STATE
  end

  local isLowAmmo = MissileSystem.isLowAmmo(actualUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
  if isLowAmmo then
    return FIRING_UNIT_STATUS.LOW_AMMO
  end

  return FIRING_UNIT_STATUS.AVAILABLE
end

---Select available firing units specified in template
---Filters battery list to only include unassigned batteries with valid status and ammunition
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param assignedFiringUnitNames table<string, boolean> Map of already assigned firing unit names
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Counter for firing unit validation outcomes
---@param taskTemplate SBJ__FireSupportTaskTemplate FST template definition
---@return SBJ__FiringUnit[] # Array of available batteries ready for assignment
local function selectAvailableFiringUnits(saveData, assignedFiringUnitNames, firingUnitStatusCounter, taskTemplate)
  local availableFiringUnits = {}

  for _, firingUnit in ipairs(taskTemplate.firingUnits) do
    local status

    if not firingUnit.name then
      status = FIRING_UNIT_STATUS.MISSING_NAME
    else
      local firingUnitCtx = getFiringUnitContext(saveData, taskTemplate.missileSystem, firingUnit.name)

      if not firingUnitCtx then
        status = FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND
      else
        status = validateFiringUnitStatus(assignedFiringUnitNames, firingUnitCtx)
      end
    end

    countFiringUnitStatus(firingUnitStatusCounter, status)
    if status == FIRING_UNIT_STATUS.AVAILABLE then
      table.insert(availableFiringUnits, firingUnit)
    end
  end

  return availableFiringUnits
end

-- ============================================================================
-- FSEM Construction
-- ============================================================================

---Build UTC start time string for one FST slot
---@param matrixStartTime integer Base matrix start time in unix timestamp
---@param strikeInterval integer Strike interval in seconds
---@param taskIndex integer Sequential task index within matrix
---@return string # UTC datetime string for task start time
local function buildTaskStartTime(matrixStartTime, strikeInterval, taskIndex)
  return os.date(constants.DATE_FORMAT, matrixStartTime + (taskIndex * strikeInterval)) --[[@as string]]
end

---Mark newly assigned firing units to prevent duplicate allocation in current build cycle
---@param assignedFiringUnitNames table<string, boolean> Shared assigned unit name map
---@param availableFiringUnits SBJ__FiringUnit[] Available firing units selected for current task
local function markFiringUnitsAssigned(assignedFiringUnitNames, availableFiringUnits)
  for _, firingUnit in ipairs(availableFiringUnits) do
    if firingUnit.name then
      assignedFiringUnitNames[firingUnit.name] = true
    end
  end
end

---Insert new FSEM into existing FSP sequence
---Adds FSEM to the Fire Support Plan and registers it as a generated operation
---@param saveData SBJ__SaveData Persistent save data with FSP structure
---@param newMatrix SBJ__FireSupportExecutionMatrix Complete FSEM with FSTs ready for execution
---@return boolean # True if FSEM was successfully inserted and registered
local function insertMatrix(saveData, newMatrix)
  saveData.c.ground.fireSupportPlan[newMatrix.name] = newMatrix
  DynamicState.registerGeneratedOperation("ground", newMatrix.name, saveData)
  return true
end

---Evaluate targets for all FSTs in a matrix template and count valid tasks
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate FSEM template to evaluate
---@return table<string, string[]> targetsByTaskName Evaluated targets grouped by FST name
---@return number targetQualifiedTaskCount Number of task templates with enough targets
local function evaluateTargetsFromTemplate(config, saveData, contacts, matrixTemplate)
  local targetsByTaskName = {}
  local targetQualifiedTaskCount = 0

  for _, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local taskTargets = TargetingProcess.processTargets(
      config,
      saveData,
      contacts,
      taskTemplate.target,
      matrixTemplate.isFirstWave
    )
    local targetCount = taskTargets and #taskTargets or 0
    -- minTargetCount is required by schema/config, so no runtime fallback is intentionally applied.
    local requiredCount = taskTemplate.target.minTargetCount

    if targetCount >= requiredCount then
      targetsByTaskName[taskTemplate.name] = taskTargets
      targetQualifiedTaskCount = targetQualifiedTaskCount + 1
    end
  end

  return targetsByTaskName, targetQualifiedTaskCount
end

---Build executable FSTs from evaluated targets with firing unit validation
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param targetsByTaskName table<string, string[]> Map of FST name to evaluated target GUID arrays
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@return SBJ__FireSupportTask[] fireSupportTasks Built executable tasks
---@return SBJ__FiringUnitStatusCounter firingUnitStatusCounter Firing unit status counter
---@return number unavailableFiringUnitTaskCount Number of evaluated tasks failed due to unavailable firing units
local function buildExecutableTasks(saveData, matrixTemplate, targetsByTaskName, matrixStartTime)
  local fireSupportTasks = {}
  local firingUnitStatusCounter = createFiringUnitStatusCounter()
  local assignedFiringUnitNames = collectAssignedFiringUnitNames(saveData)
  local taskIndex = 0
  local unavailableFiringUnitTaskCount = 0

  for _, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = targetsByTaskName[taskTemplate.name]

    if targets then
      taskIndex = taskIndex + 1
      local availableFiringUnits = selectAvailableFiringUnits(
        saveData,
        assignedFiringUnitNames,
        firingUnitStatusCounter,
        taskTemplate
      )

      if #availableFiringUnits == 0 then
        unavailableFiringUnitTaskCount = unavailableFiringUnitTaskCount + 1
      else
        local task = Utils.deepCopy(taskTemplate) --[[@as SBJ__FireSupportTask]]
        task.firingUnits = availableFiringUnits
        task.startTime = buildTaskStartTime(matrixStartTime, matrixTemplate.strikeInterval, taskIndex)
        task.isFinished = false
        task.target.list = targets
        markFiringUnitsAssigned(assignedFiringUnitNames, availableFiringUnits)
        table.insert(fireSupportTasks, task)
      end
    end
  end

  return fireSupportTasks, firingUnitStatusCounter, unavailableFiringUnitTaskCount
end

-- ============================================================================
-- Recon Schedule Orchestration
-- ============================================================================

---Create actual FSEM from template and evaluation results
---Constructs executable FSEM with FSTs, validates firing units, and inserts into FSP
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure and FST fields
---@param matrixName string Generated unique matrix name
---@param fireSupportTasks SBJ__FireSupportTask[] Built task list for this matrix
---@return SBJ__FireSupportExecutionMatrix # Matrix structure ready for insertion
local function buildFireSupportMatrix(matrixTemplate, matrixName, fireSupportTasks)
  ---@type SBJ__FireSupportExecutionMatrix
  local newMatrix = {
    name = matrixName,
    isActivated = true,
    isFinished = false,
    isFirstWave = matrixTemplate.isFirstWave,
    allFiringUnitsInPosition = false,
    fireSupportTasks = fireSupportTasks,
    -- Ground dynamic FSP uses TOT-oriented execution; interval is intentionally disabled after generation.
    strikeInterval = 0
  }

  return newMatrix
end

---Generate matrix name from template and reconnaissance type
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template used for name source
---@param reconType string Reconnaissance type identifier
---@param saveData SBJ__SaveData Persistent save data for uniqueness check
---@return string # Generated unique matrix name
local function buildMatrixName(matrixTemplate, reconType, saveData)
  return DynamicState.generateUniqueGroundOperationName(
    matrixTemplate.name,
    reconType,
    saveData
  )
end

---Create actual FSEM from template and evaluation results
---Constructs executable FSEM with FSTs, validates firing units, and inserts into FSP
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure and FST configurations
---@param targetsByTaskName table<string, string[]> Map of FST name to evaluated target GUID arrays
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@return boolean success true if FSEM was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string statusSummary Firing unit status summary
local function createAndInsertFSEMFromTemplate(saveData, matrixTemplate, targetsByTaskName, reconType)
  local matrixStartTime = GameApi.ScenEdit_CurrentTime()
  local matrixName = buildMatrixName(matrixTemplate, reconType, saveData)
  local fireSupportTasks, firingUnitStatusCounter, unavailableFiringUnitTaskCount = buildExecutableTasks(
    saveData,
    matrixTemplate,
    targetsByTaskName,
    matrixStartTime
  )
  local statusSummary = formatFiringUnitStatusCounter(firingUnitStatusCounter)

  if #fireSupportTasks == 0 then
    if unavailableFiringUnitTaskCount > 0 then
      return false, PROCESS_REASON.NO_AVAILABLE_FIRING_UNITS, statusSummary
    end

    return false, PROCESS_REASON.NO_VALID_TASKS, statusSummary
  end

  local newMatrix = buildFireSupportMatrix(matrixTemplate, matrixName, fireSupportTasks)
  return insertMatrix(saveData, newMatrix), nil, statusSummary
end

---Evaluate observation window state for a ground operation
---Window starts at operationBatch.time + operationBatch.delay and lasts windowSec seconds.
---@param currentTime integer Current scenario time in unix timestamp
---@param operationBatch SBJ__ReconTriggeredOperationBatch Reconnaissance-triggered operation batch
---@param windowSec number Observation window duration in seconds
---@return string # Observation state from OBSERVATION_STATE
local function evaluateObservationWindow(currentTime, operationBatch, windowSec)
  local triggerTime = Utils.parseDatetimeToTimestamp(operationBatch.time) + operationBatch.delay
  if currentTime < triggerTime then
    return OBSERVATION_STATE.PRE_TRIGGER
  end
  if currentTime > triggerTime + windowSec then
    return OBSERVATION_STATE.EXPIRED
  end
  return OBSERVATION_STATE.IN_WINDOW
end

---Process operation batch entry, get FSEM template and execute evaluation
---Processes all FSTs in template, evaluates targets, and creates FSEM if valid targets exist
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param batchedOp SBJ__BatchedOperation Ground operation paired with its parent batch
---@return boolean success True if FSEM was successfully created from reconnaissance results
---@return string|nil reason Failure reason when success is false
---@return string|nil statusSummary Firing unit status summary if available
local function processGroundOperation(config, saveData, contacts, batchedOp)
  local operation = batchedOp.operation
  local reconType = batchedOp.operationBatch.type

  if not operation.template or not operation.template.fireSupportTasks then
    return false, PROCESS_REASON.MISSING_TEMPLATE, nil
  end

  local matrixTemplate = Utils.deepCopy(operation.template)
  local targetsByTaskName, targetQualifiedTaskCount = evaluateTargetsFromTemplate(
    config,
    saveData,
    contacts,
    matrixTemplate
  )

  if targetQualifiedTaskCount == 0 then
    return false, PROCESS_REASON.INSUFFICIENT_TARGETS, nil
  end

  return createAndInsertFSEMFromTemplate(saveData, matrixTemplate, targetsByTaskName, reconType)
end

---Format one processed operation result into a log line
---@param result table Processed operation result
---@return string level Log entry level
---@return string message Log-safe operation result message
local function formatProcessedResultLine(result)
  if result.outcome == OPERATION_OUTCOME.OK then
    return "OK", string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s %s",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType),
      result.statusSummary or "firingUnits=none"
    )
  end

  if result.outcome == OPERATION_OUTCOME.WAIT then
    return "SKIP", string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s state=observing reason=%s %s",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType),
      LogFormat.value(result.reason or "unknown"),
      result.statusSummary or "firingUnits=none"
    )
  end

  if result.outcome == OPERATION_OUTCOME.TIMEOUT then
    return "WARN", string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s reason=observation_window_expired",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType)
    )
  end

  if result.outcome == OPERATION_OUTCOME.MISSING_TEMPLATE then
    return "ERROR", string.format(
      "operation=%s operationBatchTime=%q operationBatchType=%s reason=missing_fsem_template",
      LogFormat.value(result.operationName),
      result.operationBatchTime,
      LogFormat.value(result.operationBatchType)
    )
  end

  return "FAIL", string.format(
    "operation=%s operationBatchTime=%q operationBatchType=%s reason=%s %s",
    LogFormat.value(result.operationName),
    result.operationBatchTime,
    LogFormat.value(result.operationBatchType),
    LogFormat.value(result.reason or "unknown"),
    result.statusSummary or "firingUnits=none"
  )
end

---Emit consolidated logs for processed operation results
---@param processedResults table[] Processed operation results accumulated in one tick
local function emitProcessedResultsLog(processedResults)
  if #processedResults == 0 then
    return
  end

  local infoLines = {}
  local errorLines = {}

  for _, result in ipairs(processedResults) do
    local level, message = formatProcessedResultLine(result)
    local line = LogFormat.entry(level, message)

    if level == "ERROR" or level == "FAIL" then
      table.insert(errorLines, line)
    else
      table.insert(infoLines, line)
    end
  end

  if #infoLines > 0 then
    local msg = LogFormat.summary(
      "scope",
      "dynamicGroundOperations",
      "Process operations",
      infoLines
    )
    Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, msg)
  end

  if #errorLines > 0 then
    Logger.error(LogFormat.summary("scope", "dynamicGroundOperations", "Process operations", errorLines))
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Process recon-triggered ground operations and dynamically insert FSEMs
---Retryable operations remain pending while targets or firing units are unavailable.
---@param config SBJ__Config Global configuration with battery and weapon system parameters
---@param saveData SBJ__SaveData Persistent save data with dynamic operations and FSP structure
---@param contacts CMO__Contact[] Sensor contacts from event script for target filtering
---@return boolean # True if any ground operation was processed and executed, false if disabled or none ready
function FsemBuilder.execute(config, saveData, contacts)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.enabled then
    return false
  end

  -- In this scenario runtime, ScenEdit_CurrentTime is guaranteed to return a valid unix timestamp.
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local windowSec = config.c.recon.observationWindowSec
  local hasExecutedAny = false

  local groundBatchedOperations = DynamicState.filterOperationsByType(
    saveData.c.dynamicOperations.reconTriggeredOperationBatches,
    "ground"
  )

  if #groundBatchedOperations == 0 then
    return false
  end

  local processedResults = {}

  for _, batchedOp in ipairs(groundBatchedOperations) do
    local operationBatch = batchedOp.operationBatch
    local operation = batchedOp.operation
    local operationName = (operation.template and operation.template.name) or "unknown"
    local windowState = evaluateObservationWindow(currentTime, operationBatch, windowSec)

    if windowState == OBSERVATION_STATE.EXPIRED then
      DynamicState.markOperationExecuted(operationBatch, operation, false)
      table.insert(processedResults, {
        operationName = operationName,
        operationBatchTime = operationBatch.time,
        operationBatchType = operationBatch.type,
        outcome = OPERATION_OUTCOME.TIMEOUT,
      })
    elseif windowState == OBSERVATION_STATE.IN_WINDOW then
      local success, reason, statusSummary = processGroundOperation(config, saveData, contacts, batchedOp)

      if success then
        DynamicState.markOperationExecuted(operationBatch, operation, true)
        hasExecutedAny = true
        table.insert(processedResults, {
          operationName = operationName,
          operationBatchTime = operationBatch.time,
          operationBatchType = operationBatch.type,
          outcome = OPERATION_OUTCOME.OK,
          statusSummary = statusSummary,
        })
      elseif reason == PROCESS_REASON.MISSING_TEMPLATE then
        DynamicState.markOperationExecuted(operationBatch, operation, false)
        table.insert(processedResults, {
          operationName = operationName,
          operationBatchTime = operationBatch.time,
          operationBatchType = operationBatch.type,
          outcome = OPERATION_OUTCOME.MISSING_TEMPLATE,
        })
      elseif reason == PROCESS_REASON.INSUFFICIENT_TARGETS or
          reason == PROCESS_REASON.NO_AVAILABLE_FIRING_UNITS then
        -- Keep retryable operations pending inside the observation window; emit SKIP every tick.
        -- This exposes whether targets or firing units are currently blocking.
        table.insert(processedResults, {
          operationName = operationName,
          operationBatchTime = operationBatch.time,
          operationBatchType = operationBatch.type,
          outcome = OPERATION_OUTCOME.WAIT,
          reason = reason,
          statusSummary = statusSummary,
        })
      else
        -- Unknown failure reason; mark executed to avoid infinite retry.
        DynamicState.markOperationExecuted(operationBatch, operation, false)
        table.insert(processedResults, {
          operationName = operationName,
          operationBatchTime = operationBatch.time,
          operationBatchType = operationBatch.type,
          outcome = OPERATION_OUTCOME.FAIL,
          reason = reason,
          statusSummary = statusSummary,
        })
      end
    end
    -- PRE_TRIGGER: silent skip, identical to legacy behavior before observation window.
  end

  emitProcessedResultsLog(processedResults)
  return hasExecutedAny
end

return FsemBuilder
