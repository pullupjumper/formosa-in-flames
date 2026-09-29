local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local DynamicPlan = require("src.modules.strikePlanner.dynamicPlan")
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
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
-- NO_AVAILABLE_FIRING_UNITS also drive the retry decision OperationBatch makes.
local PROCESS_REASON = {
  INSUFFICIENT_TARGETS = "insufficient_targets",
  NO_AVAILABLE_FIRING_UNITS = "no_available_firing_units",
  NO_VALID_TASKS = "no_valid_tasks"
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
---@return SBJ__FiringUnitStatusResult # Zeroed status counter
local function createFiringUnitStatusCounter()
  local firingUnitStatusCounter = {}

  for _, status in ipairs(FIRING_UNIT_STATUS_ORDER) do
    firingUnitStatusCounter[status] = 0
  end

  return firingUnitStatusCounter
end

---Increment the count for one firing unit status
---@param firingUnitStatusCounter SBJ__FiringUnitStatusResult Status counter; mutated
---@param status string Firing unit status from FIRING_UNIT_STATUS
local function updateFiringUnitStatus(firingUnitStatusCounter, status)
  if firingUnitStatusCounter[status] ~= nil then
    firingUnitStatusCounter[status] = firingUnitStatusCounter[status] + 1
  end
end

---Format a status counter into log fields, dropping zero counts
---@param firingUnitStatusCounter SBJ__FiringUnitStatusResult Status counter to format
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
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@return table<string, boolean> # Map of committed firing unit name to true
local function collectAssignedFiringUnitNames(plannerState)
  local assignedFiringUnitNameSet = {}

  for _, matrix in pairs(plannerState.ground.fireSupportPlan) do
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

  if MissileSystem.isLowAmmo(firingUnitCtx, actualUnit) then
    return FIRING_UNIT_STATUS.LOW_AMMO
  end

  return FIRING_UNIT_STATUS.AVAILABLE
end

---Select the firing units of a task template that are free and ready to fire
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param taskTemplate SBJ__FireSupportTaskTemplate FST template definition
---@param firingUnitStatusCounter SBJ__FiringUnitStatusResult Validation outcome counter; mutated
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__FiringUnit[] # Firing units ready for assignment
local function filterAvailableFiringUnits(plannerState, taskTemplate, firingUnitStatusCounter, passCtx)
  local availableFiringUnits = {}

  for _, firingUnit in ipairs(taskTemplate.firingUnits) do
    -- A nameless entry breaks the SBJ__FiringUnit invariant, reads back a nil context and
    -- is rejected as CONTEXT_NOT_FOUND, so it never reaches an assignment map.
    local firingUnitCtx = MissileSystem.getFiringUnitContext(plannerState.ground, taskTemplate.missileSystem, firingUnit.name)
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

---Build executable FSTs from evaluated targets and available firing units
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__FireSupportTask[] fireSupportTasks Built executable tasks
---@return SBJ__FiringUnitStatusResult firingUnitStatusCounter Firing unit validation counts
---@return number firingUnitBlockedTaskCount Tasks dropped because no firing unit was available
local function buildExecutableTasks(plannerState, matrixTemplate, targetsByTaskIndex, passCtx)
  local fireSupportTasks = {}
  local firingUnitStatusCounter = createFiringUnitStatusCounter()
  local firingUnitBlockedTaskCount = 0
  local slotIndex = 0

  for taskIndex, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = targetsByTaskIndex[taskIndex]

    if targets then
      slotIndex = slotIndex + 1
      local availableFiringUnits = filterAvailableFiringUnits(
        plannerState,
        taskTemplate,
        firingUnitStatusCounter,
        passCtx
      )

      if #availableFiringUnits == 0 then
        firingUnitBlockedTaskCount = firingUnitBlockedTaskCount + 1
      else
        local task = Utils.deepCopy(taskTemplate) --[[@as SBJ__FireSupportTask]]
        task.firingUnits = availableFiringUnits
        task.startTime = buildTaskStartTime(passCtx.currentTime, matrixTemplate.strikeInterval, slotIndex)
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
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@param targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function createAndInsertMatrixFromTemplate(
    plannerState,
    matrixTemplate,
    targetsByTaskIndex,
    reconType,
    passCtx
)
  local fireSupportTasks, firingUnitStatusCounter, firingUnitBlockedTaskCount = buildExecutableTasks(
    plannerState,
    matrixTemplate,
    targetsByTaskIndex,
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

  -- Naming, insertion and registration happen in one call, so the generated name can
  -- never go unregistered.
  DynamicPlan.insert(plannerState, "ground", matrixTemplate.name, reconType, function(planName)
    return buildMatrix(matrixTemplate, planName, fireSupportTasks, passCtx.currentTime)
  end)
  return { success = true, tag = "OK", fields = statusFields }
end

---Evaluate one ground operation and insert its FSEM when targets and firing units allow
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param batchedOp SBJ__BatchedOperation Ground operation paired with its parent batch
---@param passCtx SBJ__FsemPassContext Pass-scoped caches shared by every operation in this tick
---@return SBJ__OperationProcessResult # Outcome of the FSEM insertion attempt
local function processGroundOperation(config, plannerState, batchedOp, passCtx)
  local operation = batchedOp.operation
  local reconType = batchedOp.operationBatch.type

  local targetsByTaskIndex, targetQualifiedTaskCount = DynamicPlan.evaluateTargets(
    config,
    plannerState,
    passCtx.contacts,
    "ground",
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
    plannerState,
    matrixTemplate,
    targetsByTaskIndex,
    reconType,
    passCtx
  )
end

-- ============================================================================
-- Stale Matrix Retirement
-- ============================================================================

---Check whether an active matrix has exceeded the stale timeout
---Matrices without createdAt (legacy saves) never go stale.
---@param matrix SBJ__FireSupportExecutionMatrix Matrix to check
---@param currentTime integer Current unix timestamp
---@param staleAfterSec number Stale timeout in seconds
---@return boolean # True when the matrix age exceeds the timeout
local function isMatrixStale(matrix, currentTime, staleAfterSec)
  return matrix.createdAt ~= nil and (currentTime - matrix.createdAt) > staleAfterSec
end

---Retire active matrices that exceeded the stale timeout
---Marking them finished releases their firing units to the assignable pool and stops
---FireSupportPlan.strike from commanding them, avoiding double command.
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param currentTime integer Current unix timestamp
---@param staleAfterSec number Stale timeout in seconds
---@param opReport SBJ__LogReport Report collector receiving one WARN row per retired matrix
local function retireStaleMatrices(plannerState, currentTime, staleAfterSec, opReport)
  for _, matrix in pairs(plannerState.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and isMatrixStale(matrix, currentTime, staleAfterSec) then
      matrix.isFinished = true

      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished then
          -- Only units that left their hide area need to go back; RELOAD already ends in HA.
          MissileSystem.markForStow(plannerState.ground, task.missileSystem, task.firingUnits, { onlyDeployed = true })
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
---@param config SBJ__Config Global configuration with battery and weapon system parameters
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Sensor contacts from event script for target filtering
---@return boolean # True if any ground operation was processed and executed, false if disabled or none ready
function FsemBuilder.build(config, plannerState, contacts)
  if not plannerState.dynamicOperations.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local opReport = LogFormat.report(constants.TAGS.DYNAMIC_OPERATIONS, LOG_SCOPE, LOG_ACTION)

  -- Retirement deliberately runs before any pending operation is looked at. A matrix whose
  -- targets are already gone never fires, so no task is ever marked finished and nothing
  -- else releases its firing units; gating retirement on "another operation is waiting"
  -- would leave those brigades deployed indefinitely on every quiet tick.
  retireStaleMatrices(plannerState, currentTime, config.c.recon.fsemStaleAfterSec, opReport)

  -- Must stay a local: both caches only hold still within one pass. Promoting them to
  -- module scope would let them survive across ticks (the module table becomes a global
  -- after bundling) and hand out units destroyed or committed since an earlier tick.
  -- Seeded after retirement so units released by a retired matrix are assignable now.
  ---@type SBJ__FsemPassContext
  local passCtx = {
    contacts = contacts,
    currentTime = currentTime,
    firingUnitCache = {},
    assignedFiringUnitNames = collectAssignedFiringUnitNames(plannerState)
  }

  local result = OperationBatch.run(plannerState.dynamicOperations.reconTriggeredOperationBatches, "ground", {
    currentTime = currentTime,
    windowSec = config.c.recon.observationWindowSec,
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
