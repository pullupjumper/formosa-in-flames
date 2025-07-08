local GameApi = require("src.utils.gameApi")

local RunwayRepairment = {}

---comment
---@param saveData SBJ__SaveData
---@param side string
---@param unit CMO__Unit
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

---comment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param side string
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
