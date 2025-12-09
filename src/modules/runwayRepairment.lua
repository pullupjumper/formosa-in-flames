local GameApi = require("src.utils.gameApi")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local constants = require("src.core.constants")

local RunwayRepairment = {}

---Initialize runway repair targets for both Taiwan and China
---Scans contacts and units to populate runway lists for repair tracking
---@param config SBJ__Config Global configuration with runway DBIDs and air base lists
---@param saveData SBJ__SaveData Persistent save data
function RunwayRepairment.initRunways(config, saveData)
  -- Initialize Taiwan runways from targetlist
  local taiwanAirBases = {}
  for _, baseName in ipairs(config.repairRunway.airBases) do
    table.insert(taiwanAirBases, { baseName = baseName, subTypes = config.repairRunway.runwaySubTypes })
  end

  local targetlist = TargetingProcess.filterTargetsByTypeAndBase(saveData.c.targetlist, taiwanAirBases)

  for _, guid in ipairs(targetlist) do
    local contact = GameApi.ScenEdit_GetContact('China', guid)
    if contact then
      table.insert(saveData.t.repairRunway.runways, { guid = contact.actualunitid, startTime = nil })
    end
  end

  -- Initialize China runways from facility units
  local facilities = GameApi.VP_GetSide({ side = 'China' }):unitsBy(constants.UNIT_TYPES.FACILITY)

  if not facilities then
    return
  end

  for _, u in ipairs(facilities) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit then
      -- Check if unit DBID matches any runway DBID in config
      for _, runwayDBID in ipairs(config.repairRunway.runwayDBIDs) do
        if actualUnit.dbid == runwayDBID then
          table.insert(saveData.c.repairRunway.runways, { guid = actualUnit.guid, startTime = nil })
          break
        end
      end
    end
  end
end

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

---Execute scheduled runway repair operations reducing damage incrementally
---@param config SBJ__Config Configuration containing repair rate settings
---@param runways SBJ__RunwayEntry[] Array of runways to repair
function RunwayRepairment.repairRunway(config, runways)
  for _, runway in ipairs(runways) do
    local actualRunway = GameApi.ScenEdit_GetUnit(runway.guid)

    if actualRunway and runway.startTime ~= nil then
      GameApi.ScenEdit_SetUnitDamage({
        guid = actualRunway.guid,
        dp = -actualRunway.damage.startdp * config.repairRunway.percentagePerHour / 12 / 100,
        fires = 'NoFire'
      })
    end
  end
end

return RunwayRepairment
