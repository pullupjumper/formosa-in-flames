function Reload(battery, ammunitionSection, weaponDBID)
    local group = SE_GetUnit({ guid = battery.guid })
    if group == nil then return end

    for index, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit and unit.mounts then
            for _, mount in ipairs(unit.mounts) do
                local totalWpnCurrentNum = 0
                local totalWpnDefaultNum = 0
                local mountIndex = 1
                local wpnIndex = 1

                if weaponDBID ~= nil and type(weaponDBID) == "number" then
                    for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                        if wpn['wpn_dbid'] == weaponDBID then
                            wpnIndex = wpnIdx
                            mountIndex = _
                            totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                            totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                        end
                    end
                end

                if weaponDBID == nil then
                    weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
                end

                local requiredNum = totalWpnDefaultNum - totalWpnCurrentNum

                if ammunitionSection.wpnCurrent >= requiredNum then
                    ScenEdit_AddReloadsToUnit({
                        guid = unit.guid,
                        wpn_dbid = weaponDBID,
                        number = requiredNum
                    })
                    ammunitionSection.wpnCurrent = ammunitionSection.wpnCurrent - requiredNum
                elseif ammunitionSection.wpnCurrent > 0 and ammunitionSection.wpnCurrent < requiredNum then
                    ScenEdit_AddReloadsToUnit({
                        guid = unit.guid,
                        wpn_dbid = weaponDBID,
                        number = ammunitionSection.wpnCurrent
                    })
                    ammunitionSection.wpnCurrent = 0
                end
            end
        end
    end

    if CONFIG.isDevMode then
        ScenEdit_SpecialMessage('China',
            'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
        ScenEdit_SpecialMessage('Taiwan',
            'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
    end
end

function SetReloadStartTime(battery, group, isRepositioningAutomatically)
    battery.state = CONFIG.const.batteryState.RELOAD
    battery.reloadStartTime = ScenEdit_CurrentTime()

    for _, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u and isRepositioningAutomatically then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
        end
    end
end

function SetWCSToFree(battery, group)
    battery.state = CONFIG.const.batteryState.STATIC

    for _, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
            ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 })
        end
    end
end

function SetStateToHIDE(battery, group)
    battery.state = CONFIG.const.batteryState.HIDE

    for _, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
            ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 2 })
        end
    end
end

function IsWpnNumLessThan(group, percentage, weaponDBID)
    local totalWpnCurrentNum = 0
    local totalWpnDefaultNum = 0

    if group.group == nil then
        local unit = SE_GetUnit({ guid = group.guid })

        if unit then
            for _, mount in ipairs(unit.mounts) do
                if weaponDBID ~= nil and type(weaponDBID) == "number" then
                    for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                        if wpn['wpn_dbid'] == weaponDBID then
                            totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                            totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                        end
                    end
                end
            end
        end
    else
        for _, guid in ipairs(group.group.unitlist) do
            local unit = SE_GetUnit({ guid = guid })

            if unit then
                for _, mount in ipairs(unit.mounts) do
                    if weaponDBID ~= nil and type(weaponDBID) == "number" then
                        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                            if wpn['wpn_dbid'] == weaponDBID then
                                totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                                totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                            end
                        end
                    end
                end
            end
        end
    end

    if totalWpnCurrentNum / totalWpnDefaultNum * 100 <= percentage then
        return true
    end

    return false
end

function ToFringPosition(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    local courseIdx = math.random(GetCount(battery.position.FP))
    group.course = battery.position.FP[courseIdx].course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.FP[courseIdx].course,
                holdposition = false
            })
        end
    end
end

local function toAssemblyArea(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    group.course = battery.position.RL.course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.RL.course,
                holdposition = false
            })
            ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
        end
    end
end

local function toHA(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    group.course = battery.position.HA.course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.HA.course,
                holdposition = false
            })
            ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
        end
    end
end

local function toAHA(section, group)
    section.state = CONFIG.const.batteryState.REPOSITIONING
    group.course = section.position.AHA.course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = section.position.AHA.course,
                holdposition = false
            })
        end
    end

    if CONFIG.isDevMode then
        ScenEdit_SpecialMessage('China', 'func/toAHA/' .. tostring(section.name))
    end
end

local function transload(section, ammunition)
    if ammunition.wpnCurrent > 0 and section.wpnCurrent < section.wpnDefault then
        if ammunition.wpnCurrent >= section.wpnDefault then
            section.wpnCurrent = section.wpnCurrent + section.wpnDefault
            ammunition.wpnCurrent = ammunition.wpnCurrent - section.wpnDefault
        else
            section.wpnCurrent = section.wpnCurrent + ammunition.wpnCurrent
            ammunition.wpnCurrent = 0
        end
    end

    if CONFIG.isDevMode then
        ScenEdit_SpecialMessage('China', 'func/transload/Remaining ammunition/' .. tostring(ammunition.wpnCurrent))
    end
end

local function ammoSecToRL(section, group)
    section.state = CONFIG.const.batteryState.REPOSITIONING
    group.course = { section.position.RL.course[GetCount(section.position.RL.course)] }
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = { section.position.RL.course[GetCount(section.position.RL.course)] },
                holdposition = false
            })
        end
    end

    if CONFIG.isDevMode then
        ScenEdit_SpecialMessage('China', 'func/ammoSecToRL/' .. section.name)
    end
end

function CheckBatteryState(CONFIG, platform, batteries, side, isRepositioningAutomatically)
    local field = 't'

    if side == 'China' then
        field = 'c'
    end

    for _, battery in pairs(batteries) do
        local group = SE_GetUnit({ guid = battery.guid })

        if group then
            if isRepositioningAutomatically then
                if battery.state == CONFIG.const.batteryState.STATIC then
                    if IsWpnNumLessThan(group, battery.wpnNumLessThan, battery.weaponDBID) then
                        toAssemblyArea(battery, group)
                    end
                end

                if battery.state == CONFIG.const.batteryState.RELOAD then
                    if battery.reloadStartTime == nil then
                        battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c['ground'][platform].const.reloadTime
                    end

                    local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
                    local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, false)
                    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= CONFIG.c['ground'][platform].const.reloadTime)
                        and result.isMet
                        and IsWpnNumLessThan(group, battery.wpnNumLessThan, battery.weaponDBID)

                    if CONFIG.isDevMode then
                        ScenEdit_SpecialMessage('China',
                            'func/CheckBatteryState' ..
                            '/name:' .. battery.name ..
                            '/elapsedTime:' .. tostring(elapsedTime) ..
                            '/isMet:' .. tostring(result.isMet) ..
                            '/isMoreThanReloadTime:' .. tostring(isMoreThanReloadTime))
                    end

                    if isMoreThanReloadTime then
                        Reload(
                            battery,
                            CONFIG.c['ground'][platform].ammunitionSections[battery.ammunitionSection],
                            battery.weaponDBID
                        )
                        toHA(battery, group)
                    end
                end
            else
                if battery.reloadStartTime == nil then
                    battery.reloadStartTime = ScenEdit_CurrentTime() +
                        CONFIG[field]['ground'][platform].const.reloadTime * 100
                end

                local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
                local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, isRepositioningAutomatically)
                local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG[field]['ground'][platform].const.reloadTime)
                    and result.isMet
                    and IsWpnNumLessThan(group, battery.wpnNumLessThan, battery.weaponDBID)
                -- ScenEdit_SpecialMessage('Taiwan', battery.name)
                -- ScenEdit_SpecialMessage('Taiwan', tostring(diff))
                -- ScenEdit_SpecialMessage('Taiwan', tostring(result.isMet))
                -- ScenEdit_SpecialMessage('Taiwan', tostring(isMoreThanReloadTime))
                if isMoreThanReloadTime then
                    -- Reload(battery, battery.weaponDBID)
                    Reload(
                        battery,
                        CONFIG[field]['ground'][platform].ammunitionSections[battery.ammunitionSection],
                        battery.weaponDBID
                    )
                    if CONFIG.isDevMode then ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1) end
                end
            end
        end
    end

    for _, section in pairs(CONFIG[field]['ground'][platform].ammunitionSections) do
        local group = SE_GetUnit({ guid = section.guid })

        if group then
            if isRepositioningAutomatically then
                if section.state == CONFIG.const.batteryState.STATIC then
                    if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
                        toAHA(section, group)
                    end
                end

                if section.state == CONFIG.const.batteryState.RELOAD then
                    local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
                    local result = IsMetWithAmmo(CONFIG, group, side, platform, false)
                    local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= CONFIG[field]['ground'][platform].const.reloadTime)
                        and section.wpnCurrent == 0
                        and result.isMet
                    if isMoreThanReloadTime then
                        transload(section, CONFIG[field]['ground'][platform].ammunitions[section.ammunition])
                        ammoSecToRL(section, group)
                        if CONFIG.isDevMode then ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1) end
                    end
                end
            else
                if section.reloadStartTime == nil then
                    section.reloadStartTime = ScenEdit_CurrentTime() +
                        CONFIG[field]['ground'][platform].const.reloadTime * 100
                end

                local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
                local result = IsMetWithAmmo(CONFIG, group, side, platform, false)
                local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= CONFIG[field]['ground'][platform].const.reloadTime)
                    and section.wpnCurrent == 0
                    and result.isMet
                if isMoreThanReloadTime then
                    transload(section, CONFIG[field]['ground'][platform].ammunitions[section.ammunition])
                    if CONFIG.isDevMode then ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1) end
                end
            end
        end
    end
end

-- function IsMetWithAmmoTrucks(CONFIG, unit, side, platform, isRepositioningAutomatically)
--     local key = 't'

--     if side == 'China' then
--         key = 'c'
--     end
--     -- local group = SE_GetUnit({ guid = unit.group.guid })

--     if unit.group then
--         local group = SE_GetUnit({ guid = unit.group.guid })

--         if group then
--             for _, battery in pairs(CONFIG[key].ground[platform].batteries) do
--                 local isTrue = true

--                 if isRepositioningAutomatically then
--                     isTrue = battery.state == CONFIG.const.batteryState.REPOSITIONING
--                 end

--                 if battery.guid == group.guid and isTrue then
--                     local ammoTrucks = SE_GetUnit({ guid = battery.ammunitionSection })

--                     for _, p in pairs(CONFIG[key].ground[platform].const.position) do
--                         local isMetWithAmmoTrucks = unit:inArea(p.RL.area)
--                             and (ammoTrucks and ammoTrucks:inArea(p.RL.area))
--                         if isMetWithAmmoTrucks then
--                             return { isMet = true, battery = battery }
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     return { isMet = false, battery = nil }
-- end
function IsMetWithAmmoTrucks(CONFIG, unit, side, platform, isRepositioningAutomatically)
    local key = 't'

    if side == 'China' then
        key = 'c'
    end

    if unit.group then
        local group = SE_GetUnit({ guid = unit.group.guid })

        if group then
            local field1 = 'batteries'
            local field3 = 'ammunitionSections'

            if string.find(group.name, 'Ammo') ~= nil or string.find(group.name, 'SUPP') ~= nil then
                field1 = 'ammunitionSections'
                field3 = 'batteries'
            end

            for _, battery in pairs(CONFIG[key].ground[platform][field1]) do
                local isTrue = true

                if isRepositioningAutomatically then
                    isTrue = battery.state == CONFIG.const.batteryState.REPOSITIONING
                end

                if battery.guid == group.guid and isTrue then
                    local area = nil

                    for _, p in pairs(CONFIG[key].ground[platform].const.position) do
                        if unit:inArea(p.RL.area) then
                            area = p.RL.area
                            break
                        end
                    end

                    for _, section in pairs(CONFIG[key].ground[platform][field3]) do
                        local ammoSec = SE_GetUnit({ guid = section.guid })

                        if ammoSec and area and ammoSec:inArea(area) then
                            return { isMet = true, battery = battery }
                        end
                    end
                end
            end
        end
    end

    return { isMet = false, battery = nil }
end

function IsMetWithAmmo(CONFIG, unit, side, platform, isRepositioningAutomatically)
    local key = 't'

    if side == 'China' then
        key = 'c'
    end

    if unit.group then
        local group = SE_GetUnit({ guid = unit.group.guid })

        if group then
            for _, section in pairs(CONFIG[key].ground[platform].ammunitionSections) do
                local isTrue = true

                if isRepositioningAutomatically then
                    isTrue = section.state == CONFIG.const.batteryState.REPOSITIONING
                end

                if section.guid == group.guid and isTrue then
                    local ammo = SE_GetUnit({ guid = section.ammunition })

                    for _, p in pairs(CONFIG[key].ground[platform].const.position) do
                        local isMetWithAmmo = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))

                        if isMetWithAmmo then
                            return { isMet = true, battery = section }
                        end
                    end
                end
            end
        end
    end

    return { isMet = false, battery = nil }
end

function DestroyAmmoSecHandler(unit, side, platform)
    local field = 't'
    if side == 'China' then field = 'c' end

    if unit.group == nil then
        return
    end

    local ammoSec = CONFIG[field].ground[platform].ammunitionSections[unit.group.guid]

    if ammoSec and ammoSec.wpnCurrent > 0 then
        if (ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitNum) < 0 then
            ammoSec.wpnCurrent = 0
        else
            ammoSec.wpnCurrent = ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitNum
        end
    end
end
