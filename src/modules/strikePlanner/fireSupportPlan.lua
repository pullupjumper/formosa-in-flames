local AttackManager = require("src.modules.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem")
local constants = require("src.core.constants")

local FireSupportPlan = {}
local LOG_TAG = "ground"

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
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix containing tasks to execute
---@return string[] # Strike result descriptions per task
local function executeFireSupportTasks(matrix)
  local strikeResults = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime)
        and #task.target.list >= task.target.minTargetCount then
      local result = AttackManager.attackContacts({
        contacts = task.target.list,
        qty = task.target.ammoPerTarget,
        firingUnits = task.firingUnits,
      })

      if result > 0 then
        task.isFinished = true
        table.insert(strikeResults, string.format("%s: fired %d", task.name, result))
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
---@return string[] pendingTasks Task descriptions with not-ready unit names
local function processActiveMatrix(saveData, matrix)
  local allInPosition = true
  local pendingTasks = {}

  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) then
      local taskReady, notReadyNames = deployTaskFiringUnits(saveData, task)
      if not taskReady then
        allInPosition = false
        table.insert(pendingTasks, string.format("%s (%s)", task.name, table.concat(notReadyNames, ", ")))
      end
    end
  end

  matrix.allFiringUnitsInPosition = allInPosition
  return allInPosition, pendingTasks
end

-- ============================================================================
-- Log Formatting
-- ============================================================================

---Format pending task names into summary string
---@param pendingTasks string[] Task descriptions with not-ready unit names
---@return string # Formatted summary or "none"
local function formatPendingTasks(pendingTasks)
  if #pendingTasks == 0 then
    return "none"
  end
  return table.concat(pendingTasks, "; ")
end

---Format strike results into summary string
---@param strikeResults string[] Strike result descriptions per task
---@return string # Formatted summary or "none"
local function formatStrikeResults(strikeResults)
  if #strikeResults == 0 then
    return "none"
  end
  return table.concat(strikeResults, "; ")
end

-- ============================================================================
-- Public API
-- ============================================================================

---Execute Fire Support Plan strikes for all active FSEMs
---Deploys firing units to firing points, executes strikes when ready, marks FSEMs as finished
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function FireSupportPlan.strike(saveData)
  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated then
      local allInPosition, pendingTasks = processActiveMatrix(saveData, matrix)

      local strikeResults = {}
      if allInPosition then
        strikeResults = executeFireSupportTasks(matrix)
      end

      if isMatrixFinished(matrix) then
        matrix.isFinished = true
      end

      -- Centralized logging
      if #strikeResults > 0 then
        Logger.log(LOG_TAG, string.format("Matrix %s strikes executed: %s",
          matrix.name, formatStrikeResults(strikeResults)))
      elseif #pendingTasks > 0 then
        Logger.log(LOG_TAG, string.format("Matrix %s batteries not at firing position: %s",
          matrix.name, formatPendingTasks(pendingTasks)))
      end

      if matrix.isFinished then
        Logger.log(LOG_TAG, string.format("Matrix %s all tasks completed", matrix.name))
      end
    end
  end
end

return FireSupportPlan
