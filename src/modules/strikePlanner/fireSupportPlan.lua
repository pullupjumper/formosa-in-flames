local AttackManager = require("src.modules.strikePlanner.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")

local FireSupportPlan = {}

--- Check if firing unit is ready to move to firing point
--- A firing unit is ready when it's in HIDE state and has sufficient ammunition
---@param config SBJ__CONFIG Global configuration
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state and ammo info
---@param group CMO__Unit The actual unit group
---@return boolean Returns true if unit is in HIDE state and not low on ammo
local function isFiringUnitReady(config, firingUnitCtx, group)
  return firingUnitCtx.state == config.batteryState.HIDE and
      not Launcher.isLowAmmo(group, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)
end

--- Check if firing unit is not yet at firing point
--- Returns true when unit state is not STATIC (firing position)
---@param config SBJ__CONFIG Global configuration
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context with state info
---@return boolean Returns true if unit is not at STATIC (firing point) state
local function isNotFiringUnitAtFiringPoint(config, firingUnitCtx)
  return firingUnitCtx.state ~= config.batteryState.STATIC
end

--- Deploy firing units to firing point and check if all are in position
--- Iterates through all firing units in the FST, moves ready units to firing points,
--- and verifies if all units have reached their firing positions
---@param config SBJ__CONFIG Global configuration
---@param saveData SBJ__SaveData Saved game state
---@param FST SBJ__FireSupportTask Fire Support Task containing firing units
---@return boolean Returns true if all firing units are at firing point, false otherwise
local function shouldDeployToFiringPoint(config, saveData, FST)
  local allFiringUnitsInPosition = true

  for _, firingUnit in ipairs(FST.firingUnits) do
    local actualFiringUnit = GameApi.ScenEdit_GetUnit(firingUnit.guid)

    if not actualFiringUnit then
      allFiringUnitsInPosition = false
    else
      local firingUnitCtx = saveData.c.ground[string.lower(FST.wpnSystem)].firingUnits[firingUnit.guid]

      if isFiringUnitReady(config, firingUnitCtx, actualFiringUnit) then
        Launcher.moveToFiringPoint(config, firingUnitCtx, actualFiringUnit)
      end

      if isNotFiringUnitAtFiringPoint(config, firingUnitCtx) then
        allFiringUnitsInPosition = false
      end
    end
  end

  return allFiringUnitsInPosition
end

--- Process a Fire Support Task and check if all firing units are in position
--- Checks if the task start time has been reached and deploys firing units to their firing points
---@param FST SBJ__FireSupportTask Fire Support Task to process
---@param config SBJ__CONFIG Global configuration
---@param saveData SBJ__SaveData Saved game state
---@return boolean Returns true if all firing units are in position, false otherwise
local function processFST(FST, config, saveData)
  if FST.isFinished or not GameUtils.isAfterStartTime(FST.startTime) then
    return false
  end

  if not shouldDeployToFiringPoint(config, saveData, FST) then
    Logger.log("ground", "Batteries not at firing position for " .. FST.name)
    return false
  end

  return true
end

--- Check if all Fire Support Tasks in a FSEM are finished
--- Returns true only when all FSTs have completed their strikes
---@param FSEM SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix to check
---@return boolean Returns true if all FSTs are finished, false otherwise
local function isFSEMFinished(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished then
      return false
    end
  end

  return true
end

--- Execute all Fire Support Tasks within a FSEM
--- Launches attacks on targets when start time is reached and minimum target count is met
--- Marks tasks as finished after successful weapon launches
---@param FSEM SBJ__FireSupportExecutionMatrix Fire Support Execution Matrix containing tasks to execute
local function executeFireSupportTasks(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished and GameUtils.isAfterStartTime(FST.startTime) and #FST.target.list >= FST.target.minTargetCount then
      local result = AttackManager.attackContacts({
        contacts = FST.target.list,
        qty = FST.target.ammoPerTarget,
        firingUnits = FST.firingUnits,
      })

      if result > 0 then
        FST.isFinished = true
        Logger.log("ground", 'Fired ' .. result .. ' missiles for ' .. FST.name)
      end
    end
  end
end

--- Execute Fire Support Plan strikes for all active FSEMs
--- Main entry point for fire support operations coordination
--- Processes each FSEM in two phases:
--- 1. Deploy firing units to their firing points
--- 2. Execute strikes when all units are in position
--- Marks FSEMs as finished when all their tasks are complete
---@param config SBJ__CONFIG Global configuration
---@param saveData SBJ__SaveData Saved game state containing FSEMs
function FireSupportPlan.strike(config, saveData)
  for _, FSEM in pairs(saveData.c.ground.FSP) do
    local allFiringUnitsInPosition = true

    if not FSEM.isFinished and FSEM.isActivated then
      for _, FST in ipairs(FSEM.FSTs) do
        local isInFiringPosition = processFST(FST, config, saveData)

        if not isInFiringPosition then
          allFiringUnitsInPosition = false
        end
      end
    end

    FSEM.allFiringUnitsInPosition = allFiringUnitsInPosition
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.allFiringUnitsInPosition then
      executeFireSupportTasks(FSEM)
    end

    if isFSEMFinished(FSEM) then
      FSEM.isFinished = true
    end
  end
end

return FireSupportPlan
