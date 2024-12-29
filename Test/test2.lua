-- ScenEdit_RunScript('/Development/First-Night-Kosovo/LuaInit.lua')
ScenEdit_SetEvent('LuaInit', { isActive = true })

bL3 = {}
bL3.Functions = {}
bL3.AuxFunctions = {}
bL3.Zulu = 1
bL3.OODA = {}
bL3.Contacts = {}
bL3.Sides = {}
bL3.Sides.NATO = "NATO"
bL3.Sides.SERB = "Serbia"
bL3.Sides.BOS = "Bosnia"
bL3.Sides.KOS = "Kosovo"
bL3.Sides.MON = "Montenegro"
bL3.Sides.CIV = "Serbian Civ"
bL3.Sides.BIO = "Biologics"
bL3.Sides.RUS = "USSR"
bL3.Sides.CROATIA = "Croatia"
bL3.Sides.US = "US"
bL3.Sides.USN = 'USN'
bL3.AREAS = {}
bL3.AREAS.KOS = {
  'KOS-1', 'KOS-2', 'KOS-3', 'KOS-4', 'KOS-5', 'KOS-6', 'KOS-7', 'KOS-8', 'KOS-9', 'KOS-10', 'KOS-11', 'KOS-12', 'KOS-13',
  'KOS-14', 'KOS-15', 'KOS-16', 'KOS-17', 'KOS-18', 'KOS-19', 'KOS-20', 'KOS-21', 'KOS-22', 'KOS-23', 'KOS-24', 'KOS-25',
  'KOS-26', 'KOS-27', 'KOS-28', 'KOS-29', 'KOS-30', 'KOS-31', 'KOS-32', 'KOS-33', 'KOS-34', 'KOS-35', 'KOS-36', 'KOS-37',
  'KOS-38', 'KOS-39', 'KOS-40', 'KOS-41', 'KOS-42'
}
bL3.AREAS.MON = {
  'MON-1', 'MON-2', 'MON-3', 'MON-4', 'MON-5', 'MON-6', 'MON-7', 'MON-8', 'MON-9', 'MON-10', 'MON-11', 'MON-12', 'MON-13',
  'MON-14', 'MON-15', 'MON-16', 'MON-17', 'MON-18', 'MON-19', 'MON-20', 'MON-21', 'MON-22', 'MON-23', 'MON-24', 'MON-25',
  'MON-26', 'MON-27', 'MON-28', 'MON-29', 'MON-30', 'MON-31', 'MON-32', 'MON-33', 'MON-34', 'MON-35', 'MON-36', 'MON-37',
  'MON-38', 'MON-39', 'MON-40', 'MON-41', 'MON-42', 'MON-43', 'MON-44', 'MON-45', 'MON-46', 'MON-47', 'MON-48', 'MON-49',
  'MON-50', 'MON-51', 'MON-52', 'MON-53', 'MON-54', 'MON-55', 'MON-56', 'MON-57', 'MON-58', 'MON-59', 'MON-60', 'MON-61',
  'MON-62', 'MON-63', 'MON-64', 'MON-65', 'MON-66', 'MON-67', 'MON-68', 'MON-69', 'MON-70', 'MON-71', 'MON-72', 'MON-73',
  'MON-74', 'MON-75', 'MON-76', 'MON-77', 'MON-78', 'MON-79', 'MON-80', 'MON-81'
}
bL3.AREAS.SERB = {
  'SER-1', 'SER-2', 'SER-3', 'SER-4', 'SER-5', 'SER-6', 'SER-7', 'SER-8', 'SER-9', 'SER-10', 'SER-11', 'SER-12', 'SER-13',
  'SER-14', 'SER-15', 'SER-16', 'SER-17', 'SER-18', 'SER-19', 'SER-20', 'SER-21', 'SER-22', 'SER-23', 'SER-24', 'SER-25',
  'SER-26', 'SER-27', 'SER-28', 'SER-29', 'SER-30', 'SER-31', 'SER-32', 'SER-33', 'SER-34', 'SER-35', 'SER-36', 'SER-37',
  'SER-38', 'SER-39', 'SER-40', 'SER-41', 'SER-42', 'SER-43', 'SER-44', 'SER-45', 'SER-46', 'SER-47', 'SER-48', 'SER-49',
  'SER-50', 'SER-51', 'SER-52', 'SER-53', 'SER-54', 'SER-55', 'SER-56', 'SER-57', 'SER-58', 'SER-59', 'SER-60', 'SER-61',
  'SER-62', 'SER-63', 'SER-64', 'SER-65', 'SER-66', 'SER-67', 'SER-68', 'SER-69', 'SER-70', 'SER-71', 'SER-72', 'SER-73',
  'SER-74', 'SER-75', 'SER-76', 'SER-77', 'SER-78', 'SER-79', 'SER-80', 'SER-81', 'SER-82', 'SER-83', 'SER-84', 'SER-85',
  'SER-86', 'SER-87', 'SER-88', 'SER-89', 'SER-90', 'SER-91', 'SER-92', 'SER-93', 'SER-94', 'SER-95', 'SER-96', 'SER-97',
  'SER-98', 'SER-99', 'SER-100', 'SER-101', 'SER-102', 'SER-103', 'SER-104', 'SER-105', 'SER-106', 'SER-107', 'SER-108',
  'SER-109', 'SER-110', 'SER-111', 'SER-112', 'SER-113', 'SER-114', 'SER-115', 'SER-116', 'SER-117', 'SER-118', 'SER-119',
  'SER-120', 'SER-121', 'SER-122', 'SER-123', 'SER-124', 'SER-125', 'SER-126', 'SER-127', 'SER-128', 'SER-129', 'SER-130',
  'SER-131', 'SER-132'
}
bL3.AREAS.EXCL = { 'RP-412', 'RP-413', 'RP-414', 'RP-415', 'RP-416', 'RP-417', 'RP-418', 'RP-419', 'RP-420', 'RP-421',
  'RP-422', 'RP-423', 'RP-424' }
function bL3.Functions.GetOODA(mode)
  bL3.AuxFunctions.ImprovedRandomseed(3)
  local OODA
  local C = bL3.Variables.Complexity
  if C == 1 then C = 1.2 elseif C == 2 then C = 1 elseif C == 3 then C = 0.8 end
  if mode == 'SAM' then
    OODA = { detection = math.random(10 * C, 30 * C), targeting = math.random(20 * C, 40 * C), evasion = math.random(70,
      90) * C }
  elseif mode == 'AC' then
    OODA = { detection = math.random(20 * C, 40 * C), targeting = math.random(20 * C, 60 * C), evasion = math.random(5 *
    C, 7 * C) }
  elseif mode == 'C2 Destroyed' then
    OODA = { detection = math.random(10 * C, 30 * C), targeting = math.random(20 * C, 20 * C), evasion = math.random(
    90 * C, 120 * C) }
  elseif mode == 'HQ Destroyed' then
    OODA = { detection = math.random(60 * C, 90 * C), targeting = math.random(80, 220 * C), evasion = math.random(90 * C,
      120 * C) }
  end
  return OODA
end

-- ScenEdit_RunScript('Development/First-Night-Kosovo/AuxFunctions.lua')
-- ScenEdit_RunScript('Development/First-Night-Kosovo/gKH.lua')
-- ScenEdit_RunScript('Development/First-Night-Kosovo/UnitKilled.lua')


-- SAVE & LOAD TABLES
function bL3.Functions.LoadScenKeys(key_table)
  if key_table ~= nil then
    local t_table = gKH.State.LoadTableFromKey(key_table)
    if t_table == nil then return {} end
    return t_table
  end
end

function bL3.Functions.SaveScenKeys(t_table, key_table)
  if t_table ~= nil and key_table ~= nil then
    gKH.State.SaveTableToKey(t_table, key_table)
  else
    gKH.State.SaveTableToKey(bL3.Variables, bL3.CONSTANTS.VARIABLES)
  end
end

---NFZ---
function bL3.Functions.ToggleNFZ()
  if bL3.Variables.NFZ then
    ScenEdit_SetZone('US', 0, { description = 'CROATIA', isActive = false })
    bL3.Variables.NFZ = false
  else
    ScenEdit_SetZone('US', 0, { description = 'CROATIA', isActive = true })
    bL3.Variables.NFZ = true
  end
  gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
end

---- SAM REDEPLOYMENT
function bL3.Functions.CreateAreaAroundSam(SAM, radius)
  local area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
    { shape = 'circle', side = SAM.side, distance = 1, name = 'SA' })
  if type(area) ~= "table" then return 0 end
  local target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.SERB }).guid, TargetType = 6 }
  bL3.AuxFunctions.UnitEntersAreaEvent('SAM WEAPON-' .. SAM.guid, target_type, area,
    'bL3.Functions.SAM_Fires(' .. SAM.guid .. ')', 'add', false, true, true)
  bL3.Units.SERB.OODA[SAM.guid].area = area
end

-- Weapon Detected
function bL3.Functions.SAM_HARM(sam_guid)
  local unit = ScenEdit_UnitC()
  local iads_id = bL3.AuxFunctions.split(sam_guid, '-')[3]
  local IADS_units = bL3.Units.SERB.IADS['SECTOR ' .. iads_id]
  if unit and unit.type == 'Weapon' then
    ScenEdit_SetEvent('SAM_HARM-' .. sam_guid, { isActive = false })
    ScenEdit_SetEMCON('unit', sam_guid, 'Radar=Passive')
    ScenEdit_SetDoctrine({ guid = sam_guid }, { ignore_emcon_while_under_attack = false })
    local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + math.random(90, 140))
    local script = [[ScenEdit_SetDoctrine({guid=]] .. sam_guid .. [[}, {ignore_emcon_while_under_attack=false})
    ScenEdit_SetEvent('SAM_HARM-']] .. sam_guid .. [[, {isActive=true})
    bL3.AuxFunctions.DeleteEvent('NormalEW-']] .. sam_guid .. [[)
    ]]
    bL3.AuxFunctions.TimeEvent('NormalEW-' .. sam_guid, time, script, 'add', false)
  end
  -- Apagar SAMs y EW
end

-- Move SAM LOGIC
function bL3.Functions.SAM_Fires(sam_guid)
  local weapon = UnitX()
  sam_guid = weapon.weapon.shooter.guid
  local unit = SE_GetUnit({ guid = sam_guid })
  if unit and unit.type == 'Facility' then
    bL3.Units.SERB.OODA[sam_guid].Fires = bL3.Units.SERB.OODA[sam_guid].Fires + 1

    if bL3.Units.SERB.OODA[sam_guid].Fires >= math.random(4, 5) then
      local area = bL3.Units.SERB.OODA[sam_guid].areaW
      bL3.AuxFunctions.DeleteArea(area, bL3.Sides.SERB)
      bL3.AuxFunctions.RemoveEvent('SAM Fires-' .. sam_guid)

      area = bL3.Units.SERB.OODA[sam_guid].areaHARM
      bL3.AuxFunctions.DeleteArea(area, bL3.Sides.SERB)
      bL3.AuxFunctions.RemoveEvent('SAM HARM-' .. sam_guid)

      ScenEdit_SetDoctrine({ guid = sam_guid }, { weapon_control_status_air = 2 })
      --TODO redeploy time based on scen complexity
      local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + math.random(30, 40) * 60)
      bL3.AuxFunctions.TimeEvent('SAM_Moves-' .. sam_guid, time, 'bL3.Functions.SAM_Moves("' .. sam_guid .. '")', 'add',
        false)
      time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + math.random(120, 140) * 60)
      bL3.AuxFunctions.TimeEvent('SAM_Redeploy-' .. sam_guid, time, 'bL3.Functions.SAM_Redeploys("' .. sam_guid .. '")',
        'add', false)
      gKH.State.SaveTableToKey(bL3.Units, 'UNITS')
    end
  end
end

function bL3.Functions.SAM_Moves(sam_guid)
  --Delete SAM
  SE_SetUnit({ guid = sam_guid, latitude = 60.2811118732958, longitude = 99.2867466774299 })
end

function bL3.Functions.SAM_Redeploys(sam_guid)
  --Create New SAM
  local data = bL3.Units.SERB.OODA[sam_guid]
  data.Fires = 0
  SE_SetUnit({ guid = sam_guid, latitude = data.latitude + math.random(-1000, 1000) / 10 ^ 4, longitude = data.longitude +
  math.random(-1000, 1000) / 10 ^ 4 })
  local SAM = SE_GetUnit({ guid = sam_guid })
  if not SAM then
    print("Not SAM 751489")
    return 0
  end
  --Create New Area
  local area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
    { shape = 'circle', side = SAM.side, distance = 3, name = 'SA' })
  if type(area) ~= "table" then return 0 end
  local target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.SERB }).guid, TargetType = 6 }
  bL3.AuxFunctions.UnitEntersAreaEvent('SAM Fires-' .. SAM.guid, target_type, area,
    'bL3.Functions.SAM_Fires("' .. SAM.guid .. '")', 'add', false, true, true)

  data.areaW = area

  area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
    { shape = 'circle', side = SAM.side, distance = data.radius, name = 'SP' })
  if type(area) ~= "table" then return 0 end
  target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.US }).guid, TargetType = 6 }
  bL3.AuxFunctions.UnitEntersAreaEvent('SAM HARM-' .. SAM.guid, target_type, area,
    'bL3.Functions.SAM_HARM("' .. SAM.guid .. '")', 'add', false, true, true)

  data.areaHARM = area
  data.latitude = SAM.latitude
  data.longitude = SAM.longitude
  bL3.Units.SERB.OODA[SAM.guid] = data
  ScenEdit_SetDoctrine({ guid = sam_guid }, { weapon_control_status_air = 1 })
  gKH.State.SaveTableToKey(bL3.Units, 'UNITS')
  bL3.AuxFunctions.RemoveEvent('SAM_Moves-' .. sam_guid)
  bL3.AuxFunctions.RemoveEvent('SAM_Redeploy-' .. sam_guid)
end

function bL3.Functions.SAM_SPOT(sam_guid)
  local trig_unit = UnitX()
  if trig_unit and trig_unit.altitude > 15000 then
    ScenEdit_SetEvent('SAM SPOT-' .. sam_guid, { isActive = true })
    return 0
  end
  local data = bL3.Units.SERB.OODA[sam_guid]
  SE_SetUnit({ guid = sam_guid, latitude = data.latitude, longitude = data.longitude })
  ScenEdit_SetEvent('SAM HARM-' .. sam_guid, { isActive = true })
  ScenEdit_SetEvent('SAM Fires-' .. sam_guid, { isActive = true })
  bL3.AuxFunctions.RemoveEvent('SAM SPOT-' .. sam_guid)
end

-- JAMMING


function bL3.Functions.COMM_JAMMING_SERBIA()
  local areas = bL3.AREAS.JAMMERS
  local US_AIRCRAFTS = bL3.Units.US.OODA
  if areas then
    for uguid, udata in pairs(US_AIRCRAFTS) do
      -- local starttime = os.clock()
      local unit = SE_GetUnit({ guid = uguid })
      for k, area in pairs(areas) do
        if unit and unit.condition == 'Airborne' and unit:inArea(area) then
          udata.comms_level = udata.comms_base + bL3.Functions.getCommLevel(uguid)
          if udata.comms_level < udata.comms_threshold then
            ScenEdit_SetUnit({ guid = uguid, outofcomms = true, RTB = true })
            ScenEdit_CreateBarkNotification_Unit(unit.name, 'RTB', 255, 0, 0, false, true, 6, 18)
            ScenEdit_SetLoadout({ UnitName = uguid, LoadoutID = 3 })
          end
          goto continue
        end
      end
      ::continue::
      -- local timetaken = (os.clock() - starttime) * 1000;
      -- print(string.format('Comm Jammer timetaken (ms): %.6f',timetaken));
    end
  end
end

function bL3.Functions.getCommLevel(uguid)
  local comm_bonif = 0
  --JAM Vs uguid
  for k, jam in ipairs(bL3.Units.SERB.JAMMERS) do
    comm_bonif = -120 + Tool_Range(uguid, jam) ^ 1.04 + comm_bonif
  end
  --ABCC

  for k, abcc in ipairs(bL3.Units.US.ABCC) do
    local u_abcc = SE_GetUnit({ guid = abcc })
    if u_abcc and u_abcc.condition == 'Airborne' then
      local d = Tool_Range(uguid, abcc)
      if d < 100 then
        comm_bonif = comm_bonif + 400 + math.random(-1, 1)
      elseif d < 200 then
        comm_bonif = comm_bonif + 350 + math.random(-3, 3)
      elseif d < 300 then
        comm_bonif = comm_bonif + 250 + math.random(-6, 6)
      elseif d < 400 then
        comm_bonif = comm_bonif + 150 + math.random(-10, 10)
      end
    end
  end
  return math.floor(comm_bonif)
end

function bL3.Functions.JAMMING_US()
  local jammer_guid = bL3.Units.US.COMJAM
  local jammer = SE_GetUnit({ guid = jammer_guid })

  local jammed = {}
  local EW_JAMMERS = bL3.Units.US.JAMMERS

  local JAM_Limit = 12 * bL3.Variables.Complexity

  local current_jam = 0

  local keys = {}
  for k in pairs(bL3.Units.SERB.OODA) do
    table.insert(keys, k)   -- Añade las claves a la lista keys
  end

  bL3.AuxFunctions.shuffle(keys)
  for _, k in ipairs(keys) do
    local v = bL3.Units.SERB.OODA[k]
    -- local starttime = os.clock()
    if v.isOutOfComms then
      if v.outofcomms <= math.random(15, 25) then
        local unit = SE_SetUnit({ guid = k, outofcomms = true })
        v.outofcomms = v.outofcomms + 1
      else
        local unit = SE_SetUnit({ guid = k, outofcomms = false })
        v.outofcomms = 0
        v.isOutOfComms = false
      end
    end
    if jammer and jammer.condition == 'Airborne' and jammer.jammer then
      if v.isOutOfComms == false then
        if v.outofcomms < math.random(5, 10) and v.outofcomms >= 0 and current_jam < JAM_Limit then
          local d = Tool_Range(jammer_guid, k)
          local n = 1 * math.sqrt(1 - (d ^ 1.9 / 450 ^ 1.8))
          if n == n and n > (math.random() / 2 + (v.jam_time / 20)) then
            local unit = SE_SetUnit({ guid = k, outofcomms = true })
            v.outofcomms = v.outofcomms + 1
            current_jam = current_jam + 1
          else
            local unit = SE_SetUnit({ guid = k, outofcomms = false })
            v.outofcomms = 0
            current_jam = current_jam + 1
          end
        elseif v.outofcomms < 0 then
          local unit = SE_SetUnit({ guid = k, outofcomms = false })
          v.outofcomms = v.outofcomms + 1
        else
          local unit = SE_SetUnit({ guid = k, outofcomms = false })
          v.outofcomms = math.random(-5, -1)
        end
      end
    end

    -- local timetaken = (os.clock() - starttime) * 1000;
    -- print(string.format('Airborne Jammer timetaken (ms): %.6f',timetaken));
    -- local starttime = os.clock()
    for n, JAM in ipairs(EW_JAMMERS) do
      local prowler = SE_GetUnit({ guid = JAM })
      if prowler and not jammed[k] and prowler.condition == 'Airborne' and prowler.jammer == true then
        local distance = Tool_Range(k, JAM)
        local bearing = Tool_Bearing(JAM, k)
        local heading = SE_GetUnit({ guid = JAM }).heading
        local orientation = math.abs(bearing - heading)
        if distance < math.random(75, 100) and orientation < math.random(12, 18) then
          local OODA = bL3.Units.SERB.OODA[k].OODA
          local bonif = math.floor((100 - distance / 10) + 0.9)
          jammed[k] = true
          local unit = SE_GetUnit({ guid = k })
          unit.OODA = { detection = OODA.detection * (1 + math.random(1, 3) / 10) + bonif, targeting = OODA.targeting *
          (1 + math.random(1, 3) / 10) + bonif, evasion = OODA.evasion }
        end
      end
      if n == #EW_JAMMERS and jammed[k] == nil then
        local unit = SE_GetUnit({ guid = k })
        if not unit then
          bL3.Units.SERB.OODA[k] = nil
        else
          local OODA = bL3.Units.SERB.OODA[k].OODA
          unit.OODA = OODA
        end
      end
    end
    -- local timetaken = (os.clock() - starttime) * 1000;
    -- print(string.format('Prowler Jammer timetaken (ms): %.6f',timetaken));
  end
  gKH.State.SaveTableToKey(bL3.Units, 'UNITS')
end

function bL3.Functions.RegularOneMin()
  -- local starttime = os.clock()
  bL3.Functions.COMM_JAMMING_SERBIA()
  -- local timetaken = (os.clock() - starttime) * 1000;
  -- print(string.format('Jamming SERB (ms): %.6f',timetaken));
  -- local starttime = os.clock()
  bL3.Functions.JAMMING_US()
  -- local timetaken = (os.clock() - starttime) * 1000;
  -- print(string.format('Jamming US (ms): %.6f',timetaken));
end

function bL3.Functions.UpdateTargetList()
  local missions = ScenEdit_GetMissions(bL3.Sides.US)
  if missions == nil then return 0 end
  local land_missions = {}
  table.insert(land_missions, 'Nan')
  for k, v in pairs(missions) do
    if v.subtype == 'Land Strike' then
      table.insert(land_missions, v.name)
      local targets = v.targetlist
      for _, tc in ipairs(targets) do
        local contact = ScenEdit_GetContact({ guid = tc, side = bL3.Sides.US })
        if contact then
          local target_id = contact.actualunitid
          if string.match(target_id, 'TARGET#') then
            bL3.Units.SERB.Targets[target_id].mission = v.name
            if contact.BDA and contact.BDA.STRUCTURAL then
              bL3.Units.SERB.Targets[target_id].BDA = contact.BDA.STRUCTURAL
            else
              if bL3.Units.SERB.Targets[target_id].BDA ~= 'Unknown' then
                bL3.Units.SERB.Targets[target_id].BDA = bL3.Units.SERB.Targets[target_id].BDA
              else
                bL3.Units.SERB.Targets[target_id].BDA = 'Unknown'
              end
            end
          end
        end
      end
    end
  end
  return land_missions
end

function U2EntersBunkerArea()
  if not bL3.Variables.Bunker then
    local script = [[local bunker = SE_GetUnit({guid=bL3.Units.SERB.IADS.HQ})
    SE_SetUnit({guid=bunker.guid, autodetectable=true})
    bL3.msg.bunker_spotted(bunker,2)
    bL3.Variables.Bunker = true]]
    local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + math.random(50, 120) * 60)
    bL3.AuxFunctions.TimeEvent('BunkerSpotted', time, script, 'add', false)
    bL3.Variables.Bunker = true
  end
end

function bL3.Functions.FiveMin()
  if math.random() > 0.7 then
    local detected = bL3.Functions.GetSIGINT(bL3.Units.SERB.IADS.HQ, 'C3 IADS')
    if detected and not bL3.Variables.Bunker then
      bL3.Variables[bL3.Sides.US].SIGINT = bL3.Variables[bL3.Sides.US].SIGINT + 1
      if bL3.Variables[bL3.Sides.US].SIGINT > 50 then
        local bunker = SE_GetUnit({ guid = bL3.Units.SERB.IADS.HQ })
        SE_SetUnit({ guid = bunker.guid, autodetectable = true })
        bL3.msg.bunker_spotted(bunker, 1)
        bL3.Variables.Bunker = true
        -- bL3.AuxFunctions.RemoveEvent('Regular 5min')
      end
    else
      if bL3.Variables[bL3.Sides.US].SIGINT > 40 then
        bL3.Variables[bL3.Sides.US].SIGINT = bL3.Variables[bL3.Sides.US].SIGINT - 1
      end
    end
  end
  gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
  for k, v in ipairs(bL3.Units.SERB.SIGINT) do
    if math.random() > 0.85 then
      local a = bL3.Functions.GetSIGINT(v.guid, v.emission_type)
      if a == 0 then
        table.remove(bL3.Units.SERB.SIGINT, k)
      end
    end
  end
end

function bL3.Functions.GetSIGINT(enemy_unit, notification, data)
  if not data then data = {} end
  local R = data.R or 200
  local G = data.G or 150
  local B = data.B or 0
  local lifeTime = data.lifeTime or 4
  local fontSize = data.fontSize or 16
  if enemy_unit.guid == nil then
    enemy_unit = SE_GetUnit({ guid = enemy_unit })
    if not enemy_unit then
      print("SIGINT: Enemy Unit does not exists -> " .. enemy_unit)
      return 0
    end
  end
  local function getY(x)
    if x <= 60 then
      return 1
    elseif x >= math.random(300, 340) then
      return 0
    else
      return 2.71 ^ ((-math.log(0, 03 * x) / 450) * x ^ 0.8)
    end
  end
  local function getD(x)
    return (0.00007937 * x ^ 3.8518) * 10 ^ -6.1 + (math.random(-120 * x ^ 1.8 / 15000, 120 * x ^ 1.8 / 15000) / 10 ^ 5 * (x ^ 2.25 / 10 ^ 2.4))
  end
  for k, elint_guid in ipairs(bL3.Units.US.SIGINT) do
    local elint_u = SE_GetUnit({ guid = elint_guid })
    local distance = Tool_Range(enemy_unit.guid, elint_guid)
    if elint_u and elint_u.condition == 'Airborne' and math.random() < getY(distance) then
      local latitude = enemy_unit.latitude + getD(distance) + math.random() / 10000
      local longitude = enemy_unit.longitude + getD(distance) + math.random() / 10000
      ScenEdit_CreateBarkNotification_Geo(longitude, latitude, notification, R, G, B, false, false, lifeTime, fontSize)
      return true
    end
  end

  return false
end

function bL3.Functions.GetEnemyContacts(area)
  local contacts = ScenEdit_GetContacts(bL3.Sides.SERB)
  local enemy_units = {}
  if contacts == nil then return 0 end
  for k, v in ipairs(contacts) do
    local c = ScenEdit_GetContact({ guid = v.guid, side = bL3.Sides.SERB })
    if c ~= nil and v.type == 'Air' and c:inArea(area) then
      c.posture = 'H'
      table.insert(enemy_units, c.guid)
    end
  end
  return #enemy_units, enemy_units
end

function bL3.Functions.GetCloseAB()
  local min_distance = 1000
  local ab, hq
  local contacts = VP_GetSide({ side = bL3.Sides.SERB }):contactsBy('Aircraft')
  if contacts then
    local num_contacts = 0
    local lat_agg = 0
    local lon_agg = 0
    for k, v in ipairs(contacts) do
      local c = ScenEdit_GetContact({ side = bL3.Sides.SERB, guid = v.guid })
      if c == nil then goto nextContact end
      lat_agg = lat_agg + c.latitude
      lon_agg = lon_agg + c.longitude
      num_contacts = num_contacts + 1
      ::nextContact::
    end
    local lat_med = lat_agg / num_contacts
    local lon_med = lon_agg / num_contacts
    for k, v in pairs(bL3.Units.SERB.Airbases) do
      local u = SE_GetUnit({ name = v.airbase, side = bL3.Sides.SERB })
      if u ~= nil and min_distance > Tool_Range({ latitude = lat_med, longitude = lon_med }, u.guid) then
        min_distance = Tool_Range({ latitude = lat_med, longitude = lon_med }, u.guid)
        ab = u.name
        hq = v.HQ
      end
    end

    return ab, hq
  end
  return 0
end

function bL3.Functions.Contact()
  local contact = ScenEdit_UnitC()
  local detector = ScenEdit_UnitY()

  if contact == nil or detector == nil then return 0 end
  if bL3.Variables.LastContact == nil then
    bL3.Variables.LastContact = ScenEdit_CurrentTime()
  else
    if bL3.Variables.LastContact - ScenEdit_CurrentTime() < 120 then return 0 end
  end
  bL3.Functions.GetSIGINT(contact, 'DATA TX', { R = 125, G = 255, B = 0 })
  -- local contactWr = ScenEdit_GetContact({side=bL3.Sides.SERB, guid=contact.guid})
  -- if not contactWr then return 0 end
  -- local unit = SE_GetUnit({guid=contactWr.actualunitid})
end

function bL3.Functions.ClearSkies()
  local COMPLEXITY = bL3.Variables.Complexity
  local enemy_contacts_inarea = bL3.Functions.GetEnemyContacts(bL3.AREAS.SERB) +
  bL3.Functions.GetEnemyContacts(bL3.AREAS.KOS) + bL3.Functions.GetEnemyContacts(bL3.AREAS.MON)
  if enemy_contacts_inarea >= 2 then
    bL3.Variables.ClearSkies = true
    gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
    ScenEdit_SetSidePosture(bL3.Sides.SERB, bL3.Sides.US, 'H')
    ScenEdit_SetSidePosture(bL3.Sides.SERB, bL3.Sides.USN, 'H')
    local mission = ScenEdit_AddMission(bL3.Sides.SERB, 'Interception ' .. bL3.AuxFunctions.RandomTxt(3), 'strike',
      { type = 'air' })
    ScenEdit_SetMission(bL3.Sides.SERB, mission.name,
      { FlightSize = 2, StationAltitudeAircraft = 2000, StrikeMaxDistAircraft = 100 })
    ScenEdit_SetDoctrine({ mission = mission.name, side = bL3.Sides.SERB },
      { engage_opportunity_targets = true, weapon_control_status_air = 0 })
    for k, v in pairs(bL3.Units.SERB.Airbases) do
      bL3.Functions.GetSIGINT(v.HQ, 'Airbase HIGH Activity', { R = 255, G = 0, B = 0, lifeTime = 8, fontSize = 20 })
      local units = v.units
      local c = 0
      for _, unit in ipairs(units) do
        if unit.mission == nil and c <= 6 * COMPLEXITY then
          ScenEdit_AssignUnitToMission(unit, mission.name)
          c = c + 1
        end
      end
      if c == 6 then break end
    end
    bL3.AuxFunctions.RemoveEvent('Clear Skies')
    local time = os.date("%d/%m/%Y %H:%M:%S", ScenEdit_CurrentTime() + 3 * 60 * 60)
    local luascript =
    [[bL3.AuxFunctions.RemoveEvent('Clear Skies TE') bL3.AuxFunctions.RegularEvent('Clear Skies', 6, 'bL3.Functions.ClearSkies()', 'add') ScenEdit_DeleteMission (bL3.Sides.SERB, %s)]]
    luascript = string.format(luascript, mission.name)
    bL3.AuxFunctions.TimeEvent('ClearSkies TE', time, luascript, 'add', false)
  end
end

function bL3.Functions.CheckInterception()
  bL3.AuxFunctions.RemoveEvent('CheckInterception')
  local enemy_contacts_inarea = bL3.Functions.GetEnemyContacts(bL3.AREAS.SERB) +
  bL3.Functions.GetEnemyContacts(bL3.AREAS.KOS)

  if enemy_contacts_inarea < 10 * bL3.Variables.Complexity and enemy_contacts_inarea > 2 then
    local airbase, hq = bL3.Functions.GetCloseAB()
    if airbase ~= 0 then
      local air_units, air_types = bL3.Functions.GetAirUnits(airbase)
      if #air_units >= 4 then
        local mission = ScenEdit_AddMission(bL3.Sides.SERB, 'Interception #' .. bL3.AuxFunctions.RandomTxt(3), 'strike',
          { type = 'air' })
        ScenEdit_SetMission(bL3.Sides.SERB, mission.name,
          { FlightSize = 2, AttackAltitudeAircraft = 2000, StrikeMaxDistAircraft = 100 })
        ScenEdit_SetDoctrine({ mission = mission.name, side = bL3.Sides.SERB },
          { engage_opportunity_targets = true, weapon_control_status_air = 0 })
        bL3.Functions.GetSIGINT(hq, 'Airbase Activity')
        local aircrafts_to_mission = 2 * enemy_contacts_inarea
        if aircrafts_to_mission > 6 * bL3.Variables.Complexity then aircrafts_to_mission = 6 * bL3.Variables.Complexity end
        local aircrafts_assigned = 0
        local complet_assignment = false
        for k, v in pairs(air_types) do
          for i, v1 in ipairs(v) do
            local u = ScenEdit_GetUnit({ guid = v1.guid })
            if u ~= nil then
              ScenEdit_AssignUnitToMission(u.guid, mission.name)
              aircrafts_assigned = aircrafts_assigned + 1
            end
            if aircrafts_to_mission == aircrafts_assigned then
              complet_assignment = true
              break
            end
          end
          if complet_assignment then
            break
          end
        end
        ScenEdit_SetEvent("ContactDetected", { isActive = false })
        bL3.AuxFunctions.RemoveEvent('ActiveC')
      end
    end
  end
end

function bL3.Functions.GetAirUnits(AB)
  local airbase = ScenEdit_GetUnit({ side = bL3.Sides.SERB, name = AB })

  local air_units = {}
  local air_types = {}
  for k, v in ipairs(VP_GetSide({ side = bL3.Sides.SERB }).units) do
    local u = SE_GetUnit({ guid = v.guid })
    if u ~= nil and u.type == 'Aircraft' and u.base ~= nil and u.base.name == airbase.name then
      if air_types[u.classname] == nil then
        air_types[u.classname] = {}
      end
      table.insert(air_types[u.classname], { guid = u.guid, name = u.name })
      table.insert(air_units, u.guid)
    end
  end
  return air_units, air_types
end

-- EXCLUSION ZONE

function bL3.Functions.ExclusionZone()
  local unit = UnitX()
  if unit and bL3.Contacts[unit.guid] then
    local cguid = bL3.Contacts[unit.guid].contact_guid
    local contact = ScenEdit_GetContact({ guid = cguid, side = bL3.Sides.SERB })
    contact.posture = 'H'
  end
end

---Victory Points
function bL3.Functions.FinalScoring()
  local base = 40 * (bL3.Variables.KSAM / bL3.Variables.NSAM)
  local targets = 60 * (bL3.Variables.KTARGETS / bL3.Variables.TARGETS)
  bL3.VP.US = bL3.VP.US + base
  ScenEdit_SetScore(bL3.Sides.US, bL3.VP.US)
end

function bL3.Functions.EndScenario()
  bL3.Functions.FinalScoring()
  bL3.msg.EndScenario(bL3.VP.US)
  ScenEdit_EndScenario()
end

---- SCEN KEYS
bL3.VP = gKH.State.LoadTableFromKey('VP')
bL3.Variables = gKH.State.LoadTableFromKey('VARIABLES')
if bL3.Variables == nil then
  bL3.Variables = {}
  bL3.Variables[bL3.Sides.US] = {}
  bL3.Variables[bL3.Sides.SERB] = {}
  bL3.Variables[bL3.Sides.US].SIGINT = 0
  bL3.VP = { US = 0, SERB = 0 }
  gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
  gKH.State.SaveTableToKey(bL3.VP, 'VP')
end
bL3.Contacts = gKH.State.LoadTableFromKey('CONTACTS') or {}
bL3.Units = gKH.State.LoadTableFromKey('UNITS') or {}
bL3.AREAS.JAMMERS = gKH.State.LoadTableFromKey('JAMMER AREAS') or {}



--TODO
-- Intelligence Report based in detected contacts and SIGINT level to show Serbian IADS
-- Coordinate Strikes with USN
