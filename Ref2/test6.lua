math.randomseed(os.time())
math.random()
-- Tool_EmulateNoConsole()

function CivilianAirTraffic()
    local missionList = {}

    local airports = {
        { name = 'Tehran (1st TAB)',     guid = 'Z8XE7U-0HMDTJ2EVCSEM' },
        { name = 'Tabriz (2nd TAB)',     guid = 'Z8XE7U-0HMDTJ2EVCKPQ' },
        { name = 'Dezful (4th TAB)',     guid = 'Z8XE7U-0HMDTJ2EVC1HT' },
        { name = 'Shiraz (7th TAB)',     guid = 'Z8XE7U-0HMDTJ2EVCI6B' },
        { name = 'Esfahãn (8th TAB)',    guid = 'Z8XE7U-0HMDTJ2EVC6E4' },
        { name = 'Bandar Abbas (9th TAB)', guid = 'Z8XE7U-0HMDTJ2EVBOME' },
        { name = 'Chabahar (10th TAB)',  guid = 'Z8XE7U-0HMDTJ2EVBUCE' },
        { name = 'Mashhad (14th TAB)',   guid = 'Z8XE7U-0HMDTJ2EVCE99' },
    }

    local aircraft = {
        { dbid = 2426, ferryRange = 4500, loadoutid = 9923 }, -- Airbus A.310-300
        { dbid = 2545, ferryRange = 3600, loadoutid = 9958 }, -- Airbus A.319-100
        { dbid = 2548, ferryRange = 3200, loadoutid = 9954 }, -- Airbus A.320-200
        { dbid = 2549, ferryRange = 3000, loadoutid = 9952 }, -- Airbus A.321-200
        { dbid = 2428, ferryRange = 7250, loadoutid = 9926 }, -- Airbus A.330-200
        { dbid = 2593, ferryRange = 715, loadoutid = 10128 }, -- ATR-72-200
        { dbid = 2591, ferryRange = 715, loadoutid = 10125 }, -- ATR-72-500
        { dbid = 5499, ferryRange = 715, loadoutid = 30083 }, -- ATR-72-600
        { dbid = 3966, ferryRange = 1960, loadoutid = 19891 }, -- Boeing 737-400
        { dbid = 4021, ferryRange = 1325, loadoutid = 20041 }, -- F.100 [Tay 650]
        { dbid = 4055, ferryRange = 2050, loadoutid = 20158 }, -- MD-82
        { dbid = 4056, ferryRange = 2500, loadoutid = 20160 }, -- MD-83
    }

    local function ReturnFerryRangeFromGUID(aircraftGUID)
        local result
        local unit = ScenEdit_GetUnit({ guid = aircraftGUID })
        for k, v in ipairs(aircraft) do
            if unit.dbid == v.dbid then
                result = v.ferryRange
            end
        end
        return result
    end

    local function ReturnFerryRangeFromDBID(aircraftDBID)
        local result
        for k, v in ipairs(aircraft) do
            if aircraftDBID == v.dbid then
                result = v.ferryRange
            end
        end
        return result
    end

    local function GenerateListOfPossibleDestinations_GUID(aircraftGUID)
        local unit = ScenEdit_GetUnit({ guid = aircraftGUID })
        local safeRange = ReturnFerryRangeFromGUID(aircraftGUID) * 0.8
        local result = {}
        for k, v in ipairs(airports) do
            local tripDistance = Tool_Range(aircraftGUID, v.guid)
            if tripDistance < safeRange then
                local tableEntry = { name = v.name, guid = v.guid, range = tripDistance }
                table.insert(result, tableEntry)
            end
        end
        return result
    end

    local function GenerateListOfPossibleDestinations_ByRange(safeRange, aircraftGUID)
        local unit = ScenEdit_GetUnit({ guid = aircraftGUID })
        local result = {}
        for k, v in ipairs(airports) do
            local tripDistance = Tool_Range(aircraftGUID, v.guid)
            if tripDistance < safeRange then
                local tableEntry = { name = v.name, guid = v.guid, range = tripDistance }
                table.insert(result, tableEntry)
            end
        end
        return result
    end

    local function SortListOfAirportsByRange(airportTable)
        local rangeTable, result = {}, {}
        for k, v in ipairs(airportTable) do
            table.insert(rangeTable, v.range)
        end
        table.sort(rangeTable)
        for i = #rangeTable, 1, -1 do
            rangeValue = rangeTable[i]
            for key, value in ipairs(airportTable) do
                if value.range == rangeValue then
                    table.insert(result, value)
                end
            end
        end
        return result
    end

    local function ChooseOneOfFurthestDestinations(airportTable)
        local airportTable = SortListOfAirportsByRange(airportTable)
        local tableLength = #airportTable
        if tableLength > 3 then
            tableLength = 3
        end
        local result = airportTable[math.random(1, tableLength)]
        return result
    end

    local function ThisFerryMissionExists(missionName)
        local result = false
        for k, v in ipairs(missionList) do
            if v == missionName then
                return true
            end
        end
        return false
    end

    local function AddMissionToList(missionName)
        table.insert(missionList, missionName)
    end

    local function GenerateFerryMission(destinationName)
        local mission
        if ThisFerryMissionExists(destinationName) then
            mission = ScenEdit_GetMission('Civilian', destinationName)
        else
            mission = ScenEdit_AddMission('Civilian', destinationName, 'ferry', { destination = destinationName })
            ScenEdit_SetMission('Civilian', mission.guid, { FerryBehavior = 'Cycle', flightSize = 1 })
            AddMissionToList(mission.name)
        end
        return mission
    end

    local function CreateMissionAndAssignAircraft_Random(aircraftGUID)
        local airportTable = GenerateListOfPossibleDestinations_GUID(aircraftGUID)
        local destinationName = ChooseOneOfFurthestDestinations(airportTable).name
        Tool_EmulateNoConsole()
        GenerateFerryMission(destinationName)
        ScenEdit_AssignUnitToMission(aircraftGUID, destinationName)
    end

    local function CreateMissionAndAssignAircraft(aircraftGUID, destinationName)
        Tool_EmulateNoConsole()
        local mission = GenerateFerryMission(destinationName)
        ScenEdit_AssignUnitToMission(aircraftGUID, destinationName)
        return mission
    end

    local function RandomAirline()
        local airline = { 'IRA', 'IRC', 'IZG', 'IRK', 'IRQ', 'IRM', 'TBZ', 'TBM', 'CPN', 'IRG', 'SHI', 'VRH', 'FPI',
            'PRS', 'QFZ' }
        return string.upper(airline[math.random(1, #airline)])
    end

    local function GenerateRandomAircraftName()
        local result
        local flightNumber = math.random(10, 2000)
        result = RandomAirline() .. flightNumber
        return result
    end

    local function ReturnRandomAircraftEntry()
        return aircraft[math.random(1, #aircraft)]
    end

    local function NameIsADuplicate(nameString)
        Tool_EmulateNoConsole()
        local unit = ScenEdit_GetUnit({ side = 'Civilian', name = nameString })
        if unit == nil then
            return true
        else
            return false
        end
    end

    local function RandomiseReadyTime(aircraftGUID)
        local unit = ScenEdit_GetUnit({ guid = aircraftGUID })
        ScenEdit_SetUnit({
            unitName = unit.guid,
            TimeToReady_Minutes = math.random(0, 60)
        })
    end

    local function RandomiseTransponder(aircraftGUID)
        local unit = ScenEdit_GetUnit({ guid = aircraftGUID })
        setAutodetectable = math.random(1, 100)
        if setAutodetectable <= 95 then
            ScenEdit_SetUnit({
                unitName = unit.guid,
                autodetectable = true
            })
        end
    end

    local function GenerateAircraft()
        local error_Count = 0
        ::redoGenerateAircraft::
        local aircraft = ReturnRandomAircraftEntry()
        local homebase = nil
        local homebaseList = airports

        homebase = homebaseList[math.random(1, #homebaseList)]

        local destination, destinationList

        local safeRange = ReturnFerryRangeFromDBID(aircraft.dbid)
        destinationList = GenerateListOfPossibleDestinations_ByRange(safeRange, homebase.guid)
        destination = ChooseOneOfFurthestDestinations(destinationList)

        local unit =
            ScenEdit_AddUnit({
                side = 'Civilian',
                type = 'Aircraft',
                dbid = aircraft.dbid,
                name = GenerateRandomAircraftName(),
                base = homebase.name,
                loadoutid = aircraft.loadoutid
            })

        RandomiseReadyTime(unit.guid)
        RandomiseTransponder(unit.guid)

        CreateMissionAndAssignAircraft(unit.name, destination.name)

        local result = ScenEdit_GetUnit({ guid = unit.guid })
        return result
    end

    for i = 1, 20 do
        GenerateAircraft()
    end
end
