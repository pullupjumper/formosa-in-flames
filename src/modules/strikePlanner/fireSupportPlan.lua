local AttackManager = require("src.modules.strikePlanner.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")

local FireSupportPlan = {}

---@param config SBJ__CONFIG
---@param bettery SBJ__BatteryContext
---@param group CMO__Unit
---@return boolean
local function isBtyReady(config, bettery, group)
  return bettery.state == config.batteryState.HIDE and
      not Launcher.isLowAmmo(group, bettery.ammoThreshold, bettery.weaponDBID)
end

---@param config SBJ__CONFIG
---@param bettery SBJ__BatteryContext
---@return boolean
local function isNotBtyAtFiringPosition(config, bettery)
  return bettery.state ~= config.batteryState.STATIC
end

---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param FST SBJ__FireSupportTask
---@return boolean
local function shouldDeployToFiringPosition(config, saveData, FST)
  local allBatteriesInPosition = true

  for _, bty in ipairs(FST.batteries) do
    local actualBty = GameApi.ScenEdit_GetUnit(bty.guid)

    if not actualBty then
      allBatteriesInPosition = false
    else
      local bettery = saveData.c.ground[string.lower(FST.wpnSystem)].batteries[bty.guid]

      if isBtyReady(config, bettery, actualBty) then
        Launcher.toFringPosition(config, bettery, actualBty)
      end

      if isNotBtyAtFiringPosition(config, bettery) then
        allBatteriesInPosition = false
      end
    end
  end

  return allBatteriesInPosition
end

---comment
---@param FST SBJ__FireSupportTask
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@return boolean
local function processFST(FST, config, saveData)
  if FST.isFinished or not GameUtils.isAfterStartTime(FST.startTime) then
    return false
  end

  if not shouldDeployToFiringPosition(config, saveData, FST) then
    Logger.log("Batteries not at firing position for " .. FST.name)
    return false
  end

  return true
end

---@param FSEM SBJ__FireSupportExecutionMatrix
---@return boolean
local function isFSEMFinished(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished then
      return false
    end
  end

  return true
end

---comment
---@param FSEM SBJ__FireSupportExecutionMatrix
local function executeFireSupportTasks(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished and GameUtils.isAfterStartTime(FST.startTime) and #FST.target.list >= FST.target.minTargetCount then
      local result = AttackManager.attackContacts({
        contacts = FST.target.list,
        qty = FST.target.ammoPerTarget,
        batteries = FST.batteries,
      })

      if result > 0 then
        FST.isFinished = true
        Logger.log('Fired ' .. result .. ' missiles for ' .. FST.name)
      end
    end
  end
end

---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
function FireSupportPlan.strike(config, saveData)
  for _, FSEM in pairs(saveData.c.ground.FSP) do
    local allBatteriesInPosition = true

    if not FSEM.isFinished and FSEM.isActivated then
      for _, FST in ipairs(FSEM.FSTs) do
        local isInFiringPosition = processFST(FST, config, saveData)

        if not isInFiringPosition then
          allBatteriesInPosition = false
        end
      end
    end

    FSEM.allBatteriesInPosition = allBatteriesInPosition
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.allBatteriesInPosition then
      executeFireSupportTasks(FSEM)
    end

    if isFSEMFinished(FSEM) then
      FSEM.isFinished = true
    end
  end
end

return FireSupportPlan
