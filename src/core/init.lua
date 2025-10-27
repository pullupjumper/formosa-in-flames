local ShipMovement = require("src.modules.landingOps.shipMovement")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local saveData = require("src.core.saveData")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local UnitGenerator = require("src.modules.unitGenerator")

---Initialize Command and Control systems for Taiwan IADS
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
local function initC2(config, saveData)
  local units = GameApi.VP_GetSide({ side = "Taiwan" }):unitsBy(config.unitType.FACILITY)

  for _, unit in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    for _, item in pairs(saveData.t.IADS.ROCC) do
      for _, area in ipairs(item.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if actualUnit.dbid == config.platform.CUSTOMED_TK3 or actualUnit.dbid == config.platform.PAC3 then
            local data = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }

            saveData.t.IADS.ROCC[item.guid].SAM[actualUnit.guid] = data
          end

          if actualUnit.dbid == config.platform.FPS117
              or actualUnit.dbid == config.platform.TPS43F
              or actualUnit.dbid == config.platform.HR3000
              or actualUnit.dbid == config.platform.GE592 then
            local data = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }

            saveData.t.IADS.ROCC[item.guid].radar[actualUnit.guid] = data
          end
        end
      end
    end

    for _, item in pairs(saveData.t.IADS.TAAOC) do
      for _, area in ipairs(item.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if actualUnit.dbid == config.platform.TC2 or actualUnit.dbid == config.platform.SKY_GUARD then
            local data = {
              name = actualUnit.name,
              guid = actualUnit.guid,
              OODA = actualUnit.OODA,
              currOODA = actualUnit.OODA,
              isOutOfComms = false,
              outofcomms = 0,
              EMCONSetting = 'Radar=Passive'
            }

            saveData.t.IADS.TAAOC[item.guid].SAM[actualUnit.guid] = data
          end
        end
      end
    end
  end
end

---Initialize communications jammers for the specified side
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param side string The side name (e.g., 'China')
local function initCommsJammers(config, saveData, side)
  local units = GameApi.VP_GetSide({ side = side }):unitsBy(config.unitType.AIRCRAFT)

  for _, unit in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    if actualUnit and (actualUnit.dbid == config.platform.Y9 or
          actualUnit.dbid == config.platform.J15D or
          actualUnit.dbid == config.platform.J16D) then
      saveData.c.commsJamming.jammers[actualUnit.guid] = {
        guid = actualUnit.guid,
        OODA = actualUnit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    end
  end
end

---Initialize aircraft units for Taiwan air operations
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
local function initAC(config, saveData)
  local units = GameApi.VP_GetSide({ side = 'Taiwan' }):unitsBy(config.unitType.AIRCRAFT)

  for _, unit in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(unit.guid)

    if actualUnit and actualUnit.type == 'Aircraft' and actualUnit.dbid == config.platform.E2K then
      saveData.t.air.landBased.AEW[actualUnit.guid] = {
        guid = actualUnit.guid,
        OODA = actualUnit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    elseif actualUnit and actualUnit.type == 'Aircraft' then
      saveData.t.air.landBased.AC[actualUnit.guid] = {
        guid = actualUnit.guid,
        OODA = actualUnit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    end
  end
end

---Initialize SIGINT (Signals Intelligence) units for US and China
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
local function initSIGINT(config, saveData)
  local units = GameApi.VP_GetSide({ side = 'US' }):unitsBy(config.unitType.AIRCRAFT)
  local unitsFromChina = GameApi.VP_GetSide({ side = 'China' }):unitsBy(config.unitType.AIRCRAFT)

  for _, value in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(value.guid)

    if unit and unit.type == 'Aircraft' and unit.dbid == config.platform.RC135V then
      saveData.u.SIGINT.RA[unit.guid] = {
        guid = unit.guid,
        OODA = unit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    end
  end

  for _, value in ipairs(unitsFromChina) do
    local unit = GameApi.ScenEdit_GetUnit(value.guid)

    if unit and unit.type == 'Aircraft' and unit.dbid == config.platform.Y9DZ then
      saveData.c.SIGINT.RA[unit.guid] = {
        guid = unit.guid,
        OODA = unit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    end
  end
end

---Initialize target list by scanning contacts and categorizing them
---@param saveData SBJ__SaveData
local function initTargetlist(saveData)
  local contacts = GameApi.ScenEdit_GetContacts('China')
  local bases = {
    ['Jiashan AB'] = {},
    ['Hualien AB'] = {},
    ['Taitung/Jhihhang AB'] = {},
    ['Pingtung North AB'] = {},
    ['Pingtung South AB'] = {},
    ['Gangshan AB'] = {},
    ['Tainan AB'] = {},
    ['Guiren AAB'] = {},
    ['Magong AB'] = {},
    ['Chiayi AB'] = {},
    ['Ching Chuang Kang AB'] = {},
    ['Hsinchu AB'] = {},
    ['Longtan AAB'] = {},
    ['Taipei Songshan Airport'] = {},
    ['Taoyuan International Airport'] = {},
    ['Hsinchu Field Airdrome'] = {},
    ['Minxiong Emergency Highway Strip'] = {},
    ['Madou Emergency Highway Strip'] = {},
    ['Rende Emergency Highway Strip'] = {},
    ['Tainan Field Airdrome'] = {},
  }
  local ports = {
    ['Kaohsiung Port'] = {},
    ['Donggang Wharf'] = {},
    ['Port of Taipei'] = {},
    ['Port of Keelung'] = {},
    ['Suao Port'] = {},
    ['HuangGang Fishing Harbor'] = {},
    ['Magong Port'] = {},
  }
  local targetlist = {}

  if contacts then
    for _, contact in ipairs(contacts) do
      for key, obj in pairs(bases) do
        if string.find(contact.type_description, key) ~= nil then
          obj['location'] = { latitude = contact.latitude, longitude = contact.longitude }
        end
      end
    end

    for _, contact in ipairs(contacts) do
      for key, obj in pairs(bases) do
        if string.match(contact.type_description, "Runway %(%d+m%)") ~= nil or
            string.find(contact.type_description, 'Taxiway') ~= nil then
          local d = GameApi.Tool_Range(obj['location'], contact.guid)

          if d <= 1 then
            table.insert(targetlist, {
              name = key .. '/' .. contact.type_description,
              guid = contact.guid,
              category = 'Airfield',
              subType = contact.type_description,
            })
          end
        end

        if string.find(contact.type_description, 'Shelter') ~= nil or
            string.find(contact.type_description, 'Hangar') ~= nil or
            string.find(contact.type_description, 'Tarmac') ~= nil or
            string.find(contact.type_description, 'Helipad') ~= nil then
          local d = GameApi.Tool_Range(obj['location'], contact.guid)

          if d <= 1 then
            table.insert(targetlist, {
              name = key .. '/' .. contact.type_description,
              guid = contact.guid,
              category = 'Airfield',
              subType = contact.type_description,
            })
          end
        end

        if string.find(contact.type_description, 'Ammo Bunker') ~= nil or
            string.find(contact.type_description, 'Ammo Revetment') ~= nil then
          local d = GameApi.Tool_Range(obj['location'], contact.guid)

          if d <= 1 then
            table.insert(targetlist, {
              name = key .. '/' .. contact.type_description,
              guid = contact.guid,
              category = 'Airfield',
              subType = contact.type_description,
            })
          end
        end
      end
    end

    for _, contact in ipairs(contacts) do
      if string.find(contact.type_description, 'Radar') ~= nil then
        table.insert(targetlist, {
          name = contact.type_description,
          guid = contact.guid,
          category = 'ISR',
          subType = contact.type_description,
        })
      end
    end

    for _, contact in ipairs(contacts) do
      for key, obj in pairs(ports) do
        if string.find(contact.type_description, key) ~= nil then
          obj['location'] = { latitude = contact.latitude, longitude = contact.longitude }
        end
      end
    end

    for _, contact in ipairs(contacts) do
      for key, obj in pairs(ports) do
        if string.find(contact.type_description, 'Pier') ~= nil then
          local d = GameApi.Tool_Range(obj['location'], contact.guid)

          if d <= 1 then
            table.insert(targetlist, {
              name = key .. '/' .. contact.type_description,
              guid = contact.guid,
              category = 'Port',
              subType = contact.type_description,
            })
          end
        end
      end
    end

    for _, contact in ipairs(contacts) do
      if string.find(contact.type_description, 'ASM') ~= nil then
        table.insert(targetlist, {
          name = contact.type_description,
          guid = contact.guid,
          category = 'ASM',
          subType = contact.type_description,
        })
      end

      if string.find(contact.type_description, 'Sky Bow') ~= nil then
        table.insert(targetlist, {
          name = contact.type_description,
          guid = contact.guid,
          category = 'SAM',
          subType = contact.type_description,
        })
      end

      if string.find(contact.type_description, 'Hengshan ROC command') ~= nil then
        table.insert(targetlist, {
          name = contact.type_description,
          guid = contact.guid,
          category = 'C2',
          subType = contact.type_description,
        })
      end
    end
  end

  saveData.c.targetlist = targetlist
end

---Initialize runway repair targets for both Taiwan and China
---@param saveData SBJ__SaveData
local function initRunways(saveData)
  local targetlist = TargetingProcess.selectTargetsByQueryParams({
    targetlist = saveData.c.targetlist,
    queryParams = {
      { baseName = 'Hualien AB',                    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Taitung/Jhihhang AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Ching Chuang Kang AB',          subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Chiayi AB',                     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Tainan AB',                     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Pingtung South AB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Pingtung North AB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Magong AB',                     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Hsinchu AB',                    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Jiashan AB',                    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Guiren AAB',                    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Longtan AAB',                   subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Gangshan AB',                   subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Taipei Songshan Airport',       subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Taoyuan International Airport', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
    },
  })
  for _, guid in ipairs(targetlist) do
    local contact = GameApi.ScenEdit_GetContact('China', guid)
    if contact then
      table.insert(saveData.t.repairRunway.runways, { guid = contact.actualunitid, startTime = nil })
    end
  end

  local units = GameApi.VP_GetSide({ side = 'China' }):unitsBy(config.unitType.FACILITY)

  for _, v in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(v.guid)

    if unit and (unit.dbid == 55
          or unit.dbid == 43
          or unit.dbid == 757
          or unit.dbid == 1422
          or unit.dbid == 1424
          or unit.dbid == 1423
          or unit.dbid == 1421) then
      table.insert(saveData.c.repairRunway.runways, { guid = unit.guid, startTime = nil })
    end
  end
end

if config.isSaved then
  gKH.State.SaveTableToKey(saveData, "SaveData")
end

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData ~= nil and #saveData.c.targetlist <= 0 then
  ShipMovement.calculateDestination(config.c.PHIBOP, saveData)
  initAC(config, saveData)
  initTargetlist(saveData)
  initRunways(saveData)

  if saveData.t.IADS.isActivated then
    initC2(config, saveData)
  end

  if saveData.c.IADS.isActivated then
    UnitGenerator.initC2Facilities(config, config.c.IADS, saveData)
  end

  if saveData.c.commsJamming.isActivated then
    initCommsJammers(config, saveData, 'China')
  end

  if saveData.u.SIGINT.isActivated then
    initSIGINT(config, saveData)
  end

  if config.isDevMode then
    gKH.State.SaveTableToKey(saveData, "SaveData")
    Logger.log('Init data and save.')
  else
    Logger.log('Does not init data.')
  end
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
