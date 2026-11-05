local AttackManager = require("src.modules.attackManager")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

local FireSupportPlan = {}

-- ============================================================================
-- Firing Unit Deployment
-- ============================================================================

---Deploy all firing units in a task and check if all are in position
---Destroyed units are removed from the task; a task emptied this way is closed
---so it never blocks the rest of the matrix waiting for a unit that cannot arrive.
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
---@param task SBJ__FireSupportTask
---@return boolean allInPosition Whether all surviving firing units are at firing point
---@return string[] notReadyNames Unit names not yet at firing point
---@return string[] removedNames Destroyed unit names removed from the task
local function deployTaskFiringUnits(config, plannerState, task)
  local allInPosition = true
  local notReadyNames = {}
  local removedNames = {}

  -- Reverse iteration so table.remove never skips the next entry; names are
  -- inserted at the head to preserve the original firing unit order in logs.
  for i = #task.firingUnits, 1, -1 do
    local firingUnit = task.firingUnits[i]
    local inPosition, unitMissing = MissileSystem.sendToFiringPoint(
      config, plannerState.ground, constants.SIDES.RED, task.missileSystemType, firingUnit.name
    )

    if unitMissing then
      table.remove(task.firingUnits, i)
      table.insert(removedNames, 1, firingUnit.name)
    elseif not inPosition then
      allInPosition = false
      table.insert(notReadyNames, 1, firingUnit.name)
    end
  end

  -- An emptied task is closed without counting as not-ready, so sibling tasks
  -- in the same matrix can still reach allFiringUnitsInPosition and fire.
  if #task.firingUnits == 0 then
    task.isFinished = true
  end

  return allInPosition, notReadyNames, removedNames
end

-- ============================================================================
-- Strike Execution
-- ============================================================================

---Execute all Fire Support Tasks within a FSEM
---Launches attacks when start time reached and minimum target count met, marks tasks as finished
---@param plannerState SBJ__StrikePlannerState
---@param matrix SBJ__FireSupportExecutionMatrix
---@return {taskName: string, fired: integer}[] # Strike result records per task
local function startFireSupportTasks(plannerState, matrix)
  local strikeResults = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local fired = AttackManager.attackContacts({
        contacts = task.target.list,
        qty = task.target.ammoPerTarget,
        firingUnits = task.firingUnits,
      })

      if fired > 0 then
        MissileSystem.completeFireTask(plannerState.ground, task.missileSystemType, task.firingUnits)
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
---@param matrix SBJ__FireSupportExecutionMatrix
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
---Deploys firing units to firing points, tracks position status,
---and aggregates destroyed units removed from tasks for logging
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
---@param matrix SBJ__FireSupportExecutionMatrix
---@return boolean allInPosition Whether all firing units across all tasks are in position
---@return {taskName: string, notReadyNames: string[]}[] pendingTasks Tasks with not-ready unit names
---@return {taskName: string, removedNames: string[], taskClosed: boolean}[] cleanedTasks Tasks that lost destroyed units
local function processActiveMatrix(config, plannerState, matrix)
  local allInPosition = true
  local pendingTasks = {}
  local cleanedTasks = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local taskReady, notReadyNames, removedNames = deployTaskFiringUnits(config, plannerState, task)

      if #removedNames > 0 then
        table.insert(cleanedTasks, {
          taskName = task.name,
          removedNames = removedNames,
          -- deployTaskFiringUnits closes a task it emptied, so isFinished here
          -- means every unit of the task was destroyed.
          taskClosed = task.isFinished
        })
      end

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
  return allInPosition, pendingTasks, cleanedTasks
end

-- ============================================================================
-- Public API
-- ============================================================================

---Execute Fire Support Plan strikes for all active FSEMs
---Deploys firing units, removes destroyed ones, executes strikes when ready, marks FSEMs finished
---@param config SBJ__Config
---@param plannerState SBJ__StrikePlannerState
function FireSupportPlan.process(config, plannerState)
  local report = LogFormat.report(constants.TAGS.GROUND, "fireSupportPlan", "Execute fire support plan")

  for _, matrix in pairs(plannerState.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      local allInPosition, pendingTasks, cleanedTasks = processActiveMatrix(config, plannerState, matrix)

      local strikeResults = {}
      if allInPosition then
        strikeResults = startFireSupportTasks(plannerState, matrix)
      end

      if isMatrixFinished(matrix) then
        matrix.isFinished = true
      end

      for _, cleanedTask in ipairs(cleanedTasks) do
        report.add("WARN", {
          matrix = matrix.name,
          task = cleanedTask.taskName,
          action = "dead_unit_cleanup",
          units = table.concat(cleanedTask.removedNames, ","),
          taskClosed = cleanedTask.taskClosed
        })
      end

      if #strikeResults > 0 then
        for _, strikeResult in ipairs(strikeResults) do
          report.add("OK", {
            matrix = matrix.name,
            task = strikeResult.taskName,
            action = "strike",
            fired = strikeResult.fired or 0
          })
        end
      elseif #pendingTasks > 0 then
        for _, pendingTask in ipairs(pendingTasks) do
          report.add("SKIP", {
            matrix = matrix.name,
            task = pendingTask.taskName,
            units = table.concat(pendingTask.notReadyNames or {}, ","),
            reason = "firing_units_not_in_position"
          })
        end
      end

      if matrix.isFinished then
        report.add("OK", { matrix = matrix.name, state = "finished" })
      end
    end
  end

  report.emit()
end

return FireSupportPlan
