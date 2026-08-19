local AttackManager = require("src.modules.attackManager")
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")

local FireSupportPlan = {}

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
---@return boolean inPosition Whether the unit is at firing point
---@return boolean unitMissing Whether the actual unit no longer exists in game
local function deploySingleFiringUnit(saveData, task, firingUnit)
  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnit.name)
  if not actualUnit then
    return false, true
  end

  local firingUnitCtx = getFiringUnitContext(saveData, task.missileSystem, firingUnit.name)

  if isFiringUnitReady(firingUnitCtx, actualUnit) then
    MissileSystem.moveFromHideArea(firingUnitCtx, actualUnit)
    MissileSystem.moveToFiringPoint(firingUnitCtx, actualUnit)
  end

  return isFiringUnitAtFiringPoint(firingUnitCtx), false
end

---Deploy all firing units in a task and check if all are in position
---Destroyed units are removed from the task; a task emptied this way is closed
---so it never blocks the rest of the matrix waiting for a unit that cannot arrive.
---@param saveData SBJ__SaveData Saved game state
---@param task SBJ__FireSupportTask Fire Support Task containing firing units
---@return boolean allInPosition Whether all surviving firing units are at firing point
---@return string[] notReadyNames Unit names not yet at firing point
---@return string[] removedNames Destroyed unit names removed from the task
local function deployTaskFiringUnits(saveData, task)
  local allInPosition = true
  local notReadyNames = {}
  local removedNames = {}

  -- Reverse iteration so table.remove never skips the next entry; names are
  -- inserted at the head to preserve the original firing unit order in logs.
  for i = #task.firingUnits, 1, -1 do
    local firingUnit = task.firingUnits[i]
    local inPosition, unitMissing = deploySingleFiringUnit(saveData, task, firingUnit)

    if unitMissing then
      table.remove(task.firingUnits, i)
      table.insert(removedNames, 1, firingUnit.name or "unknown")
    elseif not inPosition then
      allInPosition = false
      table.insert(notReadyNames, 1, firingUnit.name or "unknown")
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
---Deploys firing units to firing points, tracks position status,
---and aggregates destroyed units removed from tasks for logging
---@param saveData SBJ__SaveData Saved game state
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix to process
---@return boolean allInPosition Whether all firing units across all tasks are in position
---@return {taskName: string, notReadyNames: string[]}[] pendingTasks Tasks with not-ready unit names
---@return {taskName: string, removedNames: string[], taskClosed: boolean}[] cleanedTasks Tasks that lost destroyed units
local function processActiveMatrix(saveData, matrix)
  local allInPosition = true
  local pendingTasks = {}
  local cleanedTasks = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local taskReady, notReadyNames, removedNames = deployTaskFiringUnits(saveData, task)

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
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function FireSupportPlan.strike(saveData)
  local report = LogFormat.report(constants.TAGS.GROUND, "fireSupportPlan", "Execute fire support plan")

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      local allInPosition, pendingTasks, cleanedTasks = processActiveMatrix(saveData, matrix)

      local strikeResults = {}
      if allInPosition then
        strikeResults = executeFireSupportTasks(saveData, matrix)
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
