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

if CONFIG.c.aircraft.onMobileUnit.isStrikeActivated then
    for index, pack in ipairs(CONFIG.c.aircraft.onMobileUnit.strikePackage) do
        if pack.striker.units ~= nil and getCount(pack.striker.units) > 0 then
            if hasDestroyedOrRTB(pack.striker.units, 1) then
                for i, value in ipairs(pack.escort.units) do
                    local unit = SE_GetUnit({ guid = value.unit })

                    if unit ~= nil then
                        unit:RTB(true)
                    end
                end

                for i, value in ipairs(pack.wildWeasel.units) do
                    local unit = SE_GetUnit({ guid = value.unit })

                    if unit ~= nil then
                        unit:RTB(true)
                    end
                end

                pack.striker.units = {}
                pack.escort.units = {}
                pack.wildWeasel.units = {}
            end
        end
    end
end

if isMissileHit('DF', units) == false then
    return
end

if CONFIG.c.srbm.onFacility.isReloadActivated then
    reloadMissile(CONFIG.c.srbm.onFacility.launcherState, CONFIG.c.srbm.onFacility.const.reloadTime)
end

if hasDestroyedOrRTB(CONFIG.c.srbm.onSAM.h6nTemp, 1)
    and hasDestroyedOrRTB(CONFIG.c.srbm.onSAM.wz8Temp, 1) then
    CONFIG.c.srbm.onSAM.h6nTemp = launchUnits(
        CONFIG.c.srbm.onSAM.const.h6nBaseGUID,
        CONFIG.c.srbm.onSAM.const.h6nCourse,
        1,
        CONFIG.c.srbm.onSAM.const.h6nDBID,
        'Aircraft'
    )
end

if CONFIG.c.srbm.onSAM.isStrikeActivated then
    local result = { batteryIndex = 1, groupIndex = 1 }

    for index, contact in ipairs(contacts) do
        if contact.emissions ~= nil then
            local emission = contact.emissions[1]['sensor_dbid']
            local isSAM = emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID1
                or emission == CONFIG.c.srbm.onSAM.const.tk3SensorDBID2
                or emission == CONFIG.c.srbm.onSAM.const.tk2SensorDBID
            -- or emission == CONFIG.c.srbm.onSAM.const.pac3SensorDBID

            if isSAM and contact.lastDetections[1].age <= CONFIG.c.srbm.onSAM.const.contactAge then
                result = attackContact(
                    contact,
                    4,
                    CONFIG.c.srbm.onSAM.const.batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end
end

if CONFIG.c.mlrs.onMobileUnit.isStrikeActivated then
    local result = { batteryIndex = 1, groupIndex = 1 }

    for index, package in ipairs(CONFIG.c.mlrs.onMobileUnit.strikePackage) do
        local filteredContacts = filterContacts(contacts, function(value)
            if (value.typed == 8 or value.typed == 21)
            -- and value:inArea(package.area)
            then
                return true
            end

            return false
        end)

        for i, filteredContact in ipairs(filteredContacts) do
            if filteredContact.lastDetections ~= nil
                and filteredContact.lastDetections[1].age <= CONFIG.c.mlrs.onMobileUnit.const.contactAge then
                -- ScenEdit_MsgBox(tostring(filteredContact.lastDetections[1].age), 1)
                result = attackContact(
                    filteredContact,
                    4,
                    CONFIG.c.mlrs.onMobileUnit.strikePackage[index].batteries,
                    result.batteryIndex,
                    result.groupIndex,
                    CONFIG.c.mlrs.onMobileUnit.const.weaponDBID
                )
            end
        end
    end
end

if CONFIG.c.srbm.onFacility.isStrikeActivated and contacts ~= nil then
    local result = { batteryIndex = 1, groupIndex = 1 }
    local targetListIdx = CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].index
    local diff = 0

    if CONFIG.c.srbm.onFacility.lastReconTime ~= nil then
        diff = ScenEdit_CurrentTime() - CONFIG.c.srbm.onFacility.lastReconTime
    end

    for index, value in ipairs(contacts) do
        local BDA = value.BDA
        local hasReconed = (BDA ~= nil and BDA['STRUCTURAL'] ~= 'Heavy damage')
            and (CONFIG.c.srbm.onFacility.lastReconTime ~= nil and ScenEdit_CurrentTime() > CONFIG.c.srbm.onFacility.lastReconTime)
            and diff <= CONFIG.c.srbm.onFacility.const.contactAge
        local isTheFirstStrike = BDA == nil
            and CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage]
            .hasLaunchedTheFirstStrike == false

        for i, v in ipairs(CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].targetList[targetListIdx]) do
            if v.guid == value.guid and (isTheFirstStrike or hasReconed) then
                result = attackContact(
                    value,
                    CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].num,
                    CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end

    -- CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].index = CONFIG.c.srbm.onFacility
    --     .strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].index + 1

    -- local isOutofBounds = CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].index
    --     > getCount(CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].targetList)

    -- if isOutofBounds then
    --     CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].index = getCount(
    --         CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].targetList
    --     )
    --     CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].hasLaunchedTheFirstStrike = true

    --     if CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].name == 'RADAR' then
    --         CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].hasLaunchedTheFirstStrike = false
    --     end
    -- end
    CONFIG.c.srbm.onFacility.fn.increaseTargetListIdx()

    if CONFIG.c.srbm.onFacility.fn.isTargetListIdxOutOfBounds() then
        CONFIG.c.srbm.onFacility.fn.resetTargetListIdx()
        CONFIG.c.srbm.onFacility.fn.hasLaunchedTheFirstStrike(true)

        if CONFIG.c.srbm.onFacility.strikePackage[CONFIG.c.srbm.onFacility.idxStrikePackage].name == 'RADAR' then
            CONFIG.c.srbm.onFacility.fn.hasLaunchedTheFirstStrike(false)
        end
    end


    -- CONFIG.c.srbm.onFacility.idxStrikePackage = CONFIG.c.srbm.onFacility.idxStrikePackage + 1
    -- local isStrikePackageOutofBounds = CONFIG.c.srbm.onFacility.idxStrikePackage >
    --     getCount(CONFIG.c.srbm.onFacility.strikePackage)

    -- if isStrikePackageOutofBounds then
    --     CONFIG.c.srbm.onFacility.idxStrikePackage = 1
    -- end

    CONFIG.c.srbm.onFacility.fn.increaseStrikePackageIdx()

    if CONFIG.c.srbm.onFacility.fn.isStrikePackageIdxOutofBounds() then
        CONFIG.c.srbm.onFacility.fn.resetStrikePackageIdx()
    end

    CONFIG.c.srbm.onFacility.strikeTimes = CONFIG.c.srbm.onFacility.strikeTimes + 1

    if CONFIG.c.srbm.onFacility.strikeTimes >= 10 then
        CONFIG.c.aircraft.onMobileUnit.isStrikeActivated = true
    end

    CONFIG.c.srbm.onFacility.isReloadActivated = true
end

if CONFIG.c.aircraft.onMobileUnit.isStrikeActivated and CONFIG.c.aircraft.onMobileUnit.maxStrikeTimes > 0 then
    local diffTime = 0

    if CONFIG.c.aircraft.onMobileUnit.lastStrikeTime ~= nil then
        diffTime = ScenEdit_CurrentTime() - CONFIG.c.aircraft.onMobileUnit.lastStrikeTime
    end

    local isToStrike = (CONFIG.c.aircraft.onMobileUnit.lastStrikeTime == nil
        or (CONFIG.c.aircraft.onMobileUnit.lastStrikeTime ~= nil and diffTime >= CONFIG.c.aircraft.onMobileUnit.const.periodOfStrike))

    for index, package in ipairs(CONFIG.c.aircraft.onMobileUnit.strikePackage) do
        if package.hasLaunched == false then
            local filteredContacts = filterContacts(contacts, function(value)
                if (value.typed == 8 or value.typed == 21)
                    and value:inArea(package.area) then
                    return true
                end

                return false
            end)

            if getCount(filteredContacts) >= 8 and isToStrike then
                -- local mission = ScenEdit_AddMission('China', package.missionName, 'strike', { type = 'land' })
                -- ScenEdit_SetDoctrine(
                --     { side = mission.side, mission = mission.name, escort = true },
                --     { emcon = { radar = 0 } }
                -- )
                -- ScenEdit_SetDoctrine(
                --     { side = mission.side, mission = mission.name, escort = false },
                --     { weapon_state_planned = 4011 }
                -- )
                for i, value in ipairs(filteredContacts) do
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

                -- local wildWeasels = assingUnitToStrikeMission(
                --     package.wildWeasel.baseGUID,
                --     package.wildWeasel.num,
                --     package.wildWeasel.weaponDBID,
                --     package.seadMissionName,
                --     false
                -- )
                local wildWeasels = assingUnitToStrikeMission(
                    package.wildWeasel.baseGUID,
                    package.wildWeasel.num,
                    package.wildWeasel.weaponDBID,
                    package.missionName,
                    true
                )
                package.wildWeasel.units = wildWeasels
                package.hasLaunched = true
                CONFIG.c.aircraft.onMobileUnit.lastStrikeTime = ScenEdit_CurrentTime()
                CONFIG.c.aircraft.onMobileUnit.maxStrikeTimes = CONFIG.c.aircraft.onMobileUnit.maxStrikeTimes - 1
                break
            end
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")



-- { FLOOD = 'No Flooding', FIRES = 'Major Fire', STRUCTURAL = 'Heavy damage' }
--print(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[4].targetList[2])
--print(ScenEdit_GetMission('China', 'STRIKE ON SHELTER 2').targetlist)
