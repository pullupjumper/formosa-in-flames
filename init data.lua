local function initRunways(saveData)
  saveData.c.ground.srbm.packages[1].batchTargetlists[1] = InitTargetList('China', 'STRIKE/RADAR')
  saveData.c.ground.srbm.packages[2].batchTargetlists[1] = InitTargetList('China', 'STRIKE/RUNWAY/1')
  saveData.c.ground.srbm.packages[2].batchTargetlists[2] = InitTargetList('China', 'STRIKE/RUNWAY/2')
  saveData.c.ground.srbm.packages[3].batchTargetlists[1] = InitTargetList('China', 'STRIKE/PORT/1')
  saveData.c.ground.srbm.packages[3].batchTargetlists[2] = InitTargetList('China', 'STRIKE/PORT/2')
  saveData.c.ground.srbm.packages[4].batchTargetlists[1] = InitTargetList('China', 'STRIKE/SHELTER/1')
  saveData.c.ground.srbm.packages[4].batchTargetlists[2] = InitTargetList('China', 'STRIKE/SHELTER/2')
  saveData.c.ground.srbm.packages[4].batchTargetlists[3] = InitTargetList('China', 'STRIKE/SHELTER/3')
  saveData.c.ground.glcm.packages[1].batchTargetlists[1] = InitTargetList('China', 'STRIKE/HELIPAD')
  saveData.c.ground.glcm.packages[2].batchTargetlists[1] = InitTargetList('China', 'STRIKE/EMERGENCY HIGHWAY STRIP')
  saveData.c.ground.mlrs.packages[1].batchTargetlists[1] = InitTargetList('China', 'STRIKE/C2/N')
  saveData.c.ground.mlrs.packages[2].batchTargetlists[1] = InitTargetList('China', 'STRIKE/C2/S')


  for _, value in ipairs(saveData.c.ground.srbm.packages[2].batchTargetlists[2]) do
    local contact = ScenEdit_GetContact({ side = 'China', guid = value.guid })

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
  -- local unitsFromChina = VP_GetSide({ Side = "China" }).units

  for _, value in ipairs(units) do
    local unit = SE_GetUnit({ guid = value.guid })

    for ROCCGuid, item in pairs(saveData.t.IADS.ROCC) do
      if unit ~= nil and unit:inArea(item.area) then
        if unit.dbid == CONFIG.platformDBID14 or unit.dbid == CONFIG.platformDBID15 then
          local data = {
            name = unit.name,
            guid = unit.guid,
            OODA = unit.OODA,
            currOODA = unit.OODA,
            isOutOfComms = false,
            outofcomms = 0,
            EMCON_Setting = 'Radar=Passive'
          }

          saveData.t.IADS.ROCC[ROCCGuid].SAM[unit.guid] = data
        end

        if unit.dbid == CONFIG.platformDBID41
            or unit.dbid == CONFIG.platformDBID42
            or unit.dbid == CONFIG.platformDBID43
            or unit.dbid == CONFIG.platformDBID44 then
          local data = {
            name = unit.name,
            guid = unit.guid,
            OODA = unit.OODA,
            currOODA = unit.OODA,
            isOutOfComms = false,
            outofcomms = 0,
            EMCON_Setting = 'Radar=Passive'
          }

          saveData.t.IADS.ROCC[ROCCGuid].radar[unit.guid] = data
        end
      end
    end

    for TAAOCGuid, item in pairs(saveData.t.IADS.TAAOC) do
      if unit ~= nil and unit:inArea(item.area) then
        if unit.dbid == CONFIG.platformDBID33 then
          local data = {
            name = unit.name,
            guid = unit.guid,
            OODA = unit.OODA,
            currOODA = unit.OODA,
            isOutOfComms = false,
            outofcomms = 0,
            EMCON_Setting = 'Radar=Passive'
          }

          saveData.t.IADS.TAAOC[TAAOCGuid].SAM[unit.guid] = data
        end
      end
    end
  end

  ScenEdit_SpecialMessage('Taiwan', 'C2 init done.')
  ScenEdit_SpecialMessage('China', 'C2 init done.')
end

local function initCommsJammers(side, saveData)
  local units = VP_GetSide({ Side = side }).units

  for _, value in ipairs(units) do
    local unit = SE_GetUnit({ guid = value.guid })

    if unit and (unit.dbid == CONFIG.platformDBID35 or unit.dbid == CONFIG.platformDBID37) then
      table.insert(saveData.c.commsJamming.jammers, { guid = unit.guid })
    end
  end
end

local function initAC(saveData)
  local units = VP_GetSide({ Side = 'Taiwan' }).units

  for _, value in ipairs(units) do
    local unit = SE_GetUnit({ guid = value.guid })

    if unit and unit.type == 'Aircraft' and unit.dbid == CONFIG.platformDBID38 then
      table.insert(
        saveData.t.air.landBased.AEW,
        {
          guid = unit.guid,
          OODA = unit.OODA,
          comms_level = 40,
          comms_base = 40,
          comms_threshold = 30,
          outofcomms = 0,
        }
      )
    elseif unit and unit.type == 'Aircraft' then
      table.insert(
        saveData.t.air.landBased.AC,
        {
          guid = unit.guid,
          OODA = unit.OODA,
          comms_level = 40,
          comms_base = 40,
          comms_threshold = 30,
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
        comms_level = 40,
        comms_base = 40,
        comms_threshold = 30,
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
        comms_level = 40,
        comms_base = 40,
        comms_threshold = 30,
        outofcomms = 0,
      }
    end
  end
end


if CONFIG.isSaved then
  gKH.State.SaveTableToKey(SaveData, "SaveData")
end

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData ~= nil and GetCount(saveData.c.ground.srbm.packages[1].batchTargetlists) <= 0 then
  initRunways(saveData)
  CalculateDestination(saveData)
  initAC(saveData)

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
