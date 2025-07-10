local gKH = require('src.core.gKH_State_Standalone')
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local CONFIG = require("src.core.constants")
local Recon = require("src.modules.strikePlanner.recon")
local AttackManager = require("src.modules.strikePlanner.attackManager")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")


local contacts = GameApi.ScenEdit_GetContacts('China')

if not contacts then
  return
end

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if saveData.c.recon.isActivated then
  Recon.handleReconQueue(saveData)
end

if saveData.c.surface.lacm.isActivated and GameUtils.isAfterStartTime(saveData.c.surface.lacm.startTime) then
  local ships = {}

  for _, value in ipairs(GameApi.ScenEdit_GetUnit('CSG').group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(value)
    if unit and unit.dbid == CONFIG.platformDBID51 then
      table.insert(ships, { guid = value, weaponDBID = CONFIG.c.surface.lacm.weaponDBID })
    end
  end

  AttackManager.attackContacts({
    contacts = CONFIG.c.surface.lacm.targetlist,
    qty = 5,
    batteries = ships,
    weaponDBID = CONFIG.c.surface.lacm.weaponDBID
  })
  saveData.c.surface.lacm.isActivated = false
end

if saveData.c.subSurface.slcm.isActivated and GameUtils.isAfterStartTime(saveData.c.subSurface.slcm.startTime) then
  for _, unit in pairs(CONFIG.c.subSurface.slcm.submarines) do
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
    contacts = CONFIG.c.subSurface.slcm.targetlist,
    qty = 8,
    batteries = CONFIG.c.subSurface.slcm.submarines,
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  })

  saveData.c.subSurface.slcm.isActivated = false
end

if saveData.c.ground.isActivated then
  FireSupportPlan.strike(CONFIG, saveData, contacts)
end

if saveData.c.air.isActivated then
  AirTaskingOrder.airStrike(CONFIG, saveData, contacts)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
