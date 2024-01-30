local contacts = ScenEdit_GetContacts('China')
local units = VP_GetSide({ Side = 'China' }).units
local LAND_STRIKE = gKH.State.LoadTableFromKey("LAND_STRIKE")
local STRIKE_ON_FACILITY = gKH.State.LoadTableFromKey("STRIKE_ON_FACILITY")
local STRIKE_ON_SAM = gKH.State.LoadTableFromKey("STRIKE_ON_SAM")
local MLRS_ON_MOBILE_TARGETS = gKH.State.LoadTableFromKey("MLRS_ON_MOBILE_TARGETS")

if contacts == nil then
    return
end

if LAND_STRIKE.IS_LAND_STRIKE_STARTED then
    for index, pack in ipairs(LAND_STRIKE.STRIKE_PACKAGE) do
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

if STRIKE_ON_FACILITY.IS_SRBM_RELOADING_ACTIVATED then
    reloadMissile(STRIKE_ON_FACILITY.SRBM_LAUNCHER_STATE, STRIKE_ON_FACILITY.SRBM_RELOADING_TIME)
end

if hasDestroyedOrRTB(STRIKE_ON_SAM.H6N_WITH_WZ8, 1) and hasDestroyedOrRTB(STRIKE_ON_SAM.RECON_WZ8, 1) then
    STRIKE_ON_SAM.H6N_WITH_WZ8 = launchUnits(STRIKE_ON_SAM.H6N_BASE_GUID, STRIKE_ON_SAM.H6N_COURSE, 1,
        STRIKE_ON_SAM.H6N_DBID, 'Aircraft')
end

if STRIKE_ON_SAM.IS_STRIKE_ON_SAM_ACTIVATED then
    local result = { batteryIndex = 1, groupIndex = 1 }

    for index, contact in ipairs(contacts) do
        if contact.emissions ~= nil then
            local emission = contact.emissions[1]['sensor_dbid']
            local isSAM = emission == STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_1
                or emission == STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_2
                or emission == STRIKE_ON_SAM.SKY_BOW_II_SENSOR_DBID_1
            -- or emission == PAC_3_SENSOR_DBID

            if isSAM and contact.lastDetections[1].age <= STRIKE_ON_SAM.CONTACT_AGE then
                result = attackContact(contact, 4, STRIKE_ON_SAM.SRBM_BATTERIES, result.batteryIndex, result.groupIndex)
            end
        end
    end
end

if MLRS_ON_MOBILE_TARGETS.IS_STRIKE_ACTIVATED then
    local result = { batteryIndex = 1, groupIndex = 1 }

    for index, package in ipairs(MLRS_ON_MOBILE_TARGETS.STRIKE_PACKAGE) do
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
                and filteredContact.lastDetections[1].age <= MLRS_ON_MOBILE_TARGETS.CONTACT_AGE then
                -- ScenEdit_MsgBox(tostring(filteredContact.lastDetections[1].age), 1)
                result = attackContact(
                    filteredContact,
                    4,
                    MLRS_ON_MOBILE_TARGETS.STRIKE_PACKAGE[index].batteries,
                    result.batteryIndex,
                    result.groupIndex,
                    MLRS_ON_MOBILE_TARGETS.WEAPON_DBID
                )
            end
        end
    end
end

if STRIKE_ON_FACILITY.IS_STRIKE_ON_FACILITY_ACTIVATED and contacts ~= nil then
    local result = { batteryIndex = 1, groupIndex = 1 }
    local targetListIdx = STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].index
    local diff = 0

    if STRIKE_ON_FACILITY.LAST_RECON_TIME ~= nil then
        diff = ScenEdit_CurrentTime() - STRIKE_ON_FACILITY.LAST_RECON_TIME
    end

    -- if diff > 0 then
    --     ScenEdit_MsgBox(
    --         STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].name ..
    --         ' Last recon: ' .. tostring(math.floor(diff / 60)) .. ' mins ago', 0)
    -- else
    --     ScenEdit_MsgBox(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].name, 0)
    -- end

    for index, value in ipairs(contacts) do
        local BDA = value.BDA
        local hasReconed = (BDA ~= nil and BDA['STRUCTURAL'] ~= 'Heavy damage')
            and (STRIKE_ON_FACILITY.LAST_RECON_TIME ~= nil and ScenEdit_CurrentTime() > STRIKE_ON_FACILITY.LAST_RECON_TIME)
            and diff <= STRIKE_ON_FACILITY.FACILITY_CONTACT_AGE
        local isTheFirstStrike = BDA == nil
            and STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE]
            .hasLaunchedTheFirstStrike == false

        for i, v in ipairs(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].targetList[targetListIdx]) do
            if v.guid == value.guid and (isTheFirstStrike or hasReconed) then
                result = attackContact(
                    value,
                    STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].num,
                    STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].batteries,
                    result.batteryIndex,
                    result.groupIndex
                )
            end
        end
    end
    -- for i, v in ipairs(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].targetList[targetListIdx]) do
    --     local contact = ScenEdit_GetContact({ side = 'China', guid = v.guid })

    --     if contact ~= nil then
    --         local BDA = contact.BDA
    --         local hasReconed = (BDA ~= nil and BDA['STRUCTURAL'] ~= 'Heavy damage')
    --             and (STRIKE_ON_FACILITY.LAST_RECON_TIME ~= nil and ScenEdit_CurrentTime() > STRIKE_ON_FACILITY.LAST_RECON_TIME)
    --             and diff <= STRIKE_ON_FACILITY.FACILITY_CONTACT_AGE
    --         local isTheFirstStrike = BDA == nil
    --             and STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].hasLaunchedTheFirstStrike == false

    --         if isTheFirstStrike or hasReconed then
    --             result = attackContact(
    --                 contact,
    --                 STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].num,
    --                 STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].batteries,
    --                 result.batteryIndex,
    --                 result.groupIndex
    --             )
    --         end
    --     end
    -- end

    -- if STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].name ~= 'RADAR' then
    --     STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].hasLaunchedTheFirstStrike = true
    -- end

    STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].index = STRIKE_ON_FACILITY
        .SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].index + 1

    if STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].index > getCount(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].targetList) then
        STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].index = getCount(
            STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE]
            .targetList)
        STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].hasLaunchedTheFirstStrike = true

        if STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].name == 'RADAR' then
            STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE].hasLaunchedTheFirstStrike = false
        end
    end

    STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE = STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE + 1

    if STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE > getCount(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE) then
        STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE = 1
    end

    STRIKE_ON_FACILITY.SRBM_STRIKE_TIMES = STRIKE_ON_FACILITY.SRBM_STRIKE_TIMES + 1

    if STRIKE_ON_FACILITY.SRBM_STRIKE_TIMES >= 10 then
        LAND_STRIKE.IS_LAND_STRIKE_STARTED = true
    end

    STRIKE_ON_FACILITY.IS_SRBM_RELOADING_ACTIVATED = true
end

if LAND_STRIKE.IS_LAND_STRIKE_STARTED and LAND_STRIKE.LAND_STRIKE_TIMES > 0 then
    local diffTime = 0

    if LAND_STRIKE.SRBM_STRIKE_TIMES ~= nil then
        diffTime = ScenEdit_CurrentTime() - LAND_STRIKE.SRBM_STRIKE_TIMES
    end

    local isToStrike = (LAND_STRIKE.SRBM_STRIKE_TIMES == nil
        or (LAND_STRIKE.SRBM_STRIKE_TIMES ~= nil and diffTime >= LAND_STRIKE.PERIOD_OF_LAND_STRIKE))

    for index, package in ipairs(LAND_STRIKE.STRIKE_PACKAGE) do
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
                LAND_STRIKE.SRBM_STRIKE_TIMES = ScenEdit_CurrentTime()
                LAND_STRIKE.LAND_STRIKE_TIMES = LAND_STRIKE.LAND_STRIKE_TIMES - 1
                break
            end
        end
    end
end

if LAND_STRIKE ~= nil
    and STRIKE_ON_FACILITY ~= nil
    and STRIKE_ON_SAM ~= nil
    and MLRS_ON_MOBILE_TARGETS ~= nil then
    gKH.State.SaveTableToKey(LAND_STRIKE, "LAND_STRIKE")
    gKH.State.SaveTableToKey(STRIKE_ON_SAM, "STRIKE_ON_SAM")
    gKH.State.SaveTableToKey(STRIKE_ON_FACILITY, "STRIKE_ON_FACILITY")
    gKH.State.SaveTableToKey(MLRS_ON_MOBILE_TARGETS, "MLRS_ON_MOBILE_TARGETS")
end



-- { FLOOD = 'No Flooding', FIRES = 'Major Fire', STRUCTURAL = 'Heavy damage' }
--print(STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE[4].targetList[2])
--print(ScenEdit_GetMission('China', 'STRIKE ON SHELTER 2').targetlist)
