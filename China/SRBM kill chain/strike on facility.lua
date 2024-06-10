local function aircraftReturnToBase(aircraftPackages)
    for _, pack in ipairs(aircraftPackages) do
        if pack.striker.units ~= nil and getCount(pack.striker.units) > 0 and hasDestroyedOrRTB(pack.striker.units, 1) then
            if pack.escort then
                for i, value in ipairs(pack.escort.units) do
                    local unit = SE_GetUnit({ guid = value.unit })
                    if unit then
                        unit:RTB(true)
                    end
                end
            end

            if pack.wildWeasel then
                for i, value in ipairs(pack.wildWeasel.units) do
                    local unit = SE_GetUnit({ guid = value.unit })
                    if unit then
                        unit:RTB(true)
                    end
                end
            end

            pack.striker.units = {}

            if pack.escort then
                pack.escort.units = {}
            end

            if pack.wildWeasel then
                pack.wildWeasel.units = {}
            end
        end
    end
end

local function launchH6NIfRequired(onSAMConfig)
    if hasDestroyedOrRTB(onSAMConfig.h6nTemp, 1) and hasDestroyedOrRTB(onSAMConfig.wz8Temp, 1) then
        onSAMConfig.h6nTemp = launchUnits(
            onSAMConfig.const.h6nBaseGUID,
            onSAMConfig.const.h6nCourse,
            1,
            onSAMConfig.const.h6nDBID,
            'Aircraft'
        )
    end
end

local function attackSAMContacts(contacts, onSAMConfig)
    local result = { batteryIndex = 1, groupIndex = 1 }

    for _, contact in ipairs(contacts) do
        if contact.emissions and contact.emissions[1] then
            local emission = contact.emissions[1]['sensor_dbid']
            local isSAM = emission == onSAMConfig.const.tk3SensorDBID1
                or emission == onSAMConfig.const.tk3SensorDBID2
                or emission == onSAMConfig.const.tk2SensorDBID
            -- or emission == onSAMConfig.const.pac3SensorDBID

            if isSAM and contact.lastDetections and contact.lastDetections[1].age <= onSAMConfig.const.contactAge then
                result = attackContact(
                    contact,
                    4,
                    onSAMConfig.const.batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end
end

local function attackMLRSContacts(contacts, mlrsConfig)
    local result = { batteryIndex = 1, groupIndex = 1 }

    for _, package in ipairs(mlrsConfig.packages) do
        local filteredContacts = filterContacts(contacts, function(value)
            return (value.typed == 8 or value.typed == 21) and value:inArea(package.area)
        end)

        for __, filteredContact in ipairs(filteredContacts) do
            if filteredContact.lastDetections
                and filteredContact.lastDetections[1].age <= mlrsConfig.const.contactAge then
                result = attackContact(
                    filteredContact,
                    4,
                    package.batteries,
                    result.batteryIndex,
                    result.groupIndex,
                    mlrsConfig.batteries[_].weaponDBID
                )
            end
        end
    end
end

local function attackGLCMContacts(CONFIG)
    local glcmConfig = CONFIG.c.glcm
    local result = { batteryIndex = 1, groupIndex = 1, isLaunched = false }
    local packageIdx = glcmConfig.idxPackage
    local targetListIdx = glcmConfig.packages[packageIdx].index
    local diff = 0

    if glcmConfig.lastReconTime then
        diff = ScenEdit_CurrentTime() - glcmConfig.lastReconTime
    end

    for _, v in ipairs(glcmConfig.packages[packageIdx].targetList[targetListIdx]) do
        local contact = ScenEdit_GetContact({ side = 'China', guid = v.guid })

        if contact then
            local BDA = contact.BDA
            local hasReconed = (BDA and not (BDA['STRUCTURAL'] == 'Heavy damage'))
                and (glcmConfig.lastReconTime and ScenEdit_CurrentTime() > glcmConfig.lastReconTime)
                and diff <= glcmConfig.const.contactAge
            local isTheFirstStrike = BDA == nil and not (glcmConfig.packages[packageIdx].hasLaunchedTheFirstStrike)

            if (isTheFirstStrike or hasReconed) then
                result = attackContact(
                    contact,
                    glcmConfig.packages[packageIdx].num,
                    glcmConfig.packages[packageIdx].batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end

    if result.isLaunched then
        glcmConfig.packages[packageIdx].index = glcmConfig.packages[packageIdx].index + 1
    end

    local targetListLength = getCount(glcmConfig.packages[packageIdx].targetList)
    local nextTargetListIdx = glcmConfig.packages[packageIdx].index
    local isTargetListIdxOutOfBounds = nextTargetListIdx > targetListLength

    if isTargetListIdxOutOfBounds then
        glcmConfig.packages[packageIdx].index = targetListLength
        glcmConfig.packages[packageIdx].hasLaunchedTheFirstStrike = true
    end

    glcmConfig.idxPackage = glcmConfig.idxPackage + 1
    local packageLength = getCount(glcmConfig.packages)
    local nextPackageIdx = glcmConfig.idxPackage
    local isPackageIdxOutOfBounds = nextPackageIdx > packageLength

    if isPackageIdxOutOfBounds then
        glcmConfig.idxPackage = 1
    end

    glcmConfig.strikeTimes = glcmConfig.strikeTimes + 1
end

local function attackSRBMContacts(CONFIG)
    local srbmConfig = CONFIG.c.srbm
    local result = { batteryIndex = 1, groupIndex = 1, isLaunched = false }
    local packageIdx = srbmConfig.idxPackage
    local targetListIdx = srbmConfig.packages[packageIdx].index
    local diff = 0
    local _diff = 0

    if srbmConfig.lastReconTime then
        diff = ScenEdit_CurrentTime() - srbmConfig.lastReconTime
    end

    -- Strike at a fixed time.
    if srbmConfig.strikeAtFixedTime.lastStrikeTime then
        _diff = ScenEdit_CurrentTime() - srbmConfig.strikeAtFixedTime.lastStrikeTime
    end

    local isTimeExceeded = srbmConfig.strikeAtFixedTime.lastStrikeTime
        and _diff >= srbmConfig.strikeAtFixedTime.strikeTimeSpan

    if isTimeExceeded then
        srbmConfig.strikeAtFixedTime.isTimeExceeded = true
        ScenEdit_SpecialMessage('China', 'Time is exceeded.')
    end
    -- Strike at a fixed time.

    for _, v in ipairs(srbmConfig.packages[packageIdx].targetList[targetListIdx]) do
        local contact = ScenEdit_GetContact({ side = 'China', guid = v.guid })

        if contact then
            local BDA = contact.BDA
            local hasReconed = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage')
                and srbmConfig.lastReconTime and ScenEdit_CurrentTime() > srbmConfig.lastReconTime
                and diff <= srbmConfig.const.contactAge
            local isTheFirstStrike = BDA == nil and not srbmConfig.packages[packageIdx].hasLaunchedTheFirstStrike
            local strikeIfRadar = packageIdx == 1

            if (isTheFirstStrike or hasReconed or strikeIfRadar or isTimeExceeded) then
                result = attackContact(
                    contact,
                    srbmConfig.packages[packageIdx].num,
                    srbmConfig.packages[packageIdx].batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end

    if result.isLaunched then
        srbmConfig.packages[packageIdx].index = srbmConfig.packages[packageIdx].index + 1
        srbmConfig.strikeAtFixedTime.lastStrikeTime = ScenEdit_CurrentTime()
    end

    -- To do when the time is exceeded.
    if srbmConfig.strikeAtFixedTime.isTimeExceeded then
        if result.isLaunched then
            srbmConfig.strikeAtFixedTime.strikeTimes = srbmConfig.strikeAtFixedTime.strikeTimes - 1
        end

        if srbmConfig.strikeAtFixedTime.strikeTimes == 0 then
            srbmConfig.strikeAtFixedTime.strikeTimes = 4
            srbmConfig.strikeAtFixedTime.isTimeExceeded = false
        end
    end
    -- To do when the time is exceeded.

    local targetListLength = getCount(srbmConfig.packages[packageIdx].targetList)
    local nextTargetListIdx = srbmConfig.packages[packageIdx].index
    local isTargetListIdxOutOfBounds = nextTargetListIdx > targetListLength

    if isTargetListIdxOutOfBounds then
        srbmConfig.packages[packageIdx].index = targetListLength
        srbmConfig.packages[packageIdx].hasLaunchedTheFirstStrike = true

        if srbmConfig.packages[packageIdx].name == 'RADAR' then
            srbmConfig.packages[packageIdx].hasLaunchedTheFirstStrike = false
        end
    end

    srbmConfig.idxPackage = srbmConfig.idxPackage + 1
    local packageLength = getCount(srbmConfig.packages)
    local nextPackageIdx = srbmConfig.idxPackage
    local isPackageIdxOutOfBounds = nextPackageIdx > packageLength

    if isPackageIdxOutOfBounds then
        srbmConfig.idxPackage = 1
    end

    srbmConfig.strikeTimes = srbmConfig.strikeTimes + 1

    if srbmConfig.strikeTimes >= 5 then
        CONFIG.c.aircraft.antiShip.isStrikeActivated = true
    end

    if srbmConfig.strikeTimes >= 10 then
        CONFIG.c.aircraft.isStrikeActivated = true
    end
end

local function attackFacilityContacts(landStrikeConfig)
    local diffTime = 0

    if landStrikeConfig.lastStrikeTime then
        diffTime = ScenEdit_CurrentTime() - landStrikeConfig.lastStrikeTime
    end

    local isToStrike = not landStrikeConfig.lastStrikeTime
        or (landStrikeConfig.lastStrikeTime and diffTime >= landStrikeConfig.const.periodOfStrike)

    for _, package in ipairs(landStrikeConfig.packages) do
        if not package.hasLaunched and isToStrike then
            launchLandStrike(
                package.fromUnit,
                package.num,
                package.weaponDBID,
                package.allocation,
                package.course,
                package.targetList
            )

            package.hasLaunched = true
            landStrikeConfig.lastStrikeTime = ScenEdit_CurrentTime()
            break
        end
    end
end

local function attackMobileContacts(contacts, aircraftConfig)
    local diffTime = 0

    if aircraftConfig.lastStrikeTime then
        diffTime = ScenEdit_CurrentTime() - aircraftConfig.lastStrikeTime
    end

    local isToStrike = not aircraftConfig.lastStrikeTime
        or (aircraftConfig.lastStrikeTime and diffTime >= aircraftConfig.const.periodOfStrike)

    for _, package in ipairs(aircraftConfig.packages) do
        if not package.hasLaunched then
            local filteredContacts = filterContacts(contacts, function(value)
                return (value.typed == 8 or value.typed == 21) and value:inArea(package.area)
            end)

            if getCount(filteredContacts) >= 8 and isToStrike then
                for _, value in ipairs(filteredContacts) do
                    value.posture = 'H'
                    ScenEdit_AssignUnitAsTarget(value.guid, package.missionName)
                end

                local strikers = assingUnitToStrikeMission(
                    package.striker.baseGUID,
                    package.striker.num,
                    package.striker.weaponDBID,
                    package.missionName,
                    false
                )
                package.striker.units = strikers

                if package.escort then
                    local escorts = assingUnitToStrikeMission(
                        package.escort.baseGUID,
                        package.escort.num,
                        package.escort.weaponDBID,
                        package.missionName,
                        true
                    )
                    package.escort.units = escorts
                end

                if package.wildWeasel then
                    local wildWeasels = assingUnitToStrikeMission(
                        package.wildWeasel.baseGUID,
                        package.wildWeasel.num,
                        package.wildWeasel.weaponDBID,
                        package.missionName,
                        true
                    )
                    package.wildWeasel.units = wildWeasels
                end

                if package.tanker then
                    local mission = ScenEdit_GetMission('China', package.tanker.missionName)
                    mission.isactive = true
                end

                package.hasLaunched = true
                aircraftConfig.lastStrikeTime = ScenEdit_CurrentTime()
                aircraftConfig.maxStrikeTimes = aircraftConfig.maxStrikeTimes - 1
                break
            end
        end
    end
end

local function attackShipContacts(contacts, antishipConfig)
    for _, package in ipairs(antishipConfig.packages) do
        if not package.hasLaunched then
            local filteredContacts = filterContacts(contacts, function(value)
                return value.typed == 2 and value:inArea(package.area)
            end)

            if getCount(filteredContacts) >= 4 then
                for _, value in ipairs(filteredContacts) do
                    value.posture = 'H'
                    ScenEdit_AssignUnitAsTarget(value.guid, package.missionName)
                end

                local strikers = assingUnitToStrikeMission(
                    package.striker.baseGUID,
                    package.striker.num,
                    package.striker.weaponDBID,
                    package.missionName,
                    false
                )
                package.striker.units = strikers

                if package.escort then
                    local escorts = assingUnitToStrikeMission(
                        package.escort.baseGUID,
                        package.escort.num,
                        package.escort.weaponDBID,
                        package.missionName,
                        true
                    )
                    package.escort.units = escorts
                end

                if package.wildWeasel then
                    local wildWeasels = assingUnitToStrikeMission(
                        package.wildWeasel.baseGUID,
                        package.wildWeasel.num,
                        package.wildWeasel.weaponDBID,
                        package.missionName,
                        true
                    )
                    package.wildWeasel.units = wildWeasels
                end

                package.hasLaunched = true
                break
            end
        end
    end
end

local function launchAirIntercept(contacts, airInterceptConfig)
    for _, package in ipairs(airInterceptConfig.packages) do
        if not package.hasLaunched then
            local filteredContacts = filterContacts(contacts, function(value)
                if value.emissions and value.emissions[1] then
                    local emission = value.emissions[1]['sensor_dbid']
                    return value.typed == 0
                        and (emission == CONFIG.const.sensorBDID7 or emission == CONFIG.const.sensorBDID8)
                        and value:inArea(package.area)
                end

                return false
            end)

            if getCount(filteredContacts) >= 1 then
                for _, value in ipairs(filteredContacts) do
                    value.posture = 'H'
                    ScenEdit_AssignUnitAsTarget(value.guid, package.missionName)
                end

                local strikers = assingUnitToStrikeMission(
                    package.striker.baseGUID,
                    package.striker.num,
                    package.striker.weaponDBID,
                    package.missionName,
                    false,
                    package.course
                )
                package.striker.units = strikers

                if package.escort then
                    local escorts = assingUnitToStrikeMission(
                        package.escort.baseGUID,
                        package.escort.num,
                        package.escort.weaponDBID,
                        package.missionName,
                        true,
                        package.course
                    )
                    package.escort.units = escorts
                end

                if package.wildWeasel then
                    local wildWeasels = assingUnitToStrikeMission(
                        package.wildWeasel.baseGUID,
                        package.wildWeasel.num,
                        package.wildWeasel.weaponDBID,
                        package.missionName,
                        true,
                        package.course
                    )
                    package.wildWeasel.units = wildWeasels
                end

                if package.tanker then
                    local mission = ScenEdit_GetMission('China', package.tanker.missionName)
                    mission.isactive = true
                end

                package.hasLaunched = true
                break
            end
        end
    end
end

local function attackSLCMContacts(slcmConfig)
    launchSLCM(
        slcmConfig.const.submarines,
        slcmConfig.const.weaponDBID,
        8,
        CONFIG.c.slcm.const.targetList
    )
end

local contacts = ScenEdit_GetContacts('China')
local units = VP_GetSide({ Side = 'China' }).units
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if contacts == nil then
    return
end

if CONFIG.c.aircraft.isStrikeActivated then
    aircraftReturnToBase(CONFIG.c.aircraft.packages)
end

if CONFIG.c.aircraft.antiShip.isStrikeActivated then
    aircraftReturnToBase(CONFIG.c.aircraft.antiShip.packages)
end

if CONFIG.c.aircraft.airIntercept.isStrikeActivated then
    aircraftReturnToBase(CONFIG.c.aircraft.airIntercept.packages)
end

if isMissileMoreThan('DF', units, 30) then
    return
end

launchH6NIfRequired(CONFIG.c.srbm.onSAM)

if CONFIG.c.mlrs.isStrikeActivated then
    attackMLRSContacts(contacts, CONFIG.c.mlrs)
end

if CONFIG.c.srbm.isStrikeActivated then
    attackSRBMContacts(CONFIG)
end

if CONFIG.c.srbm.onSAM.isStrikeActivated then
    attackSAMContacts(contacts, CONFIG.c.srbm.onSAM)
end

if CONFIG.c.aircraft.isStrikeActivated and CONFIG.c.aircraft.maxStrikeTimes > 0 then
    attackMobileContacts(contacts, CONFIG.c.aircraft)
end

if CONFIG.c.aircraft.antiShip.isStrikeActivated then
    attackShipContacts(contacts, CONFIG.c.aircraft.antiShip)
end

if CONFIG.c.aircraft.airIntercept.isStrikeActivated then
    launchAirIntercept(contacts, CONFIG.c.aircraft.airIntercept)
end

if CONFIG.c.slcm.isStrikeActivated then
    attackSLCMContacts(CONFIG.c.slcm)
end

if CONFIG.c.glcm.isStrikeActivated then
    attackGLCMContacts(CONFIG)
end

if CONFIG.c.aircraft.landStrike.isStrikeActivated then
    attackFacilityContacts(CONFIG.c.aircraft.landStrike)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")



-- { FLOOD = 'No Flooding', FIRES = 'Major Fire', STRUCTURAL = 'Heavy damage' }
--print(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[4].targetList[2])
--print(ScenEdit_GetMission('China', 'STRIKE ON SHELTER 2').targetlist)
