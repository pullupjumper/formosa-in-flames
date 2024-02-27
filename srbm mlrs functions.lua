function setReloadStartTime(battery, group)
    battery.state = CONFIG.const.batteryState.RESUPPLY
    battery.reloadStartTime = ScenEdit_CurrentTime()

    for index, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
        end
    end
end

function setWCSToFree(battery, group)
    battery.state = CONFIG.const.batteryState.STATIC
    -- ScenEdit_MsgBox(battery.name .. ' enters into firing position', 1)

    for index, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
            ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 })
        end
    end
end

function isRunOutOfAmmon(group, weaponDBID)
    local result = true

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit and isRunOutOfAmmunition(unit.mounts, weaponDBID) == false then
            result = false
            break
        end
    end

    return result
end

function toFringPosition(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    local courseIdx = math.random(getCount(battery.position.firingpositions))

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.firingpositions[courseIdx].course
            })
        end
    end
end

function toAssemblyArea(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.assemblyArea.course
            })
            ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
        end
    end
end

function checkBatteryState(CONFIG, platform, batteries)
    for _, battery in ipairs(batteries) do
        local group = SE_GetUnit({ guid = battery.guid })

        if group then
            if battery.state == CONFIG.const.batteryState.STATIC then
                if isRunOutOfAmmon(group, battery.weaponDBID) then toAssemblyArea(battery, group) end
            end

            if battery.state == CONFIG.const.batteryState.RESUPPLY then
                if battery.reloadStartTime == nil then
                    battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c[platform].const.reloadTime
                end

                local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
                local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG.c[platform].const.reloadTime)
                    and group:inArea(battery.position.assemblyArea.area)
                    and isRunOutOfAmmon(group, battery.weaponDBID)

                if isMoreThanReloadTime then
                    resupply(battery, battery.weaponDBID)
                    if CONFIG.isDevMode then ScenEdit_MsgBox('After resupply', 1) end
                end

                if not isRunOutOfAmmon(group, battery.weaponDBID) then toFringPosition(battery, group) end
            end
        end
    end
end
