local GameApi = require("src.utils.gameApi")

local RunwayRepairment = {}

---Handle runway damage events and record repair start time
---@param saveData SBJ__SaveData Persistent save data
---@param side string Faction name ("China" or other faction)
---@param unit CMO__Unit The damaged runway unit
function RunwayRepairment.whenRunwayIsDamaged(saveData, side, unit)
  local field = (side == 'China') and 'c' or 't'

  if not saveData[field].repairRunway.isActivated then
    saveData[field].repairRunway.isActivated = true
  end

  for _, runway in ipairs(saveData[field].repairRunway.runways) do
    if unit and unit.guid == runway.guid and runway.startTime == nil then
      runway.startTime = GameApi.ScenEdit_CurrentTime()
    end
  end
end

---Execute scheduled runway repair operations (called every 5 minutes)
---Reduces damage by (startDP * percentagePerHour / 12 / 100) per interval
---@param config SBJ__CONFIG Configuration containing repair rate settings
---@param saveData SBJ__SaveData Persistent save data
---@param side string Faction name ("China" or other faction)
function RunwayRepairment.repairRunway(config, saveData, side)
  local field = (side == 'China') and 'c' or 't'

  for _, runway in ipairs(saveData[field].repairRunway.runways) do
    local actualRunway = GameApi.ScenEdit_GetUnit(runway.guid)

    if actualRunway and runway.startTime ~= nil then
      GameApi.ScenEdit_SetUnitDamage({
        guid = actualRunway.guid,
        dp = -actualRunway.damage.startdp * config[field].repairRunway.percentagePerHour / 12 / 100,
        fires = 'NoFire'
      })
    end
  end
end

return RunwayRepairment
