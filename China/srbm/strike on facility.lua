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
            if unit then return true end
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
        if UAV.mission then UAV.mission = '' end

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
    local function isHelipad(target)
        return string.find(target.type_description, 'Helipad') ~= nil
    end

    local function isHeavyDamage(mlrsConfig, target)
        local BDA = target.BDA
        local detections = target.lastDetections
        return BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
            (detections and detections[1].age <= mlrsConfig.const.contactAge) and
            not isHelipad(target)
    end

    local function isInitialWave(package, target, targetListIdx)
        return targetListIdx == 1 and not package.isFinished and not isHelipad(target)
    end

    local function isRadarTarget(package, target)
        return package.name == 'RADAR' and not isHelipad(target)
    end

    local function isHelipadWithHelicopter(package, target)
        return isHelipad(target) and
            not package.isFinished and
            -- Modified: Replaced GetCount with #
            #SE_GetUnit({ guid = target.actualunitid }).embarkedUnits['Aircraft'] > 0
    end

    local function evaluateTargets(mlrsConfig, package, targetListIdx)
        return function(v)
            local target = ScenEdit_GetContact({ side = 'China', guid = v.guid })
            if target and (
                    isInitialWave(package, target, targetListIdx) or
                    isHeavyDamage(mlrsConfig, target) or
                    isRadarTarget(package, target) or
                    isHelipadWithHelicopter(package, target)
                ) then
                return true
            end

            return false
        end
    end

    local targetsSortedByPackage = {}
    local mlrsConfig = CONFIG.c.ground[type]

    for index, package in ipairs(mlrsConfig.packages) do
        local targetListIdx = package.index
        local targets = Array_utils.new(package.targetList[targetListIdx])
            :filter(evaluateTargets(mlrsConfig, package, targetListIdx))
            :value()

        table.insert(targetsSortedByPackage, {
            isTargetsMoreThan = false,
            fixedTargets = targets,
            emittingTargets = {},
            radioTargets = {},
            targets = targets
        })

        if CONFIG.isDevMode and #targets > 0 then
            -- Modified: Replaced GetCount with #
            printBox({ 'Fixed targets/' .. package.name .. ': ' .. #targets }, 'China')
        end
    end

    return targetsSortedByPackage
end

-- local function analyzeEmissions(CONFIG, type, targetList, contacts)
--     local mlrsConfig = CONFIG.c.ground[type]

--     for index, package in ipairs(mlrsConfig.packages) do
--         local targets = {}

--         for _, area in ipairs(package.areas) do
--             for _, c in ipairs(contacts) do
--                 local isSensor = c.emissions and
--                     (c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID9 or
--                         c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID10 or
--                         c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID11 or
--                         c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID12 or
--                         c.emissions[1]['sensor_dbid'] == CONFIG.const.sensorBDID14)
--                 local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= CONFIG.c.recon.const.contactAge
--                 local isSAM = isSensor and isAgeLessThan
--                 if c:inArea(area) and isSAM then table.insert(targets, c) end
--             end
--         end

--         targetList[index].emittingTargets = targets
--         InsertList(targetList[index].targets, targets)

--         if CONFIG.isDevMode and #targets > 0 then
--             -- Modified: Replaced GetCount with #
--             ScenEdit_SpecialMessage('China', package.name .. ': ' .. #targets)

--             -- Modified: Replaced GetCount with #
--             if index == #mlrsConfig.packages then
--                 ScenEdit_SpecialMessage('China', 'Emission targets:===============================')
--             end
--         end
--     end

--     return targetList
-- end



-- 主函數
local function analyzeEmissions(CONFIG, type, targetsSortedByPackage, contacts)
    -- 定義過濾條件：檢查是否為感測器目標
    local function isEmissionFromSpecificSensor(c, CONFIG)
        if not c.emissions or not c.emissions[1] then
            return false
        end
        local sensorDbid = c.emissions[1]['sensor_dbid']
        return sensorDbid == CONFIG.const.sensorBDID9 or
            sensorDbid == CONFIG.const.sensorBDID10 or
            sensorDbid == CONFIG.const.sensorBDID11 or
            sensorDbid == CONFIG.const.sensorBDID12 or
            sensorDbid == CONFIG.const.sensorBDID14
    end

    -- 定義過濾條件：檢查年齡是否小於指定值
    local function isAgeValid(c, CONFIG)
        return c.lastDetections and c.lastDetections[1].age <= CONFIG.c.recon.const.contactAge
    end

    -- 定義過濾條件：檢查是否在區域內並滿足 SAM 條件
    local function isValidTarget(c, area, CONFIG)
        local isSensor = isEmissionFromSpecificSensor(c, CONFIG)
        local isAgeLessThan = isAgeValid(c, CONFIG)
        local isSAM = isSensor and isAgeLessThan
        return c:inArea(area) and isSAM
    end

    -- 定義 filter 的具名回調函數
    local function filterTargetsByArea(area, CONFIG)
        -- 注意：這裡需要外部變數 area 和 CONFIG，因此需要在調用時動態綁定
        -- 這個函數將在循環中使用，並依賴外部的 area 和 CONFIG
        return function(c)
            return isValidTarget(c, area, CONFIG)
        end
    end

    local mlrsConfig = CONFIG.c.ground[type]

    for index, package in ipairs(mlrsConfig.packages) do
        -- 初始化 Array_utils 對象
        local contactArray = Array_utils.new(contacts)

        -- 針對每個 area 過濾出符合條件的 targets
        local targets = {}
        for _, area in ipairs(package.areas) do
            -- 使用具名回調函數，並傳入當前的 area 和 CONFIG
            local filteredTargets = contactArray
                :filter(filterTargetsByArea(area, CONFIG))
                :value()
            -- InsertList(targets, filteredTargets)
            targets = Array_utils.new(targets):concat(filteredTargets):value()
        end

        -- 更新 targetList
        targetsSortedByPackage[index].emittingTargets = targets
        -- InsertList(targetsSortedByPackage[index].targets, targets)
        targetsSortedByPackage[index].targets = Array_utils.new(targetsSortedByPackage[index].targets)
            :concat(targets)
            :value()

        -- 開發模式下的調試信息
        if CONFIG.isDevMode and #targets > 0 then
            printBox({ 'Emission targets/' .. package.name .. ': ' .. #targets }, 'China')
        end
    end

    return targetsSortedByPackage
end

local function analyzeRadioTransmissions(CONFIG, type, targetsSortedByPackage, contacts)
    local mlrsConfig = CONFIG.c.ground[type]

    local isC2Facility = function(area)
        return function(c)
            return (c.typed == 8 or
                    string.find(c.type_description, 'ROCC') ~= nil or
                    string.find(c.type_description, 'TAAOC') ~= nil) and
                c:inArea(area)
        end
    end

    local isWithinRange = function(distance, transmission, CONFIG)
        return distance <= CONFIG.c.SIGINT.const.maxRange and
            transmission.temp > CONFIG.c.SIGINT.const.maxCount
    end

    local function filterTargetsInArea(contacts, areas)
        local targets = {}

        for _, area in ipairs(areas) do
            Array_utils.new(contacts)
                :filter(isC2Facility(area))
                :forEach(function(c) table.insert(targets, c) end)
        end

        -- for _, area in ipairs(areas) do
        --     for _, c in ipairs(contacts) do
        --         if (c.typed == 8 or
        --                 string.find(c.type_description, 'ROCC') ~= nil or
        --                 string.find(c.type_description, 'TAAOC') ~= nil) and
        --             c:inArea(area) then
        --             table.insert(targets, c)
        --         end
        --     end
        -- end

        return targets
    end

    local function filterTargetsWithinRangeOfTransmissionSources(CONFIG, contacts)
        local targets = {}
        local isTracking = false
        local units = VP_GetSide({ Side = 'China' }).units

        for _, contact in ipairs(contacts) do
            for _, tm in pairs(CONFIG.c.SIGINT.transmissions) do
                local distance = Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, contact.guid)

                if isWithinRange(distance, tm, CONFIG) then
                    table.insert(targets, contact)

                    if not isTracking and tm.type == 'mobile' then
                        isTracking = trackTarget(CONFIG, units, CONFIG.const.platformBDID13, contact)
                    end
                end
            end
        end

        return targets
    end

    for index, package in ipairs(mlrsConfig.packages) do
        local targets = filterTargetsInArea(contacts, package.areas)
        targets = filterTargetsWithinRangeOfTransmissionSources(CONFIG, targets)
        targetsSortedByPackage[index].radioTargets = targets
        -- InsertList(targetsSortedByPackage[index].targets, targets)
        targetsSortedByPackage[index].targets = Array_utils.new(targetsSortedByPackage[index].targets)
            :concat(targets)
            :value()

        if CONFIG.isDevMode and #targets > 0 then
            -- -- Modified: Replaced GetCount with #
            -- ScenEdit_SpecialMessage('China', package.name .. ': ' .. #targets)

            -- -- Modified: Replaced GetCount with #
            -- if index == #mlrsConfig.packages then
            --     ScenEdit_SpecialMessage('China', 'Radio targets:===============================')
            -- end
            printBox({ 'Radio targets/' .. package.name .. ': ' .. #targets }, 'China')
        end
    end

    return targetsSortedByPackage
end

local function determineIfDeployByTargetNum(targetsSortedByPackage, targetNum)
    for _, item in ipairs(targetsSortedByPackage) do
        -- Modified: Replaced GetCount with #
        item.isTargetsMoreThan = #item.targets >= targetNum
            or (#item.emittingTargets >= 1 and #item.fixedTargets <= 1)
            or (#item.radioTargets >= 1 and #item.fixedTargets <= 1)
    end

    return targetsSortedByPackage
end

local function deployBatteries(CONFIG, type, targetsSortedByPackage)
    local mlrsConfig = CONFIG.c.ground[type]
    local isAllBtiesArrived = true
    local keys = {}

    local isBtyReady = function(bty, mlrsConfig, group)
        return mlrsConfig.batteries[bty.guid].state == CONFIG.const.batteryState.HIDE
            and not IsWpnNumLessThan(
                group,
                mlrsConfig.batteries[bty.guid].wpnNumLessThan,
                mlrsConfig.batteries[bty.guid].weaponDBID
            )
    end

    local isNotBtyAtFiringPosition = function(bty, mlrsConfig)
        return mlrsConfig.batteries[bty.guid].state ~= CONFIG.const.batteryState.STATIC
    end

    for index, item in ipairs(targetsSortedByPackage) do
        if item.isTargetsMoreThan then
            table.insert(keys, index)
        end
    end

    for _, index in ipairs(keys) do
        for _, bty in ipairs(mlrsConfig.packages[index].batteries) do
            local group = SE_GetUnit({ guid = bty.guid })

            if group then
                if isBtyReady(bty, mlrsConfig, group) then
                    ToFringPosition(mlrsConfig.batteries[bty.guid], group)
                end

                if isNotBtyAtFiringPosition(bty, mlrsConfig) then
                    isAllBtiesArrived = false
                end
            end
        end
    end

    return isAllBtiesArrived
end

local function launchMissiles(CONFIG, type, targetsSortedByPackage, weaponDBID)
    local mlrsConfig = CONFIG.c.ground[type]

    for index, item in ipairs(targetsSortedByPackage) do
        if item.isTargetsMoreThan then
            local result = AttackContacts(
                item.targets,
                mlrsConfig.packages[index].num,
                mlrsConfig.packages[index].batteries,
                weaponDBID
            )

            if result > 0 then
                mlrsConfig.packages[index].index = mlrsConfig.packages[index].index + 1

                if CONFIG.isDevMode then
                    printBox({ mlrsConfig.packages[index].name .. '/Missiles: ' .. result }, 'China')
                end
            end

            -- Modified: Replaced GetCount with #
            local targetListLength = #mlrsConfig.packages[index].targetList
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
        AssignEmbarkedUnitToStrikeMission(
            pkg.striker.baseGUID,
            pkg.striker.num,
            pkg.striker.weaponDBID,
            nil,
            pkg.missionName,
            false
        )

        if pkg.escort then
            AssignEmbarkedUnitToStrikeMission(
                pkg.escort.baseGUID,
                pkg.escort.num,
                pkg.escort.weaponDBID,
                nil,
                pkg.missionName,
                true
            )
        end

        if pkg.wildWeasel then
            AssignEmbarkedUnitToStrikeMission(
                pkg.wildWeasel.baseGUID,
                pkg.wildWeasel.num,
                pkg.wildWeasel.weaponDBID,
                nil,
                pkg.missionName,
                true
            )
        end

        if pkg.jammer then
            AssignEmbarkedUnitToStrikeMission(
                pkg.jammer.baseGUID,
                pkg.jammer.num,
                0,
                pkg.jammer.unitDBID,
                pkg.missionName,
                true
            )
        end

        if pkg.tanker then
            local mission = ScenEdit_GetMission('China', pkg.tanker.missionName)
            mission.isactive = true
        end
    end

    if contacts and filterFn and contactNum then
        -- local fn = filterFn(package)
        -- local filteredContacts = FilterContacts(contacts, fn)
        local filteredContacts = Array_utils.new(contacts):filter(filterFn(package)):value()

        -- Modified: Replaced GetCount with #
        if #filteredContacts >= contactNum then
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
    targetList = determineIfDeployByTargetNum(targetList, 1)
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
                return (emission == CONFIG.const.sensorBDID7 or emission == CONFIG.const.sensorBDID8) and
                    value.typed == 0 and
                    value:inArea(package.area)
            end

            return false
        end
    end
    airStrike(CONFIG, 'landBased', 'aam', contacts, airContactHandler, 6)
end

if CONFIG.c.air.landBased.gbu.isStrikeActivated then
    local groundContactHandler = function(package)
        return function(value)
            return value.typed == 8 and value:inArea(package.area)
        end
    end
    airStrike(CONFIG, 'landBased', 'gbu', contacts, groundContactHandler, 1)
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
