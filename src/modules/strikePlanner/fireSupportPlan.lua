local FireSupportTaskProcessor = require("src.modules.strikePlanner.fireSupportTaskProcessor")
local AttackManager = require("src.modules.strikePlanner.attackManager")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local CONFIG = require("src.core.constants")

local FireSupportPlan = {}

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
    if not FST.isFinished and GameUtils.isAfterStartTime(FST.startTime) and #FST.target.evaluatedlist >= FST.target.minTargetCount then
      local result = AttackManager.attackContacts({
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
function FireSupportPlan.strike(CONFIG, saveData, contacts)
  for _, FSEM in pairs(saveData.c.ground.FSP) do
    local allBatteriesInPosition = true

    if not FSEM.isFinished and FSEM.isActivated then
      for _, FST in ipairs(FSEM.FSTs) do
        local isInFiringPosition = FireSupportTaskProcessor.process(
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
      executeFireSupportTasks(FSEM)
    end

    if isFSEMFinished(FSEM) then
      FSEM.isFinished = true
    end
  end
end

return FireSupportPlan
