local function launchH6NIfRequired(onSAMConfig)
    if IsDestroyedOrRTB(onSAMConfig.h6nTemp, 1) and IsDestroyedOrRTB(onSAMConfig.wz8Temp, 1) then
        onSAMConfig.h6nTemp = LaunchUnits(
            onSAMConfig.const.h6nBaseGUID,
            onSAMConfig.const.h6nCourse,
            1,
            onSAMConfig.const.h6nDBID,
            'Aircraft'
        )
    end
end

local function trackTarget(CONFIG, units, UAVDBID, target)
    local UAV = nil

    for guid, value in pairs(CONFIG.c.recon.bzk005Temp) do
        if value.targetGUID == target.guid then
            local unit = SE_GetUnit({ guid = guid })

            if unit then
                return true
            end
        end
    end

    if UAV == nil then
        for _, value in ipairs(units) do
            local unit = SE_GetUnit({ guid = value.guid })
            local d = 1000

            if unit and unit.dbid == UAVDBID and unit.condition == 'Airborne' then
                local distance = Tool_Range({ latitude = unit.latitude, longitude = unit.longitude }, target.guid)
                if distance < d then
                    d = distance
                    UAV = unit
                end
            end
        end
    end

    if UAV then
        if UAV.mission then
            UAV.mission = ''
        end

        UAV.course = { {
            latitude = target.latitude,
            longitude = target.longitude,
            desiredSpeed = 115,
            presetThrottle = 'Military'
        } }

        CONFIG.c.recon.bzk005Temp[UAV.guid] = { guid = UAV.guid, targetGUID = target.guid }
        return true
    end

    return false
end

local function analyzeTargets(CONFIG, type)
    local _targetList = {}
    local mlrsConfig = CONFIG.c.ground[type]
    -- local elapsedTime = 0

    -- if mlrsConfig.lastReconTime then
    --     elapsedTime = ScenEdit_CurrentTime() - mlrsConfig.lastReconTime
    -- end

    for index, package in ipairs(mlrsConfig.packages) do
        local targetListIdx = package.index
        local targets = {}

        for _, v in ipairs(package.targetList[targetListIdx]) do
            local target = ScenEdit_GetContact({ side = 'China', guid = v.guid })

            if target then
                local isHelipad = string.find(target.type_description, 'Helipad') ~= nil
                local BDA = target.BDA
                local detections = target.lastDetections
                -- local hasReconed = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage')
                --     and mlrsConfig.lastReconTime and ScenEdit_CurrentTime() > mlrsConfig.lastReconTime
                --     and elapsedTime <= mlrsConfig.const.contactAge
                local hasEvaluated = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
                    (detections and detections[1].age <= mlrsConfig.const.contactAge) and
                    not isHelipad
                local isInitialWaveOfAttacks = targetListIdx == 1 and
                    not mlrsConfig.packages[index].isFinished and
                    not isHelipad
                local isRadar = package.name == 'RADAR' and not isHelipad
                local isHelipadEmbarkedWithHelicopter = isHelipad and
                    not mlrsConfig.packages[index].isFinished and
                    GetCount(SE_GetUnit({ guid = target.actualunitid }).embarkedUnits['Aircraft']) > 0


                if (isInitialWaveOfAttacks or hasEvaluated or isRadar or isHelipadEmbarkedWithHelicopter) then
                    table.insert(targets, target)
                end
            end
        end

        table.insert(_targetList, {
            isDecidedToStrike = false,
            fixedTargets = targets,
            emittingTargets = {},
            radioTargets = {},
            targets = targets
        })

        if CONFIG.isDevMode and GetCount(targets) > 0 then
            ScenEdit_SpecialMessage('China', package.name .. ': ' .. GetCount(targets))

            if index == GetCount(mlrsConfig.packages) then
                ScenEdit_SpecialMessage('China', 'Fixed targets:===============================')
            end
        end
    end

    return _targetList
end

local function analyzeEmissions(CONFIG, type, targetList, contacts)
    local mlrsConfig = CONFIG.c.ground[type]

    for index, package in ipairs(mlrsConfig.packages) do
        local targets = {}

        for _, area in ipairs(package.areas) do
            for _, c in ipairs(contacts) do
                local isSensor = c.emissions and
                    (c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID9 or
                        c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID10 or
                        c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID11 or
                        c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID12)
                local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= CONFIG.c.recon.const.contactAge
                local isSAM = isSensor and isAgeLessThan
                if c:inArea(area) and isSAM then table.insert(targets, c) end
            end
        end

        targetList[index].emittingTargets = targets
        InsertList(targetList[index].targets, targets)

        if CONFIG.isDevMode and GetCount(targets) > 0 then
            ScenEdit_SpecialMessage('China', package.name .. ': ' .. GetCount(targets))

            if index == GetCount(mlrsConfig.packages) then
                ScenEdit_SpecialMessage('China', 'Emission targets:===============================')
            end
        end
    end

    return targetList
end

local function analyzeRadioTransmissions(CONFIG, type, targetList, contacts)
    local mlrsConfig = CONFIG.c.ground[type]

    local function filterTargetsInArea(contacts, areas)
        local targets = {}

        for _, area in ipairs(areas) do
            for _, c in ipairs(contacts) do
                if (c.typed == 8 or
                        string.find(c.type_description, 'ROCC') ~= nil or
                        string.find(c.type_description, 'TAAOC') ~= nil) and
                    c:inArea(area) then
                    table.insert(targets, c)
                end
            end
        end

        return targets
    end

    local function filterTargetsWithinRangeOfTransmissionSources(CONFIG, contacts)
        local targets = {}
        local isTracking = false

        for _, c in ipairs(contacts) do
            for _, transmission in pairs(CONFIG.c.SIGINT.transmissions) do
                local distance = Tool_Range(
                    { latitude = transmission.latitude, longitude = transmission.longitude }, c.guid
                )

                if distance <= CONFIG.c.SIGINT.const.maxRange and
                    transmission.temp > CONFIG.c.SIGINT.const.maxCount then
                    table.insert(targets, c)

                    if not isTracking and transmission.type == 'mobile' then
                        isTracking = trackTarget(
                            CONFIG,
                            VP_GetSide({ Side = 'China' }).units,
                            CONFIG.const.platformBDID13,
                            c
                        )
                    end
                end
            end
        end

        return targets
    end

    for index, package in ipairs(mlrsConfig.packages) do
        local targets = filterTargetsInArea(contacts, package.areas)
        targets = filterTargetsWithinRangeOfTransmissionSources(CONFIG, targets)
        targetList[index].radioTargets = targets
        InsertList(targetList[index].targets, targets)

        if CONFIG.isDevMode and GetCount(targets) > 0 then
            ScenEdit_SpecialMessage('China', package.name .. ': ' .. GetCount(targets))

            if index == GetCount(mlrsConfig.packages) then
                ScenEdit_SpecialMessage('China', 'Radio targets:===============================')
            end
        end
    end

    return targetList
end

local function determineIfDeployByTargetNum(targetList, targetNum)
    for _, item in ipairs(targetList) do
        item.isDecidedToStrike = GetCount(item.targets) >= targetNum
            or (GetCount(item.emittingTargets) >= 1 and GetCount(item.fixedTargets) <= 1)
            or (GetCount(item.radioTargets) >= 1 and GetCount(item.fixedTargets) <= 1)
    end

    return targetList
end

local function deployBatteries(CONFIG, type, targetList)
    local mlrsConfig = CONFIG.c.ground[type]
    local isAllArrived = true

    for index, item in ipairs(targetList) do
        if item.isDecidedToStrike then
            for _, bty in ipairs(mlrsConfig.packages[index].batteries) do
                local group = SE_GetUnit({ guid = bty.guid })

                if group then
                    if mlrsConfig.batteries[bty.guid].state == CONFIG.const.batteryState.RESUPPLY
                        and not IsWpnNumLessThan(
                            group,
                            mlrsConfig.batteries[bty.guid].wpnNumLessThan,
                            mlrsConfig.batteries[bty.guid].weaponDBID
                        ) then
                        ToFringPosition(mlrsConfig.batteries[bty.guid], group)
                    end

                    if mlrsConfig.batteries[bty.guid].state ~= CONFIG.const.batteryState.STATIC then
                        isAllArrived = false
                    end
                end
            end
        end
    end

    return isAllArrived
end

local function launchMissiles(CONFIG, type, targetList, weaponDBID)
    local mlrsConfig = CONFIG.c.ground[type]

    for index, item in ipairs(targetList) do
        if item.isDecidedToStrike then
            local result = AttackContacts(
                item.targets,
                mlrsConfig.packages[index].num,
                mlrsConfig.packages[index].batteries,
                weaponDBID
            )

            if result > 0 then
                mlrsConfig.packages[index].index = mlrsConfig.packages[index].index + 1

                if CONFIG.isDevMode then
                    ScenEdit_SpecialMessage(
                        'China',
                        mlrsConfig.packages[index].name .. '/Missiles: ' .. result
                    )

                    if index == GetCount(mlrsConfig.packages) then
                        ScenEdit_SpecialMessage('China', 'Firing missiles:============================')
                    end
                end
            end

            local targetListLength = GetCount(mlrsConfig.packages[index].targetList)
            local nextTargetListIdx = mlrsConfig.packages[index].index
            local isTargetListIdxOutOfBounds = nextTargetListIdx > targetListLength

            if isTargetListIdxOutOfBounds then
                mlrsConfig.packages[index].index = targetListLength
                mlrsConfig.packages[index].isFinished = true
            end
        end
    end
end

local function handleStrikePackagesWithMission(package, contacts, filterFn, contactNum)
    local assignAllUnitsToStrikeMission = function(pkg)
        local strikers = AssignEmbarkedUnitToStrikeMission(
            pkg.striker.baseGUID,
            pkg.striker.num,
            pkg.striker.weaponDBID,
            nil,
            pkg.missionName,
            false
        )
        -- pkg.striker.units = strikers

        if pkg.escort then
            local escorts = AssignEmbarkedUnitToStrikeMission(
                pkg.escort.baseGUID,
                pkg.escort.num,
                pkg.escort.weaponDBID,
                nil,
                pkg.missionName,
                true
            )
            -- pkg.escort.units = escorts
        end

        if pkg.wildWeasel then
            local wildWeasels = AssignEmbarkedUnitToStrikeMission(
                pkg.wildWeasel.baseGUID,
                pkg.wildWeasel.num,
                pkg.wildWeasel.weaponDBID,
                nil,
                pkg.missionName,
                true
            )
            -- pkg.wildWeasel.units = wildWeasels
        end

        if pkg.jammer then
            local jammers = AssignEmbarkedUnitToStrikeMission(
                pkg.jammer.baseGUID,
                pkg.jammer.num,
                0,
                pkg.jammer.unitDBID,
                pkg.missionName,
                true
            )
            -- pkg.jammer.units = jammers
        end

        if pkg.tanker then
            local mission = ScenEdit_GetMission('China', pkg.tanker.missionName)
            mission.isactive = true
        end
    end

    if contacts and filterFn and contactNum then
        local fn = filterFn(package)
        local filteredContacts = FilterContacts(contacts, fn)

        if GetCount(filteredContacts) >= contactNum then
            for _, value in ipairs(filteredContacts) do
                value.posture = 'H'
                ScenEdit_AssignUnitAsTarget(value.guid, package.missionName)
            end
            assignAllUnitsToStrikeMission(package)
            return true
        end
    else
        assignAllUnitsToStrikeMission(package)
        return true
    end
    return false
end

local function airStrike(CONFIG, base, type, contacts, contactHandler, contactNum)
    local antishipConfig = CONFIG.c.air[base][type]
    local elapsedTime = 0

    if antishipConfig.lastStrikeTime then
        elapsedTime = ScenEdit_CurrentTime() - antishipConfig.lastStrikeTime
    end

    local isAllowedToAttack = not antishipConfig.lastStrikeTime
        or (antishipConfig.lastStrikeTime and elapsedTime >= antishipConfig.const.timeSpan)

    for _, package in ipairs(antishipConfig.packages) do
        if not package.hasLaunched and isAllowedToAttack then
            local isAssigned = handleStrikePackagesWithMission(package, contacts, contactHandler, contactNum)

            if isAssigned then
                package.hasLaunched = true
                antishipConfig.lastStrikeTime = ScenEdit_CurrentTime()
            end

            break
        end
    end
end

local contacts = ScenEdit_GetContacts('China')
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if contacts == nil then
    return
end

launchH6NIfRequired(CONFIG.c.recon)

if CONFIG.c.ground.mlrs.isStrikeActivated then
    local targetList = {}
    local isAllArrived = false
    local key = CONFIG.c.ground.mlrs.packages[1].batteries[1].guid
    local weaponDBID = CONFIG.c.ground.mlrs.batteries[key].weaponDBID
    targetList = analyzeTargets(CONFIG, 'mlrs')
    targetList = analyzeEmissions(CONFIG, 'mlrs', targetList, contacts)
    targetList = analyzeRadioTransmissions(CONFIG, 'mlrs', targetList, contacts)
    targetList = determineIfDeployByTargetNum(targetList, 7)
    isAllArrived = deployBatteries(CONFIG, 'mlrs', targetList)
    if isAllArrived then launchMissiles(CONFIG, 'mlrs', targetList, weaponDBID) end
end

if CONFIG.c.ground.srbm.isStrikeActivated then
    local targetList = analyzeTargets(CONFIG, 'srbm')
    targetList = determineIfDeployByTargetNum(targetList, 7)
    local isAllArrived = deployBatteries(CONFIG, 'srbm', targetList)
    if isAllArrived then launchMissiles(CONFIG, 'srbm', targetList) end
end

if CONFIG.c.ground.glcm.isStrikeActivated then
    local targetList = analyzeTargets(CONFIG, 'glcm')
    targetList = determineIfDeployByTargetNum(targetList, 5)
    local isAllArrived = deployBatteries(CONFIG, 'glcm', targetList)
    if isAllArrived then launchMissiles(CONFIG, 'glcm', targetList) end
end

if CONFIG.c.surface.lacm.isStrikeActivated then
    local ships = {}

    for _, value in ipairs(SE_GetUnit({ unitname = 'CSG' }).group.unitlist) do
        local unit = SE_GetUnit({ guid = value })
        if unit and unit.dbid == CONFIG.const.platformBDID51 then
            table.insert(ships, { guid = value })
        end
    end

    AttackContacts(
        CONFIG.c.surface.lacm.const.targetList,
        5,
        ships,
        CONFIG.c.surface.lacm.const.weaponDBID
    )
end

if CONFIG.c.subSurface.slcm.isStrikeActivated then
    AttackContacts(
        CONFIG.c.subSurface.slcm.const.targetList,
        8,
        CONFIG.c.subSurface.slcm.const.submarines,
        CONFIG.c.subSurface.slcm.const.weaponDBID
    )
end

if CONFIG.c.air.landBased.lacm.isStrikeActivated then
    airStrike(CONFIG, 'landBased', 'lacm')
end

if CONFIG.c.air.shipBased.lacm.isStrikeActivated then
    airStrike(CONFIG, 'shipBased', 'lacm')
end

if CONFIG.c.air.landBased.ascm.isStrikeActivated then
    local navalContactHandler = function(package)
        return function(value)
            return value.typed == 2 and value:inArea(package.area)
        end
    end
    airStrike(CONFIG, 'landBased', 'ascm', contacts, navalContactHandler, 4)
end

if CONFIG.c.air.landBased.aam.isStrikeActivated then
    local airContactHandler = function(package)
        return function(value)
            if value.emissions and value.emissions[1] then
                local emission = value.emissions[1]['sensor_dbid']
                return value.typed == 0
                    and (emission == CONFIG.const.sensorBDID7 or emission == CONFIG.const.sensorBDID8)
                    and value:inArea(package.area)
            end

            return false
        end
    end
    -- local airContactHandler = function(package)
    --     return function(value)
    --         if value.typed == 0 and value:inArea(package.area) then
    --             return true
    --         end

    --         return false
    --     end
    -- end
    airStrike(CONFIG, 'landBased', 'aam', contacts, airContactHandler, 6)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")



-- { FLOOD = 'No Flooding', FIRES = 'Major Fire', STRUCTURAL = 'Heavy damage' }
