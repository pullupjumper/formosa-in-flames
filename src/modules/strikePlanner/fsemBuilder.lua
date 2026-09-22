local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local constants = require("src.core.constants")

local FsemBuilder = {}

local FIRING_UNIT_STATUS = {
  AVAILABLE = "available",
  ASSIGNED = "assigned",
  UNIT_NOT_FOUND = "unit_not_found",
  CONTEXT_NOT_FOUND = "context_not_found",
  BAD_STATE = "bad_state",
  LOW_AMMO = "low_ammo"
}

-- Single source for the counter keys and the order they appear in a log row.
local FIRING_UNIT_STATUS_ORDER = {
  FIRING_UNIT_STATUS.AVAILABLE,
  FIRING_UNIT_STATUS.ASSIGNED,
  FIRING_UNIT_STATUS.UNIT_NOT_FOUND,
  FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND,
  FIRING_UNIT_STATUS.BAD_STATE,
  FIRING_UNIT_STATUS.LOW_AMMO
}

local FIRING_UNIT_STATUS_LOG_FIELD = {
  [FIRING_UNIT_STATUS.AVAILABLE] = "firingAvailable",
  [FIRING_UNIT_STATUS.ASSIGNED] = "firingAssigned",
  [FIRING_UNIT_STATUS.UNIT_NOT_FOUND] = "firingUnitNotFound",
  [FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND] = "firingContextNotFound",
  [FIRING_UNIT_STATUS.BAD_STATE] = "firingBadState",
  [FIRING_UNIT_STATUS.LOW_AMMO] = "firingLowAmmo"
}

-- Failure reasons written straight into reason=<token>. INSUFFICIENT_TARGETS and
-- NO_AVAILABLE_FIRING_UNITS also drive the retry decision in FsemBuilder.build.
local PROCESS_REASON = {
  INSUFFICIENT_TARGETS = "insufficient_targets",
  NO_AVAILABLE_FIRING_UNITS = "no_available_firing_units",
  NO_VALID_TASKS = "no_valid_tasks",
  OBSERVATION_WINDOW_EXPIRED = "observation_window_expired"
}

-- Reasons that keep an operation pending for a later tick inside the window.
local RETRYABLE_REASON = {
  [PROCESS_REASON.INSUFFICIENT_TARGETS] = true,
  [PROCESS_REASON.NO_AVAILABLE_FIRING_UNITS] = true
}

local LOG_SCOPE = "dynamicGroundOperations"
local LOG_ACTION = "Process operations"

-- Stand-in counters for an outcome that never reached firing unit evaluation.
local NO_FIRING_UNITS_FIELDS = { firingUnits = "none" }

-- ============================================================================
-- Firing Unit Status
-- ============================================================================

---Create a firing unit status counter with every status zeroed
---@return SBJ__FiringUnitStatusCounter # Zeroed status counter
local function createFiringUnitStatusCounter()
  local firingUnitStatusCounter = {}

  for _, status in ipairs(FIRING_UNIT_STATUS_ORDER) do
    firingUnitStatusCounter[status] = 0
  end

  return firingUnitStatusCounter
end

---Increment the count for one firing unit status
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Status counter; mutated
---@param status string Firing unit status from FIRING_UNIT_STATUS
local function updateFiringUnitStatus(firingUnitStatusCounter, status)
  if firingUnitStatusCounter[status] ~= nil then
    firingUnitStatusCounter[status] = firingUnitStatusCounter[status] + 1
  end
end

---Format a status counter into log fields, dropping zero counts
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Status counter to format
---@return table<string, any> # Status log fields, firingUnits=none when nothing was counted
local function formatFiringUnitStatusCounter(firingUnitStatusCounter)
  local statusFields = {}
  local hasAnyCount = false

  for _, status in ipairs(FIRING_UNIT_STATUS_ORDER) do
    local count = firingUnitStatusCounter[status] or 0
    if count > 0 then
      statusFields[FIRING_UNIT_STATUS_LOG_FIELD[status]] = count
      hasAnyCount = true
    end
  end

  if not hasAnyCount then
    return NO_FIRING_UNITS_FIELDS
  end

  return statusFields
end

-- ============================================================================
-- Firing Unit Availability
-- ============================================================================

---Collect firing unit names already committed to active FSEMs
---@param saveData SBJ__SaveData Persistent save data containing the fire support plan
---@return table<string, boolean> # Map of committed firing unit name to true
local function collectAssignedFiringUnitNames(saveData)
  local assignedFiringUnitNameSet = {}

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished then
          for _, firingUnit in ipairs(task.firingUnits) do
            assignedFiringUnitNameSet[firingUnit.name] = true
          end
        end
      end
    end
  end

  return assignedFiringUnitNameSet
end

---Get firing unit runtime context from save data
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM")
---@param firingUnitName string Firing unit name used as context key
---@return SBJ__FiringUnitContext|nil # Firing unit runtime context, or nil when missing
local function getFiringUnitContext(saveData, missileSystem, firingUnitName)
  local missileSystemKey = string.lower(missileSystem)
  local missileSystemCtx = saveData.c.ground[missileSystemKey]
  return missileSystemCtx and missileSystemCtx.firingUnits and missileSystemCtx.firingUnits[firingUnitName]
end

---Resolve a firing unit through the pass-scoped cache
---ScenEdit_GetUnit costs two CMO round-trips per name and logs a full stack trace when
---the unit is gone, so a miss is cached as false to pay that once per pass.
---@param firingUnitCache table<string, CMO__Unit|false> Pass-scoped lookup cache; mutated
---@param firingUnitName string Firing unit name to resolve
---@return CMO__Unit|nil # Resolved unit, or nil when it no longer exists
local function getCachedFiringUnit(firingUnitCache, firingUnitName)
  local actualUnit = firingUnitCache[firingUnitName]

  if actualUnit == nil then
    actualUnit = GameApi.ScenEdit_GetUnit(firingUnitName) or false
    firingUnitCache[firingUnitName] = actualUnit
  end

  return actualUnit or nil
end

---Validate one firing unit against assignment, existence, state and ammo
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit runtime context
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return string # Firing unit status code from FIRING_UNIT_STATUS
local function validateFiringUnitStatus(firingUnitCtx, passCtx)
  local firingUnitName = firingUnitCtx.name

  if passCtx.assignedFiringUnitNames[firingUnitName] then
    return FIRING_UNIT_STATUS.ASSIGNED
  end

  local actualUnit = getCachedFiringUnit(passCtx.firingUnitCache, firingUnitName)
  if not actualUnit then
    return FIRING_UNIT_STATUS.UNIT_NOT_FOUND
  end

  if firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.HIDE then
    return FIRING_UNIT_STATUS.BAD_STATE
  end

  if MissileSystem.isLowAmmo(actualUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    return FIRING_UNIT_STATUS.LOW_AMMO
  end

  return FIRING_UNIT_STATUS.AVAILABLE
end

---Select the firing units of a task template that are free and ready to fire
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param taskTemplate SBJ__FireSupportTaskTemplate FST template definition
---@param firingUnitStatusCounter SBJ__FiringUnitStatusCounter Validation outcome counter; mutated
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__FiringUnit[] # Firing units ready for assignment
local function filterAvailableFiringUnits(saveData, taskTemplate, firingUnitStatusCounter, passCtx)
  local availableFiringUnits = {}

  for _, firingUnit in ipairs(taskTemplate.firingUnits) do
    -- A nameless entry breaks the SBJ__FiringUnit invariant, reads back a nil context and
    -- is rejected as CONTEXT_NOT_FOUND, so it never reaches an assignment map.
    local firingUnitCtx = getFiringUnitContext(saveData, taskTemplate.missileSystem, firingUnit.name)
    local status = FIRING_UNIT_STATUS.CONTEXT_NOT_FOUND

    if firingUnitCtx then
      status = validateFiringUnitStatus(firingUnitCtx, passCtx)
    end

    updateFiringUnitStatus(firingUnitStatusCounter, status)
    if status == FIRING_UNIT_STATUS.AVAILABLE then
      table.insert(availableFiringUnits, firingUnit)
    end
  end

  return availableFiringUnits
end

-- ============================================================================
-- Task Construction
-- ============================================================================

---Build the UTC start time string for one FST firing slot
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@param strikeInterval integer Strike interval in seconds
---@param slotIndex integer Sequential firing slot within the matrix
---@return string # UTC datetime string for task start time
local function buildTaskStartTime(matrixStartTime, strikeInterval, slotIndex)
  return os.date(constants.DATE_FORMAT, matrixStartTime + (slotIndex * strikeInterval)) --[[@as string]]
end

---Mark newly assigned firing units so a later task in the same pass cannot reuse them
---@param assignedFiringUnitNameSet table<string, boolean> Shared assigned unit name map; mutated
---@param availableFiringUnits SBJ__FiringUnit[] Firing units assigned to the current task
local function setFiringUnitsAssigned(assignedFiringUnitNameSet, availableFiringUnits)
  for _, firingUnit in ipairs(availableFiringUnits) do
    assignedFiringUnitNameSet[firingUnit.name] = true
  end
end

---Evaluate targets for every FST in a matrix template and count the qualified ones
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate FSEM template to evaluate
---@return table<integer, string[]> targetsByTaskIndex Evaluated targets keyed by FST index
---@return number targetQualifiedTaskCount Number of task templates with enough targets
local function evaluateTargetsFromTemplate(config, saveData, contacts, matrixTemplate)
  local targetsByTaskIndex = {}
  local targetQualifiedTaskCount = 0

  for taskIndex, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local taskTargets = TargetingProcess.processTargets(
      config,
      saveData,
      contacts,
      taskTemplate.target,
      matrixTemplate.isFirstWave
    )
    local targetCount = #taskTargets
    local requiredCount = taskTemplate.target.minTargetCount

    if targetCount >= requiredCount then
      targetsByTaskIndex[taskIndex] = taskTargets
      targetQualifiedTaskCount = targetQualifiedTaskCount + 1
    end
  end

  return targetsByTaskIndex, targetQualifiedTaskCount
end

---Build executable FSTs from evaluated targets and available firing units
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__FireSupportTask[] fireSupportTasks Built executable tasks
---@return SBJ__FiringUnitStatusCounter firingUnitStatusCounter Firing unit validation counts
---@return number firingUnitBlockedTaskCount Tasks dropped because no firing unit was available
local function buildExecutableTasks(saveData, matrixTemplate, targetsByTaskIndex, matrixStartTime, passCtx)
  local fireSupportTasks = {}
  local firingUnitStatusCounter = createFiringUnitStatusCounter()
  local firingUnitBlockedTaskCount = 0
  local slotIndex = 0

  for taskIndex, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = targetsByTaskIndex[taskIndex]

    if targets then
      slotIndex = slotIndex + 1
      local availableFiringUnits = filterAvailableFiringUnits(
        saveData,
        taskTemplate,
        firingUnitStatusCounter,
        passCtx
      )

      if #availableFiringUnits == 0 then
        firingUnitBlockedTaskCount = firingUnitBlockedTaskCount + 1
      else
        local task = Utils.deepCopy(taskTemplate) --[[@as SBJ__FireSupportTask]]
        task.firingUnits = availableFiringUnits
        task.startTime = buildTaskStartTime(matrixStartTime, matrixTemplate.strikeInterval, slotIndex)
        task.isFinished = false
        task.target.list = targets
        setFiringUnitsAssigned(passCtx.assignedFiringUnitNames, availableFiringUnits)
        table.insert(fireSupportTasks, task)
      end
    end
  end

  return fireSupportTasks, firingUnitStatusCounter, firingUnitBlockedTaskCount
end

-- ============================================================================
-- Operation Processing
-- ============================================================================

---Assemble the FSEM structure that gets written into the fire support plan
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param matrixName string Generated unique matrix name
---@param fireSupportTasks SBJ__FireSupportTask[] Built task list for this matrix
---@param createdAt integer Creation unix timestamp used for stale retirement
---@return SBJ__FireSupportExecutionMatrix # Matrix structure ready for insertion
local function buildMatrix(matrixTemplate, matrixName, fireSupportTasks, createdAt)
  ---@type SBJ__FireSupportExecutionMatrix
  local matrix = {
    name = matrixName,
    isActivated = true,
    isFinished = false,
    isFirstWave = matrixTemplate.isFirstWave,
    allFiringUnitsInPosition = false,
    fireSupportTasks = fireSupportTasks,
    createdAt = createdAt,
    -- Ground dynamic FSP uses TOT-oriented execution; interval is intentionally disabled after generation.
    strikeInterval = 0
  }

  return matrix
end

---Build an FSEM from the template and insert it into the fire support plan
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@param currentTime integer Current game time in unix timestamp
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function createAndInsertMatrixFromTemplate(
    saveData,
    matrixTemplate,
    targetsByTaskIndex,
    reconType,
    currentTime,
    passCtx
)
  local fireSupportTasks, firingUnitStatusCounter, firingUnitBlockedTaskCount = buildExecutableTasks(
    saveData,
    matrixTemplate,
    targetsByTaskIndex,
    currentTime,
    passCtx
  )
  local statusFields = formatFiringUnitStatusCounter(firingUnitStatusCounter)

  if #fireSupportTasks == 0 then
    local isRetryable = firingUnitBlockedTaskCount > 0
    return {
      success = false,
      tag = isRetryable and "SKIP" or "FAIL",
      reason = isRetryable and PROCESS_REASON.NO_AVAILABLE_FIRING_UNITS or PROCESS_REASON.NO_VALID_TASKS,
      fields = statusFields
    }
  end

  local matrixName = DynamicState.buildUniqueGroundOperationName(matrixTemplate.name, reconType, saveData)
  local matrix = buildMatrix(matrixTemplate, matrixName, fireSupportTasks, currentTime)
  saveData.c.ground.fireSupportPlan[matrix.name] = matrix
  DynamicState.addGeneratedOperation("ground", matrix.name, saveData)
  return { success = true, tag = "OK", fields = statusFields }
end

---Evaluate one ground operation and insert its FSEM when targets and firing units allow
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param batchedOp SBJ__BatchedOperation Ground operation paired with its parent batch
---@param currentTime integer Current game time in unix timestamp
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function processGroundOperation(config, saveData, contacts, batchedOp, currentTime, passCtx)
  local operation = batchedOp.operation
  local reconType = batchedOp.operationBatch.type

  local targetsByTaskIndex, targetQualifiedTaskCount = evaluateTargetsFromTemplate(
    config,
    saveData,
    contacts,
    operation.template
  )

  if targetQualifiedTaskCount == 0 then
    -- No firing unit was evaluated yet, so there are no counters to report.
    return {
      success = false,
      tag = "SKIP",
      reason = PROCESS_REASON.INSUFFICIENT_TARGETS,
      fields = NO_FIRING_UNITS_FIELDS
    }
  end

  local matrixTemplate = Utils.deepCopy(operation.template)
  return createAndInsertMatrixFromTemplate(
    saveData,
    matrixTemplate,
    targetsByTaskIndex,
    reconType,
    currentTime,
    passCtx
  )
end

-- ============================================================================
-- Stale Matrix Retirement
-- ============================================================================

-- States eligible for the stow countdown when a matrix is retired: units that were
-- deployed toward (or reached) a firing point but never fired. HIDE units are already
-- home, and the RELOAD pipeline already ends with a move back to the hide area.
local STOW_ON_RETIRE_STATE = {
  [constants.MISSILE_SYSTEM_STATE.STATIC] = true,
  [constants.MISSILE_SYSTEM_STATE.REPOSITIONING] = true
}

---Check whether an active matrix has exceeded the stale timeout
---Matrices without createdAt (legacy saves) never go stale.
---@param matrix SBJ__FireSupportExecutionMatrix Matrix to check
---@param currentTime integer Current unix timestamp
---@param staleAfterSec number Stale timeout in seconds
---@return boolean # True when the matrix age exceeds the timeout
local function isMatrixStale(matrix, currentTime, staleAfterSec)
  return matrix.createdAt ~= nil and (currentTime - matrix.createdAt) > staleAfterSec
end

---Start the stow countdown for deployed-but-unfired units of a retired task
---SAM tasks are excluded by convention and an existing countdown is preserved, so the
---missileSystem cycle sends the unit back to its hide area unchanged.
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param task SBJ__FireSupportTask Unfinished task from a retired matrix
---@param currentTime integer Current unix timestamp
local function stowRetiredTaskFiringUnits(saveData, task, currentTime)
  if not task.missileSystem or task.missileSystem == "SAM" or not task.firingUnits then
    return
  end

  for _, firingUnit in ipairs(task.firingUnits) do
    local firingUnitCtx = getFiringUnitContext(saveData, task.missileSystem, firingUnit.name)

    if firingUnitCtx and not firingUnitCtx.stowStartTime and STOW_ON_RETIRE_STATE[firingUnitCtx.state] then
      firingUnitCtx.stowStartTime = currentTime
    end
  end
end

---Retire active matrices that exceeded the stale timeout
---Marking them finished releases their firing units to the assignable pool and stops
---FireSupportPlan.strike from commanding them, avoiding double command.
---@param saveData SBJ__SaveData Persistent save data with FSP structure
---@param currentTime integer Current unix timestamp
---@param staleAfterSec number Stale timeout in seconds
---@param opReport SBJ__LogReport Report collector receiving one WARN row per retired matrix
local function retireStaleMatrices(saveData, currentTime, staleAfterSec, opReport)
  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and isMatrixStale(matrix, currentTime, staleAfterSec) then
      matrix.isFinished = true

      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished then
          stowRetiredTaskFiringUnits(saveData, task, currentTime)
        end
      end

      opReport.add("WARN", {
        matrix = matrix.name,
        reason = "fsem_stale_timeout",
        ageSec = currentTime - matrix.createdAt
      })
    end
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Retire stale FSEMs, then process recon-triggered ground operations and insert new FSEMs
---Retirement runs on every enabled tick; retryable operations stay pending inside their
---observation window and are dropped from their batch once it expires.
---@param config SBJ__Config Global configuration with battery and weapon system parameters
---@param saveData SBJ__SaveData Persistent save data with dynamic operations and FSP structure
---@param contacts CMO__Contact[] Sensor contacts from event script for target filtering
---@return boolean # True if any ground operation was processed and executed, false if disabled or none ready
function FsemBuilder.build(config, saveData, contacts)
  if not saveData.c.dynamicOperations.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local opReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, LOG_ACTION)

  -- Retirement deliberately runs before the pending-operation early return. A matrix whose
  -- targets are already gone never fires, so no task is ever marked finished and nothing
  -- else releases its firing units; gating retirement on "another operation is waiting"
  -- would leave those brigades deployed indefinitely on every quiet tick.
  retireStaleMatrices(saveData, currentTime, config.c.recon.fsemStaleAfterSec, opReport)

  local reconTriggeredOperationBatches = saveData.c.dynamicOperations.reconTriggeredOperationBatches
  local groundBatchedOperations = DynamicState.filterOperationsByType(reconTriggeredOperationBatches, "ground")
  if #groundBatchedOperations == 0 then
    -- Retirement rows still have to reach the log on a tick with nothing to process.
    opReport.emit()
    return false
  end

  local windowSec = config.c.recon.observationWindowSec
  local hasExecutedAny = false

  -- Must stay a local: both caches only hold still within one pass. Promoting them to
  -- module scope would let them survive across ticks (the module table becomes a global
  -- after bundling) and hand out units destroyed or committed since an earlier tick.
  -- Seeded after retirement so units released by a retired matrix are assignable now.
  ---@type SBJ__FsemPassContext
  local passCtx = {
    firingUnitCache = {},
    assignedFiringUnitNames = collectAssignedFiringUnitNames(saveData)
  }

  for _, batchedOp in ipairs(groundBatchedOperations) do
    local operationBatch = batchedOp.operationBatch
    local operation = batchedOp.operation
    local windowState = DynamicState.evaluateObservationWindow(currentTime, operationBatch, windowSec)

    -- PRE_TRIGGER: silent skip, the operation is simply not due yet.
    if windowState ~= DynamicState.OBSERVATION_STATE.PRE_TRIGGER then
      ---@type SBJ__OperationProcessResult
      local outcome
      if windowState == DynamicState.OBSERVATION_STATE.EXPIRED then
        outcome = { success = false, tag = "WARN", reason = PROCESS_REASON.OBSERVATION_WINDOW_EXPIRED }
      else
        outcome = processGroundOperation(config, saveData, contacts, batchedOp, currentTime, passCtx)
      end

      local fields = LogFormat.merge({
        operation = operation.template.name,
        batch = operationBatch.type .. "@" .. operationBatch.time
      }, outcome.fields)
      fields.reason = outcome.reason

      if outcome.success then
        DynamicState.setOperationExecuted(operationBatch, operation)
        hasExecutedAny = true
      elseif RETRYABLE_REASON[outcome.reason] then
        -- Retryable operations stay pending inside the window and re-report the
        -- blocking counters every tick, so the log shows what is holding them back.
        fields.state = "observing"
      else
        -- Everything else, including an unknown reason, is dropped from the batch so
        -- OperationScheduler re-opens the same wave instead of advancing past it.
        DynamicState.abandonOperation(operationBatch, operation)
        fields.state = "abandoned"
      end

      opReport.add(outcome.tag, fields, outcome.details)
    end
  end

  opReport.emit()
  return hasExecutedAny
end

return FsemBuilder
