local AttackManager = require("src.modules.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

local FireSupportPlan = {}
local PLAN_OUTCOME = {
  STRIKE = "strike",
  PENDING = "pending",
  FINISHED = "finished",
  FAIL = "fail"
}

---@class SBJ__FireSupportPlanProcessedResult
---@field matrixName string Matrix name
---@field outcome string Result outcome from PLAN_OUTCOME
---@field taskName? string Fire support task name
---@field fired? integer Fired weapon count
---@field notReadyNames? string[] Firing unit names not yet in position
---@field reason? string Failure reason

-- ============================================================================
-- Firing Unit Readiness
-- ============================================================================

---Check if firing unit is ready to move to firing point
---A firing unit is ready when it's in HIDE state and has sufficient ammunition
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state and ammo info
---@param group CMO__Unit The actual unit group
---@return boolean # Returns true if unit is in HIDE state and not low on ammo
local function isFiringUnitReady(firingUnitCtx, group)
  return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE and
      not MissileSystem.isLowAmmo(group, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
end

---Check if firing unit is at firing point
---Returns true when unit state is STATIC (firing position)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state info
---@return boolean # Returns true if unit is at STATIC (firing point) state
local function isFiringUnitAtFiringPoint(firingUnitCtx)
  return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.STATIC
end

-- ============================================================================
-- Firing Unit Deployment
-- ============================================================================

---Get firing unit context from save data by missile system type and unit name
---@param saveData SBJ__SaveData Saved game state
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM")
---@param firingUnitName string The name of the firing unit
---@return SBJ__FiringUnitContext # Firing unit context
local function getFiringUnitContext(saveData, missileSystem, firingUnitName)
  local key = string.lower(missileSystem)
  return saveData.c.ground[key].firingUnits[firingUnitName]
end

---Deploy single firing unit to firing point and check if it is in position
---@param saveData SBJ__SaveData Saved game state
---@param task SBJ__FireSupportTask Fire Support Task containing missile system info
---@param firingUnit SBJ__FiringUnit Firing unit to deploy
---@return boolean # Returns true if unit is at firing point
local function deploySingleFiringUnit(saveData, task, firingUnit)
  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnit.name)
  if not actualUnit then
    return false
  end

  local firingUnitCtx = getFiringUnitContext(saveData, task.missileSystem, firingUnit.name)

  if isFiringUnitReady(firingUnitCtx, actualUnit) then
    MissileSystem.moveFromHideArea(firingUnitCtx, actualUnit)
    MissileSystem.moveToFiringPoint(firingUnitCtx, actualUnit)
  end

  return isFiringUnitAtFiringPoint(firingUnitCtx)
end

---Deploy all firing units in a task and check if all are in position
---@param saveData SBJ__SaveData Saved game state
---@param task SBJ__FireSupportTask Fire Support Task containing firing units
---@return boolean allInPosition Whether all firing units are at firing point
---@return string[] notReadyNames Unit names not yet at firing point
local function deployTaskFiringUnits(saveData, task)
  local allInPosition = true
  local notReadyNames = {}

  for _, firingUnit in ipairs(task.firingUnits) do
    if not deploySingleFiringUnit(saveData, task, firingUnit) then
      allInPosition = false
      table.insert(notReadyNames, firingUnit.name or "unknown")
    end
  end

  return allInPosition, notReadyNames
end

-- ============================================================================
-- Strike Execution
-- ============================================================================

---Execute all Fire Support Tasks within a FSEM
---Launches attacks when start time reached and minimum target count met, marks tasks as finished
---@param saveData SBJ__SaveData Saved game state
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix containing tasks to execute
---@return {taskName: string, fired: integer}[] # Strike result records per task
local function executeFireSupportTasks(saveData, matrix)
  local strikeResults = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local fired = AttackManager.attackContacts({
        contacts = task.target.list,
        qty = task.target.ammoPerTarget,
        firingUnits = task.firingUnits,
      })

      if fired > 0 then
        if task.missileSystem ~= "SAM" then
          for _, firingUnit in ipairs(task.firingUnits) do
            local firingUnitContext = getFiringUnitContext(saveData, task.missileSystem, firingUnit.name)

            if firingUnitContext and not firingUnitContext.stowStartTime then
              firingUnitContext.stowStartTime = GameApi.ScenEdit_CurrentTime()
            end
          end
        end

        task.isFinished = true
        table.insert(strikeResults, {
          taskName = task.name,
          fired = fired
        })
      end
    end
  end

  return strikeResults
end

-- ============================================================================
-- Matrix Lifecycle
-- ============================================================================

---Check if all Fire Support Tasks in a FSEM are finished
---Returns true only when all FSTs have completed their strikes
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix to check
---@return boolean # Returns true if all FSTs are finished, false otherwise
local function isMatrixFinished(matrix)
  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished then
      return false
    end
  end

  return true
end

---Process active matrix deployment phase
---Deploys firing units to firing points and tracks position status
---@param saveData SBJ__SaveData Saved game state
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix to process
---@return boolean allInPosition Whether all firing units across all tasks are in position
---@return {taskName: string, notReadyNames: string[]}[] pendingTasks Tasks with not-ready unit names
local function processActiveMatrix(saveData, matrix)
  local allInPosition = true
  local pendingTasks = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local taskReady, notReadyNames = deployTaskFiringUnits(saveData, task)
      if not taskReady then
        allInPosition = false
        table.insert(pendingTasks, {
          taskName = task.name,
          notReadyNames = notReadyNames
        })
      end
    end
  end

  matrix.allFiringUnitsInPosition = allInPosition
  return allInPosition, pendingTasks
end

-- ============================================================================
-- Log Formatting
-- ============================================================================

---Format one processed matrix result into a log line
---@param result SBJ__FireSupportPlanProcessedResult Processed matrix result
---@return string level Log entry level
---@return string message Log-safe matrix result message
local function formatProcessedResultLine(result)
  if result.outcome == PLAN_OUTCOME.STRIKE then
    return "OK", string.format(
      "matrix=%s action=strike task=%s fired=%d",
      LogFormat.value(result.matrixName),
      LogFormat.value(result.taskName),
      result.fired or 0
    )
  end

  if result.outcome == PLAN_OUTCOME.PENDING then
    return "SKIP", string.format(
      "matrix=%s task=%s reason=firing_units_not_in_position units=%q",
      LogFormat.value(result.matrixName),
      LogFormat.value(result.taskName),
      table.concat(result.notReadyNames or {}, "; ")
    )
  end

  if result.outcome == PLAN_OUTCOME.FINISHED then
    return "OK", string.format(
      "matrix=%s state=finished",
      LogFormat.value(result.matrixName)
    )
  end

  return "FAIL", string.format(
    "matrix=%s reason=%s",
    LogFormat.value(result.matrixName),
    LogFormat.value(result.reason or "unknown")
  )
end

---Emit consolidated logs for processed fire support plan results
---@param processedResults SBJ__FireSupportPlanProcessedResult[] Processed matrix results accumulated in one tick
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
    Logger.log(constants.TAGS.GROUND, LogFormat.summary(
      "scope",
      "fireSupportPlan",
      "Execute fire support plan",
      infoLines
    ))
  end

  if #errorLines > 0 then
    Logger.error(LogFormat.summary("scope", "fireSupportPlan", "Execute fire support plan", errorLines))
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Execute Fire Support Plan strikes for all active FSEMs
---Deploys firing units to firing points, executes strikes when ready, marks FSEMs as finished
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function FireSupportPlan.strike(saveData)
  local processedResults = {}

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      local allInPosition, pendingTasks = processActiveMatrix(saveData, matrix)

      local strikeResults = {}
      if allInPosition then
        strikeResults = executeFireSupportTasks(saveData, matrix)
      end

      if isMatrixFinished(matrix) then
        matrix.isFinished = true
      end

      if #strikeResults > 0 then
        for _, strikeResult in ipairs(strikeResults) do
          table.insert(processedResults, {
            matrixName = matrix.name,
            taskName = strikeResult.taskName,
            fired = strikeResult.fired,
            outcome = PLAN_OUTCOME.STRIKE
          })
        end
      elseif #pendingTasks > 0 then
        for _, pendingTask in ipairs(pendingTasks) do
          table.insert(processedResults, {
            matrixName = matrix.name,
            taskName = pendingTask.taskName,
            notReadyNames = pendingTask.notReadyNames,
            outcome = PLAN_OUTCOME.PENDING
          })
        end
      end

      if matrix.isFinished then
        table.insert(processedResults, {
          matrixName = matrix.name,
          outcome = PLAN_OUTCOME.FINISHED
        })
      end
    end
  end

  emitProcessedResultsLog(processedResults)
end

return FireSupportPlan
