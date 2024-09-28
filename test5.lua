---@diagnostic disable: need-check-nil
local function US_OOB()
    bL3.Units.US = {}
    bL3.Units.US.OODA = {}
    bL3.Units.US.JAMMERS = {}
    bL3.Units.NATO = {}
    bL3.Units.US.ABCC = {}

    local function AddHangars(unit)
        for k = 1, 15 do
            local hangar = ScenEdit_AddUnit({ type = 'Facility', dbid = 103, name = 'Additional Tarmac', guid = unit
            .guid .. '-TARMAC#' .. k, side = 'NATO', latitude = unit.latitude + math.random(-100, 100) / 10 ^ 5, longitude =
            unit.longitude + math.random(-100, 100) / 10 ^ 5 })
            hangar.group = unit.group.name
            hangar = ScenEdit_AddUnit({ type = 'Facility', dbid = 198, name = 'Additional Hangar', guid = unit.guid ..
            '-HG#' .. k, side = 'NATO', latitude = unit.latitude + math.random(-100, 100) / 10 ^ 5, longitude = unit
            .longitude + math.random(-100, 100) / 10 ^ 5 })
            hangar.group = unit.group.name
        end
    end
    local us_callasigns = { "Ghost", "Shadow", "Maverick", "Avalanche", "Cyclone", "Hammer", "Avalanche", "Phoenix",
        "Razor", "Banshee", "Nomad", "Wraith", "Tempest", "Spectre", "Valkyrie", "Corsair", "Renegade", "Titan", "Sabre",
        "Sentinel", "Rendezvous", "Serpent", "Gryphon", "Nightshade", "Cyclone", "Eclipse", "Warlock", "Wally", "Boar",
        "Brick" }

    local COMPLEXITY = bL3.Variables.Complexity
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Fairford AB', guid = 'NATO-AIRBASE-UK-FAIRFORD', side =
    'NATO', latitude = 51.682222, longitude = -1.79 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Sigonella AB', guid = 'NATO-AIRBASE-ITA-SIGONELLA', side =
    'NATO', latitude = 37.401667, longitude = 14.922222 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Rhein-Main AB', guid = 'NATO-AIRBASE-GER-RHEINMAIN', side =
    'NATO', latitude = 50.030194, longitude = 8.588047 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Gioia AB', guid = 'NATO-AIRBASE-ITA-GIOIA', side = 'NATO', latitude = 40.764167, longitude = 16.933333 })
    local AB = ScenEdit_AddUnit({ type = 'Facility', dbid = 1996, name = 'Aviano AB', guid = 'NATO-AIRBASE-ITA-AVIANO', side =
    'NATO', latitude = 46.031389, longitude = 12.596944 })
    -- if COMPLEXITY >= 2 then
    -- AB.group ='Aviano AB'
    -- AddHangars(AB)
    -- end
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Trapani AB', guid = 'NATO-AIRBASE-ITA-TRAPANI', side =
    'NATO', latitude = 37.911944, longitude = 12.493333 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Tuzla AB', guid = 'BOS-AIRBASE-BOS-TUZLA', side = 'Bosnia', latitude = 44.458611, longitude = 18.724722 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Brize Norton AB', guid = 'NATO-AIRBASE-UK-BRIZENORTON', side =
    'NATO', latitude = 51.75, longitude = -1.583611 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Mildenhall AB', guid = 'NATO-AIRBASE-UK-MILDENHALL', side =
    'NATO', latitude = 52.365, longitude = 0.480833 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Whiteman AB', guid = 'US-USAF-WHITEMAN-WHITEMANAFB', side =
    bL3.Sides.US, latitude = 38.730111474994104, longitude = -93.54781864472203 })
    ScenEdit_AddUnit({ type = 'Facility', dbid = 430, name = 'Cervia AB', guid = 'NATO-AIRBASE-ITA-CERVIA', latitude = 44.22378866089468, side =
    'NATO', longitude = 12.308297164270398, heading = 297 })

    -- ABCC
    local unit = ScenEdit_AddUnit({ type = 'Aircraft', dbid = 2879, loadoutid = 8037, name = 'EC-130E 603th ACS', guid =
    'US-USAF-AMC-ABCC#EC130E603thACS', side = 'US', base = 'Aviano AB' })
    bL3.Units.US.ABCC[1] = unit.guid
    -- STAND OFF JAMMER
    unit = ScenEdit_AddUnit({ type = 'Aircraft', dbid = 320, loadoutid = 14471, name = 'ZAPPER #' ..
    bL3.AuxFunctions.RandomTxt(4), guid = 'US-USAF-AMC-COMJAM#EC130H41stECS', side = 'US', base = 'Aviano AB' })
    bL3.Units.US.COMJAM = unit.guid
    --AWACS
    bL3.Units.US.AWACS = {}
    for i = 1, COMPLEXITY do
        unit = ScenEdit_AddUnit({ type = 'Aircraft', dbid = 3186, loadoutid = 8076, name = 'E-3A NATO AEW Force#' .. i, guid =
        'NATO-AEWFORCE-AEW#E3ANATOAEWForce-' .. i .. bL3.AuxFunctions.RandomTxt(4), side = 'US', base = 'Trapani AB' })
        table.insert(bL3.Units.US.AWACS, unit.guid)
    end
    --U-2S
    local function RemoveSensor(unit, dbid)
        for _, v in ipairs(unit.sensors) do
            if dbid == v.sensor_dbid then
                ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_sensor', dbid = v.sensor_dbid, sensorid = v
                .sensor_guid })
            end
        end
    end
    local id, name, unit, u
    if COMPLEXITY > 2 then
        id = 'PINYON #1'
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-16thEXPOPGROUP-' .. id, dbid = 821, loadoutid = 8583, base =
        'Sigonella AB' })
        RemoveSensor(u, 3137)
        id = 'PINYON #2'
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-16thEXPOPGROUP-' .. id, dbid = 821, loadoutid = 8583, base =
        'Sigonella AB' })
        RemoveSensor(u, 3137)
    else
        id = 'PINYON #1'
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-16thEXPOPGROUP-' .. id, dbid = 821, loadoutid = 8583, base =
        'Sigonella AB' })
        RemoveSensor(u, 3137)
    end

    for i = 1, bL3.AuxFunctions.RandomPar(4 * COMPLEXITY, 6 * COMPLEXITY) do
        id = 'ELEPHANT #' .. i
        --KC-135R
        local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-16thEXPOPGROUP-' ..
        id, dbid = 1984, loadoutid = 3, base = 'Sigonella AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 60,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel base de comunicación de la unidad
            comms_threshold = 25,             -- Nivel mínimo de comunicacion
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end

    --Tuzla
    for i = 1, 2 do
        id = 'ROB #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USA-11thEXPDRECONSQ-' .. id, dbid = 1716, loadoutid = 3, base =
        'Tuzla AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    -- u = ScenEdit_AddUnit({type='Aircraft', side=bL3.Sides.US, name='Test',guid='US-USA-11thEXPDRECONSQ-TEST', dbid=1716, loadoutid=8861, altitude=3000, latitude='44.13293972648', longitude='18.9243193275905'})
    -- bL3.Units.US.OODA[u.guid] = {  type = 'Aircraft',
    --   comms_level = 40, -- Nivel de comunicación de la unidad actualmente
    --   comms_base = 40, -- Nivel mínimo de comunicación de la unidad
    --   comms_threshold = 30, -- Nivel de la capacidad de transmitir información de la unidad
    --   outofcomms = 0, -- Tiempo que la unidad ha estado out of comms
    --   OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
    --   jam_level = 0, -- Jam actual de la unidad
    --   jam_threshold = 20, -- Capacidad de soportar Jamming de la unidad
    --   jam_capacity = 0, -- Capacidad de Jam de la unidad
    --   EMCON_Setting = 'Radar=Passive' -- EMCON de la unidad
    -- }

    --Cervia F-15C
    local n = math.random(#us_callasigns)
    local callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(6 * COMPLEXITY, 8 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-493FSQ-' .. id, dbid = 331, loadoutid = 3, base =
        'Cervia AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
        for _, load in ipairs({ 16928, 18207, 12356, 12253, 3753, 12200, 2793, 11414, 1525, 6114, 12261, 127, 3757, 12206, 808 }) do
            ScenEdit_FillMagsForLoadout({ unit = 'Cervia AB', loadoutid = load, quantity = 1 })
        end
    end
    --F-15E
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(6 * COMPLEXITY, 8 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-492FSQ-' .. id, dbid = 930, loadoutid = 3, base =
        'Cervia AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --F.16CJ
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(6 * COMPLEXITY, 8 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-157FSQ-' .. id, dbid = 591, loadoutid = 3, base =
        'Cervia AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --Gioia
    --A-10
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(4 * COMPLEXITY, 6 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-104FW-' .. id, dbid = 1624, loadoutid = 3, base =
        'Gioia AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                   -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                    -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,               -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                     -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                      -- Jam actual de la unidad
            jam_threshold = 20,                 -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                   -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'     -- EMCON de la unidad
        }
        for _, load in ipairs({ 15160, 1415, 1414, 1426, 15135, 18996 }) do
            ScenEdit_FillMagsForLoadout({ unit = 'Gioia AB', loadoutid = load, quantity = 2 })
        end
    end
    --OA-10
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(2 * COMPLEXITY, 3 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-20FW-' .. id, dbid = 724, loadoutid = 3, base =
        'Gioia AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                   -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                    -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,               -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                     -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                      -- Jam actual de la unidad
            jam_threshold = 20,                 -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                   -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'     -- EMCON de la unidad
        }
    end
    --Whiteman B-2
    local limit = 2
    if COMPLEXITY == 3 then
        limit = 4
    end
    for i = 1, limit do
        id = 'DEATH #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-509thBOMBWING-' .. id, dbid = 286, loadoutid = 1771, base =
        'Whiteman AB' })
        SE_SetUnit({ guid = u.guid, TimeToReady_Minutes = 60 * 3 })
        -- bL3.Units.US.OODA[u.guid] = {  type = 'Aircraft',
        --     comms_level = 40, -- Nivel de comunicación de la unidad actualmente
        --     comms_base = 45, -- Nivel mínimo de comunicación de la unidad
        --     comms_threshold = 20, -- Nivel de la capacidad de transmitir información de la unidad
        --     outofcomms = 0, -- Tiempo que la unidad ha estado out of comms
        --     OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
        --     jam_level = 0, -- Jam actual de la unidad
        --     jam_threshold = 20, -- Capacidad de soportar Jamming de la unidad
        --     jam_capacity = 0, -- Capacidad de Jam de la unidad
        --     EMCON_Setting = 'Radar=Passive' -- EMCON de la unidad
        --   }
    end
    --Fairford
    --B-52
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, 4 * COMPLEXITY do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-2ndBOMBWING-' .. id, dbid = 569, loadoutid = 33064, base =
        'Fairford AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
        SE_SetUnit({ guid = u.guid, TimeToReady_Minutes = 60 * 4 })
    end
    --Brize Norton
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    --KC-135
    for i = 1, 6 + math.floor(COMPLEXITY * 1.8) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-117thAIRREFUELINGWING-' ..
        id, dbid = 1984, loadoutid = 19801, base = 'Brize Norton AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
        if i > 4 then
            if i > 14 then i = 14 end
            SE_SetUnit({ guid = u.guid, TimeToReady_Minutes = 60 * i })
        end
    end
    --RC-135V Mildenhall AB
    id = 'Homer1'
    bL3.Units.US.SIGINT = {}
    -- u = ScenEdit_AddUnit({type='Aircraft', side=bL3.Sides.US, name=id,guid='US-USAF-55thWING-'..id, dbid=573, loadoutid=8824, base='Mildenhall AB'})
    for i = 1, COMPLEXITY do
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id .. i, guid = 'US-USAF-55thWING-' ..
        id .. i, dbid = 573, loadoutid = 8824, base = 'Mildenhall AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 100,                -- Nivel de comunicación de la unidad actualmente
            comms_base = 500,                 -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 10,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 40,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
        table.insert(bL3.Units.US.SIGINT, u.guid)
    end
    -- u = ScenEdit_AddUnit({type='Aircraft', side=bL3.Sides.US, name="SIGINT TEST",guid='US-USAF-55thWING-TEST', dbid=573, loadoutid=8824, latitude=40, longitude=18, altitude=4000})
    table.insert(bL3.Units.US.SIGINT, u.guid)
    --Rhein-Main AB
    --2 	E-8 JSTARS 	93rd Air Control Wing
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, 2 do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-93thAIRCONTROLWING-' ..
        id, dbid = 290, loadoutid = 8091, base = 'Rhein-Main AB' })
        bL3.Units.US.ABCC[i + 1] = u.guid
        if i == 2 and COMPLEXITY <= 2 then
            ScenEdit_SetLoadout({ UnitName = u.guid, LoadoutID = 4 })
        end
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 550,                 -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 0,              -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end

    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, 4 + COMPLEXITY do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USA-9thAIRREFUELINGSQ-' ..
        id, dbid = 214, loadoutid = 8989, base = 'Rhein-Main AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 50,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 20,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --Aviano
    --PROWLERS
    for i = 1, bL3.AuxFunctions.RandomPar(4 * COMPLEXITY, 6 * COMPLEXITY) do
        name = "THUNDER #" .. i
        unit = ScenEdit_AddUnit({ type = 'Aircraft', side = 'US', dbid = 2316, name = name, loadoutid = 3, guid =
        'US-USN-VAQ134-' .. name, base = 'Aviano AB' })
        table.insert(bL3.Units.US.JAMMERS, unit.guid)
        bL3.Units.US.OODA[unit.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 80,                -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
        for _, load in ipairs({ 9234, 9236, 9239, 9240, 6836, 6837, 4745, 11537, 16805, 4310, 4311, 4305, 11414, 11414, 16852, 11413, 11419, 4303, 12200, 2793, 11414, 1525, 6114, 12261, 127, 3757, 12206, 808 }) do
            ScenEdit_FillMagsForLoadout({ unit = 'Aviano AB', loadoutid = load, quantity = 2 })
        end
    end
    --F-117
    local n = math.random(#us_callasigns)
    local callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(5 * COMPLEXITY, 6 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-7thFS-' .. id, dbid = 2524, loadoutid = 3, base =
        'Aviano AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --F-16CJ
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(6 * COMPLEXITY, 7 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-31stAIREXPWING-' ..
        id, dbid = 591, loadoutid = 3, base = 'Aviano AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --F-16C
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(5 * COMPLEXITY, 7 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        local u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-510FSQ-' .. id, dbid = 1065, loadoutid = 3, base =
        'Aviano AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end
    --F-15E
    n = math.random(#us_callasigns)
    callasign = table.remove(us_callasigns, n)
    for i = 1, bL3.AuxFunctions.RandomPar(8 * COMPLEXITY, 10 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-494FSQ-' .. id, dbid = 930, loadoutid = 3, base =
        'Aviano AB' })
        bL3.Units.US.OODA[u.guid] = {
            type = 'Aircraft',
            comms_level = 40,                 -- Nivel de comunicación de la unidad actualmente
            comms_base = 40,                  -- Nivel mínimo de comunicación de la unidad
            comms_threshold = 30,             -- Nivel de la capacidad de transmitir información de la unidad
            outofcomms = 0,                   -- Tiempo que la unidad ha estado out of comms
            OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
            jam_level = 0,                    -- Jam actual de la unidad
            jam_threshold = 20,               -- Capacidad de soportar Jamming de la unidad
            jam_capacity = 0,                 -- Capacidad de Jam de la unidad
            EMCON_Setting = 'Radar=Passive'   -- EMCON de la unidad
        }
    end

    -- --KC-135
    -- n = math.random(#us_callasigns)
    callasign = 'WAILER'
    for i = 1, bL3.AuxFunctions.RandomPar(4 * COMPLEXITY, 5 * COMPLEXITY) do
        id = callasign .. ' #' .. i
        u = ScenEdit_AddUnit({ type = 'Aircraft', side = bL3.Sides.US, name = id, guid = 'US-USAF-171ARW-' .. id, dbid = 1984, loadoutid = 3, base =
        'Aviano AB' })
        if u then
            bL3.Units.US.OODA[u.guid] = {
                type = 'Aircraft',
                comms_level = 40,             -- Nivel de comunicación de la unidad actualmente
                comms_base = 40,              -- Nivel mínimo de comunicación de la unidad
                comms_threshold = 30,         -- Nivel de la capacidad de transmitir información de la unidad
                outofcomms = 0,               -- Tiempo que la unidad ha estado out of comms
                OODA = bL3.Functions.GetOODA('AC'), -- OODA de la unidad
                jam_level = 0,                -- Jam actual de la unidad
                jam_threshold = 20,           -- Capacidad de soportar Jamming de la unidad
                jam_capacity = 0,             -- Capacidad de Jam de la unidad
                EMCON_Setting = 'Radar=Passive' -- EMCON de la unidad
            }
        else
            break
        end
    end
    ------- SHIPS
    local location = { latitude = 41.4091227958113, longitude = 17.4040942498212 }
    local FON = bL3.AuxFunctions.NewArea(location, { shape = 'circle', side = bL3.Sides.USN, distance = 60 })
    ScenEdit_AddMission(bL3.Sides.USN, 'FON Adriatic', 'patrol', { type = 'sea', zone = FON })
    ScenEdit_SetEMCON('mission', 'FON Adriatic', 'Radar=Passive')
    u = ScenEdit_AddUnit({ type = 'Ship', side = bL3.Sides.USN, dbid = 1862, name = 'USS Gonzalez (DDG 66)', guid =
    'US-USN-DDG66-USSGONZALEZ', latitude = 41.3521204743268, longitude = 17.830852202755 })
    bL3.AuxFunctions.SetUnitCourse(u, '15NE15SW15NW15SW20N20S', 30)
    ScenEdit_AssignUnitToMission(u.guid, 'FON Adriatic')
    u = ScenEdit_AddUnit({ type = 'Ship', side = bL3.Sides.USN, dbid = 549, name = 'USS Philippine Sea (CG-58)', guid =
    'US-USN-CG58-USSPHILIPPINESEA', latitude = 41.4695055585849, longitude = 18.1851809802956 })
    ScenEdit_AssignUnitToMission(u.guid, 'FON Adriatic')
    bL3.AuxFunctions.SetUnitCourse(u, '15NE15SW15NE15SW', 30)
    if COMPLEXITY > 1 then
        u = ScenEdit_AddUnit({ type = 'Ship', side = bL3.Sides.USN, dbid = 756, name = 'USS Vella Gulf (CG-72)', guid =
        'US-USN-CG58-USSVELLAGULF', latitude = 39.11, longitude = 18.2 })
        bL3.AuxFunctions.SetUnitCourse(u, '15NW15SW15NW15SW', 70)
        ScenEdit_AssignUnitToMission(u.guid, 'FON Adriatic')
    end
end
US_OOB()
