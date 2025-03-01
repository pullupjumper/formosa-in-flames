--ScenEdit_RunScript('Development/First-Night-Kosovo/UnitKilled.lua')
function bL3.Functions.UnitKilled()
  local unit = UnitX()
  if not unit then return 0 end
  if unit.side == bL3.Sides.SERB and unit.type ~= 'Weapon' then
    local reference = os.time { day = 24, year = 1999, month = 3, hour = 1, min = 0, sec = 0 }
    if os.difftime(ScenEdit_CurrentTime(), reference) < 0 and not bL3.Variables.ClearSkies then
      bL3.msg.KillingBeforeTime()
      ScenEdit_EndScenario()
      return 0
    end
    ScenEdit_SetSidePosture(bL3.Sides.SERB, bL3.Sides.US, 'H')
    ScenEdit_SetSidePosture(bL3.Sides.SERB, bL3.Sides.USN, 'H')
    local guid = unit.guid

    local side = bL3.AuxFunctions.split(guid, '-')[2]
    local unit_id = bL3.AuxFunctions.split(guid, '-')[1]
    local unit_type = bL3.AuxFunctions.split(unit_id, '#')[1]

    if string.match(unit_id, 'HQSERBAD') then
      for k, v in ipairs(bL3.Units.SERB.OODA) do
        local u = SE_GetUnit({ guid = v })
        local detect = bL3.Units.SERB.OODA[v].OODA.detection
        local target = bL3.Units.SERB.OODA[v].OODA.targeting
        local OODA = bL3.Functions.GetOODA('HQ Destroyed')
        bL3.Units.SERB.OODA[v].OODA = { detection = detect + OODA.detection, targeting = target + OODA.targeting, evasion =
        OODA.evasion }
        u.OODA = bL3.Units.SERB.OODA[v].OODA
      end
      bL3.VP.US = bL3.VP.US + 10
    elseif string.match(unit_id, 'C2#') or string.match(unit_id, 'CMND#') then -- C2 Control -
      local IADS_ID = unit_id
      local IADS_Units = bL3.Units.SERB.IADS['SECTOR ' .. IADS_ID]
      for k, v in ipairs(IADS_Units.SAMS) do
        local u = SE_GetUnit({ guid = v })
        local detect = bL3.Units.SERB.OODA[v].OODA.detection
        local target = bL3.Units.SERB.OODA[v].OODA.targeting
        local OODA = bL3.Functions.GetOODA('C2 Destroyed')
        bL3.Units.SERB.OODA[v].OODA = { detection = detect + OODA.detection, targeting = target + OODA.targeting, evasion =
        OODA.evasion }
        u.OODA = bL3.Units.SERB.OODA[v].OODA
      end
      if IADS_Units.RADAR then
        for k, v in ipairs(IADS_Units.RADAR) do
          local u = SE_GetUnit({ guid = v })
          local detect = bL3.Units.SERB.OODA[v].OODA.detection
          local target = bL3.Units.SERB.OODA[v].OODA.targeting
          local OODA = bL3.Functions.GetOODA('C2 Destroyed')
          bL3.Units.SERB.OODA[v].OODA = { detection = detect + OODA.detection, targeting = target + OODA.targeting, evasion =
          OODA.evasion }
          u.OODA = bL3.Units.SERB.OODA[v].OODA
        end
      end
    elseif string.match(unit_id, 'COMMFAC#') then
      local IADS_ID = bL3.AuxFunctions.split(guid, '-')[3]
      local IADS_Units = bL3.Units.SERB.IADS['SECTOR ' .. IADS_ID]
      for k, v in ipairs(IADS_Units.SAMS) do
        local u = SE_GetUnit({ guid = v })
        if u then
          bL3.Units.SERB.OODA[v].isOutOfComms = true
          SE_SetUnit({ guid = v, outofcomms = true })
        else
          table.remove(bL3.Units.SERB.IADS['SECTOR ' .. IADS_ID].SAMS, k)
        end
      end
      for k, v in ipairs(IADS_Units.RADAR) do
        local u = SE_GetUnit({ guid = v })
        if u then
          bL3.Units.SERB.OODA[v].isOutOfComms = true
          SE_SetUnit({ guid = v, outofcomms = true })
        else
          table.remove(bL3.Units.SERB.IADS['SECTOR ' .. IADS_ID].SAMS, k)
        end
      end
    elseif unit_type == 'SAM' or unit_type == 'MOBRAD' or unit_type == 'EWRAD' then
      bL3.Variables.KSAM = bL3.Variables.KSAM + 1
    end
    if bL3.Units.SERB.OODA[guid] then
      bL3.Units.SERB.OODA[guid] = nil
    end
    local target = bL3.Units.SERB.Targets[guid]
    if target then
      bL3.Units.SERB.Targets[guid] = nil
      bL3.Variables.KTARGETS = bL3.Variables.KTARGETS + 1
    end
    if bL3.AREAS.JAMMERS[guid] then
      bL3.AREAS.JAMMERS[guid] = nil
      gKH.State.SaveTableToKey(bL3.AREAS.JAMMERS, 'JAMMER AREAS')

      for k, g in ipairs(bL3.Units.SERB.JAMMERS) do
        if g == unit.guid then
          table.remove(bL3.Units.SERB.JAMMERS, k)
          break
        end
      end
    end
  elseif unit.side == bL3.Sides.US and unit.type ~= 'Weapon' then
    local USUnits = {
      [2879] = { name = 'EC-130E Commando Solo II', dbid = 2879, crew = 5, cost = 20 },
      [320] = { name = 'EC-130H Compass Call', dbid = 320, crew = 5, cost = 20 },
      [3186] = { name = 'E-3A Sentry', dbid = 3186, crew = 17, cost = 20 },
      [821] = { name = 'U-2S', dbid = 821, crew = 1, cost = 20 },
      [1984] = { name = 'KC-135R Stratotanker', dbid = 1984, crew = 3, cost = 10 },
      [1716] = { name = 'RQ-1A Predator UAV', dbid = 1716, crew = 0, cost = 2 },
      [331] = { name = 'F-15C Eagle', dbid = 331, crew = 1, cost = 5 },
      [930] = { name = 'F-15E Strike Eagle', dbid = 930, crew = 2, cost = 5 },
      [591] = { name = 'F-16CJ Blk 52 Falcon', dbid = 591, crew = 1, cost = 5 },
      [1624] = { name = 'A-10A Thunderbolt II', dbid = 1624, crew = 1, cost = 5 },
      [724] = { name = 'OA-10A Thunderbolt II', dbid = 724, crew = 1, cost = 5 },
      [286] = { name = 'B-2A Spirit Blk 30', dbid = 286, crew = 3, cost = 30 },
      [569] = { name = 'B-52H Stratofortress', dbid = 569, crew = 4, cost = 20 },
      [573] = { name = 'RC-135V Rivet Joint', dbid = 573, crew = 50, cost = 30 },
      [290] = { name = 'E-8C Joint STARS', dbid = 290, crew = 15, cost = 25 },
      [214] = { name = 'KC-10A Extender', dbid = 214, crew = 4, cost = 10 },
      [2316] = { name = 'EA-6B Prowler ICAP II Blk 89', dbid = 2316, crew = 4, cost = 10 },
      [2524] = { name = 'F-117A Night Hawk', dbid = 2524, crew = 1, cost = 20 },
      [1065] = { name = 'F-16C Blk 30 Falcon', dbid = 1065, crew = 1, cost = 5 },
    }
    if USUnits[unit.dbid] then
      bL3.VP.US = bL3.VP.US - USUnits[unit.side].cost
    end
    bL3.Variables.USLosses = bL3.Variables.USLosses + 1
    if bL3.Units.US.OODA[guid] then
      bL3.Units.US.OODA[guid] = nil
    elseif unit.dbid == 2879 or unit.dbid == 290 then
      for k, g in ipairs(bL3.Units.US.ABCC) do
        if g == unit.guid then
          table.remove(bL3.Units.US.ABCC, k)
          break
        end
      end
    elseif unit.dbid == 2316 then   --Prowler
      for k, g in ipairs(bL3.Units.US.JAMMERS) do
        if g == unit.guid then
          table.remove(bL3.Units.US.JAMMERS, k)
          break
        end
      end
    elseif unit.dbid == 320 then   -- Compas Call
      bL3.Units.US.COMJAM = nil
    elseif unit.dbid == 573 then   -- Rivet Join
      for k, g in ipairs(bL3.Units.US.SIGINT) do
        if g == unit.guid then
          table.remove(bL3.Units.US.SIGINT, k)
          break
        end
      end
    end
  elseif unit.side == bL3.Sides.CIV then
    bL3.Variables.KCivilian = bL3.Variables.KCivilian + 1
    bL3.VP.US = bL3.VP.US - 10
    local offset = math.random(90, 180) * 60
    local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + offset)
    bL3.AuxFunctions.TimeEvent('CIV-Kill' .. bL3.AuxFunctions.RandomTxt(4), time,
      'bL3.msg.CivKill(bL3.Variables.KCivilian)', 'add', false)
    if bL3.Variables.KCivilian > 6 then
      time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + offset)
      bL3.AuxFunctions.TimeEvent('EndScenario-KCiv', time, 'bL3.Functions.EndScenario()', 'add', false)
    end
  elseif unit.side == bL3.Sides.MON then
    bL3.Variables.KMon = bL3.Variables.KMon + 1
    local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + math.random(90, 140) * 60)
    if bL3.Variables.KMon <= 2 then
      bL3.AuxFunctions.TimeEvent('MON-Kill' .. bL3.AuxFunctions.RandomTxt(2), time, 'bL3.msg.MonKill()', 'add', false)
    else
      bL3.AuxFunctions.TimeEvent('MON-KillB', time, 'bL3.msg.MonKill2(); ScenEdit_EndScenario()', 'add', false)
    end
  end

  gKH.State.SaveTableToKey(bL3.Units, 'UNITS')
  gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
  gKH.State.SaveTableToKey(bL3.VP, 'VP')
end
