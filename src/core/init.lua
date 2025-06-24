ShipMovement = require("modules/landingOps/shipMovement")
-- local function initGPSJammers()
--     for _, value in ipairs(CONFIG.c.GPSJamming.jammers) do
--         local jammer = SE_GetUnit({ guid = value.guid })
--         local eventName = value.eventName
--         local event = ScenEdit_GetEvent(eventName)

--         if jammer and event == nil then
--             if jammer.dbid == CONFIG.platformDBID25 then
--                 local jammingArea = NewArea(
--                     { latitude = jammer.latitude, longitude = jammer.longitude },
--                     { side = 'China', distance = '15', shape = 'circle' }
--                 )
--                 local FilterType = { TargetSide = 'Taiwan', TargetType = 6 }
--                 UnitEntersAreaEvent(eventName, FilterType, jammingArea, 'GPSJamming()', 'add', false, true, true)
--             end
--         end
--     end
-- end

local function initC2(saveData)
  local units = VP_GetSide({ Side = "Taiwan" }).units

  for _, unit in ipairs(units) do
    local actualUnit = SE_GetUnit({ guid = unit.guid })

    for _, item in pairs(saveData.t.IADS.ROCC) do
      for _, area in ipairs(item.areas) do
        if actualUnit ~= nil and actualUnit:inArea(area) then
          if actualUnit.dbid == CONFIG.platformDBID14 or actualUnit.dbid == CONFIG.platformDBID15 then
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

          if actualUnit.dbid == CONFIG.platformDBID41
              or actualUnit.dbid == CONFIG.platformDBID42
              or actualUnit.dbid == CONFIG.platformDBID43
              or actualUnit.dbid == CONFIG.platformDBID44 then
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
          if actualUnit.dbid == CONFIG.platformDBID33 or actualUnit.dbid == CONFIG.platformDBID34 then
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

local function initCommsJammers(side, saveData)
  local units = VP_GetSide({ Side = side }).units

  for _, unit in ipairs(units) do
    local actualUnit = SE_GetUnit({ guid = unit.guid })

    if actualUnit and (actualUnit.dbid == CONFIG.platformDBID35 or actualUnit.dbid == CONFIG.platformDBID37) then
      table.insert(saveData.c.commsJamming.jammers, { guid = actualUnit.guid })
    end
  end
end

local function initAC(saveData)
  local units = VP_GetSide({ Side = 'Taiwan' }).units

  for _, unit in ipairs(units) do
    local actualUnit = SE_GetUnit({ guid = unit.guid })

    if actualUnit and actualUnit.type == 'Aircraft' and actualUnit.dbid == CONFIG.platformDBID38 then
      table.insert(
        saveData.t.air.landBased.AEW,
        {
          guid = actualUnit.guid,
          OODA = actualUnit.OODA,
          commsLevel = 40,
          commsBase = 40,
          commsThreshold = 30,
          outofcomms = 0,
        }
      )
    elseif actualUnit and actualUnit.type == 'Aircraft' then
      table.insert(
        saveData.t.air.landBased.AC,
        {
          guid = actualUnit.guid,
          OODA = actualUnit.OODA,
          commsLevel = 40,
          commsBase = 40,
          commsThreshold = 30,
          outofcomms = 0,
        }
      )
    end
  end
end

local function initSIGINT(saveData)
  local units = VP_GetSide({ Side = 'US' }).units
  local unitsFromChina = VP_GetSide({ Side = 'China' }).units

  for _, value in ipairs(units) do
    local unit = SE_GetUnit({ guid = value.guid })

    if unit and unit.type == 'Aircraft' and unit.dbid == CONFIG.platformDBID45 then
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
    local unit = SE_GetUnit({ guid = value.guid })

    if unit and unit.type == 'Aircraft' and unit.dbid == CONFIG.platformDBID47 then
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

local function setupReconQueue(saveData)
  for _, item in pairs(saveData.c.air.ATO) do
    if item.reconUAVs then
      InsertList(saveData.c.recon.queue, item.reconUAVs)
    end
  end
end

local function initATO(saveData)
  for _, wave in pairs(saveData.c.air.ATO) do
    for index, package in ipairs(wave.packages) do
      if package.takeoffTime == nil and index == 1 then
        PrintBox('China', 'No takeoff time for ' .. wave.name .. ' package ' .. index)
      end

      if type(package.queryParams) == 'table' then
        package.targetlist = SelectTargetsByQueryParams({
          targetlist = saveData.c.targetlist,
          queryParams = package.queryParams
        })
      end

      if package.takeoffTime == nil and index > 1 then
        package.takeoffTime = os.date(
          "%Y-%m-%d %I:%M:%S",
          ParseDatetimeToTimestamp(wave.packages[index - 1].takeoffTime) + wave.strikeInterval
        )
      end
    end
  end
end

local function initFSP(saveData)
  for key, FSEM in pairs(saveData.c.ground.FSP) do
    for index, FST in ipairs(FSEM.FSTs) do
      if type(FST.queryParams) == 'table' then
        FST.targetlist = SelectTargetsByQueryParams({
          targetlist = saveData.c.targetlist,
          queryParams = FST.queryParams
        })
      end

      if FST.startTime == nil and index == 1 then
        PrintBox('China', 'No start time for ' .. FSEM.name .. ' Fire Support Task ' .. index)
      end

      if FST.startTime == nil and index > 1 then
        FST.startTime = os.date(
          "%Y-%m-%d %I:%M:%S",
          ParseDatetimeToTimestamp(FSEM.FSTs[index - 1].startTime) + FSEM.strikeInterval
        )
      end
    end
  end
end

local function initTargetlist(saveData)
  local contacts = ScenEdit_GetContacts('China')
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
          local d = Tool_Range(obj['location'], contact.guid)

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
          local d = Tool_Range(obj['location'], contact.guid)

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
          local d = Tool_Range(obj['location'], contact.guid)

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
          local d = Tool_Range(obj['location'], contact.guid)

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

local function initRunways(saveData)
  local targetlist = SelectTargetsByQueryParams({
    targetlist = saveData.c.targetlist,
    queryParams = {
      { baseName = 'Hualien AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Taitung/Jhihhang AB',  subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Ching Chuang Kang AB', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Chiayi AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Tainan AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Pingtung South AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Pingtung North AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Magong AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Hsinchu AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      { baseName = 'Jiashan AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
    },
  })
  for _, guid in ipairs(targetlist) do
    local contact = ScenEdit_GetContact({ side = 'China', guid = guid })
    if contact then
      table.insert(saveData.t.repairRunway.runways, { guid = contact.actualunitid, startTime = nil })
    end
  end

  local units = VP_GetSide({ Side = 'China' }).units

  for _, v in ipairs(units) do
    local unit = SE_GetUnit({ guid = v.guid })

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

if CONFIG.isSaved then
  gKH.State.SaveTableToKey(SaveData, "SaveData")
end

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData ~= nil and #saveData.c.ground.FSP['STRIKE/INFRASTRUCTURE/1'].FSTs[1].targetlist <= 0 then
  ShipMovement.CalculateDestination(saveData)
  initAC(saveData)
  initTargetlist(saveData)
  initATO(saveData)
  initFSP(saveData)
  initRunways(saveData)


  if saveData.t.IADS.isActivated then
    initC2(saveData)
  end

  if saveData.c.IADS.isActivated then
    InitC2Facilities(saveData)
  end

  if saveData.c.commsJamming.isActivated then
    initCommsJammers('China', saveData)
  end

  if saveData.u.SIGINT.isActivated then
    initSIGINT(saveData)
  end

  if saveData.c.recon.isActivated then
    setupReconQueue(saveData)
  end

  if CONFIG.isDevMode then
    gKH.State.SaveTableToKey(saveData, "SaveData")
    ScenEdit_SpecialMessage('Taiwan', 'Init data and save.')
  end
else
  ScenEdit_SpecialMessage('Taiwan', 'Does not init data.')
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
