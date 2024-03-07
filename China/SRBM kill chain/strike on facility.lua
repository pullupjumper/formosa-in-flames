local function aircraftReturnToBase(aircraftPackages)
    for _, pack in ipairs(aircraftPackages) do
        if pack.striker.units ~= nil and getCount(pack.striker.units) > 0 and hasDestroyedOrRTB(pack.striker.units, 1) then
            for i, value in ipairs(pack.escort.units) do
                local unit = SE_GetUnit({ guid = value.unit })
                if unit then
                    unit:RTB(true)
                end
            end

            for i, value in ipairs(pack.wildWeasel.units) do
                local unit = SE_GetUnit({ guid = value.unit })
                if unit then
                    unit:RTB(true)
                end
            end

            pack.striker.units = {}
            pack.escort.units = {}
            pack.wildWeasel.units = {}
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

        for _, filteredContact in ipairs(filteredContacts) do
            if filteredContact.lastDetections
                and filteredContact.lastDetections[1].age <= mlrsConfig.const.contactAge then
                result = attackContact(
                    filteredContact,
                    4,
                    package.batteries,
                    result.batteryIndex,
                    result.groupIndex,
                    mlrsConfig.batteries[1].weaponDBID
                )
            end
        end
    end
end

local function attackSRBMContacts(contacts, CONFIG)
    local srbmConfig = CONFIG.c.srbm
    local result = { batteryIndex = 1, groupIndex = 1, isLaunched = false }
    local packageIdx = srbmConfig.idxPackage
    local targetListIdx = srbmConfig.packages[packageIdx].index
    local diff = 0

    if srbmConfig.lastReconTime then
        diff = ScenEdit_CurrentTime() - srbmConfig.lastReconTime
    end

    for _, value in ipairs(contacts) do
        local BDA = value.BDA
        local hasReconed = BDA and not BDA['STRUCTURAL'] == 'Heavy damage'
            and srbmConfig.lastReconTime and ScenEdit_CurrentTime() > srbmConfig.lastReconTime
            and diff <= srbmConfig.const.contactAge
        local isTheFirstStrike = not BDA
            and not srbmConfig.packages[packageIdx].hasLaunchedTheFirstStrike

        for _, v in ipairs(srbmConfig.packages[packageIdx].targetList[targetListIdx]) do
            if v.guid == value.guid and (isTheFirstStrike or hasReconed) then
                result = attackContact(
                    value,
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
    end

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

    if srbmConfig.strikeTimes >= 4 then
        CONFIG.c.antiShip.isStrikeActivated = true
    end

    if srbmConfig.strikeTimes >= 10 then
        CONFIG.c.aircraft.isStrikeActivated = true
    end
end

local function launchLandStrike(contacts, aircraftConfig)
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

                local escorts = assingUnitToStrikeMission(
                    package.escort.baseGUID,
                    package.escort.num,
                    package.escort.weaponDBID,
                    package.missionName,
                    true
                )
                package.escort.units = escorts

                local wildWeasels = assingUnitToStrikeMission(
                    package.wildWeasel.baseGUID,
                    package.wildWeasel.num,
                    package.wildWeasel.weaponDBID,
                    package.missionName,
                    true
                )
                package.wildWeasel.units = wildWeasels
                package.hasLaunched = true
                aircraftConfig.lastStrikeTime = ScenEdit_CurrentTime()
                aircraftConfig.maxStrikeTimes = aircraftConfig.maxStrikeTimes - 1
                break
            end
        end
    end
end

local function launchNavalStrike(contacts, antishipConfig)
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

                local escorts = assingUnitToStrikeMission(
                    package.escort.baseGUID,
                    package.escort.num,
                    package.escort.weaponDBID,
                    package.missionName,
                    true
                )
                package.escort.units = escorts

                local wildWeasels = assingUnitToStrikeMission(
                    package.wildWeasel.baseGUID,
                    package.wildWeasel.num,
                    package.wildWeasel.weaponDBID,
                    package.missionName,
                    true
                )
                package.wildWeasel.units = wildWeasels
                package.hasLaunched = true
                break
            end
        end
    end
end

local contacts = ScenEdit_GetContacts('China')
local units = VP_GetSide({ Side = 'China' }).units
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if contacts == nil then
    return
end

if CONFIG.c.aircraft.isStrikeActivated then
    aircraftReturnToBase(CONFIG.c.aircraft.packages)
end

if CONFIG.c.antiShip.isStrikeActivated then
    aircraftReturnToBase(CONFIG.c.antiShip.packages)
end

if isMissileMoreThan('DF', units, 30) then
    return
end

launchH6NIfRequired(CONFIG.c.srbm.onSAM)

if CONFIG.c.srbm.onSAM.isStrikeActivated then
    attackSAMContacts(contacts, CONFIG.c.srbm.onSAM)
end

if CONFIG.c.mlrs.isStrikeActivated then
    attackMLRSContacts(contacts, CONFIG.c.mlrs)
end

if CONFIG.c.srbm.isStrikeActivated then
    attackSRBMContacts(contacts, CONFIG)
end

if CONFIG.c.aircraft.isStrikeActivated and CONFIG.c.aircraft.maxStrikeTimes > 0 then
    launchLandStrike(contacts, CONFIG.c.aircraft)
end

if CONFIG.c.antiShip.isStrikeActivated then
    launchNavalStrike(contacts, CONFIG.c.antiShip)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")



-- { FLOOD = 'No Flooding', FIRES = 'Major Fire', STRUCTURAL = 'Heavy damage' }
--print(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[4].targetList[2])
--print(ScenEdit_GetMission('China', 'STRIKE ON SHELTER 2').targetlist)
