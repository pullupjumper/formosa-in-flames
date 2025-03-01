math.randomseed(os.time())
math.random()

-- =============
-- Key Values --
-- =============

-- =========================
-- Enable Search and Rescue
-- =========================

function SearchAndRescueEnabled(boolValue)
    if boolValue == nil then
        return ConvertStringToBoolean(ScenEdit_GetKeyValue('SAR'))
    elseif boolValue == true then
        ScenEdit_SetKeyValue('SAR', 'true')
        return true
    elseif boolValue == false then
        ScenEdit_SetKeyValue('SAR', 'false')
        return false
    else
        return nil
    end
end

-- =========================
-- Hostilities Have Commenced
-- =========================

function HostilitiesHaveCommenced(boolValue)
    if boolValue == nil then
        return ConvertStringToBoolean(ScenEdit_GetKeyValue('HostilitiesCommenced'))
    elseif boolValue == true then
        ScenEdit_SetKeyValue('HostilitiesCommenced', 'true')
        return true
    elseif boolValue == false then
        ScenEdit_SetKeyValue('HostilitiesCommenced', 'false')
        return false
    else
        return nil
    end
end

-- =========================
-- Iran Use Hypothetical Loadouts
-- =========================

function IranUseHypotheticalLoadouts()
    if boolValue == nil then
        return ConvertStringToBoolean(ScenEdit_GetKeyValue('IranHypotheticalLoadouts'))
    elseif boolValue == true then
        ScenEdit_SetKeyValue('IranHypotheticalLoadouts', 'true')
        return true
    elseif boolValue == false then
        ScenEdit_SetKeyValue('IranHypotheticalLoadouts', 'false')
        return false
    else
        return nil
    end
end

-- =========================
-- Iran Use Export Only Aircraft and Loadouts
-- =========================

function IranUseExportOnly(boolValue)
    if boolValue == nil then
        return ConvertStringToBoolean(ScenEdit_GetKeyValue('IranExportOnly'))
    elseif boolValue == true then
        ScenEdit_SetKeyValue('IranExportOnly', 'true')
        return true
    elseif boolValue == false then
        ScenEdit_SetKeyValue('IranExportOnly', 'false')
        return false
    else
        return nil
    end
end

-- =========================
-- Israel US Missiles Strikes Approved
-- =========================

function IsraelMissileStrikesApproved(boolValue)
    if boolValue == nil then
        return ConvertStringToBoolean(ScenEdit_GetKeyValue('MissileStrikesApproved'))
    elseif boolValue == true then
        ScenEdit_SetKeyValue('MissileStrikesApproved', 'true')
        return true
    elseif boolValue == false then
        ScenEdit_SetKeyValue('MissileStrikesApproved', 'false')
        return false
    else
        return nil
    end
end

-- ==============================
-- Scenario Specific Functions --
-- ==============================

-- =========================
-- Serialiation Functions --
-- =========================

function serialize(dataTable)
    local serializedValueString = "{"
    for _, guid in ipairs(dataTable) do
        serializedValueString = serializedValueString .. '"' .. tostring(guid) .. '",'
    end
    serializedValueString = serializedValueString:sub(1, -2) .. "}" -- remove last comma and add closing bracket
    return serializedValueString
end

function deserialize(serializedDataString)
    local t = {}
    serializedDataString = serializedDataString:sub(2, -2) -- remove the curly braces
    for guid in serializedDataString:gmatch('"([^"]+)"') do
        table.insert(t, guid)
    end
    return t
end

function storeData(dataTable, keyStoreString)
    local serializedDataString = serialize(dataTable)
    print(serializedDataString)
    ScenEdit_SetKeyValue(keyStoreString, serializedDataString)
end

function retrieveData(keyStoreString)
    local serializedDataString = ScenEdit_GetKeyValue(keyStoreString)
    print(serializedDataString)
    if serializedDataString then
        return deserialize(serializedDataString)
    else
        return {}
    end
end

function setGlobalFromKeyStore(globalVarNameString, keyStoreString)
    local serializedDataString = ScenEdit_GetKeyValue(keyStoreString)
    print(serializedDataString)
    if serializedDataString then
        _G[globalVarNameString] = deserialize(serializedDataString)
    else
        _G[globalVarNameString] = {}
    end
end

-- =========================
-- Random Replace Aircraft
-- =========================

function SelectRandomAircraft(aircraftList)
    local AircraftChance = math.random(1, 100)

    -- Iterate through the aircraft table and compare the chance values
    for _, aircraft in ipairs(aircraftList) do
        if AircraftChance <= aircraft.chance then
            -- Check if the aircraft has multiple loadouts
            if aircraft.loadouts then
                local LoadoutChance = math.random(1, 100)
                for _, loadout in ipairs(aircraft.loadouts) do
                    if LoadoutChance <= loadout.chance then
                        return aircraft.dbid, loadout.loadoutID
                    end
                end
            else
                return aircraft.dbid, aircraft.loadoutID
            end
        end
    end
end

function RandomReplaceAircraft(side, listOfAircraftToReplace, chance, aircraftList, chanceNovice, chanceCadet,
                               chanceRegular, chanceVeteran, chanceAce, TimeToReady)
    for _, v in ipairs(listOfAircraftToReplace) do
        if math.random(1, 100) <= chance then
            local AircraftDBID, AircraftLoadout = SelectRandomAircraft(aircraftList)
            ReplaceAircraft_ByName(side, v.num1, v.num2, AircraftDBID, v.name, AircraftLoadout, TimeToReady) -- Aircraft replaced by name allows for mix of aircraft types
            RandomizeMultipleUnitProficiency(side, v.num1, v.num2, v.name, chanceNovice, chanceCadet, chanceRegular,
                chanceVeteran, chanceAce)
        end
    end
end

-- =======================
-- Automatic FARP Setup --
-- =======================

function LandingConditionsAreMet(aircraft, minAltitude, landingSpeed)
    local aircraftAltitude = ReturnUnitAltitudeAGL(aircraft.guid)
    if aircraft.unitstate ~= 'RTB' and aircraft.unitstate ~= 'RTB_Manual' then
        if not OverWater(aircraft.latitude, aircraft.longitude) and aircraftAltitude <= minAltitude and aircraft.speed <= landingSpeed and aircraft.airbornetime_v >= 300 then
            return true
        end
    end
    return false
end

function AddForwardRefuelingPoint(aircraft, TimeToReady)
    local FARP = ScenEdit_AddUnit({
        side = aircraft.side,
        type = 'Facility',
        dbid = 1594,
        name = 'FARP',
        latitude = aircraft.latitude,
        longitude = aircraft.longitude,
        heading = 0
    })

    ScenEdit_HostUnitToParent({ HostedUnitNameOrID = aircraft.guid, SelectedHostNameOrID = FARP.guid })
    ScenEdit_SetLoadout({ unitname = aircraft.guid, TimeToReady_Minutes = TimeToReady, IgnoreMagazines = true })
    ScenEdit_SetUnit({ guid = aircraft.guid, course = {} })
end

function SetupForwardRefuelingPoint()
    for _, aircraft in ipairs(CargoAircraftList) do
        local aircraftData = ScenEdit_GetUnit({ side = aircraft.side, name = aircraft.name })
        if aircraftData then
            if LandingConditionsAreMet(aircraftData, aircraft.minAltitude, aircraft.landingSpeed) then
                AddForwardRefuelingPoint(aircraftData, aircraft.TimeToReady)
            end
        end
    end
end

-- =========================
-- Request Basing
-- =========================

function PlayerRequestBasing(chance, base, messageRecipient, messageSender, messageSubject, countryName, baseName,
                             messageStringGranted, messageStringDenied)
    if math.random(1, 100) <= chance then
        baseStatus[base] = true -- Set the base status to true
        TelexMessageToPlayer(
            messageRecipient,
            messageSender,
            messageSubject,
            'TOP SECRET',
            'IMMEDIATE',
            'O',
            countryName ..
            ' HAS AGREED TO ALLOW AIRCRAFT BASED AT ' ..
            baseName .. ' TO PARTICIPATE IN OPERATIONS AGAINST IRAN. ' .. messageStringGranted,
            nil
        )
        return true
    else
        baseStatus[base] = false -- Set the base status to false
        TelexMessageToPlayer(
            messageRecipient,
            messageSender,
            messageSubject,
            'TOP SECRET',
            'IMMEDIATE',
            'O',
            countryName ..
            ' HAS DENIED OUR REQUEST FOR AIRCRAFT BASED ' ..
            baseName .. ' TO PARTICIPATE IN OPERATIONS AGAINST IRAN. ' .. messageStringDenied,
            nil
        )
        return false
    end
end

function checkBaseStatus(baseRequest)
    return baseStatus[baseRequest] or false
end

-- =========================
-- Request Overflight
-- =========================

function PlayerRequestOverflight(chance, country, zoneDescription, messageRecipient, messageSender, messageSubject,
                                 airspaceName)
    local PlayerSide = ScenEdit_PlayerSide()

    if math.random(1, 100) <= chance then
        overflight[country] = true -- Set the overflight status to true
        ScenEdit_SetZone(PlayerSide, 0, { description = zoneDescription, isactive = false })
        TelexMessageToPlayer(
            messageRecipient,
            messageSender,
            messageSubject,
            'TOP SECRET',
            'IMMEDIATE',
            'O',
            'YOUR REQUEST TO OVERFLY ' .. airspaceName .. ' AIR SPACE IS APPROVED.',
            nil
        )
        return true
    else
        overflight[country] = false -- Set the overflight status to false
        TelexMessageToPlayer(
            messageRecipient,
            messageSender,
            messageSubject,
            'TOP SECRET',
            'IMMEDIATE',
            'O',
            'YOUR REQUEST TO OVERFLY ' .. airspaceName .. ' AIR SPACE IS DENIED.',
            nil
        )
        return false
    end
end

-- =========================
-- Conduct Missile Strike on Selected Contacts
-- =========================

function ConductMissileStrikeOnSelectedContacts(firingUnitGUID, numMissilesAvailable, missileDBID, specialActionName,
                                                updateGlobalVariablesBoolean, numMissilesAvailableKey)
    local PlayerSide = ScenEdit_PlayerSide()
    local firingUnit = ScenEdit_GetUnit({ guid = firingUnitGUID })

    -- Input the number of missiles to fire at each selected contact
    local numMissilesFired = ScenEdit_InputBox(
    'Enter the number of missiles you want to fire at each selected contact(s). Remaining missiles on the ' ..
    firingUnit.name .. ': ' .. numMissilesAvailable .. '.')

    -- Convert input to a number and validate
    numMissilesFired = tonumber(numMissilesFired)
    if not numMissilesFired or numMissilesFired <= 0 then
        ScenEdit_MsgBox('Invalid number of missiles entered. Please enter a valid number.', 0)
        return
    end

    -- Check if there are valid contacts selected
    local selectedUnits = ScenEdit_SelectedUnits()
    if not selectedUnits.contacts or #selectedUnits.contacts == 0 then
        ScenEdit_MsgBox('Please select valid contacts before performing this special action.', 0)
        return
    end

    -- Calculate the total number of missiles needed
    local totalMissilesFired = numMissilesFired * #selectedUnits.contacts
    if totalMissilesFired > numMissilesAvailable then
        ScenEdit_MsgBox(
        'You do not have enough missiles. You are trying to fire a total of ' ..
        totalMissilesFired .. ' missiles, but only ' .. numMissilesAvailable .. ' are available.', 0)
        return
    end

    -- Fire missiles at the selected contacts
    for _, target in ipairs(selectedUnits.contacts) do
        ScenEdit_AttackContact(firingUnit.guid, target.guid, { mode = 1, weapon = missileDBID, qty = numMissilesFired })
    end

    -- Update the number of available missiles
    numMissilesAvailable = numMissilesAvailable - totalMissilesFired

    -- Update global variable if desired
    -- This only updates the global variable key value
    -- Set the global variable to the new key value outside of this function
    if updateGlobalVariablesBoolean then
        ScenEdit_SetKeyValue(numMissilesAvailableKey, tostring(numMissilesAvailable))
    end

    -- Turn off special action if the number of available missiles equals 0
    if numMissilesAvailable == 0 then
        ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameOrID = specialActionName, isactive = false })
    end
end

-- ==================
-- Scenario Events --
-- ==================

-- =========================
-- Player Scenario Setup
-- =========================

function PlayerScenarioSetup()
    local PlayerSide = ScenEdit_PlayerSide()

    -- Turn off events and special actions
    ScenEdit_SetEvent('Complete Scenario Setup', { isActive = false })

    ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameorID = 'Complete Scenario Setup', isactive = false })
    ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameorID = 'Political and Strategic Actions', isactive = false })
    ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameorID = 'Ready All Aircraft', isactive = false })

    -- Turn side specific actions on/off
    if PlayerSide == 'Israel' then
        if IsraelMissileStrikesApproved() then
            ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameorID = 'Launch USS Georgia Tomahawk Missile Strike', isactive = true })
            ScenEdit_SetSpecialAction({ side = PlayerSide, ActionNameorID = 'Launch USS Vermont Tomahawk Missile Strike', isactive = true })
        end
    elseif PlayerSide == 'United States' then
        -- Turn off USA deployment special actions
    elseif PlayerSide == 'United States-Israel' then
        -- Turn off USA deployment special actions
    end
end

-- =========================
-- Iran Initiates Hostilities
-- =========================

function IranInitiatesHostilities()
    local PlayerSide = ScenEdit_PlayerSide()
    ScenEdit_SetSidePosture('Iran', PlayerSide, 'H')
    ScenEdit_SetEMCON('Side', 'Iran', 'Radar=Active')

    ScenEdit_SetMission('Iran', 'CAP Center East', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'CAP Center West', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'CAP North', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'CAP South', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'CAP Southeast', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'CAP Southwest', { CheckOPA = true })
    ScenEdit_SetMission('Iran', 'QRA Long Range', { isactive = true })
    ScenEdit_SetMission('Iran', 'QRA Short Range', { isactive = true })
    SetSideMissionStatus('Civilian', false)

    ScenEdit_SetEvent('Iran Detects Unknown Aircraft', { isActive = false })
    ScenEdit_SetEvent('Iran Initiates Hostilities', { isActive = false })
    ScenEdit_SetEvent('Syria Detects Unknown Aircraft', { isActive = false })
end
