math.randomseed(os.time())
math.random()

scenarioZuluOffset = 0

-- =================
-- Core Functions --
-- =================

function RunScript(fileName)
    local scriptFilePath = scenarioScriptFilePath .. fileName .. '.lua'
    print('Attempting to execute ' .. scriptFilePath)
    if ScenEdit_RunScript(scriptFilePath) then
        print('Success!')
    end
end

function LuaReset()
    print('Resetting...')
    ScenEdit_ClearKeyValue("")
    print('KeyValues cleared.')
    RunScript('Game_LuaInit')
end

function ConvertStringToBoolean(stringName)
    local stringName = string.upper(stringName)
    local result = false
    if stringName == 'TRUE' then
        result = true
    end
    return result
end

function FindInTable(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
    return nil
end

function IsInList(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

function IsInListTable(list, checkTableFor, value)
    for _, v in ipairs(list) do
        if v[checkTableFor] == value then
            return true
        end
    end
    return false
end

function FindInListTable(list, checkTableFor, value)
    for _, v in ipairs(list) do
        if v[checkTableFor] == value then
            return v
        end
    end
    return nil
end

function shuffleTable(tableName)
    local n = #tableName
    for i = n, 2, -1 do
        local j = math.random(i)
        tableName[i], tableName[j] = tableName[j], tableName[i]
    end
end

function IsValidDBID(unit, allowedDBIDs)
    for _, allowedDbid in ipairs(allowedDBIDs) do
        if unit.dbid == allowedDbid then
            return true
        end
    end
    return false
end

function PrintUnitsOnSide(side)
    local sideUnits = VP_GetSide({ side = side }).units
    local unitList = {} -- Create a new blank Lua table to hold the units without duplicates

    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type ~= 'Group' and not unitList[unit.dbid] then
            -- Only add the unit if it is not a Group and not already in the list
            unitList[unit.dbid] = { type = unit.type, name = unit.classname }
        end
    end

    -- Print the unitList table
    for dbid, data in pairs(unitList) do
        print("[" .. dbid .. "] = {type='" .. data.type .. "', name='" .. data.name .. "'},")
    end
end

function PrintUnitsOnSide_ByType(side, unitType)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == unitType then
            print(unit)
        end
    end
end

function PrintUnitsInRange_ByDBID(side, dbid, centerPointGUID, maxRange)
    local unitList = {}
    local sideUnits = VP_GetSide({ side = side }).units

    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == dbid then
            local range = Tool_Range(centerPointGUID, unit.guid)
            if range <= maxRange then
                table.insert(unitList, unit.guid)
            end
        end
    end

    print('local unitList = {')
    for _, guid in ipairs(unitList) do
        print("	'" .. guid .. "',")
    end
    print('}')
end

function RoundNumber(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function GetRandomRoundedNumber(min, max, roundTo)
    local randomNum = math.random(min, max)
    return math.floor((randomNum + roundTo / 2) / roundTo) * roundTo
end

function randomGaussian(mean, standardDeviation)
    -- Box-Muller transform to get a normally distributed random value
    local u1, u2
    repeat
        u1 = math.random()
    until u1 ~= 0
    repeat
        u2 = math.random()
    until u2 ~= 0

    local z = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return mean + z * standardDeviation
end

function RangeBearing(fromHere, toHere)
    local range = Tool_Range(fromHere, toHere)
    local bearing = Tool_Bearing(fromHere, toHere)
    return range, bearing
end

function CheckRangeToUnit(selectedUnit, targetUnit, maxRange)
    ScenEdit_GetUnit({ guid = selectedUnit.guid })
    local range = Tool_Range(selectedUnit.guid, targetUnit.guid)
    return range <= maxRange
end

function CheckRangeToCoordinates(selectedUnit, targetLat, targetLon, maxRange)
    ScenEdit_GetUnit({ guid = selectedUnit.guid })
    local targetPosition = { latitude = targetLat, longitude = targetLon }
    local range = Tool_Range(selectedUnit.guid, targetPosition)
    return range <= maxRange
end

function CheckMinRangeToCoordinates(positionLat, positionLon, targetLat, targetLon, minRange)
    local position = { latitude = positionLat, longitude = positionLon }
    local targetPosition = { latitude = targetLat, longitude = targetLon }
    local range = Tool_Range(position, targetPosition)
    return range >= minRange -- Note: Use '>=' to check if the range is above the minimum range
end

function ConvertDecimalToCoord(latitude, longitude)
    -- Convert latitude and longitude to numbers if they are strings
    latitude = tonumber(latitude)
    longitude = tonumber(longitude)

    -- Determine if latitude is North or South
    local latDirection = "N"
    if latitude < 0 then
        latDirection = "S"
        latitude = math.abs(latitude)
    end

    -- Determine if longitude is East or West
    local lonDirection = "E"
    if longitude < 0 then
        lonDirection = "W"
        longitude = math.abs(longitude)
    end

    -- Separate degrees, minutes, and seconds for latitude
    local latDegrees = math.floor(latitude)
    local latMinutesFull = (latitude - latDegrees) * 60
    local latMinutes = math.floor(latMinutesFull)
    local latSeconds = math.floor((latMinutesFull - latMinutes) * 60) -- Rounded to no decimals

    -- Separate degrees, minutes, and seconds for longitude
    local lonDegrees = math.floor(longitude)
    local lonMinutesFull = (longitude - lonDegrees) * 60
    local lonMinutes = math.floor(lonMinutesFull)
    local lonSeconds = math.floor((lonMinutesFull - lonMinutes) * 60) -- Rounded to no decimals

    -- Format the result as degrees, minutes, and rounded seconds with direction
    local formattedLatitude = string.format("%d° %d' %d\" %s", latDegrees, latMinutes, latSeconds, latDirection)
    local formattedLongitude = string.format("%d° %d' %d\" %s", lonDegrees, lonMinutes, lonSeconds, lonDirection)

    return formattedLatitude, formattedLongitude
end

function RandomPosition(latitudeMin, latitudeMax, longitudeMin, longitudeMax)
    local lat_var = math.random(1, (10 ^ 13))                               -- random number between 1 and 10^13
    local lon_var = math.random(1, (10 ^ 13))                               -- random number between 1 and 10^13
    local pos_lat = math.random(latitudeMin, latitudeMax) + (lat_var / (10 ^ 13)) -- latitude;
    local pos_lon = math.random(longitudeMin, longitudeMax) + (lon_var / (10 ^ 13)) -- longitude;
    return { latitude = pos_lat, longitude = pos_lon }
end

function CircularRandomPosition(x_latitude, x_longitude, max_radius)
    local randomisationCircle = World_GetCircleFromPoint({
        latitude = x_latitude,
        longitude = x_longitude,
        radius = (math.random(0, max_radius * 10) / 10),
        numpoints = 72
    })
    local randomisedPoint = randomisationCircle[math.random(1, #randomisationCircle)]
    return randomisedPoint
end

function JitterPosition(guid, radius, overWater)
    if overWater == nil then overWater = false end
    local unit = ScenEdit_GetUnit({ guid = guid })
    local newPos = CircularRandomPosition(unit.latitude, unit.longitude, radius)
    if OverWater(newPos.latitude, newPos.longitude) == overWater then
        ScenEdit_SetUnit({
            guid = unit.guid,
            latitude = newPos.latitude,
            longitude = newPos.longitude
        })
    end
end

function AddCircleOfReferencePoints(refPointside, refPointName, centerLatitude, centerLongitude, radius, numpoints,
                                    highlightedBoolean)
    local circle = World_GetCircleFromPoint({ latitude = centerLatitude, longitude = centerLongitude, radius = radius, numpoints =
    numpoints })
    for k, v in ipairs(circle) do
        ScenEdit_AddReferencePoint({ side = refPointside, name = refPointName .. k, latitude = v.latitude, longitude = v
        .longitude, highlighted = highlightedBoolean })
    end
end

function AddReferencePointAtBearingDistance(side, originReferencePointName, bearing, distance, newReferencePointName,
                                            highlighted)
    local originPosition = ScenEdit_GetReferencePoint({ side = side, name = originReferencePointName })
    local newPosition = World_GetPointFromBearing({ latitude = originPosition.latitude, longitude = originPosition
    .longitude, bearing = bearing, distance = distance })
    local newReferencePoint = ScenEdit_AddReferencePoint({ side = side, name = newReferencePointName, latitude =
    newPosition.latitude, longitude = newPosition.longitude, highlighted = highlighted })
end

function AddReferencePointAtBearingDistanceFromUnit(side, unitGUID, referencePointName, relativeToUnitHeadingBoolean,
                                                    bearing, distance, bearingType, highlightedBoolean)
    local unit = ScenEdit_GetUnit({ guid = unitGUID })
    local refPointBearing
    local refPointPosition

    -- Determine if the reference point bearing is relative to the unit heading
    if relativeToUnitHeadingBoolean then
        refPointBearing = unit.heading + bearing
    else
        refPointBearing = bearing
    end

    -- Add the reference point relative to the unit
    ScenEdit_AddReferencePoint({ side = side, name = referencePointName, relativeTo = unitGUID, bearing = refPointBearing, distance =
    distance, bearingtype = bearingType, highlighted = highlightedBoolean })
end

function AddReferencePointAtUnitLocation(side, dbid, referencePointName, highlighted)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == dbid then
            ScenEdit_AddReferencePoint({ side = side, name = referencePointName, latitude = unit.latitude, longitude =
            unit.longitude, highlighted = highlighted })
        end
    end
end

function DeleteReferencePoints_BySide(side)
    local sideRefPoints = VP_GetSide({ side = side }).rps
    for k, v in ipairs(sideRefPoints) do
        ScenEdit_DeleteReferencePoint({ guid = v.guid })
    end
end

function DeleteReferencePoints_ByName(side, referencePointName, numberOfReferencePoints)
    for i = 1, numberOfReferencePoints do
        ScenEdit_DeleteReferencePoint({ side = side, name = referencePointName .. ' ' .. i })
    end
end

function HighlightReferencePoints_BySide(side, boolean)
    local sideRefPoints = VP_GetSide({ side = side }).rps
    for k, v in ipairs(sideRefPoints) do
        ScenEdit_SetReferencePoint({ side = side, guid = v.guid, highlighted = boolean })
    end
end

function SetReferencePointAtBearingDistanceFromUnit(side, unitGUID, referencePointName, relativeToUnitHeadingBoolean,
                                                    bearing, distance, bearingType)
    local unit = ScenEdit_GetUnit({ guid = unitGUID })
    local refPointBearing
    local refPointPosition

    -- Determine if the reference point bearing is relative to the unit heading
    if relativeToUnitHeadingBoolean then
        refPointBearing = unit.heading + bearing
    else
        refPointBearing = bearing
    end

    -- Get the new position of the reference point relative to the unit
    -- This is a temporary solution until distance/bearing issue with SetReferencePoint is fixed
    refPointPosition = World_GetPointFromBearing({ latitude = unit.latitude, longitude = unit.longitude, bearing =
    refPointBearing, distance = distance })

    -- Set the reference point to the new position
    ScenEdit_SetReferencePoint({ side = side, name = referencePointName, latitude = refPointPosition.latitude, longitude =
    refPointPosition.longitude, bearingtype = bearingType })
end

function GoToLatitudeLongitude(latitude, longitude, msg)
    local msg = msg
    if not msg then
        msg = 'Jumped to:<BR>Latitude: ' .. latitude .. '<BR>Longitude: ' .. longitude
    end
    ScenEdit_SpecialMessage('playerside', msg, { latitude = latitude, longitude = longitude }, true)
end

function GoToReferencePoint(side, name)
    local refPoint = ScenEdit_GetReferencePoint({ side = side, name = name })
    local msg = 'Jumped to Reference Point: ' ..
    refPoint.name .. '<BR>Latitude: ' .. refPoint.latitude .. '<BR>Longitude: ' .. refPoint.longitude
    Tool_GoToLatitudeLongitude(refPoint.latitude, refPoint.longitude, msg)
end

function BugMessage(eventName, description)
    ScenEdit_MsgBox(
    'An issue occured with ' ..
    eventName ..
    '.\n\n' ..
    description ..
    '\n\nThis will not affect system stability but may affect scenario balance.\n\nPlease report this to the scenario thread on the Matrix Games forum or to the Steam Workshop page.',
        0)
end

function ChangeScore(side, amt, reason)
    local newScore = ScenEdit_GetScore(side) + amt
    ScenEdit_SetScore(side, newScore, reason)
    print(side .. ' score changed to ' .. newScore)
    return newScore
end

function OverWater(latitude, longitude)
    local pointElevation = World_GetElevation({
        latitude = latitude,
        longitude = longitude
    })
    if pointElevation < 0 then
        return true
    else
        return false
    end
end

function ChanceOfAppearance(guid, unitChance)
    local chance = math.random(1, 100)
    if chance <= unitChance then
        ScenEdit_DeleteUnit({ guid = guid })
    end
end

function GetRandomBoolean(chance)
    if math.random(1, 100) <= chance then
        return true
    else
        return false
    end
end

-- ===========================
-- Communications Functions --
-- ===========================

function RadioSoundEffect()
    local fileName = 'radioChirp' .. math.random(1, 8) .. '.mp3'
    ScenEdit_PlaySound(fileName)
end

function DTG(TimeVar)
    if TimeVar == nil then
        TimeVar = ScenEdit_CurrentTime()
    end
    local msgtime = os.date("!%d%H%M" .. "Z" .. " " .. "%b %y", TimeVar)
    local msgtime = string.upper(msgtime)
    return msgtime
end

function RegisterMessage(messageString)
    local counter = 0
    for int1 = 1, 10 do
        local storedMessage = ScenEdit_GetKeyValue('storedMessage_' .. int1)
        if storedMessage ~= nil then
            counter = counter + 1
        end
    end

    if counter == 10 then
        for int2 = 1, 10 do
            local shiftedMessage = ScenEdit_GetKeyValue('storedMessage_' .. int2)
            local shiftedMessageSlot = int2 - 1
            ScenEdit_SetKeyValue('storedMessage_' .. shiftedMessageSlot, shiftedMessage)
        end
        messageNumber = 10
    elseif counter <= 9 then
        messageNumber = counter + 1
    elseif counter == 0 then
        messageNumber = 1
    end
    ScenEdit_SetKeyValue('storedMessage_' .. messageNumber, messageString)
end

function ReplayMessages()
    for i = 10, 1, -1 do
        local message = ScenEdit_GetKeyValue('storedMessage_' .. i)
        if message ~= nil and message ~= '' then
            ScenEdit_SpecialMessage('playerside', message)
        end
    end
end

function RadioMessage(band, frequency, theMessage, location)
    assert(theMessage, 'RadioMessage(): No message passed!')

    -- Generate the radio message body with formatted text
    local formattedMessage = '<P><I>"' .. theMessage .. '"</I></P> '
    local DTG = DTG()
    local theRadioMessage = '<P>' .. DTG .. '<BR>' .. band .. '<BR>' .. frequency .. '</P>' .. formattedMessage

    -- Send the message with or without location information
    if location ~= nil then
        ScenEdit_SpecialMessage('playerside', theRadioMessage, { latitude = location.latitude, longitude = location
        .longitude })
    else
        ScenEdit_SpecialMessage('playerside', theRadioMessage)
    end

    -- Register the message and play sound
    RegisterMessage(theRadioMessage)
    RadioSoundEffect()
end

function Signal(precedence, time, code, sender, recipient, classification, subject, body)
    -- Precedence -- Flash (Z), Immediate (O), Priority (P), Routine (R), Flash Override (Y)
    -- From -- e.g. MET FLT OPS
    -- To -- e.g. SSN 21 SEAWOLF
    -- Classification -- Unclas +/- SBU / FOUO / NOFORN (Restricted), Confidential, Secret, Top Secret
    -- Body
    local msg_time
    if time == nil then
        msg_time = DTG()
    else
        msg_time = time
    end
    local signal_string = string.upper('<P><FONT face=Courier New>'
        .. precedence .. ' <BR>'
        .. code .. ' ' .. msg_time .. ' <BR>' ..
        'FM ' .. sender .. ' <BR>' ..
        'TO ' .. recipient .. ' <BR>'
        .. classification .. ' <BR>' ..
        'SUBJ: ' .. subject .. '</P>' ..
        '<P>' .. body .. '</P>'
    )
    return signal_string
end

function TelexMessageToPlayer(precedence, time, code, sender, recipient, classification, subject, body, location)
    local theMessage = Signal(precedence, time, code, sender, recipient, classification, subject, body)
    if location ~= nil then
        ScenEdit_SpecialMessage('playerside', theMessage, { latitude = location.latitude, longitude = location.longitude })
    else
        ScenEdit_SpecialMessage('playerside', theMessage)
    end
    ScenEdit_PlaySound('telex.mp3')
    RegisterMessage(theMessage)
end

-- ====================
-- Weather Functions --
-- ====================

function RandomTemperature(meanMinTemp, meanMaxTemp, absoluteMinTemp, absoluteMaxTemp, outlierChance, outlierTemp,
                           normalTemp)
    -- Randomly choose mean temperature within given ranges
    local meanTemp = meanMinTemp + (meanMaxTemp - meanMinTemp) * math.random()

    -- Determine if temperature is an outlier
    local outlierBoolean = (math.random(100) <= outlierChance)

    -- Choose appropriate deviation based on outlier condition
    local tempDeviation = outlierBoolean and outlierTemp or normalTemp

    -- Generate raw Gaussian-distributed temperature
    local tempVariability = randomGaussian(meanTemp, tempDeviation)

    -- Clamp values to absolute min and max
    local newTemp = math.floor(math.max(absoluteMinTemp, math.min(tempVariability, absoluteMaxTemp)) + 0.5)

    return newTemp
end

function RandomUndercloud(meanMinUndercloud, meanMaxUndercloud, absoluteMinUndercloud, absoluteMaxUndercloud,
                          outlierChance, outlierUndercloud, normalUndercloud)
    -- Randomly choose mean undercloud within given ranges
    local meanUndercloud = meanMinUndercloud + (meanMaxUndercloud - meanMinUndercloud) * math.random()

    -- Determine if undercloud coverage is an outlier
    local outlierBoolean = (math.random(100) <= outlierChance)

    -- Choose appropriate deviation based on outlier condition
    local undercloudDeviation = outlierBoolean and outlierUndercloud or normalUndercloud

    -- Generate raw Gaussian-distributed undercloud coverage
    local undercloudVariability = randomGaussian(meanUndercloud, undercloudDeviation)

    -- Clamp values to absolute min and max (both presumably between 0 and 1)
    local newUndercloud = math.floor(math.max(absoluteMinUndercloud,
        math.min(undercloudVariability, absoluteMaxUndercloud))) / 10

    return newUndercloud
end

function RandomRainfall(meanMinRainfall, meanMaxRainfall, absoluteMinRainfall, absoluteMaxRainfall, outlierChance,
                        outlierRainfall, normalRainfall, undercloud)
    -- Randomly choose mean rainfall within given ranges
    local meanRainfall = meanMinRainfall + (meanMaxRainfall - meanMinRainfall) * math.random()

    -- Determine if rainfall is an outlier
    local outlierBoolean = (math.random(100) <= outlierChance)

    -- Choose appropriate deviation based on outlier condition
    local rainfallDeviation = outlierBoolean and outlierRainfall or normalRainfall

    -- Generate raw Gaussian-distributed rainfall
    local rainfallVariability = randomGaussian(meanRainfall, rainfallDeviation)

    -- Clamp values to absolute min and max
    local newRainfall = math.floor(math.max(absoluteMinRainfall, math.min(rainfallVariability, absoluteMaxRainfall)) +
    0.5)

    if undercloud <= 0.2 then
        newRainfall = 0 -- No rain if undercloud is too low
    end

    return newRainfall
end

function RandomSeastate(meanMinSeastate, meanMaxSeastate, absoluteMinSeastate, absoluteMaxSeastate, outlierChance,
                        outlierSeastate, normalSeastate)
    -- Randomly choose mean seastate within given ranges
    local meanSeastate = meanMinSeastate + (meanMaxSeastate - meanMinSeastate) * math.random()

    -- Determine if seastate is an outlier
    local outlierBoolean = (math.random(100) <= outlierChance)

    -- Choose appropriate deviation based on outlier condition
    local seastateDeviation = outlierBoolean and outlierSeastate or normalSeastate

    -- Generate raw Gaussian-distributed seastate
    local seastateVariability = randomGaussian(meanSeastate, seastateDeviation)

    -- Clamp values to absolute min and max
    local newSeastate = math.floor(math.max(absoluteMinSeastate, math.min(seastateVariability, absoluteMaxSeastate)) +
    0.5)

    return newSeastate
end

function ForecastTemperature(currentTemp, latitude, longitude, intervalMultiplier, minTemp, maxTemp)
    -- Temperature variability is set by time of day
    -- intervalMultiplier is used to adjust temperature change for frequency of event execution
    -- Use lower value (1) for more frequent execution and higher (2-3) for less frequent
    local timeOfDay = ScenEdit_GetTimeOfDay({ latitude = latitude, longitude = longitude })
    local tempVariability
    if timeOfDay.TOD == 'dawn' then
        tempVariability = math.random(0, 1) * intervalMultiplier
    elseif timeOfDay.TOD == 'day' then
        tempVariability = math.random(0, 2) * intervalMultiplier
    elseif timeOfDay.TOD == 'dusk' then
        tempVariability = math.random(-1, 0) * intervalMultiplier
    else -- Time of Day = Night
        tempVariability = math.random(-2, 0) * intervalMultiplier
    end

    -- Calculate new temperature and enforce min/max limits
    local newTemp = currentTemp + tempVariability
    newTemp = math.max(minTemp, math.min(newTemp, maxTemp)) -- Sets temperature within min/max temperature range

    return newTemp
end

function ForecastUndercloud(currentUndercloud, chanceOfClouds, cloudVariabilityChance, maxUndercloud)
    local newUndercloud
    if math.random(1, 100) <= chanceOfClouds then
        newUndercloud = math.max(0, math.min(currentUndercloud + math.random(0, 3) / 10, maxUndercloud)) -- Increase undercloud
    else
        if math.random(1, 100) <= cloudVariabilityChance then
            newUndercloud = math.max(0, math.min(currentUndercloud + math.random(-3, 0) / 10, maxUndercloud)) -- Decrease undercloud
        else
            newUndercloud = currentUndercloud
        end
    end

    return newUndercloud
end

function ForecastRainfall(currentRainfall, chanceOfRain, undercloud, rainfallVariabilityChance, maxRainfall)
    local newRainfall
    if math.random(1, 100) <= chanceOfRain then
        newRainfall = math.max(0, math.min(currentRainfall + math.random(0, 3), maxRainfall)) -- Increase rainfall
        if undercloud <= 0.2 then
            newRainfall = 0                                                            -- No rain if cloud cover is too low
        end
    else
        if math.random(1, 100) <= rainfallVariabilityChance then
            newRainfall = math.max(0, math.min(currentRainfall + math.random(-3, 0), maxRainfall)) -- Decrease rainfall
        else
            newRainfall = currentRainfall
        end
    end

    return newRainfall
end

function ForecastSeastate(currentSeastate, chanceOfWind, windVariabilityChance, maxSeastate)
    local newSeastate
    if math.random(1, 100) <= chanceOfWind then
        newSeastate = math.max(0, math.min(currentSeastate + math.random(0, 2), maxSeastate)) -- Increase seastate/wind
    else
        if math.random(1, 100) <= windVariabilityChance then
            newSeastate = math.max(0, math.min(currentSeastate + math.random(-2, 0), maxSeastate)) -- Decrease seastate/wind
        else
            newSeastate = currentSeastate
        end
    end

    return newSeastate
end

function GlobalWeatherDrift(latitude, longitude, intervalMultiplier, minTemp, maxTemp, chanceOfClouds,
                            cloudVariabilityChance, maxUndercloud, chanceOfRain, rainfallVariabilityChance, maxRainfall,
                            chanceOfWind, windVariabilityChance, maxSeastate)
    -- Latitude and Longitude should be set to the approximate center of scenarios Operations
    -- chanceOfClouds, chanceOfRain, and chanceOfWind are the chances for the weather effect to increase
    -- cloudVariabilityChance, rainfallVariabilityChance, and windVariabilityChance are the chance of the weather effect to remain the same or decrease if it does not increase
    -- minTemp, maxTemp, maxUndercloud, maxRainfall, and maxSeastate set the minimum and maximum for their weather effect

    -- Get the current weather to use as a baseline and set new weather conditions
    local weatherBaseline = ScenEdit_GetWeather()
    local newTemp = ForecastTemperature(weatherBaseline.temp, latitude, longitude, intervalMultiplier, minTemp, maxTemp)
    local newUndercloud = ForecastUndercloud(weatherBaseline.undercloud, chanceOfClouds, cloudVariabilityChance,
        maxUndercloud)
    local newRainfall = ForecastRainfall(weatherBaseline.rainfall, chanceOfRain, newUndercloud, rainfallVariabilityChance,
        maxRainfall)
    local newSeastate = ForecastSeastate(weatherBaseline.seastate, chanceOfWind, windVariabilityChance, maxSeastate)

    -- Update global weather conditions
    ScenEdit_SetWeather(
        newTemp, -- temp
        newRainfall, -- rainfall
        newUndercloud, -- undercloud
        newSeastate -- seastate
    )
end

function CustomEnviromentalZoneWeatherDrift(ListOfCustomEnvironmentZones)
    -- Latitude and Longitude should be set to the approximate center of scenarios Operations
    -- chanceOfClouds, chanceOfRain, and chanceOfWind are the chances for the weather effect to increase
    -- cloudVariabilityChance, rainfallVariabilityChance, and windVariabilityChance are the chance of the weather effect to remain the same or decrease if it does not increase
    -- minTemp, maxTemp, maxUndercloud, maxRainfall, and maxSeastate set the minimum and maximum for their weather effect

    -- Check for Custom Environment Zones on the Nature side then iterate through the ListOfCustomEnvironmentZones
    -- ListOfCustomEnvironmentZones links zone to the specific zone variables
    local side = VP_GetSide({ name = 'Nature' })
    for _, zone in ipairs(ListOfCustomEnvironmentZones) do
        -- Get zone weather to use as a baseline and set new weather conditions
        local currentZone = side:getcustomenvironmentzone(zone.guid)
        local weatherBaseline = currentZone.weatherprofile
        local newTemp = ForecastTemperature(weatherBaseline.temp, zone.latitude, zone.longitude, zone.intervalMultiplier,
            zone.minTemp, zone.maxTemp)
        local newUndercloud = ForecastUndercloud(weatherBaseline.undercloud, zone.chanceOfClouds,
            zone.cloudVariabilityChance, zone.maxUndercloud)
        local newRainfall = ForecastRainfall(weatherBaseline.rainfall, zone.chanceOfRain, newUndercloud,
            zone.rainfallVariabilityChance, zone.maxRainfall)
        local newSeastate = ForecastSeastate(weatherBaseline.seastate, zone.chanceOfWind, zone.windVariabilityChance,
            zone.maxSeastate)

        -- Update zone weather conditions
        currentZone.weatherprofile = {
            temp = newTemp,
            rainfall = newRainfall,
            undercloud = newUndercloud,
            seastate = newSeastate
        }
    end
end

function SetCustomEnviromentalZoneWeather(ListOfCustomEnvironmentZones)
    -- Used to inject weather generated outside of function into Custom Environment Zones
    -- Example Usage - Forcast weather report before setting weather or set random weather conditions

    -- Check for Custom Environment Zones on the Nature side then iterate through the ListOfCustomEnvironmentZones
    -- ListOfCustomEnvironmentZones links zone to the specific zone variables
    local side = VP_GetSide({ name = 'Nature' })
    for _, zone in ipairs(ListOfCustomEnvironmentZones) do
        -- Get zone GUID and set new weather conditions
        local currentZone = side:getcustomenvironmentzone(zone.guid)
        local newTemp = zone.temp
        local newUndercloud = zone.undercloud
        local newRainfall = zone.rainfall
        local newSeastate = zone.seastate

        -- Update weather conditions
        currentZone.weatherprofile = {
            temp = newTemp,
            rainfall = newRainfall,
            undercloud = newUndercloud,
            seastate = newSeastate
        }
    end
end

-- ===========================
-- Weather Report Functions --
-- ===========================

function GenerateRainDescriptor(rain)
    local result
    if rain == 0 then
        result = 'NO'
    elseif rain < 5 then
        result = 'VERY LIGHT'
    elseif rain < 11 then
        result = 'LIGHT'
    elseif rain < 20 then
        result = 'MODERATE'
    elseif rain < 30 then
        result = 'HEAVY'
    elseif rain < 40 then
        result = 'VERY HEAVY'
    else
        result = 'EXTREME'
    end
    return result
end

function GenerateCloudDescriptor(cloud)
    local result
    if cloud == 0 then
        result = 'CLEAR SKIES'
    elseif cloud < 0.2 then
        result = 'LIGHT LOW CLOUDS'
    elseif cloud < 0.3 then
        result = 'LIGHT MIDDLE CLOUDS'
    elseif cloud < 0.4 then
        result = 'LIGHT HIGH CLOUDS'
    elseif cloud < 0.5 then
        result = 'MODERATE LOW CLOUDS'
    elseif cloud < 0.6 then
        result = 'MODERATE MIDDLE CLOUDS'
    elseif cloud < 0.7 then
        result = 'MODERATE HIGH CLOUDS'
    elseif cloud < 0.8 then
        result = 'MODERATE MIDDLE CLOUDS AND LIGHT HIGH CLOUDS'
    elseif cloud < 0.9 then
        result = 'SOLID MIDDLE CLOUDS AND MODERATE HIGH CLOUDS'
    elseif cloud < 1.0 then
        result = 'THIN FOG AND SOLID CLOUD COVER'
    else
        result = 'THICK FOG AND SOLID CLOUD COVER'
    end
    return result
end

function ConvertTempCtoF(temp)
    local result = RoundNumber((temp * 1.8) + 32, 0)
    return result
end

function WeatherReport(globalWeatherRegion, weatherUpdateBoolean, timeToNextUpdateInSeconds)
    -- Get the current global weather and generate descriptions
    local weather = ScenEdit_GetWeather()
    local globalUndercloud = GenerateCloudDescriptor(weather.undercloud)
    local globalRainfall = GenerateRainDescriptor(weather.rainfall)
    local globalSeastate = weather.seastate
    local globalTempC = weather.temp
    local globalTempF = ConvertTempCtoF(weather.temp)

    -- Add global weather to weather report message
    local message = globalWeatherRegion ..
    ': ' ..
    globalUndercloud ..
    '. ' ..
    globalRainfall ..
    ' PRECIPITATION. SEA STATE ' ..
    globalSeastate .. '. AVERAGE TEMPERATURE ' .. globalTempC .. 'C / ' .. globalTempF .. 'F.<BR><BR>'

    -- Check for Custom Environment Zones on the Nature side and append each CEZs weather to weather report message
    -- If there are no CEZs then only global weather will be reported
    local side = VP_GetSide({ name = 'Nature' })
    if side and side.customenvironmentzones then
        for _, zone in ipairs(side.customenvironmentzones) do
            -- Get the current weather in CEZ and generate descriptions
            local currentZone = side:getcustomenvironmentzone(zone.guid)
            local weatherBaseline = currentZone.weatherprofile
            local zoneUndercloud = GenerateCloudDescriptor(weatherBaseline.undercloud)
            local zoneRainfall = GenerateRainDescriptor(weatherBaseline.rainfall)
            local zoneSeastate = weatherBaseline.seastate
            local zoneTempC = weatherBaseline.temp
            local zoneTempF = ConvertTempCtoF(weatherBaseline.temp)

            -- Add CEZ weather to the weather report message
            message = message ..
            zone.description ..
            ': ' ..
            zoneUndercloud ..
            '. ' ..
            zoneRainfall ..
            ' PRECIPITATION. SEA STATE ' ..
            zoneSeastate .. '. AVERAGE TEMPERATURE ' .. zoneTempC .. 'C / ' .. zoneTempF .. 'F.<BR><BR>'
        end
    end

    -- Optionally  append next weather update to the weather report message
    -- Use true automated messages
    -- Use false for player special actions to retrieve current weather
    if weatherUpdateBoolean == true then
        local nextUpdate
        if timeToNextUpdateInSeconds == nil then
            nextUpdate = 'NEXT UPDATE AT ' ..
            DTG(ScenEdit_CurrentTime() + 10800)                          -- Default: Current Time + 10,800 seconds (3 hours)
        else
            nextUpdate = 'NEXT UPDATE AT ' .. DTG(ScenEdit_CurrentTime() + timeToNextUpdateInSeconds)
        end
        message = message .. nextUpdate
    end

    -- Send the weather report to the player
    TelexMessageToPlayer(
        'ROUTINE',
        nil,
        'R',
        'METOPS',
        'ALL STATIONS',
        'UNCLAS',
        'WEATHER REPORT',
        message,
        nil
    )
end

function WeatherForecast(globalWeatherRegion, globalUndercloudForecast, globalRainfallForecast, globalSeastateForecast,
                         globalMinTempForecast, globalMaxTempForecast, ListOfCustomEnvironmentZones, weatherUpdateBoolean,
                         timeToNextUpdateInSeconds)
    -- Get the current global weather and generate descriptions
    local globalundercloud = GenerateCloudDescriptor(globalUndercloudForecast)
    local globalrainfall = GenerateRainDescriptor(globalRainfallForecast)
    local globalSeastate = globalSeastateForecast
    local globalMinTempC = globalMinTempForecast
    local globalMaxTempC = globalMaxTempForecast
    local globalMinTempF = ConvertTempCtoF(globalMinTempForecast)
    local globalMaxTempF = ConvertTempCtoF(globalMaxTempForecast)

    -- Add global weather to weather report message
    local message = globalWeatherRegion ..
    ': ' ..
    globalundercloud ..
    '. ' ..
    globalrainfall ..
    ' PRECIPITATION. SEA STATE ' ..
    globalSeastate ..
    '. AVERAGE LOW ' ..
    globalMinTempC ..
    'C / ' .. globalMinTempF .. 'F AND An AVERAGE HIGH OF ' .. globalMaxTempC .. 'C / ' .. globalMaxTempF .. 'F.<BR><BR>'

    -- Check for Custom Environment Zones on the Nature side then iterate through the ListOfCustomEnvironmentZones
    -- ListOfCustomEnvironmentZones links zone to the specific zone variables
    -- If there are no CEZs then only global weather will be reported
    local side = VP_GetSide({ name = 'Nature' })
    if side and side.customenvironmentzones then
        for _, zone in ipairs(ListOfCustomEnvironmentZones) do
            -- Get the current weather in CEZ and generate descriptions
            local zoneUndercloud = GenerateCloudDescriptor(zone.undercloud)
            local zoneRainfall = GenerateRainDescriptor(zone.rainfall)
            local zoneSeastate = zone.seastate
            local zoneMinTempC = zone.minTemp
            local zoneMaxTempC = zone.maxTemp
            local zoneMinTempF = ConvertTempCtoF(zone.minTemp)
            local zoneMaxTempF = ConvertTempCtoF(zone.maxTemp)

            -- Add CEZ weather to the weather report message
            message = message ..
            zone.description ..
            ': ' ..
            zoneUndercloud ..
            '. ' ..
            zoneRainfall ..
            ' PRECIPITATION. SEA STATE ' ..
            zoneSeastate ..
            '. AVERAGE LOW ' ..
            zoneMinTempC ..
            'C / ' .. zoneMinTempF .. 'F AND An AVERAGE HIGH OF ' .. zoneMaxTempC .. 'C / ' .. zoneMaxTempF ..
            'F.<BR><BR>'
        end
    end

    -- Optionally  append next weather update to the weather report message
    -- Use true automated messages
    -- Use false for player special actions to retrieve current weather
    if weatherUpdateBoolean == true then
        local nextUpdate
        if timeToNextUpdateInSeconds == nil then
            nextUpdate = 'NEXT UPDATE AT ' ..
            DTG(ScenEdit_CurrentTime() + 10800)                          -- Default: Current Time + 10,800 seconds (3 hours)
        else
            nextUpdate = 'NEXT UPDATE AT ' .. DTG(ScenEdit_CurrentTime() + timeToNextUpdateInSeconds)
        end
        message = message .. nextUpdate
    end

    -- Send the weather report to the player
    TelexMessageToPlayer(
        'ROUTINE',
        nil,
        'R',
        'METOPS',
        'ALL STATIONS',
        'UNCLAS',
        'WEATHER FORECAST',
        message,
        nil
    )
end

function TimeIs(timeVar)
    if timeVar == nil then timeVar = ScenEdit_CurrentTime() end
    local timeStampTable = os.date("!*t", timeVar)
    local timeTable = {
        day = timeStampTable.day,
        hour = timeStampTable.hour,
        minute = timeStampTable.min
    }
    return timeTable
end

function WeatherReportIsDue(reportInterval)
    local result = false
    local hourZulu = TimeIs().hour
    local hourLocal = hourZulu + scenarioZuluOffset
    if hourLocal % reportInterval == 0 then
        result = true
    end

    return result
end

-- ==========================
-- Downed Pilot Generation --
-- ==========================

function DetermineTypeOfPilotSurvivor(latitude, longitude, survivalChance)
    local survivorType = 'Facility'
    local survivorDBID = 2046 -- Stranded Personnel (1x)

    local survived = PilotSurvives(survivalChance)

    if OverWater(latitude, longitude) then
        survivorType = 'Ship'
        if survived then
            local liferaftOptions = { 3725, 4877 } -- 1.8m Life Raft Single Person [Aircrew Survival Raft]; Person in Water, Alive
            survivorDBID = liferaftOptions[math.random(#liferaftOptions)]
        else
            survivorDBID = 4878 -- Person in Water, Deceased
        end
    else
        if not survived then
            survivorDBID = 2441 -- Stranded Personnel (1x), Immobile
        end
    end

    return { type = survivorType, dbid = survivorDBID }
end

function PlacePilotSurvivor(side, latitude, longitude, survivalChance)
    local randomPosition = CircularRandomPosition(latitude, longitude, 2)
    local survivorData = DetermineTypeOfPilotSurvivor(randomPosition.latitude, randomPosition.longitude, survivalChance)
    local survivor = ScenEdit_AddUnit({
        side = side,
        type = survivorData.type,
        dbid = survivorData.dbid,
        name = 'Downed Pilot',
        latitude = randomPosition.latitude,
        longitude = randomPosition.longitude
    })

    table.insert(SurvivorList, survivor)
end

function RandomBailoutString()
    local damagePrefixes = {
        "I've lost control!",
        "They got me!",
        "Taking hits!",
        "I'm hit!",
        "Flight controls are gone!",
        "Taking heavy fire!",
        "...",
    }

    local bailoutSuffixes = {
        "Going in!",
        "Going down!",
        "Eject, eject, eject!!!",
        "I can't hold it together!",
        "Bailing out!",
        "...",
    }

    local result = damagePrefixes[math.random(1, #damagePrefixes)] ..
    ' ' .. bailoutSuffixes[math.random(1, #bailoutSuffixes)]
    return result
end

function BailoutMessage(name, latitude, longitude)
    local theMessage = RandomBailoutString()
    RadioMessage('VHF', '243 MHz', theMessage, { latitude = latitude, longitude = longitude })
end

function PilotSurvives(survivalChance)
    if math.random(1, 100) <= survivalChance then
        return true
    else
        return false
    end
end

function GenerateDownPilot(name, side, latitude, longitude, survivalChance, numberOfCrew)
    for i = 1, numberOfCrew do
        if PilotSurvives(survivalChance) then
            PlacePilotSurvivor(side, latitude, longitude, survivalChance)
        end
    end

    BailoutMessage(name, latitude, longitude)
end

-- ==========================
-- Ship Suvivor Generation --
-- ==========================

function DetermineTypeOfLifeRaft()
    local survivorTypeOptions = {
        { dbid = 2552, name = 'Life Raft [10m]' }, -- Civilian Life Raft [10m]
        { dbid = 2553, name = 'Life Raft [5m]' } -- Life Raft [5m]
    }

    local survivorType = survivorTypeOptions[math.random(#survivorTypeOptions)]
    return { dbid = survivorType.dbid, name = survivorType.name }
end

function DetermineTypeOfPersonInWater()
    local survivorTypeOptions = {
        { dbid = 4877, name = 'Person in Water (Alive)' }, -- Person in Water, Alive
        { dbid = 4878, name = 'Person in Water (Deceased)' } -- Person in Water, Deceased
    }

    local survivorType = survivorTypeOptions[math.random(#survivorTypeOptions)]
    return { dbid = survivorType.dbid, name = survivorType.name }
end

function PlaceShipSurvivor(latitude, longitude, survivorType)
    local randomPosition = CircularRandomPosition(latitude, longitude, 2)
    local survivorData

    if survivorType == 'Life Raft' then
        survivorData = DetermineTypeOfLifeRaft()
    else
        survivorData = DetermineTypeOfPersonInWater()
    end

    local survivor = ScenEdit_AddUnit({
        side = 'Survivors',
        type = 'Ship',
        dbid = survivorData.dbid,
        name = survivorData.name,
        latitude = randomPosition.latitude,
        longitude = randomPosition.longitude
    })

    table.insert(SurvivorList, survivor)
end

function AbandonShipMessage(name, latitude, longitude, numberOfCrew)
    local shipName = string.upper(name)
    local shipLatitude, shipLongitude = ConvertDecimalToCoord(latitude, longitude)
    local messageChance = math.random(1, 100)
    local radioBand
    local radioFrequencyOptions
    local radioFrequency
    local theMessage

    if messageChance <= 50 then -- Radio Mayday message
        radioBand = 'HF'
        radioFrequencyOptions = { '4125 KHz', '6215 KHz', '8291 KHz', '12290 KHz' }
        radioFrequency = radioFrequencyOptions[math.random(#radioFrequencyOptions)]
        theMessage = 'MAYDAY, MAYDAY, MAYDAY.<BR>THIS IS ' ..
        shipName ..
        ', ' ..
        shipName ..
        ', ' ..
        shipName ..
        '.<BR>MAYDAY ' ..
        shipName ..
        '. <BR>MY POSITION IS ' ..
        shipLatitude ..
        ', ' ..
        shipLongitude ..
        '.<BR>WE ARE SINKING.<BR>I REQUIRE IMMEDIATE ASSISTANCE.<BR>WE HAVE ' ..
        numberOfCrew .. ' PERSONS ON BOARD.<BR>WE ARE ABANDONING THE SHIP.<BR>OVER.'
    else -- EPIRB beacon message
        radioBand = 'VHF'
        radioFrequencyOptions = { '1021', '1023', '1082', '1083' }
        radioFrequency = 'CHANNEL ' .. radioFrequencyOptions[math.random(#radioFrequencyOptions)]
        theMessage = 'THIS IS THE RCC.<BR><BR>AN EPIRB DISTRESS MESSAGE HAS BEEN RECEIVED FROM THE ' ..
        shipName .. '.<BR><BR>REPORTED POSITION IS ' .. shipLatitude .. ', ' .. shipLongitude .. '.'
    end

    RadioMessage(radioBand, radioFrequency, theMessage, { latitude = latitude, longitude = longitude })
end

function GenerateShipSurvivors(name, latitude, longitude, numberOfCrew)
    for i = 1, math.random(10, 20) do -- Randomize the number of life raft survivors
        PlaceShipSurvivor(latitude, longitude, 'Life Raft')
    end

    for i = 1, math.random(10, 30) do -- Randomize the number of person in water survivors
        PlaceShipSurvivor(latitude, longitude, 'Person in Water')
    end

    AbandonShipMessage(name, latitude, longitude, numberOfCrew)
end

-- ==============================
-- Search and Rescue Functions --
-- ==============================

function GenerateListOfSurvivorUnits(side)
    local unitsList = {}
    local sideUnits = VP_GetSide({ side = side }).units

    -- List of possible survivor units to be recovered
    local SurvivorUnitList = {
        { type = 'Facility', dbid = 2046 }, -- Stranded Personnel
        { type = 'Facility', dbid = 2046 }, -- Stranded Personnel, Immobile
        { type = 'Ship',   dbid = 3725 }, -- 1.8m Life Raft Single Person [Aircrew Survival Raft]
        { type = 'Ship',   dbid = 2552 }, -- Civilian Life Raft [10m]
        { type = 'Ship',   dbid = 2553 }, -- Life Raft [5m]
        { type = 'Ship',   dbid = 4877 }, -- Person in Water, Alive
        { type = 'Ship',   dbid = 4878 }, -- Person in Water, Deceased
    }

    for _, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })

        for _, survivor in ipairs(SurvivorUnitList) do
            if unit.type == survivor.type and unit.dbid == survivor.dbid then
                table.insert(unitsList, unit)
                break
            end
        end
    end

    return unitsList
end

function RescueCapableUnits(unit)
    -- Check if the unit type is aircraft and the list exists
    if unit.type == 'Aircraft' and rescueCapableUnits.aircraft then
        for _, dbid in ipairs(rescueCapableUnits.aircraft) do
            if unit.dbid == dbid then
                return true
            end
        end

        -- Check if the unit type is ship and the list exists
    elseif unit.type == 'Ship' and rescueCapableUnits.ship then
        for _, dbid in ipairs(rescueCapableUnits.ship) do
            if unit.dbid == dbid then
                return true
            end
        end

        -- Check if the unit type is submarine and the list exists
    elseif unit.type == 'Submarine' and rescueCapableUnits.submarine then
        for _, dbid in ipairs(rescueCapableUnits.submarine) do
            if unit.dbid == dbid then
                return true
            end
        end

        -- Check if the unit type is facility and the list exists
    elseif unit.type == 'Facility' and rescueCapableUnits.facility then
        for _, dbid in ipairs(rescueCapableUnits.facility) do
            if unit.dbid == dbid then
                return true
            end
        end
    end

    return false
end

function GenerateListOfRescueUnits()
    local unitsList = {}
    local playerSide = ScenEdit_PlayerSide()
    local sideUnits = VP_GetSide({ side = playerSide }).units
    for _, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if RescueCapableUnits(unit) then
            table.insert(unitsList, v)
        end
    end

    return unitsList
end

function GetListOfRescueUnitsNearSurvivors(survivorGUID, maximumRescueDistance)
    local unitsList = {}
    local survivorUnit = ScenEdit_GetUnit({ guid = survivorGUID })

    if survivorUnit then
        for _, v in ipairs(RescueCapableUnitsList) do
            local rescuerUnit = ScenEdit_GetUnit({ guid = v.guid })

            if rescuerUnit and Tool_Range(survivorGUID, rescuerUnit.guid) <= maximumRescueDistance then
                table.insert(unitsList, rescuerUnit)
            end
        end
    end

    return unitsList
end

function ReturnUnitAltitudeAGL(guid)
    local unit = ScenEdit_GetUnit({ guid = guid })
    local altitudeAboveSeaLevel, terrainElevation = unit.altitude,
        World_GetElevation({ latitude = unit.latitude, longitude = unit.longitude })
    if terrainElevation < 0 then terrainElevation = 0 end
    local altitudeAboveGround = altitudeAboveSeaLevel - terrainElevation
    return altitudeAboveGround
end

function RescuerIsCloseEnoughToRescueSurvivor(survivorGUID, rescuerGUID, maximumRescueDistance)
    if survivorGUID and rescuerGUID then
        local rangeNMi = Tool_Range(survivorGUID, rescuerGUID)
        if rangeNMi < maximumRescueDistance then
            return true
        else
            return false
        end
    else
        return false
    end
end

function AirUnitIsWithinRescueParams(survivorGUID, rescuerGUID)
    local unit = ScenEdit_GetUnit({ guid = rescuerGUID })
    local unitAltitude = ReturnUnitAltitudeAGL(rescuerGUID)
    if RescuerIsCloseEnoughToRescueSurvivor(survivorGUID, rescuerGUID, 1) and unitAltitude <= 75 and unit.speed <= 0 then
        return true
    else
        return false
    end
end

function ShipOrSubmarineIsWithinRescueParams(survivorGUID, rescuerGUID)
    local unit = ScenEdit_GetUnit({ guid = rescuerGUID })
    if RescuerIsCloseEnoughToRescueSurvivor(survivorGUID, rescuerGUID, 1) and unit.altitude >= -20 and unit.speed <= 6 then
        return true
    else
        return false
    end
end

function UnitIsEligibleToRescue(survivorGUID, rescuerGUID)
    local unit = ScenEdit_GetUnit({ guid = rescuerGUID })
    if RescueCapableUnits(unit) then
        if unit.type == 'Ship' or unit.type == 'Submarine' then
            return ShipOrSubmarineIsWithinRescueParams(survivorGUID, unit.guid)
        elseif unit.type == 'Aircraft' then
            return AirUnitIsWithinRescueParams(survivorGUID, unit.guid)
        elseif unit.type == 'Facility' then
            return true
        end
    end

    return false
end

function PerformRescue(survivorGUID, rescuerGUID)
    local rescuedUnit = ScenEdit_GetUnit({ guid = survivorGUID })
    local rescuer = ScenEdit_GetUnit({ guid = rescuerGUID })
    local playerSide = ScenEdit_PlayerSide()

    for i = #SurvivorList, 1, -1 do
        if SurvivorList[i].guid == survivorGUID then
            table.remove(SurvivorList, i)
            break
        end
    end

    ScenEdit_DeleteUnit({ guid = survivorGUID })
    ChangeScore(playerSide, 50, rescuedUnit.name .. ' was rescued.')
    local message = "We've rescued " .. rescuedUnit.name .. "."
    RadioMessage('VHF', '282.8 MHz', theMessage, { latitude = rescuedUnit.latitude, longitude = rescuedUnit.longitude })
end

function AttemptRescue(rescueChance)
    local rescuePerformed = {}

    for _, survivor in ipairs(SurvivorList) do
        local ListOfRescueUnitsNearSurvivors = GetListOfRescueUnitsNearSurvivors(survivor.guid, 1)
        if ScenEdit_GetUnit({ guid = survivor.guid }) then
            for _, nearbyUnit in ipairs(ListOfRescueUnitsNearSurvivors) do
                if not rescuePerformed[nearbyUnit.guid] then
                    if UnitIsEligibleToRescue(survivor.guid, nearbyUnit.guid) and math.random(1, 100) <= rescueChance then
                        PerformRescue(survivor.guid, nearbyUnit.guid)
                        rescuePerformed[nearbyUnit.guid] = true
                    end
                end
            end
        end
    end
end

-- ====================
-- Survivor Captured --
-- ====================

function SurvivorCaptured(evasionChance)
    local playerSide = ScenEdit_PlayerSide()
    for _, survivor in ipairs(SurvivorList) do
        if survivor.type == 'Facility' and survivor.dbid == 2046 and math.random(1, 100) >= evasionChance then -- Only checks for Downed Pilots on land, can be modified for other survivor types if required
            for i = #SurvivorList, 1, -1 do
                if SurvivorList[i].guid == survivor.guid then
                    table.remove(SurvivorList, i)
                    break
                end
            end

            ScenEdit_DeleteUnit({ guid = survivor.guid })
            ChangeScore(playerSide, -50, survivor.name .. ' was captured before being rescued.')
            local theMessage = survivor.name ..
            ' is no longer responding to radio communications. Presumed captured at ' .. DTG()
            RadioMessage('VHF', '282.8 MHz', theMessage, { latitude = survivor.latitude, longitude = survivor.longitude })
        end
    end
end

-- ============================
-- Survivor Dies by Exposure --
-- ============================

function SurvivorDiesByExposure(exposureDuration, survivalChance, addDeceasedUnitBoolean)
    for _, survivor in ipairs(SurvivorList) do
        if survivor.type == 'Ship' and survivor.dbid == 4877 then -- Only checks for Person in Water (Alive), can be modified for other survivor types if required
            local unit = ScenEdit_GetUnit({ guid = survivor.guid })

            -- Check if unit has been in water for longer then exposure duration and random chance of survival
            -- These settings can be customized for your scenario environment and time of year
            -- Example, lower exposure duration and chance of survival for cold environments or higher duration and chance for tropical
            if unit.timeunderway >= exposureDuration and math.random(1, 100) >= survivalChance then
                if addDeceasedUnitBoolean then
                    -- Replace Person in Water (Alive) with Person in Water (Deceased)
                    ScenEdit_DeleteUnit({ guid = unit.guid })
                    ScenEdit_AddUnit({
                        side = 'Survivors',
                        type = 'Ship',
                        dbid = 4878,
                        name = 'Person in Water',
                        latitude = unit.latitude,
                        longitude = unit.longitude
                    })

                    -- Remove survivor from the list after replacement
                    for i = #SurvivorList, 1, -1 do
                        if SurvivorList[i].guid == survivor.guid then
                            table.remove(SurvivorList, i)
                            break
                        end
                    end
                else
                    -- Delete the survivor unit and remove it from the survivor list
                    for i = #SurvivorList, 1, -1 do
                        if SurvivorList[i].guid == survivor.guid then
                            table.remove(SurvivorList, i)
                            break
                        end
                    end

                    ScenEdit_DeleteUnit({ guid = unit.guid })
                end
            end
        end
    end
end

-- ======================================
-- Add, Delete, Replace Unit Functions --
-- ======================================

function AddAircraft(side, num1, num2, dbid, name, base, loadoutID, TimeToReady)
    for i = num1, num2 do
        local unit = ScenEdit_AddUnit({ side = side, type = 'Aircraft', dbid = dbid, name = name .. i, base = base, loadoutid = 3, TimeToReady_Minutes = 0 })
        ScenEdit_SetLoadout({ unitname = unit.guid, loadoutid = loadoutID, TimeToReady_Minutes = TimeToReady, IgnoreMagazines = true })
    end
end

function unitExistsAtLocation(unitList, latitude, longitude)
    for _, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.latitude == latitude and unit.longitude == longitude then
            return true
        end
    end
    return false
end

function AddRandomFacility_FixedPosition(side, positionRefPointName, numOfPositions, chanceOfAppearance, checkExisting,
                                         randomUnitList, chanceOfDetection)
    local sideUnits = checkExisting and VP_GetSide({ side = side }).units or nil

    for i = 1, numOfPositions do
        if math.random(1, 100) <= chanceOfAppearance then
            local position = ScenEdit_GetReferencePoint({ side = side, name = positionRefPointName .. ' ' .. i })
            if not checkExisting or not unitExistsAtLocation(sideUnits, position.latitude, position.longitude) then
                local randomUnit = randomUnitList[math.random(1, #randomUnitList)]
                local unitDetected = math.random(1, 100) <= chanceOfDetection
                local newUnit = ScenEdit_AddUnit({
                    side = side,
                    type = 'Facility',
                    dbid = randomUnit.dbid,
                    name = randomUnit.name,
                    latitude = position.latitude,
                    longitude = position.longitude,
                    autodetectable = unitDetected
                })
            end
        end
    end
end

function AddRandomFacility_RandomPosition(side, numOfUnits, chanceOfAppearance, randomUnitList, centerpoint, radius,
                                          chanceOfDetection)
    for i = 1, numOfUnits do
        if math.random(1, 100) <= chanceOfAppearance then
            local errorCount = 0
            local randomUnit = randomUnitList[math.random(1, #randomUnitList)]
            ::redoPosition::
            local position = CircularRandomPosition(centerpoint.latitude, centerpoint.longitude, radius)
            local unitDetected = math.random(1, 100) <= chanceOfDetection

            if OverWater(position.latitude, position.longitude) then
                errorCount = errorCount + 1
                if errorCount <= 500 then
                    goto redoPosition
                else
                    BugMessage('function AddRandomFacility_RandomPosition',
                        'Unable to place random unit on ' .. side .. ' after 500 attempts!')
                    break
                end
            end

            local newUnit = ScenEdit_AddUnit({
                side = side,
                type = 'Facility',
                dbid = randomUnit.dbid,
                name = randomUnit.name,
                latitude = position.latitude,
                longitude = position.longitude,
                autodetectable = unitDetected
            })
        end
    end
end

function AddRandomUnits_RandomPosition(side, numOfUnits, chanceOfAppearance, unitType, randomUnitList, centerpoint,
                                       radius, CheckRangeBetweenUnitsBoolean, minRangeBetweenUnits, chanceOfDetection,
                                       unitHeading, unitSpeed, unitGroup, mission)
    for i = 1, numOfUnits do
        if math.random(1, 100) <= chanceOfAppearance then
            local errorCount = 0
            local positionErrorCount = 0
            local randomUnit = randomUnitList[math.random(1, #randomUnitList)]

            -- Get unit position
            ::redoUnitPosition:: -- New label for retrying position due to range check failure
            local position = CircularRandomPosition(centerpoint.latitude, centerpoint.longitude, radius)
            local isValidPosition = true -- Assume position is valid until proven otherwise

            if (unitType == 'Facility' and OverWater(position.latitude, position.longitude)) or ((unitType == 'Ship' or unitType == 'Submarine') and not OverWater(position.latitude, position.longitude)) then
                errorCount = errorCount + 1
                if errorCount <= 500 then
                    goto redoUnitPosition
                else
                    BugMessage('function AddRandomUnits_RandomPosition',
                        'Unable to place random unit on ' .. side .. ' after 500 attempts!')
                    break
                end
            end

            -- Retrieve all units of the same side, then check range to all units of same type
            if CheckRangeBetweenUnitsBoolean == true then
                local sideUnits = VP_GetSide({ side = side }).units
                for k, v in ipairs(sideUnits) do
                    local targetUnit = ScenEdit_GetUnit({ guid = v.guid }) -- Get details for each unit
                    if targetUnit.type == unitType then -- Check only units of the same type
                        if not CheckMinRangeToCoordinates(position.latitude, position.longitude, targetUnit.latitude, targetUnit.longitude, minRangeBetweenUnits) then
                            isValidPosition = false
                            positionErrorCount = positionErrorCount + 1
                            if positionErrorCount > 500 then
                                BugMessage('function AddRandomUnits_RandomPosition',
                                    'Unable to place random ' .. side .. ' ' .. unitType .. ' after 500 attempts!')
                                break
                            end
                            goto redoUnitPosition
                        end
                    end
                end
            end

            local unitDetected = math.random(1, 100) <= chanceOfDetection

            if isValidPosition then
                local newUnit = ScenEdit_AddUnit({
                    side = side,
                    type = unitType,
                    dbid = randomUnit.dbid,
                    name = randomUnit.name,
                    latitude = position.latitude,
                    longitude = position.longitude,
                    heading = unitHeading,
                    speed = unitSpeed,
                    manualspeed = unitSpeed,
                    autodetectable = unitDetected
                })

                if unitGroup ~= nil then
                    newUnit.group = unitGroup
                end
            end

            if mission ~= nil then
                ScenEdit_AssignUnitToMission(newUnit.guid, mission)
            end
        end
    end
end

function AddUnitAtBearingDistanceFromUnit(refUnitGUID, bearing, distance, newUnitType, newUnitSide, newUnitDBID,
                                          newUnitName, newUnitLoadoutID, newUnitSpeed, newUnitAltitude, newUnitHeading,
                                          newUnitGroup)
    local originPosition = ScenEdit_GetUnit({ guid = refUnitGUID })
    local newUnitPosition = World_GetPointFromBearing({
        latitude = originPosition.latitude,
        longitude = originPosition.longitude,
        bearing = bearing,
        distance = distance,
    })

    local newUnit = nil

    if newUnitType == 'Aircraft' then
        newUnit = ScenEdit_AddUnit({
            type = 'Aircraft',
            side = newUnitSide,
            dbid = newUnitDBID,
            name = newUnitName,
            loadoutid = newUnitLoadoutID,
            latitude = newUnitPosition.latitude,
            longitude = newUnitPosition.longitude,
            speed = newUnitSpeed,
            altitude = newUnitAltitude,
            heading = newUnitHeading
        })
    elseif newUnitType == 'Weapon' then
        newUnit = ScenEdit_AddUnit({
            type = 'Weapon',
            side = newUnitSide,
            dbid = newUnitDBID,
            name = newUnitName,
            latitude = newUnitPosition.latitude,
            longitude = newUnitPosition.longitude,
            altitude = newUnitAltitude,
            heading = newUnitHeading
        })
    else
        newUnit = ScenEdit_AddUnit({
            type = newUnitType,
            side = newUnitSide,
            dbid = newUnitDBID,
            name = newUnitName,
            latitude = newUnitPosition.latitude,
            longitude = newUnitPosition.longitude,
            speed = newUnitSpeed,
            heading = newUnitHeading
        })
    end

    if newUnitGroup ~= nil then
        newUnit.group = newUnitGroup
    end

    return newUnit
end

function AddWeaponSalvo(targetGUID, centerPoint, numWeapons, weaponSide, weaponDBID, weaponName, weaponAltitude,
                        salvoSpacing)
    local position = CircularRandomPosition(centerPoint.latitude, centerPoint.longitude, centerPoint.maxRange)
    local target = ScenEdit_GetContact({ side = weaponSide, guid = targetGUID })
    local bearing = Tool_Bearing({ latitude = position.latitude, longitude = position.longitude },
        { latitude = target.latitude, longitude = target.longitude })
    local weaponSpacing = 0 + salvoSpacing
    local salvoSize = numWeapons - 1 -- subtract one for the first weapon in the savlo

    -- Add first weapon in salvo
    local firstWeaponInSalvo = ScenEdit_AddUnit({
        side = weaponSide,
        type = 'Weapon',
        dbid = weaponDBID,
        name = weaponName,
        latitude = position.latitude,
        longitude = position.longitude,
        altitude = weaponAltitude,
        heading = bearing
    })

    firstWeaponInSalvo.target = { guid = targetGUID }

    -- Add the rest of the weapons in the salvo
    for i = 1, salvoSize do
        local newFalseWeapon = AddUnitAtBearingDistanceFromUnit(
            firstWeaponInSalvo.guid,
            270,
            weaponSpacing,
            'Weapon',
            weaponSide,
            weaponDBID,
            weaponName,
            nil,
            nil,
            weaponAltitude,
            bearing,
            nil
        )

        newFalseWeapon.target = { guid = targetGUID }
        weaponSpacing = weaponSpacing + salvoSpacing
    end
end

function DeleteAllUnitsOnSide(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        ScenEdit_DeleteUnit({ guid = v.guid })
    end
end

function DeleteAllUnitsOnSide_ByType(side, type)
    local sideUnits = VP_GetSide({ side = side }).units
    for _, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == type then
            ScenEdit_DeleteUnit({ guid = unit.guid })
        end
    end
end

function DeleteAllUnitsOnSide_ByDBID(side, dbid)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == dbid then
            ScenEdit_DeleteUnit({ guid = unit.guid })
        end
    end
end

function DeletePercentageOfUnitsOnSide_ByDBID_(side, dbid, percentage)
    local sideUnits = VP_GetSide({ side = side }).units
    local dbidUnits = {}

    -- Collect all units with the specified DBID
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == dbid then
            table.insert(dbidUnits, unit)
        end
    end

    -- Determine the number of units to delete based on the percentage
    local numToDelete = math.floor(#dbidUnits * (percentage / 100))

    -- Shuffle the dbidUnits table to randomize selection
    for i = #dbidUnits, 2, -1 do
        local j = math.random(1, i)
        dbidUnits[i], dbidUnits[j] = dbidUnits[j], dbidUnits[i]
    end

    -- Delete the specified number of units
    for i = 1, numToDelete do
        ScenEdit_DeleteUnit({ guid = dbidUnits[i].guid })
    end
end

function DeletePercentageOfUnits_ByList(unitList, percentage)
    -- Determine the number of units to delete based on the percentage
    local numToDelete = math.floor(#unitList * (percentage / 100))

    -- Shuffle the unitList table to randomize selection
    for i = #unitList, 2, -1 do
        local j = math.random(1, i)
        unitList[i], unitList[j] = unitList[j], unitList[i]
    end

    -- Delete the specified number of units
    for i = 1, numToDelete do
        ScenEdit_DeleteUnit({ guid = unitList[i] })
    end
end

function DeletePercentageOfUnits_ByMission(side, mission, percentage)
    local UnitsAssignedToMissionList = {}
    local mission = ScenEdit_GetMission(side, mission)
    if (mission ~= nil) and mission.unitlist ~= nil then
        for k, v in ipairs(mission.unitlist) do
            table.insert(UnitsAssignedToMissionList, unit.guid)
        end
    end

    DeletePercentageOfUnits_ByList(UnitsAssignedToMissionList, percentage)
end

function DeleteUnits(side, num1, num2, name)
    for i = num1, num2 do
        ScenEdit_DeleteUnit({ side = side, name = name .. i })
    end
end

function DeleteUnitX_ByType(unitType)
    local theUnit = ScenEdit_UnitX()
    if theUnit.type == unitType then
        ScenEdit_DeleteUnit({ guid = theUnit.guid })
    end
end

function DeleteUnitX_ByDBID(unitDBID)
    local theUnit = ScenEdit_UnitX()
    if theUnit.dbid == unitDBID then
        ScenEdit_DeleteUnit({ guid = theUnit.guid })
    end
end

function KillUnitX_ByType(unitType)
    local theUnit = ScenEdit_UnitX()
    if theUnit.type == unitType then
        ScenEdit_KillUnit({ guid = theUnit.guid })
    end
end

function KillUnitX_ByDBID(unitDBID)
    local theUnit = ScenEdit_UnitX()
    if theUnit.dbid == unitDBID then
        ScenEdit_KillUnit({ guid = theUnit.guid })
    end
end

function DeleteAirborneAircraft(side, dbid, airborneTime, eventName)
    local sideUnits = VP_GetSide({ side = side }).units
    local existingAircraftDBID = false

    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == dbid then
            existingAircraftDBID = true
            if unit.airbornetime_v >= airborneTime then
                ScenEdit_DeleteUnit({ guid = unit.guid })
            end
        end
    end

    if eventName ~= nil then
        if not existingAircraftDBID then
            ScenEdit_SetEvent(eventName, { isActive = false })
        end
    end
end

function ReplaceUnitsOnSide(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type ~= 'Group' then
            ScenEdit_DeleteUnit({ guid = unit.guid })
            local newUnit = ScenEdit_AddUnit({ type = unit.type, side = unit.side, dbid = unit.dbid, name = unit.name, latitude =
            unit.latitude, longitude = unit.longitude })

            if unit.group ~= nil then
                newUnit.group = unit.group.name
            end
        end
    end
end

function ReplaceUnitsOnSide_ByDBID(side, oldDBID, newDBID)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == oldDBID then
            ScenEdit_DeleteUnit({ guid = unit.guid })
            ScenEdit_AddUnit({ type = unit.type, side = unit.side, dbid = newDBID, name = unit.name, latitude = unit
            .latitude, longitude = unit.longitude, guid = unit.guid })
        end
    end
end

function ReplaceUnitsOnSide_ByName(side, oldName, newName, dbid)
    local unit = ScenEdit_GetUnit({ side = side, name = oldName })
    ScenEdit_DeleteUnit({ side = side, name = oldName })
    local newUnit = ScenEdit_AddUnit({
        type = unit.type,
        side = side,
        name = newName,
        dbid = dbid,
        lat = unit.latitude,
        lon = unit.longitude,
        heading = unit.heading,
    })

    if unit.group ~= nil then
        newUnit.group = unit.group.name
    end

    if unit.mission ~= nil then
        ScenEdit_AssignUnitToMission(unit.name, unit.mission.name)
    end
end

function ReplaceUnit_ByList(unitList)
    for k, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        ScenEdit_DeleteUnit({ guid = unit.guid })
        local newUnit = ScenEdit_AddUnit({ type = unit.type, side = unit.side, dbid = unit.dbid, name = v.name, latitude =
        unit.latitude, longitude = unit.longitude })

        if unit.group ~= nil then
            newUnit.group = unit.group.name
        end
    end
end

function ReplaceAircraft_ByDBID(side, oldDBID, newDBID, loadoutID, TimeToReady)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == oldDBID then
            ScenEdit_DeleteUnit({ guid = unit.guid })
            ScenEdit_AddUnit({
                side = side,
                type = 'Aircraft',
                dbid = newDBID,
                name = unit.name,
                loadoutid = loadoutID,
                base = unit.base.name,
                TimeToReady_Minutes = TimeToReady
            })

            if unit.mission ~= nil then
                ScenEdit_AssignUnitToMission(unit.name, unit.mission.name)
            end
        end
    end
end

function ReplaceAircraft_ByName(side, num1, num2, dbid, name, loadoutID, TimeToReady)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ Side = side, Name = name .. i })
        if unit ~= nil then
            ScenEdit_DeleteUnit({ guid = unit.guid })
            ScenEdit_AddUnit({
                side = side,
                type = 'Aircraft',
                dbid = dbid,
                name = unit.name,
                loadoutid = loadoutID,
                base = unit.base.name,
                TimeToReady_Minutes = TimeToReady
            })

            if unit.mission ~= nil then
                ScenEdit_AssignUnitToMission(unit.name, unit.mission.name)
            end
        end
    end
end

function ReplaceAirborneAircraft_ByName(side, num1, num2, dbid, name, loadoutID)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ Side = side, Name = name .. i })
        if unit ~= nil then
            ScenEdit_DeleteUnit({ guid = unit.guid })
            local newUnit = ScenEdit_AddUnit({
                side = side,
                type = 'Aircraft',
                dbid = dbid,
                name = unit.name,
                loadoutid = loadoutID,
                latitude = unit.latitude,
                longitude = unit.longitude,
                altitude = unit.altitude,
                heading = unit.heading,
            })

            if unit.group ~= nil then
                newUnit.group = unit.group.name
            end

            if unit.mission ~= nil then
                ScenEdit_AssignUnitToMission(unit.name, unit.mission.name)
            end
        end
    end
end

function GetReplaceChanceFromList(replacableUnits, dbid)
    for _, unitEntry in ipairs(replacableUnits) do
        if unitEntry.dbid == dbid then
            return unitEntry.replaceChance
        end
    end
    return nil -- Return nil if the dbid was not found in the list
end

function RandomReplaceFacility(side, chance, unitsToReplaceList, radius, replaceChance, unitList, chanceOfDetection)
    local sideUnits = VP_GetSide({ side = side }).units

    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if IsInListTable(unitsToReplaceList, 'dbid', unit.dbid) then -- Check if unit's dbid is in replaceable list
            if math.random(1, 100) <= chance then
                local position
                local errorCount = 0
                local radius = radius

                -- Get the replaceChance for the unit from the unitsToReplaceList, or use the default
                local unitReplaced = GetReplaceChanceFromList(unitsToReplaceList, unit.dbid) or replaceChance

                -- Determine the chance to replace the unit
                local unitReplaceChance
                if replaceChance == 'Random' then
                    unitReplaceChance = math.random(1, 100)
                else
                    unitReplaceChance = unitReplaced
                end

                -- Check if the unit should be replaced based on the replace chance
                if math.random(1, 100) <= unitReplaceChance then
                    -- Replace the old unit directly
                    position = ScenEdit_GetUnit({ guid = unit.guid })
                    ScenEdit_DeleteUnit({ guid = unit.guid })
                else
                    -- Add a new unit nearby
                    local centerPoint = ScenEdit_GetUnit({ guid = unit.guid })

                    ::redoPosition::
                    position = CircularRandomPosition(centerPoint.latitude, centerPoint.longitude, radius)

                    if OverWater(position.latitude, position.longitude) then
                        errorCount = errorCount + 1
                        if errorCount <= 500 then
                            goto redoPosition
                        else
                            BugMessage('RandomReplaceFacility',
                                'Unable to place random unit on ' .. side .. ' after 500 attempts!')
                            break
                        end
                    end
                end

                -- Add a new randomly selected unit
                local randomType = unitList[math.random(1, #unitList)]
                local unitDetected = math.random(1, 100) <= chanceOfDetection
                local newUnit = ScenEdit_AddUnit({
                    side = side,
                    type = 'Facility',
                    dbid = randomType.dbid,
                    name = randomType.name,
                    latitude = position.latitude,
                    longitude = position.longitude,
                    autodetectable = unitDetected
                })
            end
        end
    end
end

function ChangeUnitSide_ByList(unitList, oldSide, newSide)
    for k, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        ScenEdit_SetUnitSide({ side = oldSide, guid = unit.guid, newside = newSide })
    end
end

function ChangeUnitSide(oldSide, newSide)
    local sideUnits = VP_GetSide({ side = oldSide }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Group' then
            ScenEdit_SetUnitSide({ side = oldSide, guid = unit.guid, newside = newSide })
        end
    end
    ChangeUnitSide_ByList(sideUnits, oldSide, newSide)
end

function RotateUnitAroundCenterpoint(centerPoint, unitGUID, unitRotation)
    local bearing = Tool_Bearing({ latitude = centerPoint.latitude, longitude = centerPoint.longitude }, unitGUID)
    local distance = Tool_Range({ latitude = centerPoint.latitude, longitude = centerPoint.longitude }, unitGUID)
    local newBearing = bearing + unitRotation
    local newPostion = World_GetPointFromBearing({ latitude = centerPoint.latitude, longitude = centerPoint.longitude, bearing =
    newBearing, distance = distance })
    ScenEdit_SetUnit({ guid = unitGUID, latitude = newPostion.latitude, longitude = newPostion.longitude })
end

-- ===================================
-- Modify Unit Properties Functions --
-- ===================================

function SetAircraftLoadouts(side, num1, num2, name, loadoutid, TimeToReady, IgnoreMagazinesBoolean)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ side = side, name = name .. i })
        if unit then
            ScenEdit_SetLoadout({ name = unit.name, loadoutID = loadoutid, TimeToReady_Minutes = TimeToReady, IgnoreMagazines =
            IgnoreMagazinesBoolean })
        end
    end
end

function RandomizeAircraftLoadouts(chance, loadoutID1, loadoutID2)
    if math.random(1, 100) <= chance then
        return loadoutID1
    else
        return loadoutID2
    end
end

function SetAircraftTimeToReady_BySide(side, TimeToReady)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            ScenEdit_SetLoadout({ unitname = unit.guid, TimeToReady_Minutes = TimeToReady })
        end
    end
end

function SetAircraftTimeToReady_ByMission(side, mission, TimeToReady)
    local mission = ScenEdit_GetMission(side, mission)
    if (mission ~= nil) and mission.unitlist ~= nil then
        for _, aircraft in ipairs(mission.unitlist) do
            ScenEdit_SetLoadout({ unitname = aircraft, TimeToReady_Minutes = TimeToReady })
        end
    end
end

function SetAircraftTimeToReady_ByBaseAndDBID(baseGUID, dbid, TimeToReady)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    for i, aircraftGUID in ipairs(base.assignedUnits.Aircraft) do
        local aircraft = ScenEdit_GetUnit({ guid = aircraftGUID })
        if aircraft.dbid == dbid then
            ScenEdit_SetLoadout({ unitname = aircraft.guid, TimeToReady_Minutes = TimeToReady })
        end
    end
end

function SetAircraftTimeToReady(side, num1, num2, name, TimeToReady)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ side = side, name = name .. i })
        if unit then
            ScenEdit_SetLoadout({ unitname = unit.guid, TimeToReady_Minutes = TimeToReady })
        end
    end
end

function SetAircraftReadiness_BySide(side, chance)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            if math.random(1, 100) <= chance then
                -- Set aircraft to Maintenance [Unavailable]
                ScenEdit_SetLoadout({ unitname = unit.guid, LoadoutID = 4, TimeToReady_Minutes = 0 })
            else
                -- Set aircraft to Reserve [Available] if aircraft was set to Maintenance [Unavailable]
                if unit.loadoutdbid == 4 then
                    ScenEdit_SetLoadout({ unitname = unit.guid, LoadoutID = 3, TimeToReady_Minutes = 0 })
                end
            end
        end
    end
end

function RandomizeAircraftReadiness_ByBaseAndDBID(baseGUID, dbid, chance)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    for i, aircraftGUID in ipairs(base.assignedUnits.Aircraft) do
        local aircraft = ScenEdit_GetUnit({ guid = aircraftGUID })
        if aircraft.dbid == dbid then
            if math.random(1, 100) <= chance then
                ScenEdit_SetLoadout({ unitname = aircraft.guid, LoadoutID = 4, TimeToReady_Minutes = 0 })
            end
        end
    end
end

function ResetAircraftTimeToReady_BySide(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            TimeToReady = unit.readytime_v / 60
            ScenEdit_SetLoadout({ unitname = unit.guid, TimeToReady_Minutes = TimeToReady })
        end
    end
end

function SetUnitsAutodetectable_BySide(side, boolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.guid })
        ScenEdit_SetUnit({ guid = unit.guid, autodetectable = boolean })
    end
end

function SetUnitsAutodetectable_ByType(side, type, boolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.guid })
        if unit.type == type then
            ScenEdit_SetUnit({ guid = unit.guid, autodetectable = boolean })
        end
    end
end

function SetUnitsAutodetectable_ByDBID(side, dbid, boolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.guid })
        if unit.dbid == dbid then
            ScenEdit_SetUnit({ guid = unit.guid, autodetectable = boolean })
        end
    end
end

function RandomizeUnitsAutodetectable_ByDBID(side, dbid, chance, boolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.guid })
        if unit.dbid == dbid then
            if math.random(1, 100) <= chance then
                ScenEdit_SetUnit({ guid = unit.guid, autodetectable = boolean })
            end
        end
    end
end

function UpdateUnitMounts(unitGUID, mode, numOfMounts, mountDBID, mountArc)
    local modeString = string.lower(mode)
    local unit = ScenEdit_GetUnit({ guid = unitGUID })
    if modeString == 'add' then
        for i = 1, numOfMounts do
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', dbid = mountDBID, arc_mount = mountArc })
        end
    elseif modeString == 'remove' then
        for i = 1, numOfMounts do
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_mount', dbid = mountDBID })
        end
    else
        print("Invalid mode: " .. tostring(mode) .. ". Use 'Add' or 'Remove'.")
    end
end

function UpdateUnitMounts_BySide(side, unitDBID, mode, numOfMounts, mountDBID, mountArc)
    local modeString = string.lower(mode)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == unitDBID then
            if modeString == 'add' then
                for i = 1, numOfMounts do
                    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'add_mount', dbid = mountDBID, arc_mount = mountArc })
                end
            elseif modeString == 'remove' then
                for i = 1, numOfMounts do
                    ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_mount', dbid = mountDBID })
                end
            else
                print("Invalid mode: " .. tostring(mode) .. ". Use 'Add' or 'Remove'.")
            end
        end
    end
end

function UpdateUnitMunitions_BySide(side, unitDBID, wpnDBID, numWeapons, removeBoolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == unitDBID then
            ScenEdit_AddReloadsToUnit({ guid = unit.guid, wpn_dbid = wpnDBID, number = numWeapons, remove = removeBoolean })
        end
    end
end

function UpdateUnitMagazines_BySide(side, unitDBID, wpnDBID, numWeapons, removeBoolean)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.dbid == unitDBID then
            ScenEdit_AddWeaponToUnitMagazine({ guid = unit.guid, wpn_dbid = wpnDBID, number = numWeapons, remove =
            removeBoolean })
        end
    end
end

-- ===============================
-- Doctrine and EMCON Functions --
-- ===============================

function SetUnitProficiency_ByList(unitList, unitProficiency)
    for k, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type ~= 'Group' then
            ScenEdit_SetUnit({ guid = v.guid, proficiency = unitProficiency })
        end
    end
end

function RandomizeUnitProficiency(unitGUID, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
    local chance = math.random(1, 100)
    local proficiency

    if chance <= chanceNovice then
        proficiency = 0 -- Novice
    elseif chance <= chanceCadet then
        proficiency = 1 -- Cadet
    elseif chance <= chanceRegular then
        proficiency = 2 -- Regular
    elseif chance <= chanceVeteran then
        proficiency = 3 -- Veteran
    else
        proficiency = 4 -- Ace
    end

    ScenEdit_SetUnit({ guid = unitGUID, proficiency = proficiency })
end

function RandomizeMultipleUnitProficiency(side, num1, num2, name, chanceNovice, chanceCadet, chanceRegular, chanceVeteran,
                                          chanceAce)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ side = side, name = name .. i })
        if unit then
            RandomizeUnitProficiency(unit.guid, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
        end
    end
end

function RandomizeUnitProficiency_BySide(side, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit and unit.type ~= 'Group' then
            RandomizeUnitProficiency(unit.guid, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
        end
    end
end

function RandomizeUnitProficiency_ByList(unitList, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
    for k, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit and unit.type ~= 'Group' then
            RandomizeUnitProficiency(unit.guid, chanceNovice, chanceCadet, chanceRegular, chanceVeteran, chanceAce)
        end
    end
end

function SetUnitDoctrineWCS_BySide(side, air, land, subsurface, surface)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.name })
        ScenEdit_SetDoctrine({ guid = unit.guid }, {
            weapon_control_status_air = air,
            weapon_control_status_land = land,
            weapon_control_status_subsurface = subsurface,
            weapon_control_status_surface = surface
        })
    end
end

function SetUnitDoctrineWCS_ByList(unitList, air, land, subsurface, surface)
    for k, v in ipairs(unitList) do
        local unit = ScenEdit_GetUnit({ name = v.name })
        ScenEdit_SetDoctrine({ guid = unit.guid }, {
            weapon_control_status_air = air,
            weapon_control_status_land = land,
            weapon_control_status_subsurface = subsurface,
            weapon_control_status_surface = surface
        })
    end
end

function SetUnitEMCON_BySide(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ name = v.guid })
        ScenEdit_SetEMCON('Unit', unit.guid, 'Radar=passive')
    end
end

function SetUnitsEMCON_ByDBID(side, unitDBIDs, chance)
    -- Convert the list of DBIDs into a table for faster lookup
    local dbidLookup = {}
    for _, dbidInfo in ipairs(unitDBIDs) do
        dbidLookup[dbidInfo.dbid] = true
    end

    -- Get all units on the specified side
    local sideUnits = VP_GetSide({ side = side }).units
    for _, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        -- Check if this unit's DBID is in the lookup table
        if dbidLookup[unit.dbid] then
            -- Evaluate the chance for each unit individually
            if chance == 0 then
                -- If chance is explicitly set to 0, set to passive regardless of the roll
                ScenEdit_SetEMCON('unit', unit.guid, 'Radar=Passive')
                ScenEdit_SetDoctrine({ side = side, guid = unit.guid }, { weapon_control_status_air = '2' }) -- WCS Weapons HOLD
            else
                if math.random(1, 100) <= chance then
                    -- If the roll is less than or equal to the chance, activate radar
                    ScenEdit_SetEMCON('unit', unit.guid, 'Radar=Active')
                    ScenEdit_SetDoctrine({ side = side, guid = unit.guid }, { weapon_control_status_air = 'Inherit' })
                else
                    -- Otherwise, set to passive
                    ScenEdit_SetEMCON('unit', unit.guid, 'Radar=Passive')
                    ScenEdit_SetDoctrine({ side = side, guid = unit.guid }, { weapon_control_status_air = '2' }) -- WCS Weapons HOLD
                end
            end
        end
    end
end

-- ===========================
-- Modify Mission Functions --
-- ===========================

function SetSideMissionStatus(side, status)
    local sideMissions = VP_GetSide({ side = side }).missions
    for k, v in ipairs(sideMissions) do
        local mission = ScenEdit_GetMission(side, v.guid)
        ScenEdit_SetMission(side, mission.guid, { isactive = status })
    end
end

function DeleteAllMissionsOnSide(side)
    local sideMissions = VP_GetSide({ side = side }).missions
    for k, v in ipairs(sideMissions) do
        local mission = ScenEdit_GetMission(side, v.guid)
        ScenEdit_DeleteMission(side, mission.guid)
    end
end

function AssignUnitsToMission(side, num1, num2, name, mission, escortBoolean)
    for i = num1, num2 do
        local unit = ScenEdit_GetUnit({ side = side, name = name .. i })
        if unit ~= nil then
            ScenEdit_AssignUnitToMission(unit.guid, mission, escortBoolean)
        end
    end
end

function ChangeUnitsMission(side, oldMission, newMission)
    local mission = ScenEdit_GetMission(side, oldMission)
    if (mission ~= nil) and mission.unitlist ~= nil then
        for k, v in ipairs(mission.unitlist) do
            ScenEdit_AssignUnitToMission(value, newMission)
        end
    end
end

function SetMaxFlightsForStrikeMission(side, missionName, percentage, roundTo)
    local numUnits = 0
    -- Get number of units assigned to mission
    local mission = ScenEdit_GetMission(side, missionName)
    if (mission ~= nil) and mission.unitlist ~= nil then
        for k, v in ipairs(mission.unitlist) do
            numUnits = numUnits + 1
        end
    end

    -- Set the maximum number of flights for the mission
    local percentage = percentage / 100
    local flightSize = numUnits * percentage

    -- Round flightSize to the nearest multiple of roundTo
    local MaxFlights = math.floor((flightSize + roundTo / 2) / roundTo) * roundTo

    ScenEdit_SetMission(side, missionName, { StrikeMax = MaxFlights })
end

-- =================
-- Misc Functions --
-- =================

function AttackContactType(side, attackerID, contactName, weaponDBID, numWeapons)
    local contacts = ScenEdit_GetContacts(side)
    for _, contact in pairs(contacts) do
        if contact.name == contactName then
            -- If the specified contact type is found, insert its GUID into the AttackContact function
            ScenEdit_AttackContact(attackerID, contact.guid, { mode = 1, weapon = weaponDBID, qty = numWeapons })
        end
    end
end

function SetSideAircraftToRTB(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            ScenEdit_SetUnit({ guid = unit.guid, rtb = true })
        end
    end
end

function SetSideAircraftToRTB(side)
    local sideUnits = VP_GetSide({ side = side }).units
    for k, v in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            unit:RTB(true)
        end
    end
end

function TeleportAircraftToBase_BySide(side)
    local units = VP_GetSide({ side = side }).units
    for k, v in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = v.guid })
        if unit.type == 'Aircraft' then
            ScenEdit_HostUnitToParent({ HostedUnitNameOrID = unit.guid, SelectedHostNameOrID = unit.base.guid })
        end
    end
end

function SetShipFormation(unitList, groupLeaderGUID, speed, stationType)
    for k, v in ipairs(unitList) do
        local groupLeader = ScenEdit_GetUnit({ guid = groupLeaderGUID })
        local ship = ScenEdit_GetUnit({ guid = v.guid })
        local bearing = Tool_Bearing(groupLeader.guid, ship.guid)
        local range = Tool_Range(groupLeader.guid, ship.guid)
        ScenEdit_SetUnit({ guid = ship.guid, speed = speed })
        ship.formation = { type = stationType, bearing = bearing, distance = range }
    end
end

-- =========================
-- KnightHawk75 Refuel Unit Functions
-- =========================

function khRefuelUnit(myunit)
    local newfuel = myunit.fuel
    for i, v in pairs(newfuel) do
        v.current = v.max
        myunit.fuel = newfuel
    end
    newfuel = nil;
end

function khRefuelSide(thesidename, unittype, subtype)
    if unittype == nil then unittype = "All" end;
    if subtype == nil then subtype = "All" end;
    local a = VP_GetSide({ Side = thesidename })
    for i, v in pairs(a.units) do
        local myunit;
        myunit = ScenEdit_GetUnit({ name = v.name, guid = v.guid })
        if myunit ~= nil then
            if unittype ~= "All" and subtype ~= "All" then
                if myunit.type == unittype and myunit.subtype == subtype then
                    khRefuelUnit(myunit);
                end
            elseif unittype ~= "All" and subtype == "All" then
                if myunit.type == unittype then
                    khRefuelUnit(myunit);
                end
            elseif unittype == "All" and subtype ~= "All" then
                if myunit.subtype == subtype then
                    khRefuelUnit(myunit);
                end
            else --either ==All or both ==ALL
                if myunit.type ~= "Weapon" then
                    khRefuelUnit(myunit);
                end
            end
        end
        myunit = nil;
    end
    local a = nil;
end
