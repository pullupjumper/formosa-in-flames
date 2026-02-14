local AttackManager = require("src.modules.strikePlanner.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem")
local constants = require("src.core.constants")

local FireSupportPlan = {}

---Check if firing unit is ready to move to firing point
---A firing unit is ready when it's in HIDE state and has sufficient ammunition
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state and ammo info
---@param group CMO__Unit The actual unit group
---@return boolean # Returns true if unit is in HIDE state and not low on ammo
local function isFiringUnitReady(firingUnitCtx, group)
  return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE and
      not MissileSystem.isLowAmmo(group, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
end

---Check if firing unit is not yet at firing point
---Returns true when unit state is not STATIC (firing position)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state info
---@return boolean # Returns true if unit is not at STATIC (firing point) state
local function isNotFiringUnitAtFiringPoint(firingUnitCtx)
  return firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC
end

---Deploy firing units to firing point and check if all are in position
---Moves ready units to firing points and verifies if all units have reached their positions
---@param saveData SBJ__SaveData Saved game state
---@param task SBJ__FireSupportTask Fire Support Task containing firing units
---@return boolean # Returns true if all firing units are at firing point, false otherwise
local function shouldDeployToFiringPoint(saveData, task)
  local allFiringUnitsInPosition = true

  for _, firingUnit in ipairs(task.firingUnits) do
    local actualFiringUnit = GameApi.ScenEdit_GetUnit(firingUnit.name)

    if not actualFiringUnit then
      allFiringUnitsInPosition = false
    else
      local firingUnitCtx = saveData.c.ground[string.lower(task.missileSystem)].firingUnits[firingUnit.name]

      if isFiringUnitReady(firingUnitCtx, actualFiringUnit) then
        MissileSystem.moveToFiringPoint(firingUnitCtx, actualFiringUnit)
      end

      if isNotFiringUnitAtFiringPoint(firingUnitCtx) then
        allFiringUnitsInPosition = false
      end
    end
  end

  return allFiringUnitsInPosition
end

---Process a Fire Support Task and check if all firing units are in position
---Checks if the task start time has been reached and deploys firing units to their firing points
---@param task SBJ__FireSupportTask Fire Support Task to process
---@param saveData SBJ__SaveData Saved game state
---@return boolean # Returns true if all firing units are in position, false otherwise
local function processFireSupportTask(task, saveData)
  if task.isFinished or not GameUtils.isAfterStartTime(task.startTime) then
    return false
  end

  if not shouldDeployToFiringPoint(saveData, task) then
    Logger.log("ground", "Batteries not at firing position for " .. task.name)
    return false
  end

  return true
end

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

---Execute all Fire Support Tasks within a FSEM
---Launches attacks when start time reached and minimum target count met, marks tasks as finished
---@param matrix SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix containing tasks to execute
local function executeFireSupportTasks(matrix)
  for _, task in ipairs(matrix.fireSupportTasks) do
    if not task.isFinished and GameUtils.isAfterStartTime(task.startTime) and #task.target.list >= task.target.minTargetCount then
      local result = AttackManager.attackContacts({
        contacts = task.target.list,
        qty = task.target.ammoPerTarget,
        firingUnits = task.firingUnits,
      })

      if result > 0 then
        task.isFinished = true
        Logger.log("ground", "Fired " .. result .. " missiles for " .. task.name)
      end
    end
  end
end

---Execute Fire Support Plan strikes for all active FSEMs
---Deploys firing units to firing points, executes strikes when ready, marks FSEMs as finished
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function FireSupportPlan.strike(saveData)
  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    local allFiringUnitsInPosition = true

    if not matrix.isFinished and matrix.isActivated then
      for _, task in ipairs(matrix.fireSupportTasks) do
        local isInFiringPosition = processFireSupportTask(task, saveData)

        if not isInFiringPosition then
          allFiringUnitsInPosition = false
        end
      end
    end

    matrix.allFiringUnitsInPosition = allFiringUnitsInPosition
  end

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and matrix.allFiringUnitsInPosition then
      executeFireSupportTasks(matrix)
    end

    if isMatrixFinished(matrix) then
      matrix.isFinished = true
    end
  end
end

return FireSupportPlan
