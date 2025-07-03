local FireSupportTaskProcessor = require("src.modules.strikePlanner.fireSupportTaskProcessor")
local AttackManager = require("src.modules.strikePlanner.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")

local FireSupportPlan = {}

---@param FSEM SBJ__FireSupportExecutionMatrix
---@return boolean
function FireSupportPlan._isFSEMFinished(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished then
      return false
    end
  end

  return true
end

---comment
---@param FSEM SBJ__FireSupportExecutionMatrix
function FireSupportPlan._executeFireSupportTasks(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished and GameUtils.IsAfterStartTime(FST.startTime) and #FST.target.evaluatedlist >= FST.target.minTargetCount then
      local result = AttackManager.AttackContacts({
        contacts = FST.target.evaluatedlist,
        qty = FST.target.ammoPerTarget,
        batteries = FST.batteries,
      })

      if result > 0 then
        FST.isFinished = true

        if CONFIG.isDevMode then
          Logger.log('Fired ' .. result .. ' missiles for ' .. FST.name)
        end
      end
    end
  end
end

---@param CONFIG table
---@param saveData table
---@param contacts CMO__Contact[]
function FireSupportPlan.Strike(CONFIG, saveData, contacts)
  for _, FSEM in pairs(saveData.c.ground.FSP) do
    local allBatteriesInPosition = true

    if not FSEM.isFinished and FSEM.isActivated then
      for _, FST in ipairs(FSEM.FSTs) do
        local isInFiringPosition = FireSupportTaskProcessor.Process(
          FST, CONFIG, saveData, contacts, FSEM.isFirstWave
        )

        if not isInFiringPosition then
          allBatteriesInPosition = false
        end
      end
    end

    FSEM.allBatteriesInPosition = allBatteriesInPosition
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.allBatteriesInPosition then
      FireSupportPlan._executeFireSupportTasks(FSEM)
    end

    if FireSupportPlan._isFSEMFinished(FSEM) then
      FSEM.isFinished = true
    end
  end
end

return FireSupportPlan
