local gKH = require("src.core.gKH_State_Standalone")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local StrikePlanner = require("src.modules.strikePlanner.init")
local AttackManager = require("src.modules.attackManager")
local constants = require("src.core.constants")
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.ENEMY)

if not contacts then
  Logger.error("contacts is nil")
  return
end

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

-- Dynamic operations plan - unified handling of reconnaissance scheduling and various strike methods
if saveData.c.dynamicOperations.enabled then
  -- Execute ground fire support operations
  StrikePlanner.executeDynamicFireSupportPlan(config, saveData, contacts)
  -- Execute air combat missions
  StrikePlanner.processDynamicATO(config, saveData, contacts)
end

if saveData.c.recon.enabled then
  StrikePlanner.handleReconQueue(
    config,
    saveData.c.recon,
    saveData.c.dynamicOperations.reconSchedule,
    saveData.c.surface.lacm,
    saveData.c.amphibOps.fireSupportOnHold == true
  )

  if math.random() > 0.5 then
    StrikePlanner.insertEntry(saveData.c.recon, config.c.recon.template.WZ8_RECON_ISLAND)
  end
end

if saveData.c.surface.lacm.enabled and GameUtils.isAfterStartTime(saveData.c.surface.lacm.startTime) then
  local ships = {}

  for _, value in ipairs(GameApi.ScenEdit_GetUnit("CSG").group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(value)
    if unit and unit.dbid == constants.PLATFORMS.TYPE_055 then
      table.insert(ships, { guid = value, weaponDBID = config.c.surface.lacm.weaponDBID })
    end
  end

  AttackManager.attackContacts({
    contacts = config.c.surface.lacm.targetlist,
    qty = 5,
    firingUnits = ships,
    weaponDBID = config.c.surface.lacm.weaponDBID
  })
  saveData.c.surface.lacm.enabled = false
end

if saveData.c.subSurface.slcm.enabled and GameUtils.isAfterStartTime(saveData.c.subSurface.slcm.startTime) then
  for _, unit in pairs(config.c.subSurface.slcm.submarines) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.name)

    if actualUnit then
      local course = { { latitude = actualUnit.latitude, longitude = actualUnit.longitude, presetDepth = 2 } }
      for _, value in ipairs(actualUnit.course) do
        table.insert(course, { latitude = value.latitude, longitude = value.longitude, presetDepth = 2 })
      end

      actualUnit.course = course
    end
  end

  AttackManager.attackContacts({
    contacts = config.c.subSurface.slcm.targetlist,
    qty = 8,
    firingUnits = config.c.subSurface.slcm.submarines,
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  })

  saveData.c.subSurface.slcm.enabled = false
end

if saveData.c.ground.enabled then
  StrikePlanner.strikeGroundTargets(saveData)
end

if saveData.c.air.enabled then
  StrikePlanner.executeAirStrike(config, saveData)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
