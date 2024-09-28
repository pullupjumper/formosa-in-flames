bL3.AuxFunctions.ImprovedRandomseed(3)

local function DifficultSelector()
    local trys = 0
    local complexity
    ::redoInput::
    complexity = ScenEdit_InputBox(
    "Enter a complexity level:\n\n\r1 - Easy \n\n\r2 - Normal \n\n\r3 - Hard \n\n\rType 1, 2 or 3:")

    if complexity ~= "1" and complexity ~= "2" and complexity ~= "3" and trys < 4 then
        trys = trys + 1
        goto redoInput
    else
        return tonumber(complexity)
    end
    -- DIFICULTAD POR DEFECTO
    complexity = "2"
    return tonumber(complexity)
end
local COMPLEXITY = DifficultSelector()
bL3.Variables.Complexity = COMPLEXITY
gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
--[[
  Serbia tablas:

  - Jammers -> Calculo de penalización en comunicaciones enemigas
  - SAMs y Radares -> Calculo de jamming/comm jamming enemigo
  - SAMs sectores -> Movilidad SAM
  - IADS -> Acciones al perder unidades
]]

--[[

Organizacion IADS serbia.

1. HQ que gobierna sobre todos los sectores
2. Para cada sector hay:
    + Uno o dos SAM
    + Uno o dos EW
    + Una unidad de comunicaciones
    + Un C2

]]

local COMPLEXITY = bL3.Variables.Complexity
local yugoslavia_aaa = { dbid = 2574, name = 'AAA Sec (40mm/70 Bofors x 2)' }
local yugoslavia_sensors_id = {
    { dbid = 966, name = 'Long Track [P-40]' },
    { dbid = 5623, name = 'S-605' },
    { dbid = 3290, name = 'S-613 HF' },
    { dbid = 2697, name = 'Flat Face B [P-19]' }
}
local antennas = { 3295, 3312, 3313, 3314, 3315, 3316 }
local civ_infrastructure = { 17, 101, 115, 164, 318, 319 }
local yugoslavia_mobile_sensors = {
    { dbid = 2561, name = 'Radar (AN/TPS-70)' },
    { dbid = 2565, name = 'Radar (Long Track [P-40])' },
    { dbid = 2567, name = 'Radar (Thin Skin B HF [PRV-16])' },
    { dbid = 2569, name = 'Radar (Spoon Rest D [P-18])' },
    { dbid = 2575, name = 'Radar (Giraffe 75 [M-85 Zirafa])' },
    { dbid = 2578, name = 'Radar (Dog Ear [9S80])' },
}

local function CreateAreaAroundSam(SAM, radius)
    -- AREA WHEN SAM LAUNCH MISSILES
    local area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
        { shape = 'circle', side = SAM.side, distance = 3, name = 'SA' })
    if type(area) ~= "table" then return 0 end
    local target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.SERB }).guid, TargetType = 6 }
    bL3.AuxFunctions.UnitEntersAreaEvent('SAM Fires-' .. SAM.guid, target_type, area,
        'bL3.Functions.SAM_Fires("' .. SAM.guid .. '")', 'add', false, true, false)

    bL3.Units.SERB.OODA[SAM.guid].areaW = area

    -- AREA WHEN MISSILE IT'S LAUNCH AGAINST THE SAM
    area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
        { shape = 'circle', side = SAM.side, distance = 10, name = 'SP' })
    if type(area) ~= "table" then return 0 end
    target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.US }).guid, TargetType = 6 }
    bL3.AuxFunctions.UnitEntersAreaEvent('SAM HARM-' .. SAM.guid, target_type, area,
        'bL3.Functions.SAM_HARM("' .. SAM.guid .. '")', 'add', false, true, false)

    bL3.Units.SERB.OODA[SAM.guid].areaHARM = area

    -- AREA TO SPOT THE SAM ONCE THE
    area = bL3.AuxFunctions.NewArea({ latitude = SAM.latitude, longitude = SAM.longitude },
        { shape = 'circle', side = SAM.side, distance = 25, name = 'SP' })
    if type(area) ~= "table" then return 0 end
    target_type = { TargetSide = VP_GetSide({ side = bL3.Sides.US }).guid, TargetType = 1 }
    bL3.AuxFunctions.UnitEntersAreaEvent('SAM SPOT-' .. SAM.guid, target_type, area,
        'bL3.Functions.SAM_SPOT("' .. SAM.guid .. '")', 'add', false, false, true)
    bL3.Units.SERB.OODA[SAM.guid].radius = radius
end
local function RemoveMounts(unit, t_Mounts)
    bL3.AuxFunctions.RemoveMounts(unit, t_Mounts)
end
local function SA3_radar(insert)
    -- SAM Bn (SA-3b Goa [S-125M Pechora])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 1617, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1600] = 1 })

    -- SA-7a Grail [9K32 Strela-2] MANPADS
    if math.random() > 0.6 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1479 })
    end
    -- Vehicle (Flat Face B [P-19]) -> Flat Face B [P-19]:Radar, Air Search, 2D Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1600})
    return unit
end
local function SA3(insert)
    -- SAM Bn (SA-3b Goa [S-125M Pechora])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 1617, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1599] = 1, [1600] = 1 })
    -- SA-3b Goa Quad Rail
    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 320 })
    if math.random() > 0.2 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 320 })
    end
    -- SA-7a Grail [9K32 Strela-2] MANPADS
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1479})
    -- Vehicle (Low Blow [SNR-125]) -> Low Blow [SNR-125]:Radar Illuminator, Medium-Range | SA-3 TV Camera:Visual, Target Tracking and Identification TV Camera
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1599})
    -- Vehicle (Flat Face B [P-19]) -> Flat Face B [P-19]:Radar, Air Search, 2D Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1600})
    return unit
end
local function SA2_radar(insert)
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 1620, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    -- RemoveMounts(unit,{[1120]=1,[1597]=1})
    -- SA-2b Guideline Single Rail
    if math.random() > 0.5 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1479 })
    end
    -- Vehicle (Spoon Rest C [P-12]) -> Spoon Rest C [P-12]:Radar, Air Search, 2D Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1120})
    -- Vehicle (Fan Song C [SNR-75M]) -> Fan Song C [SNR-75]:Radar Illuminator, Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1597})
    return unit
end
local function SA2(insert)
    -- SAM Bn (SA-2b Guideline [S-75 Dvina])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 1620, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1120] = 1, [1597] = 1 })
    -- SA-2b Guideline Single Rail
    for k = 1, math.random(2, 4) do
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 118 })
    end
    if math.random() > 0.2 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 118 })
    end
    -- SA-7a Grail [9K32 Strela-2] MANPADS
    if math.random() > 0.8 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1479 })
    end
    -- Vehicle (Spoon Rest C [P-12]) -> Spoon Rest C [P-12]:Radar, Air Search, 2D Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1120})
    -- Vehicle (Fan Song C [SNR-75M]) -> Fan Song C [SNR-75]:Radar Illuminator, Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1597})
    return unit
end
local function SA2d(insert)
    -- SAM Bn (SA-2f Guideline [S-75M Volkhov])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 1621, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1120] = 1, [1596] = 1 })
    -- SA-2f Guideline Mod 1 Single Rail
    for k = 1, math.random(2, 4) do
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 321 })
    end
    if math.random() > 0.2 then
        -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=321})
    end
    -- SA-7a Grail [9K32 Strela-2] MANPADS
    if math.random() > 0.8 then
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1479 })
    end

    -- Vehicle (Spoon Rest C [P-12]) -> Spoon Rest C [P-12]:Radar, Air Search, 2D Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_track ={360},arc_detect ={360} dbid=1120})
    -- Vehicle (Fan Song F [RSNA-75M]) -> SA-2 TV Camera:Visual, Target Tracking and Identification TV Camera | Fan Song F [SNR-75M]:Radar Illuminator, Medium-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1596})
    return unit
end

local function SA6a(insert)
    -- SAM Bn (SA-6a Gainful [2K12E Kvadrat, Kub-M Upgrade])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 2572, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1602] = 1 })

    -- SA-6a Gainful [2P25] TEL
    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 313 })
    -- Vehicle (Straight Flush [1S91]) -> Straight Flush [TV Camera]:Visual, Target Tracking and Identification TV Camera | Straight Flush [1S91]:Radar, FCR, Surface-to-Air, Short-Range
    -- ScenEdit_UpdateUnit({guid = unit.guid, mode='add_mount',arc_mount ={360}, dbid=1602})
    return unit
end

local function SA9(insert)
    -- SAM Plt (SA-9b Gaskin [9K31 Strela-1])
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 2580, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [951] = 1 })
    -- SA-9b Gaskin [BRDM-2] TEL 2 -> Generic TV Camera:Visual, Target Tracking and Identification TV Camera
    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 951 })
    return unit
end

local function SA18(insert)
    -- SAM Sec (SA-18 Grouse [9K38 Igla] MANPADS x 3)
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 2584, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1483] = 1 })
    -- SA-18 Grinch [9K38 Igla] MANPADS
    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1483 })
    return unit
end

local function SA11(insert)
    -- SAM Sec (SA-11 Grouse [9K38 Igla] MANPADS x 3)
    local unit = ScenEdit_AddUnit({ type = 'Facility', side = insert.side, name = insert.name, guid = insert.guid, dbid = 2584, latitude =
    insert.latitude, longitude = insert.longitude, autodetectable = false })
    if unit == nil then return nil end
    RemoveMounts(unit, { [1483] = 1 })
    -- SA-18 Grinch [9K38 Igla] MANPADS
    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', arc_mount = { 360 }, dbid = 1483 })
    return unit
end
local function MobSAM(insert)
    local randomNum = math.random(5)
    local unit
    local radius
    if randomNum <= 3 then
        unit = SA9(insert)
        radius = 6
    elseif randomNum == 4 then
        unit = SA11(insert)
        radius = 15
    elseif randomNum == 5 then
        unit = SA18(insert)
        radius = 4
    end
    return unit, radius
end
local function RandomSAM(insert)
    local randomNum = math.random()
    local unit
    local radius
    if randomNum <= 0.8 then
        unit = SA3(insert)
        radius = 20
    elseif randomNum <= 1 then
        unit = SA2d(insert)
        radius = 15
    end
    return unit, radius
end

-- ScenEdit_RunScript('/Development/First-Night-Kosovo/Airbases.lua')
bL3.Functions.CreateAirbases()


local montenegro_coordinates = {
    { latitude = 43.045527040094, longitude = 19.2149805753702 },
    { latitude = 42.13047179572, longitude = 19.2004181458571 },
    { latitude = 42.7213637996029, longitude = 19.8701080466463 },
    { latitude = 42.2851748282149, longitude = 19.2132068866905 },
    { latitude = 42.7073548790602, longitude = 19.3765461919795 },
    { latitude = 43.0692565862761, longitude = 19.0763724177526 },
    { latitude = 42.7814423768419, longitude = 19.1691106519237 }
}

local serbia_coordinates = {
    -- {latitude=45.5176473046837, longitude=19.8945055671557},
    -- {latitude=44.7234278855653, longitude=20.3791596331677},
    { latitude = 43.3937412066182, longitude = 21.2167722981362 },
    { latitude = 43.9574505556607, longitude = 21.2570523735141 },
    { latitude = 43.1669434322907, longitude = 20.789242774796 },
    { latitude = 43.5015182978803, longitude = 20.6387663539705 },
    { latitude = 44.5922794459422, longitude = 20.2673970865773 },
    { latitude = 43.0807219757896, longitude = 20.2829904517667 },
    { latitude = 43.3657855746591, longitude = 21.1320146409326 },
    { latitude = 43.5229868079384, longitude = 21.0032787191399 },
    { latitude = 43.3229868079384, longitude = 21.0032787191399 },
    { latitude = 43.298588668926, longitude = 20.1003329113996 },
    { latitude = 43.5182184736274, longitude = 21.1654391698144 }
}

--Create Serbia General HQ
local function AddHQ()
    ::redoP::
    local point = serbia_coordinates[math.random(#serbia_coordinates)]
    local area = bL3.AREAS.SERB
    local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
        { maxDistance = 15, mode = 1, area = area, side = bL3.Sides.SERB })
    if p1 == nil then
        print("HQ point nil")
        goto redoP
    end
    local HQID = 'HQSERBAD#' .. bL3.AuxFunctions.RandomTxt(2)
    bL3.Units.SERB.IADS['SECTOR ' .. HQID] = {}
    bL3.Units.SERB.IADS['SECTOR ' .. HQID].C2 = HQID
    local guid = HQID .. '-SERB-IADS'
    local name = 'BUNK#' .. bL3.AuxFunctions.RandomTxt(2)
    local HQ = ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
    name, side = bL3.Sides.SERB, dbid = 177, latitude = p1.latitude, longitude = p1.longitude, guid = guid, autodetectable = false })
    bL3.Variables.Bunker = false
    bL3.Units.SERB.IADS.HQ = guid
    local hqarea = bL3.AuxFunctions.NewArea({ latitude = HQ.latitude, longitude = HQ.longitude },
        { shape = 'circle', side = HQ.side, distance = 0.8, name = 'HQ' })
    if type(hqarea) ~= "table" then return 0 end
    local filter = { TargetSide = VP_GetSide({ side = bL3.Sides.US }).guid, TargetType = 1, SpecificUnitClass = 821 }
    bL3.AuxFunctions.UnitEntersAreaEvent('U2EntersBunkerArea', filter, hqarea, 'U2EntersBunkerArea()', 'add', false,
        false, true)
    table.insert(bL3.Units.SERB.SIGINT, { guid = HQ.guid, emission_type = 'C2', detected = 0 })
    name = 'ELE#' .. bL3.AuxFunctions.RandomTxt(4)
    local id = name .. '-SERB-' .. HQID
    ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
    name, side = bL3.Sides.SERB, guid = id, dbid = 164, latitude = p1.latitude +
    bL3.AuxFunctions.RandomFloat(-1, 1, 5) * 10 ^ -4, longitude = p1.longitude +
    bL3.AuxFunctions.RandomFloat(-1, 1, 5) * 10 ^ -4, autodetectable = false })
    for i = 1, math.random(1, 3) do
        local pantenna = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude, { maxDistance = 2, mode = 1 })
        if pantenna == nil then
            print("Antenna MON HQ nil")
            return
        end
        id = 'ANN#' .. bL3.AuxFunctions.RandomTxt(5)
        guid = name .. '-SERB-' .. HQID
        table.insert(bL3.Units.SERB.SIGINT, { guid = 'SERB-SERBAD-' .. HQID .. '-' .. id, emission_type = 'COMM', detected = 0 })
        ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
        id, side = bL3.Sides.SERB, dbid = antennas[math.random(#antennas)], guid = 'SERB-SERBAD-' .. HQID .. '-' .. id, latitude =
        pantenna.latitude, longitude = pantenna.longitude, autodetectable = false })
        --OOB.COMMS['id'] = {parent=HQID, type='Communitaction', subtype='Anntena'}
    end
    --ADD Comms Center
    name = 'COMMFAC#' .. bL3.AuxFunctions.RandomTxt(8)
    guid = name .. '-SERB-' .. HQID
    name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(4)
    local comm_facility = ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.SERB, name = name, guid = guid, dbid = 615, latitude =
    p1.latitude + math.random() / 100, longitude = p1.longitude + math.random() / 100, autodetectable = false })
    bL3.Units.SERB.IADS['SECTOR ' .. HQID].COMMS = guid
    table.insert(bL3.Units.SERB.SIGINT, { guid = comm_facility.guid, emission_type = 'Comm', detected = 0 })
    --ADD Defense Points for HQ
    bL3.Units.SERB.IADS['SECTOR ' .. HQID].RADAR = {}
    bL3.Units.SERB.IADS['SECTOR ' .. HQID].SAMS = {}
    for i = 1, math.random(1, 2) do
        local pAAA = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
            { maxDistance = 1, mode = 1, area = area, side = bL3.Sides.SERB })
        if pAAA == nil then
            print("EW Sites MON nil")
            return
        end
        id        = 'AAA#' .. bL3.AuxFunctions.RandomTxt(7)
        local aaa = ScenEdit_AddUnit({ side = bL3.Sides.SERB, guid = id .. '-SERB-' .. HQID, type = 'Facility', name =
        'MOB#' .. bL3.AuxFunctions.RandomTxt(4), dbid = 2574, latitude = pAAA.latitude, longitude = pAAA.longitude })
        aaa.OODA  = bL3.Functions.GetOODA('SAM')
        --ADD SAMS
        for x = 1, math.random(COMPLEXITY + 1) do
            local insert = { side = bL3.Sides.SERB, latitude = 0, longitude = 0 }
            id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(6)
            insert.guid = id .. '-SERB-' .. HQID
            insert.name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
            local position = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude, { maxDistance = 10, mode = 1 })
            if position == nil then
                print("Fallo creando posicion SAM HQ")
                break
            end
            insert.latitude = position.latitude
            insert.longitude = position.longitude
            local rand = bL3.AuxFunctions.RandomFloat(0, 1, 3)
            local SAM
            if rand < 0.4 then
                SAM = SA6a(insert)
            elseif rand < 0.7 then
                SAM = SA9(insert)
            else
                SAM = SA18(insert)
            end
            if SAM == nil then
                print("SAM Point Defense nil")
                return 0
            end
            bL3.Variables.NSAM = bL3.Variables.NSAM + 1
            table.insert(bL3.Units.SERB.IADS['SECTOR ' .. HQID].SAMS, SAM.guid)
            bL3.Units.SERB.OODA[SAM.guid] = {
                type = 'SAM',
                comms_level = 30,            -- Nivel de comunicación de la unidad actualmente
                comms_base = 30,             -- Nivel mínimo de comunicación de la unidad
                comms_threshold = 30,        -- Nivel de la capacidad de transmitir información de la unidad
                outofcomms = 0,              -- Tiempo que la unidad ha estado out of comms
                OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                jam_level = 0,               -- Jam actual de la unidad
                jam_time = 0,
                jam_threshold = 20,          -- Capacidad de soportar Jamming de la unidad
                jam_capacity = 0,            -- Capacidad de Jam de la unidad
                EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                latitude = SAM.latitude,
                longitude = SAM.longitude,
                Fires = 0
            }
            CreateAreaAroundSam(SAM, 10)
            SAM.OODA = bL3.Functions.GetOODA('SAM')
            SE_SetUnit({ guid = SAM.guid, latitude = 60.2811118732958, longitude = 99.2867466774299 })
        end
    end
    for i = 1, 2 do
        local insert = { side = bL3.Sides.SERB, latitude = 0, longitude = 0 }
        local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
            { maxDistance = 4, mode = 1, side = bL3.Sides.SERB, area = area })
        if p == nil then
            print("HQ point nil")
            return 0
        end
        local id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(8)
        insert.guid = id .. '-SERB-' .. HQID
        table.insert(bL3.Units.SERB.IADS['SECTOR ' .. HQID].SAMS, insert.guid)
        insert.name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
        insert.latitude = p.latitude
        insert.longitude = p.longitude
        local SAM = MobSAM(insert)
        if SAM then
            bL3.Variables.NSAM = bL3.Variables.NSAM + 1
            bL3.Units.SERB.OODA[SAM.guid] = {
                type = 'SAM',
                comms_level = 30,            -- Nivel de comunicación de la unidad actualmente
                comms_base = 30,             -- Nivel mínimo de comunicación de la unidad
                comms_threshold = 30,        -- Nivel de la capacidad de transmitir información de la unidad
                outofcomms = 0,              -- Tiempo que la unidad ha estado out of comms
                isOutOfComms = false,
                OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                jam_level = 0,
                jam_time = 0,                -- Jam actual de la unidad
                jam_threshold = 80,          -- Capacidad de soportar Jamming de la unidad
                jam_capacity = 0,            -- Capacidad de Jam de la unidad
                EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                latitude = SAM.latitude,
                longitude = SAM.longitude,
                Fires = 0,
            }
            -- CreateAreaAroundSam(SAM,math.random(5,8))
            SAM.OODA = bL3.Functions.GetOODA('SAM')
            -- SE_SetUnit({guid=SAM.guid, latitude=60.2811118732958, longitude=99.2867466774299})
        end
    end
    -- ADD JAMMER
    local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
        { maxDistance = 2, mode = 1, area = area, side = bL3.Sides.SERB })
    id = 'JAM#' .. bL3.AuxFunctions.RandomTxt(8)
    local name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
    local jam = ScenEdit_AddUnit({ side = bL3.Sides.SERB, type = 'Facility', name = name, guid = id .. '-SERB-' .. HQID, dbid = 2394, latitude =
    p.latitude, longitude = p.longitude, autodetectable = false })
    table.insert(bL3.Units.SERB.JAMMERS, jam.guid)
    ScenEdit_SetUnitIntermittentEmissionConfig(jam.guid, 'CUSTOM',
        { UseEmissionInterval = 1, EmissionDuration = math.random(30, 60), EmissionInterval = 120, EmissionIntervalVariation =
        math.random(30, 120), WakeStance_HOSTILE = 0 })
    jam.UseCustomIntermittentEmissionOnly = true
    ScenEdit_SetEMCON('unit', jam.guid, 'OECM=Active')
end
AddHQ()


-- Sector controls
local function SectorControls(coordinates)
    bL3.Units.SERB.SC = {}
    local area = bL3.AREAS.SERB
    local GHQ = bL3.AuxFunctions.split(bL3.Units.SERB.IADS.HQ, '-')[1]
    local coor = coordinates
    local num_sc
    if COMPLEXITY == 1 then num_sc = math.random(1, 3) elseif COMPLEXITY == 2 then num_sc = math.random(2, 4) else num_sc =
        math.random(2, 5) end
    bL3.Variables.SectorControl = num_sc
    for i = 1, num_sc do
        ::redoSC::
        local r = math.random(#coor)
        local point = serbia_coordinates[r]
        table.remove(coor, r)
        local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
            { maxDistance = 15, mode = 1, area = area, side = bL3.Sides.SERB })
        if p1 == nil then
            print("SC point nil")
            goto redoSC
        end
        local C2_ID = 'C2#' .. bL3.AuxFunctions.RandomTxt(3)
        table.insert(bL3.Units.SERB.SC, C2_ID)
        bL3.Units.SERB.IADS['SECTOR ' .. C2_ID] = {}
        --Add Sector Control C2
        local guid = C2_ID .. '-SERB-' .. GHQ
        local HQ = ScenEdit_AddUnit({
            type = 'Facility',
            AI_EvaluateTargets_enabled = false,
            AI_DeterminePrimaryTarget_enabled = false,
            name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(6),
            side = bL3.Sides.SERB,
            dbid = 3735
            ,
            latitude = p1.latitude,
            longitude = p1.longitude,
            guid = guid,
            autodetectable = false
        })
        bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].C2 = HQ.guid
        table.insert(bL3.Units.SERB.SIGINT, { guid = HQ.guid, emission_type = 'C2', detected = 0 })

        --Add Sector Control Comms
        local name = 'COMMFAC#' .. bL3.AuxFunctions.RandomTxt(8)
        guid = name .. '-SERB-' .. C2_ID .. '-' .. GHQ
        name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(4)
        local comm_facility = ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.SERB, name = name, guid = guid, dbid = 615, latitude =
        p1.latitude + math.random() / 100, longitude = p1.longitude + math.random() / 100, autodetectable = false })
        bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].COMMS = guid
        table.insert(bL3.Units.SERB.SIGINT, { guid = comm_facility.guid, emission_type = 'Comm', detected = 0 })
        --Add Sector Control Fixed SAMs
        bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].SAMS = {}

        for k = 1, math.random(COMPLEXITY) do
            local insert = { side = bL3.Sides.SERB, latitude = 0, longitude = 0 }
            local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
                { maxDistance = 35, mode = 1, area = area, side = bL3.Sides.SERB })
            if p == nil then
                print("HQ point nil")
                return 0
            end
            local id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(8)
            insert.guid = id .. '-SERB-' .. C2_ID .. '-' .. GHQ
            insert.name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(8)
            insert.latitude = p.latitude
            insert.longitude = p.longitude
            local SAM = RandomSAM(insert)
            if SAM then
                table.insert(bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].SAMS, insert.guid)
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                bL3.Units.SERB.OODA[SAM.guid] = {
                    type = 'SAM',
                    comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                    isOutOfComms = false,
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,
                    jam_time = 0,              -- Jam actual de la unidad
                    jam_threshold = 20,        -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,          -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = SAM.latitude,
                    longitude = SAM.longitude,
                    Fires = 0,
                }
                -- CreateAreaAroundSam(SAM,math.random(5,25))
                SAM.OODA = bL3.Functions.GetOODA('SAM')
                -- SE_SetUnit({guid=SAM.guid, latitude=60.2811118732958, longitude=99.2867466774299})
            end
        end
        --Add MOB SAMs
        for k = 1, math.random(COMPLEXITY, COMPLEXITY + 3) do
            local id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(5)
            guid = id .. '-SERB-' .. C2_ID .. '-' .. GHQ
            local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
                { maxDistance = 25, mode = 1, area = area, side = bL3.Sides.SERB })
            local SAM
            if math.random() > 0.5 then
                SAM = ScenEdit_AddUnit({ type = 'Facility', name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(6), side = bL3
                .Sides.SERB, dbid = 2562, latitude = p.latitude, longitude = p.longitude, guid = guid, autodetectable = false })
            else
                SAM = ScenEdit_AddUnit({ type = 'Facility', name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(6), side = bL3
                .Sides.SERB, dbid = 133, latitude = p.latitude, longitude = p.longitude, guid = guid, autodetectable = false })
            end
            if SAM then
                table.insert(bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].SAMS, SAM.guid)
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                bL3.Units.SERB.OODA[SAM.guid] = {
                    type = 'SAM',
                    comms_level = 30,            -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,             -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,        -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,              -- Tiempo que la unidad ha estado out of comms
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,               -- Jam actual de la unidad
                    jam_time = 0,
                    jam_threshold = 20,          -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,            -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = SAM.latitude,
                    longitude = SAM.longitude,
                    Fires = 0
                }
                CreateAreaAroundSam(SAM, 14)
                SAM.OODA = bL3.Functions.GetOODA('SAM')
                SE_SetUnit({ guid = SAM.guid, latitude = 60.2811118732958, longitude = 99.2867466774299 })
            end
        end
        -- Add Jammer
        local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
            { maxDistance = 2, mode = 1, area = area, side = bL3.Sides.SERB })
        id = 'JAM#' .. bL3.AuxFunctions.RandomTxt(4)
        local jam = ScenEdit_AddUnit({ side = bL3.Sides.SERB, type = 'Facility', name = 'MOB#' ..
        bL3.AuxFunctions.RandomTxt(4), guid = id .. '-SERB-' .. C2_ID .. '-' .. GHQ, dbid = 2394, latitude = p.latitude, longitude =
        p.longitude, autodetectable = false })

        table.insert(bL3.Units.SERB.JAMMERS, jam.guid)
        ScenEdit_SetUnitIntermittentEmissionConfig(jam.guid, 'CUSTOM',
            { UseEmissionInterval = 1, EmissionDuration = math.random(30, 60), EmissionInterval = 120, EmissionIntervalVariation =
            math.random(30, 120), WakeStance_HOSTILE = 0 })
        jam.UseCustomIntermittentEmissionOnly = true
        ScenEdit_SetEMCON('unit', jam.guid, 'OECM=Active')
        --Add Sector Control EWs Radar
        bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].RADAR = {}
        for k = 1, math.random(1, COMPLEXITY + 1) do
            p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
                { maxDistance = 30, mode = 1, area = area, side = bL3.Sides.SERB })
            if p == nil then
                print("EWR point nil")
                return 0
            end
            local id = 'EWRAD#' .. bL3.AuxFunctions.RandomTxt(8)
            guid = id .. '-SERB-' .. C2_ID .. '-' .. GHQ
            table.insert(bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].RADAR, guid)
            name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(8)
            local fixed_radar = ScenEdit_AddUnit({ side = bL3.Sides.SERB, guid = guid, type = 'Facility', name = name, dbid = 3818, latitude =
            p.latitude, longitude = p.longitude, autodetectable = false })
            if fixed_radar == nil then
                print("FIXED RADAR BAD ")
                return 0
            end
            ScenEdit_UpdateUnit({ guid = fixed_radar.guid, mode = 'add_sensor', arc_detect = { '360' }, arc_track = { '360' }, dbid =
            yugoslavia_sensors_id[math.random(#yugoslavia_sensors_id)].dbid })
            if fixed_radar then
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                fixed_radar.OODA = bL3.Functions.GetOODA('SAM')
                bL3.Units.SERB.OODA[fixed_radar.guid] = {
                    type = 'RADAR',
                    comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,
                    jam_time = 0,              -- Jam actual de la unidad
                    jam_threshold = 20,        -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,          -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = fixed_radar.latitude,
                    longitude = fixed_radar.longitude,
                }
                ScenEdit_SetUnitIntermittentEmissionConfig(fixed_radar.guid, 'CUSTOM',
                    { UseEmissionInterval = 1, EmissionDuration = math.random(40, 60), EmissionInterval = 240, EmissionIntervalVariation =
                    math.random(60, 120) })
                fixed_radar.UseCustomIntermittentEmissionOnly = true
                ScenEdit_SetEMCON('unit', fixed_radar.guid, "Radar=Active")
            end
        end
        --Add Sector Control MobRadars
        for k = 1, math.random(1, COMPLEXITY + 1) do
            p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
                { maxDistance = 15, mode = 1, area = area, side = bL3.Sides.SERB })
            if p == nil then
                print("HQ point nil")
                return 0
            end
            local id = 'MOBRAD#' .. bL3.AuxFunctions.RandomTxt(8)
            guid = id .. '-SERB-' .. C2_ID .. '-' .. GHQ
            table.insert(bL3.Units.SERB.IADS['SECTOR ' .. C2_ID].RADAR, guid)
            name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
            local mobile_radar = ScenEdit_AddUnit({ side = bL3.Sides.SERB, guid = guid, type = 'Facility', name = name, dbid =
            yugoslavia_mobile_sensors[math.random(#yugoslavia_mobile_sensors)].dbid, latitude = p.latitude, longitude = p
            .longitude, autodetectable = false })
            if mobile_radar then
                mobile_radar.OODA = bL3.Functions.GetOODA('SAM')
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                bL3.Units.SERB.OODA[mobile_radar.guid] = {
                    type = 'RADAR',
                    comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,
                    jam_time = 0,              -- Jam actual de la unidad
                    jam_threshold = 20,        -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,          -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = mobile_radar.latitude,
                    longitude = mobile_radar.longitude,
                }
                ScenEdit_SetUnitIntermittentEmissionConfig(mobile_radar.guid, 'CUSTOM',
                    { UseEmissionInterval = 1, EmissionDuration = math.random(40, 60), EmissionInterval = 240, EmissionIntervalVariation =
                    math.random(60, 120) })
                mobile_radar.UseCustomIntermittentEmissionOnly = true
                ScenEdit_SetEMCON('unit', mobile_radar.guid, "Radar=Active")
            end
        end
    end
end
SectorControls(serbia_coordinates)
local function CreateJamAreas()
    bL3.AREAS.JAMMERS = {}
    local FilterType = { TargetSide = bL3.Sides.US, TargetType = 1 }
    for k, guid in ipairs(bL3.Units.SERB.JAMMERS) do
        local jam = SE_GetUnit({ guid = guid })
        local area = bL3.AuxFunctions.NewArea({ latitude = jam.latitude, longitude = jam.longitude },
            { side = bL3.Sides.SERB, shape = 'circle', distance = math.random(30, 30 * (1 + COMPLEXITY / 10)) })
        if area == nil then
            print("AREA JAMMER SERB NIL")
            return
        end
        bL3.AREAS.JAMMERS[guid] = area
    end
end
CreateJamAreas()
local function Decoys()
    local area = bL3.AREAS.SERB
    local c2_decoys = 0
    local sam_decoys = 0
    for i = 3, math.random(COMPLEXITY + 3, COMPLEXITY + 5) do
        local point = serbia_coordinates[math.random(#serbia_coordinates)]

        if math.random() > 0.3 * c2_decoys then
            local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
                { mode = 1, area = area, side = bL3.Sides.SERB, maxDistance = 100 })
            local guid = 'DECOY#' .. bL3.AuxFunctions.RandomTxt(5)
            c2_decoys = c2_decoys + 1
            ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
            'FIXED#' .. bL3.AuxFunctions.RandomTxt(6), side = bL3.Sides.SERB, dbid = 3735, latitude = p1.latitude, longitude =
            p1.longitude, guid = guid, autodetectable = false })
        end
        if math.random() > 0.2 * sam_decoys / COMPLEXITY then
            local dbid = { 1617, 1620 }
            local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
                { mode = 1, area = area, side = bL3.Sides.SERB, maxDistance = 100 })
            local guid = 'DECOY#' .. bL3.AuxFunctions.RandomTxt(5)
            sam_decoys = sam_decoys + 1
            local unit = ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
            'FIXED#' .. bL3.AuxFunctions.RandomTxt(5), side = bL3.Sides.SERB, dbid = dbid[math.random(2)], latitude = p1
            .latitude, longitude = p1.longitude, guid = guid, autodetectable = false })
            RemoveMounts(unit, {})
        end
        if math.random() > 0.5 then
            local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
                { mode = 1, area = area, side = bL3.Sides.SERB, maxDistance = 70 })
            local guid = 'DECOY#' .. bL3.AuxFunctions.RandomTxt(6)
            ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
            'FIXED#' .. bL3.AuxFunctions.RandomTxt(6), side = bL3.Sides.SERB, dbid = 3818, latitude = p1.latitude, longitude =
            p1.longitude, guid = guid, autodetectable = false })
            if math.random() > 0.5 then
                local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
                    { mode = 1, area = area, side = bL3.Sides.SERB, maxDistance = 40 })
                local guid = 'DECOY#' .. bL3.AuxFunctions.RandomTxt(6)
                ScenEdit_AddUnit({ type = 'Facility', AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, name =
                'FIXED#' .. bL3.AuxFunctions.RandomTxt(6), side = bL3.Sides.SERB, dbid = 615, latitude = p1.latitude, longitude =
                p1.longitude, guid = guid, autodetectable = false })
            end
        end
    end
end
Decoys()
local function MontenegroEW()
    local area = bL3.AREAS.MON
    local coordinates = {
        { latitude = 42.8581690679332, longitude = 19.192632825544 },
        { latitude = 42.7209066184042, longitude = 18.9638463435425 },
        { latitude = 42.8177839467505, longitude = 19.8148815746432 },
        { latitude = 42.2513097628697, longitude = 19.1748398736171 }
    }
    for k = 1, math.random(1, COMPLEXITY + 2) do
        -- EW RADAR
        local p1 = coordinates[math.random(#coordinates)]
        local p = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
            { maxDistance = 30, mode = 1, area = area, side = bL3.Sides.SERB })
        if p == nil then
            print("EWR point nil")
            return 0
        end
        local id = 'EWRAD#' .. bL3.AuxFunctions.RandomTxt(8)
        local guid = id .. '-MONTENEGRO'
        local name = 'FIXED#' .. bL3.AuxFunctions.RandomTxt(8)
        local fixed_radar = ScenEdit_AddUnit({ side = bL3.Sides.MON, guid = guid, type = 'Facility', name = name, dbid = 3818, latitude =
        p.latitude, longitude = p.longitude, autodetectable = false })
        if fixed_radar == nil then
            print("FIXED RADAR BAD ")
            return 0
        end
        ScenEdit_UpdateUnit({ guid = fixed_radar.guid, mode = 'add_sensor', arc_detect = { '360' }, arc_track = { '360' }, dbid =
        yugoslavia_sensors_id[math.random(#yugoslavia_sensors_id)].dbid })
        if fixed_radar then
            fixed_radar.OODA = bL3.Functions.GetOODA('SAM')
            bL3.Units.SERB.OODA[fixed_radar.guid] = {
                type = 'RADAR',
                comms_level = 30,            -- Nivel de comunicación de la unidad actualmente
                comms_base = 30,             -- Nivel mínimo de comunicación de la unidad
                comms_threshold = 30,        -- Nivel de la capacidad de transmitir información de la unidad
                outofcomms = 0,              -- Tiempo que la unidad ha estado out of comms
                OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                jam_level = 0,
                jam_time = 0,                -- Jam actual de la unidad
                jam_threshold = 20,          -- Capacidad de soportar Jamming de la unidad
                jam_capacity = 0,            -- Capacidad de Jam de la unidad
                EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                latitude = fixed_radar.latitude,
                longitude = fixed_radar.longitude,
            }
            ScenEdit_SetUnitIntermittentEmissionConfig(fixed_radar.guid, 'CUSTOM',
                { UseEmissionInterval = 1, EmissionDuration = math.random(40, 60), EmissionInterval = 240, EmissionIntervalVariation =
                math.random(60, 120) })
            fixed_radar.UseCustomIntermittentEmissionOnly = true
            ScenEdit_SetEMCON('unit', fixed_radar.guid, "Radar=Active")
        end
    end
end
MontenegroEW()
ScenEdit_SetDoctrine({ side = bL3.Sides.SERB }, { ignore_emcon_while_under_attack = false })

bL3.Units.SERB.Targets = {}
bL3.Variables.TARGETS = 0
bL3.Variables.KTARGETS = 0
local function CreateTargets()
    local area = bL3.AREAS.SERB
    local GHQ = bL3.AuxFunctions.split(bL3.Units.SERB.IADS.HQ, '-')[1]
    local target_types = { 'Ground Station', 'Military Headquarters', 'Communication Installation',
        'Ammunition Store Depot', 'Ammunition Factory', 'Military Base', 'Radio/TV Station', 'C3 Station' }
    local target_dbids = { 3735, 428, 615, 1426, 455, 2419, 238, 3730 }
    bL3.Units.SERB.Targets = {}
    local civ_dbids = { 115, 318, 164, 113, 319, 676, 624, 3896, 2723 }
    local max = 6 * COMPLEXITY / bL3.Variables.SectorControl
    local num_targets
    if bL3.Variables.SectorControl < 2 then num_targets = 3 else num_targets = math.random(1, max) end
    for k, sc in pairs(bL3.Units.SERB.IADS) do
        if string.find(k, 'C2') then
            for i = 1, num_targets do
                if bL3.Variables.TARGETS > COMPLEXITY * 4 then break end
                local r = math.random(#target_types)
                -- local point = serbia_coordinates[math.random(#serbia_coordinates)]
                local HQ = SE_GetUnit({ guid = sc.C2 })
                local C2_ID = bL3.AuxFunctions.split(HQ.guid, '-')[1]
                local point = { latitude = HQ.latitude, longitude = HQ.longitude }
                local p1 = bL3.AuxFunctions.GetRandomPoint(point.latitude, point.longitude,
                    { maxDistance = 40, mode = 1, area = area, side = bL3.Sides.SERB })
                if p1 == nil then
                    print("TARGET CIV NIL POINT")
                    return 0
                end
                local civ_id = 'CIVBUILD#' .. bL3.AuxFunctions.RandomTxt(8) .. '-Civilian'
                ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.CIV, name = 'FIXED#' ..
                bL3.AuxFunctions.RandomTxt(5), dbid = civ_dbids[math.random(#civ_dbids)], guid = civ_id, latitude = p1
                .latitude + math.random(-2000, 2000) / 10 ^ 5, longitude = p1.longitude + math.random(-1000, 1000) / 10 ^
                5, autodetectable = false, AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false })
                if math.random() > 0.6 then
                    civ_id = 'CIVBUILD#' .. bL3.AuxFunctions.RandomTxt(5) .. '-Civilian'
                    ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.CIV, name = 'FIXED#' ..
                    bL3.AuxFunctions.RandomTxt(5), dbid = civ_dbids[math.random(#civ_dbids)], guid = civ_id, latitude =
                    p1.latitude + math.random(-10000, 10000) / 10 ^ 5, longitude = p1.longitude +
                    math.random(-1000, 1000) / 10 ^ 5, autodetectable = false, AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false })
                end
                bL3.Variables.TARGETS = bL3.Variables.TARGETS + 1
                local target_id = 'TARGET#' .. bL3.AuxFunctions.RandomTxt(8) .. '-SERBIA'
                local target = ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.SERB, name = 'Target #' ..
                bL3.AuxFunctions.RandomTxt(5), dbid = target_dbids[r], guid = target_id, latitude = p1.latitude +
                math.random(-100, 100) / 10 ^ 5, longitude = p1.longitude + math.random(-100, 100) / 10 ^ 5, AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false, autodetectable = true })

                bL3.Units.SERB.Targets[target_id] = { dbid = target_dbids[r], ID = target.name, Type = target_types[r], Lat =
                string.format("%.3f", target.latitude), Lon = string.format("%.3f", target.longitude), mission = 'Nan', notes =
                '', BDA = 'Unknown', guid = target_id }
                local p = bL3.AuxFunctions.GetRandomPoint(target.latitude, target.longitude,
                    { maxDistance = 5, mode = 1, area = bL3.AREAS.SERB, side = bL3.Sides.SERB })
                local SC = bL3.Units.SERB.IADS[k].C2
                local insert = { latitude = p.latitude + math.random(-500, 500) / 10 ^ 5, longitude = p1.longitude +
                math.random(-500, 500) / 10 ^ 5, id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(4) ..
                '-SERB-' .. C2_ID .. '-' .. GHQ, name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(4) }
                local SAM = ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.SERB, name = insert.name, dbid = 243, guid =
                insert.id, latitude = insert.latitude, longitude = insert.longitude, autodetectable = false })
                if SAM then
                    table.insert(bL3.Units.SERB.IADS[k].SAMS, SAM.guid)
                    bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                    -- print(bL3.Units.SERB.IADS[k].SAMS)
                    bL3.Units.SERB.OODA[SAM.guid] = {
                        type = 'SAM',
                        comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                        comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                        comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                        outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                        isOutOfComms = false,
                        OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                        jam_level = 0,
                        jam_time = 0,              -- Jam actual de la unidad
                        jam_threshold = 20,        -- Capacidad de soportar Jamming de la unidad
                        jam_capacity = 0,          -- Capacidad de Jam de la unidad
                        EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                        latitude = SAM.latitude,
                        longitude = SAM.longitude,
                        Fires = 0,
                    }
                    CreateAreaAroundSam(SAM, 12)
                    SAM.OODA = bL3.Functions.GetOODA('SAM')
                    SE_SetUnit({ guid = SAM.guid, latitude = 60.2811118732958, longitude = 99.2867466774299 })
                end

                for k = 1, math.random(2 + COMPLEXITY) do
                    local p2 = bL3.AuxFunctions.GetRandomPoint(p1.latitude, p1.longitude,
                        { maxDistance = 10, mode = 1, area = area, side = bL3.Sides.SERB })
                    if p1 == nil then
                        print("TARGET CIV NIL POINT")
                        return 0
                    end
                    civ_id = 'CIVBUILD#' .. bL3.AuxFunctions.RandomTxt(8) .. '-Civilian'
                    ScenEdit_AddUnit({ type = 'Facility', side = bL3.Sides.CIV, name = 'FIXED#' ..
                    bL3.AuxFunctions.RandomTxt(5), dbid = civ_dbids[math.random(#civ_dbids)], guid = civ_id, latitude =
                    p1.latitude + math.random(-100, 100) / 10 ^ 5, longitude = p1.longitude + math.random(-100, 100) /
                    10 ^ 4, autodetectable = false, AI_EvaluateTargets_enabled = false, AI_DeterminePrimaryTarget_enabled = false })
                end
            end
        end
    end
end
CreateTargets()
local function AddAircrafts()
    local function getAircraftCallAsign()
        local names = { "Bear", "Red Star", "Hammer and Sickle", "Sputnik", "Kremlin", "Volga", "Siberian", "Cosmonaut",
            "Samovar", "Matryoshka", "Cossack", "Tundra", "Taiga", "Bolshevik", "Ivan", "Orlov", "Medved", "Rys'", "Lobo",
            "Rosinka", "Orlitsa", "Zmey", "Bars", "Belka", "Sokol", "Rodion", "Druzhok", "Tikhon", "Zvezdochka", "Voron" }
        return names[math.random(#names)]
    end
    local min, max
    if COMPLEXITY == 1 then
        min = 6
        max = 12
    else
        min = 6
        max = 10
    end
    local area
    for name, AB in pairs(bL3.Units.SERB.Airbases) do
        bL3.Units.SERB.Airbases[name].units = {}
        for k, dbid in pairs(AB.aircrafts.dbid) do
            local callasign = getAircraftCallAsign()
            for i = 1, bL3.AuxFunctions.RandomPar(min, max) do
                local guid = 'MIG' .. callasign .. i .. '#' .. bL3.AuxFunctions.RandomTxt(5) .. '-SERB-' .. AB.airbase
                local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.SERB, name = callasign .. ' #' .. i, dbid =
                dbid, loadoutid = AB.aircrafts.loadoutid[k], guid = guid, base = AB.airbase })
                if u == nil then goto nextAC end
                table.insert(bL3.Units.SERB.Airbases[name].units, u.guid)
                ScenEdit_FillMagsForLoadout({ unit = AB.airbase, loadoutid = AB.aircrafts.loadoutid[k], quantity = 3 })
            end
        end
        ::nextAC::
        -- Create SAM / EW defense for airbases
        local HQ = bL3.AuxFunctions.split(AB.HQ, '-')[1]
        bL3.Units.SERB.IADS['SECTOR ' .. HQ] = {}
        bL3.Units.SERB.IADS['SECTOR ' .. HQ].SAMS = {}
        bL3.Units.SERB.IADS['SECTOR ' .. HQ].C2 = AB.HQ
        bL3.Units.SERB.IADS['SECTOR ' .. HQ].RADAR = {}
        bL3.Units.SERB.IADS['SECTOR ' .. HQ].COMMS = {}
        if AB.airbase == 'Golubovci AB' then area = bL3.AREAS.MON else area = bL3.AREAS.SERB end
        for x = 1, math.random(1, COMPLEXITY) do
            local insert = { side = bL3.Sides.SERB, latitude = 0, longitude = 0 }
            local p = bL3.AuxFunctions.GetRandomPoint(AB.latitude, AB.longitude,
                { maxDistance = 10, mode = 1, side = bL3.Sides.SERB, area = area })
            if p == nil then
                print("HQ point nil")
                return 0
            end
            local id = 'SAM#' .. bL3.AuxFunctions.RandomTxt(8)
            insert.guid = id .. '-SERB-' .. AB.HQ
            table.insert(bL3.Units.SERB.IADS['SECTOR ' .. HQ].SAMS, insert.guid)
            insert.name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
            insert.latitude = p.latitude
            insert.longitude = p.longitude
            local SAM = MobSAM(insert)
            if SAM then
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                bL3.Units.SERB.OODA[SAM.guid] = {
                    type = 'SAM',
                    comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                    isOutOfComms = false,
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,
                    jam_time = 0,              -- Jam actual de la unidad
                    jam_threshold = 80,        -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,          -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = SAM.latitude,
                    longitude = SAM.longitude,
                    Fires = 0,
                }
                CreateAreaAroundSam(SAM, math.random(5, 8))
                SAM.OODA = bL3.Functions.GetOODA('SAM')
                SE_SetUnit({ guid = SAM.guid, latitude = 60.2811118732958, longitude = 99.2867466774299 })
            end
        end
        for x = 1, math.random(1, COMPLEXITY) do
            local p = bL3.AuxFunctions.GetRandomPoint(AB.latitude, AB.longitude,
                { maxDistance = 20, mode = 1, side = bL3.Sides.SERB, area = bL3.AREAS.SERB })
            if p == nil then return false end
            local id = 'MOBRAD#' .. bL3.AuxFunctions.RandomTxt(8)
            guid = id .. '-SERB-' .. AB.HQ
            table.insert(bL3.Units.SERB.IADS['SECTOR ' .. HQ].RADAR, guid)
            name = 'MOB#' .. bL3.AuxFunctions.RandomTxt(8)
            local mobile_radar = ScenEdit_AddUnit({ side = bL3.Sides.SERB, guid = guid, type = 'Facility', name = name, dbid =
            yugoslavia_mobile_sensors[math.random(#yugoslavia_mobile_sensors)].dbid, latitude = p.latitude, longitude = p
            .longitude, autodetectable = false })
            if mobile_radar then
                mobile_radar.OODA = bL3.Functions.GetOODA('SAM')
                bL3.Variables.NSAM = bL3.Variables.NSAM + 1
                bL3.Units.SERB.OODA[mobile_radar.guid] = {
                    type = 'RADAR',
                    comms_level = 30,          -- Nivel de comunicación de la unidad actualmente
                    comms_base = 30,           -- Nivel mínimo de comunicación de la unidad
                    comms_threshold = 30,      -- Nivel de la capacidad de transmitir información de la unidad
                    outofcomms = 0,            -- Tiempo que la unidad ha estado out of comms
                    OODA = bL3.Functions.GetOODA('SAM'), -- OODA de la unidad
                    jam_level = 0,
                    jam_time = 0,              -- Jam actual de la unidad
                    jam_threshold = 20,        -- Capacidad de soportar Jamming de la unidad
                    jam_capacity = 0,          -- Capacidad de Jam de la unidad
                    EMCON_Setting = 'Radar=Passive', -- EMCON de la unidad
                    latitude = mobile_radar.latitude,
                    longitude = mobile_radar.longitude,
                }
                ScenEdit_SetUnitIntermittentEmissionConfig(mobile_radar.guid, 'CUSTOM',
                    { UseEmissionInterval = 1, EmissionDuration = math.random(40, 60), EmissionInterval = 240, EmissionIntervalVariation =
                    math.random(60, 120) })
                mobile_radar.UseCustomIntermittentEmissionOnly = true
                ScenEdit_SetEMCON('unit', mobile_radar.guid, "Radar=Active")
            end
        end
        for x = 1, math.random(1, COMPLEXITY + 1) do
            local pAAA = bL3.AuxFunctions.GetRandomPoint(AB.latitude, AB.longitude,
                { maxDistance = 1, mode = 1, side = bL3.Sides.SERB })
            if pAAA == nil then
                print("AAA AB HQ nil")
                return
            end
            id        = 'AAA#' .. bL3.AuxFunctions.RandomTxt(7)
            local aaa = ScenEdit_AddUnit({ side = bL3.Sides.SERB, guid = id .. '-SERB-' .. AB.HQ, type = 'Facility', name =
            'MOB#' .. bL3.AuxFunctions.RandomTxt(4), dbid = 2574, latitude = pAAA.latitude, longitude = pAAA.longitude })
            aaa.OODA  = bL3.Functions.GetOODA('SAM')
        end
    end
end
AddAircrafts()
local function SetWRA()
    local side_name = bL3.Sides.SERB ------- NAME OF THE AI SIDE

    local function SetDoctrineUnit(unit, dbid, range)
        for k, i in ipairs({ 1999, 2000, 2001, 2002, 2003, 2004, 2011, 2012, 2013, 2021, 2022, 2023, 2031, 2100 }) do
            ScenEdit_SetDoctrineWRA({ guid = unit.guid, target_type = i, weapon_dbid = dbid },
                { '1', 'inherit', range, 'inherit' })
        end
        for k, i in ipairs({ 2200, 2201, 2202, 2203, 2204 }) do
            ScenEdit_SetDoctrineWRA({ guid = unit.guid, target_type = i, weapon_dbid = dbid }, { '0', '0', '0', '0' })
        end
    end
    local function AssignWRA(unit, dbid, max_range)
        local range
        if max_range > 10 then
            range = math.ceil(math.random(30, 55) / 100 * max_range)
        else
            range = max_range
        end
        SetDoctrineUnit(unit, dbid, range)
    end
    local side = VP_GetSide({ side = side_name })
    local weapons_t = {}


    for k2, unit in ipairs(side.units) do
        local u = SE_GetUnit({ guid = unit.guid })
        local weapons
        if u.type == 'Aircraft' then
            --print(unit)
            weapons = ScenEdit_GetLoadout({ unitname = u.guid })
            if weapons.weapons then
                for k3, w in ipairs(weapons.weapons) do
                    if w.wpn_type == 2001 then
                        local data = ScenEdit_QueryDB('weapon', w.wpn_dbid)
                        AssignWRA(u, w.wpn_dbid, data.ranges.air.max)
                    end
                end
            end
        elseif u.type == 'Facility' or u.type == 'Ship' then
            --print(unit)
            local mounts = u.mounts
            if mounts ~= nil and #mounts > 0 then
                for i, m in ipairs(mounts) do
                    local mount_weapons = m.mount_weapons
                    if mount_weapons ~= nil then
                        for _, w in ipairs(mount_weapons) do
                            if w.wpn_type == 2001 then
                                local data = ScenEdit_QueryDB('weapon', w.wpn_dbid)
                                AssignWRA(u, w.wpn_dbid, data.ranges.air.max)
                            end
                        end
                    end
                end
            end
        end
    end
end
SetWRA()
gKH.State.SaveTableToKey(bL3.Variables, 'VARIABLES')
ScenEdit_SetTrigger({ name = 'UnitDetected_SERB', mode = 'add', type = 'UnitDetected', DetectorSideID = VP_GetSide({ side =
bL3.Sides.SERB }).guid })
ScenEdit_SetAction({ name = 'UnitDetected_lua', mode = 'add', type = 'LuaScript', ScriptText = 'bL3.Functions.Contact()' })
ScenEdit_SetEvent('ContactDetected', { mode = 'add', IsRepeatable = true, isShown = false })
ScenEdit_SetEventTrigger('ContactDetected', { mode = 'add', name = 'UnitDetected_SERB' })
ScenEdit_SetEventAction('ContactDetected', { mode = 'add', name = 'UnitDetected_lua' })
