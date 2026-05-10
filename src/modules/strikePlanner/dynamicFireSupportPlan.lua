local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")

local DynamicFireSupportPlan = {}
local FIRING_UNIT_STATUS = {
  AVAILABLE = "available",
  MISSING_NAME = "missing_name",
  ASSIGNED = "assigned",
  UNIT_NOT_FOUND = "unit_not_found",
  CONTEXT_NOT_FOUND = "context_not_found",
  BAD_STATE = "bad_state",
  LOW_AMMO = "low_ammo"
}

-- ============================================================================
-- Firing Unit Status
-- ============================================================================

---Create a new status counter table initialized with zero counts for each firing unit status
---@return table<string, number> # Status counter table for firing unit filtering
local function createStatusCounter()
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
---@param statusCounter table<string, number> Status counter table
---@param status string Firing unit status
local function countStatus(statusCounter, status)
  if statusCounter[status] ~= nil then
    statusCounter[status] = statusCounter[status] + 1
  end
end

---Format status counter into a human-readable summary string
---@param statusCounter table<string, number> Status counter table
---@return string # Printable status summary string
local function formatStatusCounter(statusCounter)
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
    local count = statusCounter[status] or 0
    if count > 0 then
      table.insert(fragments, status .. "=" .. count)
    end
  end

  if #fragments == 0 then
    return "none"
  end

  return table.concat(fragments, ", ")
end

-- ============================================================================
-- Firing Unit Availability
-- ============================================================================

---Collect all currently assigned battery names from active FSEMs
---Scans all active FSEMs to identify batteries already assigned to prevent double allocation
---@param saveData SBJ__SaveData Persistent save data containing FSP (Fire Support Plan) information
---@return table<string, boolean> # Map of firing unit name to true (assigned status)
local function collectAssignedFiringUnits(saveData)
  if not saveData.c.ground.fireSupportPlan then
    return {}
  end

  local assignedFiringUnits = {}

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and matrix.fireSupportTasks then
      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished and task.firingUnits then
          for _, firingUnit in ipairs(task.firingUnits) do
            if firingUnit.name then
              assignedFiringUnits[firingUnit.name] = true
            end
          end
        end
      end
    end
  end

  return assignedFiringUnits
end

---Validate individual firing unit status and readiness
---Checks if firing unit exists, is in HIDE state, and has sufficient ammunition
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param assignedFiringUnits table<string, boolean> Map of already assigned firing unit names
---@param firingUnitName? string The name of the battery/firing unit to validate
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM") used to locate battery data
---@return string status Firing unit status code from FIRING_UNIT_STATUS
---@return string|nil message Error or detail message by status
local function validateFiringUnitStatus(saveData, assignedFiringUnits, firingUnitName, missileSystem)
  if not firingUnitName then
    return FIRING_UNIT_STATUS.MISSING_NAME, "Firing unit is missing name field in template"
  end

  if assignedFiringUnits[firingUnitName] then
    return FIRING_UNIT_STATUS.ASSIGNED, firingUnitName .. " already assigned to other FST"
  end

  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  if not actualUnit then
    return FIRING_UNIT_STATUS.UNIT_NOT_FOUND, "Cannot find actual unit: " .. firingUnitName
  end

  local missileSystemLower = string.lower(missileSystem)
  local firingUnitCtx = saveData.c.ground[missileSystemLower] and
      saveData.c.ground[missileSystemLower].firingUnits and
      saveData.c.ground[missileSystemLower].firingUnits[firingUnitName]

  if not firingUnitCtx then
    return FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND, "Cannot find battery data: " .. firingUnitName
  end

  local isInGoodState = firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE
  if not isInGoodState then
    return FIRING_UNIT_STATUS.BAD_STATE, "Battery " .. firingUnitName .. " is not in HIDE state"
  end

  local isLowAmmo = MissileSystem.isLowAmmo(actualUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
  if isLowAmmo then
    return FIRING_UNIT_STATUS.LOW_AMMO, "Battery " .. firingUnitName .. " has low ammunition"
  end

  return FIRING_UNIT_STATUS.AVAILABLE, nil
end

---Check if firing units specified in template are available
---Filters battery list to only include unassigned batteries with valid status and ammunition
---@param saveData SBJ__SaveData Persistent save data containing FSP and firing unit information
---@param firingUnits SBJ__FiringUnit[] Array of firing unit contexts specified in FST template
---@param assignedFiringUnits table<string, boolean> Map of already assigned firing unit names
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM") for validation
---@param statusCounter table<string, number> Status counter table
---@return SBJ__FiringUnit[] # Array of available batteries ready for assignment
local function checkFiringUnitAvailability(saveData, firingUnits, assignedFiringUnits, missileSystem, statusCounter)
  local availableFiringUnitCtxs = {}

  for _, firingUnit in ipairs(firingUnits) do
    local status = validateFiringUnitStatus(saveData, assignedFiringUnits, firingUnit.name, missileSystem)
    countStatus(statusCounter, status)
    if status == FIRING_UNIT_STATUS.AVAILABLE then
      table.insert(availableFiringUnitCtxs, firingUnit)
    end
  end

  return availableFiringUnitCtxs
end

-- ============================================================================
-- FSEM Construction
-- ============================================================================

---Build executable Fire Support Task from template and runtime data
---@param taskTemplate SBJ__FireSupportTaskTemplate Fire Support Task template
---@param targets string[] Target GUID list
---@param availableFiringUnits SBJ__FiringUnit[] Available firing units
---@param startTime string Task start time in UTC string format
---@return SBJ__FireSupportTask # Fire Support Task ready for insertion
local function buildFireSupportTask(taskTemplate, targets, availableFiringUnits, startTime)
  ---@type SBJ__FireSupportTask
  local task = {
    name = taskTemplate.name,
    missileSystem = taskTemplate.missileSystem,
    firingUnits = availableFiringUnits,
    startTime = startTime,
    isFinished = false,
    target = {
      list = targets,
      objs = taskTemplate.target.objs or {},
      areas = taskTemplate.target.areas or {},
      filterNames = taskTemplate.target.filterNames,
      contactAge = taskTemplate.target.contactAge,
      minTargetCount = taskTemplate.target.minTargetCount,
      ammoPerTarget = taskTemplate.target.ammoPerTarget
    }
  }

  return task
end

---Build UTC start time string for one FST slot
---@param matrixStartTime integer Base matrix start time in unix timestamp
---@param strikeInterval integer Strike interval in seconds
---@param taskIndex integer Sequential task index within matrix
---@return string # UTC datetime string for task start time
local function buildTaskStartTime(matrixStartTime, strikeInterval, taskIndex)
  return os.date("!%Y-%m-%d %H:%M:%S", matrixStartTime + (taskIndex * strikeInterval)) --[[@as string]]
end

---Mark newly assigned firing units to prevent duplicate allocation in current build cycle
---@param assignedFiringUnits table<string, boolean> Shared assigned unit map
---@param availableFiringUnits SBJ__FiringUnit[] Available firing units selected for current task
local function markFiringUnitsAssigned(assignedFiringUnits, availableFiringUnits)
  for _, firingUnit in ipairs(availableFiringUnits) do
    if firingUnit.name then
      assignedFiringUnits[firingUnit.name] = true
    end
  end
end

---Try build one executable FST from evaluated targets and available firing units
---@param saveData SBJ__SaveData Persistent save data for lookups and allocation checks
---@param taskTemplate SBJ__FireSupportTaskTemplate FST template definition
---@param targets string[] Evaluated target GUID list
---@param assignedFiringUnits table<string, boolean> Shared assigned unit map
---@param statusCounter table<string, number> Status counter table
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@param taskIndex integer Sequential task index within matrix
---@param strikeInterval integer Strike interval in seconds
---@return SBJ__FireSupportTask|nil task Built task or nil when no available firing units
---@return string|nil reason Failure reason when task is nil
local function tryBuildExecutableTask(
    saveData,
    taskTemplate,
    targets,
    assignedFiringUnits,
    statusCounter,
    matrixStartTime,
    taskIndex,
    strikeInterval)
  local availableFiringUnits = checkFiringUnitAvailability(
    saveData,
    taskTemplate.firingUnits,
    assignedFiringUnits,
    taskTemplate.missileSystem,
    statusCounter
  )
  if #availableFiringUnits == 0 then
    return nil, "NO_AVAILABLE_FIRING_UNITS"
  end

  local startTime = buildTaskStartTime(matrixStartTime, strikeInterval, taskIndex)
  local task = buildFireSupportTask(taskTemplate, targets, availableFiringUnits, startTime)
  markFiringUnitsAssigned(assignedFiringUnits, availableFiringUnits)
  return task, nil
end

---Insert new FSEM into existing FSP sequence
---Adds FSEM to the Fire Support Plan and registers it as a generated operation
---@param saveData SBJ__SaveData Persistent save data with FSP structure
---@param newMatrix SBJ__FireSupportExecutionMatrix Complete FSEM with FSTs ready for execution
---@return boolean # True if FSEM was successfully inserted and registered
local function insertMatrix(saveData, newMatrix)
  saveData.c.ground.fireSupportPlan[newMatrix.name] = newMatrix
  DynamicOperationsUtils.registerGeneratedOperation("ground", newMatrix.name, saveData)
  return true
end

---Evaluate targets for all FSTs in a matrix template and count valid tasks
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate FSEM template to evaluate
---@return table<string, string[]> evaluatedTargets Evaluated targets grouped by FST name
---@return number validTaskCount Number of task templates with enough targets
local function evaluateTargetsFromTemplate(config, saveData, contacts, matrixTemplate)
  local evaluatedTargets = {}
  local validTaskCount = 0

  for _, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local taskTargets = TargetingProcess.processTargets(config, saveData, contacts, taskTemplate.target,
      matrixTemplate.isFirstWave)
    local targetCount = taskTargets and #taskTargets or 0
    -- minTargetCount is required by schema/config, so no runtime fallback is intentionally applied.
    local requiredCount = taskTemplate.target.minTargetCount

    if targetCount >= requiredCount then
      evaluatedTargets[taskTemplate.name] = taskTargets
      validTaskCount = validTaskCount + 1
    end
  end

  return evaluatedTargets, validTaskCount
end

---Build executable FSTs from evaluated targets with firing unit validation
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param evaluatedTargets table<string, string[]> Map of FST name to evaluated target GUID arrays
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@return SBJ__FireSupportTask[] fireSupportTasks Built executable tasks
---@return table<string, number> statusCounter Firing unit status counter
---@return number buildFailureCount Number of evaluated tasks failed to build due to unavailable firing units
local function buildExecutableTasks(saveData, matrixTemplate, evaluatedTargets, matrixStartTime)
  local fireSupportTasks = {}
  local statusCounter = createStatusCounter()
  local assignedFiringUnits = collectAssignedFiringUnits(saveData)
  local taskIndex = 0
  local buildFailureCount = 0

  for _, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = evaluatedTargets[taskTemplate.name]
    if targets then
      taskIndex = taskIndex + 1
      local task, reason = tryBuildExecutableTask(
        saveData,
        taskTemplate,
        targets,
        assignedFiringUnits,
        statusCounter,
        matrixStartTime,
        taskIndex,
        matrixTemplate.strikeInterval
      )
      if task then
        table.insert(fireSupportTasks, task)
      elseif reason == "NO_AVAILABLE_FIRING_UNITS" then
        buildFailureCount = buildFailureCount + 1
      end
    end
  end

  return fireSupportTasks, statusCounter, buildFailureCount
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
  return DynamicOperationsUtils.generateUniqueGroundOperationName(
    matrixTemplate.name:match("([^/]+)") or matrixTemplate.name, reconType, saveData
  )
end

---Create actual FSEM from template and evaluation results
---Constructs executable FSEM with FSTs, validates firing units, and inserts into FSP
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure and FST configurations
---@param evaluatedTargets table<string, string[]> Map of FST name to evaluated target GUID arrays
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@return boolean success true if FSEM was successfully created and inserted
---@return string|nil reason Failure reason when success is false
---@return string statusSummary Firing unit status summary
local function createFSEMFromTemplate(saveData, matrixTemplate, evaluatedTargets, reconType)
  local matrixStartTime = GameApi.ScenEdit_CurrentTime()
  local matrixName = buildMatrixName(matrixTemplate, reconType, saveData)
  local fireSupportTasks, statusCounter, buildFailureCount = buildExecutableTasks(
    saveData, matrixTemplate, evaluatedTargets, matrixStartTime
  )
  local statusSummary = formatStatusCounter(statusCounter)

  if #fireSupportTasks == 0 then
    if buildFailureCount > 0 then
      return false, "NO_AVAILABLE_FIRING_UNITS", statusSummary
    end
    return false, "NO_VALID_TASKS", statusSummary
  end

  local newMatrix = buildFireSupportMatrix(matrixTemplate, matrixName, fireSupportTasks)
  return insertMatrix(saveData, newMatrix), nil, statusSummary
end

---Observation window state for a ground operation in the recon schedule
local OBSERVATION_STATE = {
  PRE_TRIGGER = "pre_trigger",
  IN_WINDOW   = "in_window",
  EXPIRED     = "expired",
}

---Evaluate observation window state for a ground operation
---Window starts at reconEntry.time + reconEntry.delay and lasts windowSec seconds.
---@param currentTime integer Current scenario time in unix timestamp
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry
---@param windowSec number Observation window duration in seconds
---@return string # Observation state from OBSERVATION_STATE
local function evaluateObservationWindow(currentTime, reconEntry, windowSec)
  local triggerTime = Utils.parseDatetimeToTimestamp(reconEntry.time) + reconEntry.delay
  if currentTime < triggerTime then
    return OBSERVATION_STATE.PRE_TRIGGER
  end
  if currentTime > triggerTime + windowSec then
    return OBSERVATION_STATE.EXPIRED
  end
  return OBSERVATION_STATE.IN_WINDOW
end

---Process reconnaissance schedule entry, get FSEM template and execute evaluation
---Processes all FSTs in template, evaluates targets, and creates FSEM if valid targets exist
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry triggering this operation
---@param operation SBJ__Operation Ground operation containing FSEM template
---@return boolean success true if FSEM was successfully created from reconnaissance results
---@return string|nil reason Failure reason when success is false
---@return string|nil statusSummary Firing unit status summary if available
local function processGroundOperation(config, saveData, contacts, reconEntry, operation)
  if not operation.template or not operation.template.fireSupportTasks then
    return false, "MISSING_TEMPLATE", nil
  end

  local matrixTemplate = Utils.deepCopy(operation.template)
  local evaluatedTargets, validTaskCount = evaluateTargetsFromTemplate(config, saveData, contacts, matrixTemplate)
  if validTaskCount == 0 then
    return false, "INSUFFICIENT_TARGETS", nil
  end

  return createFSEMFromTemplate(saveData, matrixTemplate, evaluatedTargets, reconEntry.type)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Main execution function, process reconnaissance schedule and dynamically create FSEM
---Ground operations stay in the recon schedule across ticks while inside their observation
---window; they are only marked executed when (a) the FSEM is successfully inserted, (b) the
---template is missing (fatal), (c) the window has expired (timeout), or (d) an unknown failure
---reason is returned. INSUFFICIENT_TARGETS / NO_AVAILABLE_FIRING_UNITS keep the operation
---pending so contacts can accumulate or firing units can free up over subsequent ticks.
---@param config SBJ__Config Global configuration with battery and weapon system parameters
---@param saveData SBJ__SaveData Persistent save data with dynamic operations and FSP structure
---@param contacts CMO__Contact[] Sensor contacts from event script for target filtering
---@return boolean # True if any ground operation was processed and executed, false if disabled or none ready
function DynamicFireSupportPlan.execute(config, saveData, contacts)
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.enabled then
    return false
  end

  -- In this scenario runtime, ScenEdit_CurrentTime is guaranteed to return a valid unix timestamp.
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local windowSec = config.c.recon.observationWindowSec
  local hasExecutedAny = false

  local groundOperations = DynamicOperationsUtils.filterOperationsByType(
    saveData.c.dynamicOperations.reconSchedule, "ground"
  )

  if #groundOperations == 0 then
    return false
  end

  local processedResults = {}

  for _, item in ipairs(groundOperations) do
    local reconEntry = item.reconEntry
    local operation = item.operation
    local operationName = (operation.template and operation.template.name) or "unknown"
    local windowState = evaluateObservationWindow(currentTime, reconEntry, windowSec)

    if windowState == OBSERVATION_STATE.EXPIRED then
      DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, false)
      table.insert(processedResults, {
        operationName = operationName,
        reconTime = reconEntry.time,
        reconType = reconEntry.type,
        outcome = "TIMEOUT",
      })
    elseif windowState == OBSERVATION_STATE.IN_WINDOW then
      local success, reason, statusSummary = processGroundOperation(
        config, saveData, contacts, reconEntry, operation
      )

      if success then
        DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, true)
        hasExecutedAny = true
        table.insert(processedResults, {
          operationName = operationName,
          reconTime = reconEntry.time,
          reconType = reconEntry.type,
          outcome = "OK",
          statusSummary = statusSummary,
        })
      elseif reason == "MISSING_TEMPLATE" then
        DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, false)
        table.insert(processedResults, {
          operationName = operationName,
          reconTime = reconEntry.time,
          reconType = reconEntry.type,
          outcome = "MISSING_TEMPLATE",
        })
      elseif reason == "INSUFFICIENT_TARGETS" or reason == "NO_AVAILABLE_FIRING_UNITS" then
        -- Stay in observation window; do NOT mark executed. Re-emit [WAIT] each tick so
        -- operators can track how long the operation has been observing and which gate
        -- (targets vs firing units) is currently blocking.
        table.insert(processedResults, {
          operationName = operationName,
          reconTime = reconEntry.time,
          reconType = reconEntry.type,
          outcome = "WAIT",
          reason = reason,
          statusSummary = statusSummary,
        })
      else
        -- Unknown failure reason; mark executed to avoid infinite retry.
        DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, false)
        table.insert(processedResults, {
          operationName = operationName,
          reconTime = reconEntry.time,
          reconType = reconEntry.type,
          outcome = "FAIL",
          reason = reason,
          statusSummary = statusSummary,
        })
      end
    end
    -- PRE_TRIGGER: silent skip, identical to legacy behavior before observation window.
  end

  if #processedResults > 0 then
    local infoLines = {}
    local errorLines = {}

    for _, r in ipairs(processedResults) do
      if r.outcome == "OK" then
        table.insert(infoLines, string.format("  [OK] %s (%s, %s) | firing units: %s",
          r.operationName, r.reconTime, r.reconType, r.statusSummary or "none"))
      elseif r.outcome == "WAIT" then
        table.insert(infoLines, string.format("  [WAIT] %s (%s, %s) | %s | firing units: %s",
          r.operationName, r.reconTime, r.reconType, r.reason or "unknown", r.statusSummary or "none"))
      elseif r.outcome == "TIMEOUT" then
        table.insert(infoLines, string.format("  [TIMEOUT] %s (%s, %s) | observation window expired",
          r.operationName, r.reconTime, r.reconType))
      elseif r.outcome == "MISSING_TEMPLATE" then
        table.insert(errorLines, string.format("  [ERROR] %s (%s, %s) | missing FSEM template",
          r.operationName, r.reconTime, r.reconType))
      else
        table.insert(errorLines, string.format("  [FAIL] %s (%s, %s) | %s | firing units: %s",
          r.operationName, r.reconTime, r.reconType, r.reason or "UNKNOWN", r.statusSummary or "none"))
      end
    end

    if #infoLines > 0 then
      Logger.log(constants.TAGS.DYNAMIC_OPERATIONS, string.format(
        "Ground operations processed: %d items\n%s", #infoLines, table.concat(infoLines, "\n")))
    end

    if #errorLines > 0 then
      Logger.error(string.format(
        "Ground operations errors: %d items\n%s", #errorLines, table.concat(errorLines, "\n")))
    end
  end

  return hasExecutedAny
end

return DynamicFireSupportPlan
