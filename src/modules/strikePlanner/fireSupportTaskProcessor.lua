local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local Launcher = require("src.modules.launcher")

local FireSupportTaskProcessor = {}

---@param config SBJ__CONFIG
---@param bettery SBJ__Battery
---@param group CMO__Unit
---@return boolean
local function isBtyReady(config, bettery, group)
  return bettery.state == config.batteryState.HIDE and
      not Launcher.isLowAmmo(group, bettery.ammoThreshold, bettery.weaponDBID)
end

---@param config SBJ__CONFIG
---@param bettery SBJ__Battery
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
---@param task SBJ__Task
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return string[]
local function findTargets(task, config, saveData, contacts, isFirstWave)
  local evaluatedTargetlist = TargetingProcess.assessTargetsDamage(task, isFirstWave)

  -- Find dynamic targets (based on filters)
  if type(task.target.filterNames) == "table" and #task.target.filterNames > 0 then
    for _, name in ipairs(task.target.filterNames) do
      if TargetingProcess[name] then
        local filteredTargets = TargetingProcess[name]({
          config = config,
          saveData = saveData,
          contacts = contacts,
          task = task -- Pass packageData as 'task' for compatibility
        })
        Utils.insertList(evaluatedTargetlist, filteredTargets)
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
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return boolean
function FireSupportTaskProcessor.process(FST, config, saveData, contacts, isFirstWave)
  if FST.isFinished or not GameUtils.isAfterStartTime(FST.startTime) then
    return false
  end

  local evaluatedTargetlist = findTargets(FST, config, saveData, contacts, isFirstWave)
  Logger.log(FST.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < FST.target.minTargetCount then
    Logger.log("Not enough targets found for " .. FST.name .. ". Need " .. FST.target.minTargetCount)
    return false
  end

  if not shouldDeployToFiringPosition(config, saveData, FST) then
    Logger.log("Batteries not at firing position for " .. FST.name)
    return false
  end

  FST.target.evaluatedlist = evaluatedTargetlist
  return true
end

return FireSupportTaskProcessor
