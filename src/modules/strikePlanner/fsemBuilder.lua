local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicPlan = require("src.modules.strikePlanner.dynamicPlan")
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
local constants = require("src.core.constants")

local FsemBuilder = {}

local READINESS = constants.MISSILE_SYSTEM_READINESS

-- Planner-side status; every other status is a missile system readiness.
local ASSIGNED_STATUS = "assigned"

-- Single source for the counter keys and the order they appear in a log row.
local READINESS_COUNT_ORDER = {
  READINESS.READY,
  ASSIGNED_STATUS,
  READINESS.UNIT_NOT_FOUND,
  READINESS.NO_STATE,
  READINESS.NOT_HIDDEN,
  READINESS.LOW_AMMO
}

local READINESS_COUNT_LOG_FIELD = {
  [READINESS.READY] = "launcherAvailable",
  [ASSIGNED_STATUS] = "launcherAssigned",
  [READINESS.UNIT_NOT_FOUND] = "launcherNotFound",
  [READINESS.NO_STATE] = "launcherContextNotFound",
  [READINESS.NOT_HIDDEN] = "launcherBadState",
  [READINESS.LOW_AMMO] = "launcherLowAmmo"
}

-- Failure reasons written straight into reason=<token>. INSUFFICIENT_TARGETS and
-- NO_AVAILABLE_LAUNCHERS also drive the retry decision OperationBatch makes.
local PROCESS_REASON = {
  INSUFFICIENT_TARGETS = "insufficient_targets",
  NO_AVAILABLE_LAUNCHERS = "no_available_launchers",
  NO_VALID_TASKS = "no_valid_tasks"
}

-- Reasons that keep an operation pending for a later tick inside the window.
local RETRYABLE_REASON = {
  [PROCESS_REASON.INSUFFICIENT_TARGETS] = true,
  [PROCESS_REASON.NO_AVAILABLE_LAUNCHERS] = true
}

local LOG_SCOPE = "dynamicGroundOperations"
local LOG_ACTION = "Process operations"

-- Stand-in counters for an outcome that never reached launcher evaluation.
local NO_LAUNCHERS_FIELDS = { launchers = "none" }

-- ============================================================================
-- Launcher Readiness Count
-- ============================================================================

---Create a readiness count with every outcome zeroed
---@return SBJ__LauncherReadinessCount # Zeroed readiness count
local function createReadinessCount()
  local readinessCount = {}

  for _, status in ipairs(READINESS_COUNT_ORDER) do
    readinessCount[status] = 0
  end

  return readinessCount
end

---Increment the count for one readiness outcome
---@param readinessCount SBJ__LauncherReadinessCount
---@param status string
local function updateReadinessCount(readinessCount, status)
  if readinessCount[status] ~= nil then
    readinessCount[status] = readinessCount[status] + 1
  end
end

---Format a readiness count into log fields, dropping zero counts
---@param readinessCount SBJ__LauncherReadinessCount
---@return table<string, any> # Status log fields, launchers=none when nothing was counted
local function formatReadinessCount(readinessCount)
  local statusFields = {}
  local hasAnyCount = false

  for _, status in ipairs(READINESS_COUNT_ORDER) do
    local count = readinessCount[status] or 0
    if count > 0 then
      statusFields[READINESS_COUNT_LOG_FIELD[status]] = count
      hasAnyCount = true
    end
  end

  if not hasAnyCount then
    return NO_LAUNCHERS_FIELDS
  end

  return statusFields
end

-- ============================================================================
-- Launcher Availability
-- ============================================================================

---Collect launcher names already committed to active FSEMs
---@param plannerState SBJ__StrikePlannerState
---@return table<string, boolean> # Map of committed launcher name to true
local function collectAssignedLauncherNames(plannerState)
  local assignedLauncherNameSet = {}

  for _, matrix in pairs(plannerState.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished then
          for _, launcherName in ipairs(task.launcherNames) do
            assignedLauncherNameSet[launcherName] = true
          end
        end
      end
    end
  end

  return assignedLauncherNameSet
end

---Resolve a launcher through the pass-scoped cache
---ScenEdit_GetUnit costs two CMO round-trips per name and logs a full stack trace when
---the unit is gone, so a miss is cached as false to pay that once per pass.
---@param launcherCache table<string, CMO__Unit|false>
---@param launcherName string
---@return CMO__Unit|nil # Resolved unit, or nil when it no longer exists
local function getCachedLauncher(launcherCache, launcherName)
  local actualUnit = launcherCache[launcherName]

  if actualUnit == nil then
    actualUnit = GameApi.ScenEdit_GetUnit(launcherName) or false
    launcherCache[launcherName] = actualUnit
  end

  return actualUnit or nil
end

---Evaluate one launcher against assignment, then missile system readiness
---@param plannerState SBJ__StrikePlannerState
---@param missileSystemType string
---@param launcherName string
---@param passCtx SBJ__FsemPassContext
---@return string # ASSIGNED_STATUS or a constants.MISSILE_SYSTEM_READINESS value
local function evaluateLauncherReadiness(plannerState, missileSystemType, launcherName, passCtx)
  if passCtx.assignedLauncherNames[launcherName] then
    return ASSIGNED_STATUS
  end

  return MissileSystem.evaluateReadiness(
    passCtx.config, plannerState.ground, constants.SIDES.RED, missileSystemType, launcherName,
    function(name)
      return getCachedLauncher(passCtx.launcherCache, name)
    end
  )
end

---Select the launchers of a task template that are free and ready to fire
---@param plannerState SBJ__StrikePlannerState
---@param taskTemplate SBJ__FireSupportTaskTemplate
---@param readinessCount SBJ__LauncherReadinessCount
---@param passCtx SBJ__FsemPassContext
---@return string[] # Names of the launchers ready for assignment
local function filterAvailableLaunchers(plannerState, taskTemplate, readinessCount, passCtx)
  local availableLaunchers = {}

  for _, launcherName in ipairs(taskTemplate.launcherNames) do
    local status = evaluateLauncherReadiness(plannerState, taskTemplate.missileSystemType, launcherName, passCtx)

    updateReadinessCount(readinessCount, status)
    if status == READINESS.READY then
      table.insert(availableLaunchers, launcherName)
    end
  end

  return availableLaunchers
end

-- ============================================================================
-- Task Construction
-- ============================================================================

---Build the UTC start time string for one FST firing slot
---@param matrixStartTime integer Matrix base start time in unix timestamp
---@param strikeInterval integer Strike interval in seconds
---@param slotIndex integer
---@return string # UTC datetime string for task start time
local function buildTaskStartTime(matrixStartTime, strikeInterval, slotIndex)
  return os.date(constants.DATE_FORMAT, matrixStartTime + (slotIndex * strikeInterval)) --[[@as string]]
end

---Mark newly assigned launchers so a later task in the same pass cannot reuse them
---@param assignedLauncherNameSet table<string, boolean>
---@param availableLaunchers string[]
local function setLaunchersAssigned(assignedLauncherNameSet, availableLaunchers)
  for _, launcherName in ipairs(availableLaunchers) do
    assignedLauncherNameSet[launcherName] = true
  end
end

---Build executable FSTs from evaluated targets and available launchers
---@param plannerState SBJ__StrikePlannerState
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate
---@param targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@param passCtx SBJ__FsemPassContext
---@return SBJ__FireSupportTask[] fireSupportTasks Built executable tasks
---@return SBJ__LauncherReadinessCount readinessCount Launcher count per readiness outcome
---@return number launcherBlockedTaskCount Tasks dropped because no launcher was available
local function buildExecutableTasks(plannerState, matrixTemplate, targetsByTaskIndex, passCtx)
  local fireSupportTasks = {}
  local readinessCount = createReadinessCount()
  local launcherBlockedTaskCount = 0
  local slotIndex = 0

  for taskIndex, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = targetsByTaskIndex[taskIndex]

    if targets then
      slotIndex = slotIndex + 1
      local availableLaunchers = filterAvailableLaunchers(
        plannerState,
        taskTemplate,
        readinessCount,
        passCtx
      )

      if #availableLaunchers == 0 then
        launcherBlockedTaskCount = launcherBlockedTaskCount + 1
      else
        local task = Utils.deepCopy(taskTemplate) --[[@as SBJ__FireSupportTask]]
        task.launcherNames = availableLaunchers
        task.startTime = buildTaskStartTime(passCtx.currentTime, matrixTemplate.strikeInterval, slotIndex)
        task.isFinished = false
        task.target.list = targets
        setLaunchersAssigned(passCtx.assignedLauncherNames, availableLaunchers)
        table.insert(fireSupportTasks, task)
      end
    end
  end

  return fireSupportTasks, readinessCount, launcherBlockedTaskCount
end

-- ============================================================================
-- Operation Processing
-- ============================================================================

---Assemble the FSEM structure that gets written into the fire support plan
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate
---@param matrixName string
---@param fireSupportTasks SBJ__FireSupportTask[]
---@param createdAt integer Creation unix timestamp used for stale retirement
---@return SBJ__FireSupportExecutionMatrix # Matrix structure ready for insertion
local function buildMatrix(matrixTemplate, matrixName, fireSupportTasks, createdAt)
  ---@type SBJ__FireSupportExecutionMatrix
  local matrix = {
    name = matrixName,
    isActivated = true,
    isFinished = false,
    isFirstWave = matrixTemplate.isFirstWave,
    allLaunchersInPosition = false,
    fireSupportTasks = fireSupportTasks,
    createdAt = createdAt,
    -- Ground dynamic FSP uses TOT-oriented execution; interval is intentionally disabled after generation.
    strikeInterval = 0
  }

  return matrix
end

---Build an FSEM from the template and insert it into the fire support plan
---@param plannerState SBJ__StrikePlannerState
---@param params SBJ__MatrixInsertParams
---@param passCtx SBJ__FsemPassContext
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function createAndInsertMatrixFromTemplate(plannerState, params, passCtx)
  local matrixTemplate, targetsByTaskIndex = params.matrixTemplate, params.targetsByTaskIndex
  local reconType = params.reconType
  local fireSupportTasks, readinessCount, launcherBlockedTaskCount = buildExecutableTasks(
    plannerState,
    matrixTemplate,
    targetsByTaskIndex,
    passCtx
  )
  local statusFields = formatReadinessCount(readinessCount)

  if #fireSupportTasks == 0 then
    local isRetryable = launcherBlockedTaskCount > 0
    return {
      success = false,
      tag = isRetryable and "SKIP" or "FAIL",
      reason = isRetryable and PROCESS_REASON.NO_AVAILABLE_LAUNCHERS or PROCESS_REASON.NO_VALID_TASKS,
      fields = statusFields
    }
  end

  -- Naming, insertion and registration happen in one call, so the generated name can
  -- never go unregistered.
  DynamicPlan.add(plannerState, {
    operationType = "ground",
    templateName = matrixTemplate.name,
    reconType = reconType,
    buildPlan = function(planName)
      return buildMatrix(matrixTemplate, planName, fireSupportTasks, passCtx.currentTime)
    end
  })
  return { success = true, tag = "OK", fields = statusFields }
end

---Evaluate one ground operation and insert its FSEM when targets and launchers allow
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
---@param batchedOp SBJ__BatchedOperation
---@param passCtx SBJ__FsemPassContext
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function processGroundOperation(config, plannerState, batchedOp, passCtx)
  local operation = batchedOp.operation
  local reconType = batchedOp.operationBatch.type

  local targetsByTaskIndex, targetQualifiedTaskCount = DynamicPlan.evaluateTargets(config, plannerState, {
    contacts = passCtx.contacts,
    operationType = "ground",
    template = operation.template
  })

  if targetQualifiedTaskCount == 0 then
    -- No launcher was evaluated yet, so there are no counters to report.
    return {
      success = false,
      tag = "SKIP",
      reason = PROCESS_REASON.INSUFFICIENT_TARGETS,
      fields = NO_LAUNCHERS_FIELDS
    }
  end

  local matrixTemplate = Utils.deepCopy(operation.template)
  return createAndInsertMatrixFromTemplate(plannerState, {
    matrixTemplate = matrixTemplate,
    targetsByTaskIndex = targetsByTaskIndex,
    reconType = reconType
  }, passCtx)
end

-- ============================================================================
-- Stale Matrix Retirement
-- ============================================================================

---Check whether an active matrix has exceeded the stale timeout
---Matrices without createdAt (legacy saves) never go stale.
---@param matrix SBJ__FireSupportExecutionMatrix
---@param currentTime integer
---@param staleAfterSec number
---@return boolean # True when the matrix age exceeds the timeout
local function isMatrixStale(matrix, currentTime, staleAfterSec)
  return matrix.createdAt ~= nil and (currentTime - matrix.createdAt) > staleAfterSec
end

---Retire active matrices that exceeded the stale timeout
---Marking them finished releases their launchers to the assignable pool and stops
---FireSupportPlan.strike from commanding them, avoiding double command.
---@param plannerState SBJ__StrikePlannerState
---@param currentTime integer
---@param staleAfterSec number
---@param opReport SBJ__LogReport
local function retireStaleMatrices(plannerState, currentTime, staleAfterSec, opReport)
  for _, matrix in pairs(plannerState.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and isMatrixStale(matrix, currentTime, staleAfterSec) then
      matrix.isFinished = true

      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished then
          MissileSystem.abortFireTask(plannerState.ground, task.missileSystemType, task.launcherNames)
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
---Retirement runs on every enabled tick. OperationBatch drives the observation window;
---this module only answers whether an FSEM can be inserted right now.
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
---@param contacts CMO__Contact[]
---@return boolean # True if any ground operation was processed and executed, false if disabled or none ready
function FsemBuilder.build(config, plannerState, contacts)
  if not plannerState.dynamicOperations.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local opReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, LOG_ACTION)

  -- Retirement deliberately runs before any pending operation is looked at. A matrix whose
  -- targets are already gone never fires, so no task is ever marked finished and nothing
  -- else releases its launchers; gating retirement on "another operation is waiting"
  -- would leave those brigades deployed indefinitely on every quiet tick.
  retireStaleMatrices(plannerState, currentTime, config.red.recon.fsemStaleAfterSec, opReport)

  -- Must stay a local: both caches only hold still within one pass. Promoting them to
  -- module scope would let them survive across ticks (the module table becomes a global
  -- after bundling) and hand out units destroyed or committed since an earlier tick.
  -- Seeded after retirement so units released by a retired matrix are assignable now.
  ---@type SBJ__FsemPassContext
  local passCtx = {
    config = config,
    contacts = contacts,
    currentTime = currentTime,
    launcherCache = {},
    assignedLauncherNames = collectAssignedLauncherNames(plannerState)
  }

  local result = OperationBatch.process(plannerState.dynamicOperations.reconTriggeredOperationBatches, "ground", {
    currentTime = currentTime,
    windowSec = config.red.recon.observationWindowSec,
    retryableReasonSet = RETRYABLE_REASON,
    tryInsert = function(batchedOp)
      return processGroundOperation(config, plannerState, batchedOp, passCtx)
    end
  })

  for _, entry in ipairs(result.entries) do
    opReport.add(entry.tag, entry.fields, entry.outcome.details)
  end

  -- Retirement rows still have to reach the log on a tick with nothing to process.
  opReport.emit()
  return result.hasExecutedAny
end

return FsemBuilder
