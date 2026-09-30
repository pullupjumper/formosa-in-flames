local GameApi = require("src.utils.gameApi")
local PersistentState = require("src.core.persistentState")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local RunwayRepairment = {}

---Initialize runway repair targets for both Taiwan and China
---Scans contacts and units to populate runway lists for repair tracking
---Taiwan runways are found in China's fixed-target list, so that list must be built first.
---@param config SBJ__Config Global configuration with runway DBIDs and air base lists
---@param saveData SBJ__SaveData Persistent save data; both sides' runway repair lists are filled
function RunwayRepairment.init(config, saveData)
  local taiwanRunways = PersistentState.runwayRepair(saveData, constants.SIDES.PLAYER).runways
  local chinaRunways = PersistentState.runwayRepair(saveData, constants.SIDES.ENEMY).runways

  -- Initialize Taiwan runways from targetlist
  local taiwanAirBases = {}
  for _, baseName in ipairs(config.t.repairRunway.airBases) do
    table.insert(taiwanAirBases, { baseName = baseName, subTypes = config.t.repairRunway.runwaySubTypes })
  end

  local runwayGUIDs = StrikePlanner.filterTargetsByTypeAndBase(PersistentState.targetlist(saveData), taiwanAirBases)

  for _, guid in ipairs(runwayGUIDs) do
    local contact = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, guid)
    if contact then
      table.insert(taiwanRunways, { guid = contact.actualunitid, startTime = nil })
    end
  end

  -- Initialize China runways from facility units
  local facilities = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY }):unitsBy(constants.UNIT_TYPES.FACILITY)
  if not facilities then return end

  for _, u in ipairs(facilities) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit then
      -- Check if unit DBID matches any runway DBID in config
      for _, runwayDBID in ipairs(config.c.repairRunway.runwayDBIDs) do
        if actualUnit.dbid == runwayDBID then
          table.insert(chinaRunways, { guid = actualUnit.guid, startTime = nil })
          break
        end
      end
    end
  end
end

---Handle runway damage events and record repair start time
---@param saveData SBJ__SaveData Persistent save data; the damaged runway's side is mutated
---@param unit CMO__Unit The damaged runway unit
function RunwayRepairment.processRunwayDamage(saveData, unit)
  local repairCtx = PersistentState.runwayRepair(saveData, unit.side)
  repairCtx.enabled = true

  for _, runway in ipairs(repairCtx.runways) do
    if unit.guid == runway.guid and runway.startTime == nil then
      runway.startTime = GameApi.ScenEdit_CurrentTime()
    end
  end
end

---Repair a side's damaged runways by one scheduled increment
---@param config SBJ__Config Configuration containing repair rate settings
---@param saveData SBJ__SaveData Persistent save data
---@param sideName string Side name (China or Taiwan)
function RunwayRepairment.repairSide(config, saveData, sideName)
  for _, runway in ipairs(PersistentState.runwayRepair(saveData, sideName).runways) do
    local actualRunway = GameApi.ScenEdit_GetUnit(runway.guid)

    if actualRunway and runway.startTime ~= nil then
      GameApi.ScenEdit_SetUnitDamage({
        guid = actualRunway.guid,
        dp = -actualRunway.damage.startdp * config[GameUtils.getCachedSideConfig(sideName).field].repairRunway.percentagePerHour / 12 / 100,
        fires = "NoFire"
      })
    end
  end
end

return RunwayRepairment
