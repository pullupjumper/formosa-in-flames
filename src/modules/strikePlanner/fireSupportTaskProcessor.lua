local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")

local FireSupportTaskProcessor = {}

---@param CONFIG SBJ__CONFIG
---@param bettery SBJ__Battery
---@param group CMO__Unit
---@return boolean
function FireSupportTaskProcessor._isBtyReady(CONFIG, bettery, group)
  return bettery.state == CONFIG.batteryState.HIDE and not IsLowAmmo(group, bettery.ammoThreshold, bettery.weaponDBID)
end

---@param CONFIG SBJ__CONFIG
---@param bettery SBJ__Battery
---@return boolean
function FireSupportTaskProcessor._isNotBtyAtFiringPosition(CONFIG, bettery)
  return bettery.state ~= CONFIG.batteryState.STATIC
end

---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param FST SBJ__FireSupportTask
---@return boolean
function FireSupportTaskProcessor._shouldDeployToFiringPosition(CONFIG, saveData, FST)
  local allBatteriesInPosition = true

  for _, bty in ipairs(FST.batteries) do
    local actualBty = GameApi.ScenEdit_GetUnit(bty.guid)

    if not actualBty then
      allBatteriesInPosition = false
    else
      local bettery = saveData.c.ground[string.lower(FST.wpnSystem)].batteries[bty.guid]

      if FireSupportTaskProcessor._isBtyReady(CONFIG, bettery, actualBty) then
        ToFringPosition(bettery, actualBty)
      end

      if FireSupportTaskProcessor._isNotBtyAtFiringPosition(CONFIG, bettery) then
        allBatteriesInPosition = false
      end
    end
  end

  return allBatteriesInPosition
end

---comment
---@param task SBJ__Task
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return string[]
function FireSupportTaskProcessor._findTargets(task, CONFIG, saveData, contacts, isFirstWave)
  local evaluatedTargetlist = TargetingProcess.AssessTargetsDamage(task, isFirstWave)

  -- Find dynamic targets (based on filters)
  if type(task.target.filterNames) == "table" and #task.target.filterNames > 0 then
    for _, name in ipairs(task.target.filterNames) do
      if TargetingProcess[name] then
        local filteredTargets = TargetingProcess[name]({
          CONFIG = CONFIG,
          saveData = saveData,
          contacts = contacts,
          task = task -- Pass packageData as 'task' for compatibility
        })
        Utils.InsertList(evaluatedTargetlist, filteredTargets)
        Logger.log(name .. " found " .. #filteredTargets .. " targets.")
      else
        Logger.error("TargetingProcess filter not found: " .. name)
      end
    end
  end

  return evaluatedTargetlist
end

---comment
---@param FST SBJ__FireSupportTask
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return boolean
function FireSupportTaskProcessor.Process(FST, CONFIG, saveData, contacts, isFirstWave)
  if FST.isFinished or not GameUtils.IsAfterStartTime(FST.startTime) then
    return false
  end

  local evaluatedTargetlist = FireSupportTaskProcessor._findTargets(FST, CONFIG, saveData, contacts, isFirstWave)
  Logger.log(FST.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < FST.target.minTargetCount then
    Logger.log("Not enough targets found for " .. FST.name .. ". Need " .. FST.target.minTargetCount)
    return false
  end

  if not FireSupportTaskProcessor._shouldDeployToFiringPosition(CONFIG, saveData, FST) then
    Logger.log("Batteries not at firing position for " .. FST.name)
    return false
  end

  FST.target.evaluatedlist = evaluatedTargetlist
  return true
end

return FireSupportTaskProcessor
