-- function IsRunOutOfAmmunition(mounts, weaponDBID, magazines)
--     local isRunOutOfAmmo = true

--     if mounts == nil then
--         return
--     end

--     for _, mount in ipairs(mounts) do
--         local weaponCurrentNum = 0
--         local wpnIndex = 1

--         if weaponDBID ~= nil and type(weaponDBID) == "number" then
--             for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                 if wpn['wpn_dbid'] == weaponDBID then
--                     wpnIndex = wpnIdx
--                     break
--                 end
--             end
--         end

--         weaponCurrentNum = mount['mount_weapons'][wpnIndex]['wpn_current']

--         if weaponCurrentNum > 0 then
--             isRunOutOfAmmo = false
--             break
--         end
--     end

--     if magazines == nil then
--         return isRunOutOfAmmo
--     end

--     for _, magazine in ipairs(magazines) do
--         local weaponCurrentNum = 0
--         local wpnIndex = 1

--         if weaponDBID ~= nil and type(weaponDBID) == "number" then
--             for wpnIdx, wpn in ipairs(magazine['mag_weapons']) do
--                 if wpn['wpn_dbid'] == weaponDBID then
--                     wpnIndex = wpnIdx
--                     break
--                 end
--             end
--         end

--         weaponCurrentNum = magazine['mag_weapons'][wpnIndex]['wpn_current']

--         if weaponCurrentNum > 0 then
--             isRunOutOfAmmo = false
--             break
--         end
--     end

--     return isRunOutOfAmmo
-- end

-- function Reload(battery, weaponDBID)
--     local group = SE_GetUnit({ guid = battery.guid })
--     if group == nil then return end

--     for index, guid in ipairs(group.group.unitlist) do
--         local unit = SE_GetUnit({ guid = guid })

--         if unit and unit.mounts then
--             for _, mount in ipairs(unit.mounts) do
--                 local totalWpnCurrentNum = 0
--                 local totalWpnDefaultNum = 0
--                 local mountIndex = 1
--                 local wpnIndex = 1

--                 if weaponDBID ~= nil and type(weaponDBID) == "number" then
--                     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                         if wpn['wpn_dbid'] == weaponDBID then
--                             wpnIndex = wpnIdx
--                             mountIndex = _
--                             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                         end
--                     end
--                 end


--                 if weaponDBID == nil then
--                     weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
--                 end

--                 local requiredNum = totalWpnDefaultNum - totalWpnCurrentNum

--                 if battery.position.magazineWeapenNum >= requiredNum then
--                     ScenEdit_AddReloadsToUnit({
--                         guid = unit.guid,
--                         wpn_dbid = weaponDBID,
--                         number = requiredNum
--                     })
--                     battery.position.magazineWeapenNum = battery.position.magazineWeapenNum - requiredNum
--                 end
--             end
--         end
--     end
-- end
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
                end
            end
        end
    end

    ScenEdit_SpecialMessage('China', tostring(ammunitionSection.wpnCurrent))
    ScenEdit_SpecialMessage('Taiwan', tostring(ammunitionSection.wpnCurrent))
end

function SetReloadStartTime(battery, group, isRepositioningAutomatically)
    battery.state = CONFIG.const.batteryState.RESUPPLY
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
    local courseIdx = math.random(GetCount(battery.position.firingpositions))
    group.course = battery.position.firingpositions[courseIdx].course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.firingpositions[courseIdx].course,
                holdposition = false
            })
        end
    end
end

local function toAssemblyArea(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    group.course = battery.position.assemblyArea.course
    group.manualSpeed = 30

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit then
            ScenEdit_SetUnit({
                guid = unit.guid,
                manualthrottle = 'Flank',
                manualSpeed = 30,
                course = battery.position.assemblyArea.course,
                holdposition = false
            })
            ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
        end
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

                if battery.state == CONFIG.const.batteryState.RESUPPLY then
                    if battery.reloadStartTime == nil then
                        battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c['ground'][platform].const.reloadTime
                    end

                    local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
                    local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, isRepositioningAutomatically)
                    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= CONFIG.c['ground'][platform].const.reloadTime)
                        and result.isMet
                        and IsWpnNumLessThan(group, battery.wpnNumLessThan, battery.weaponDBID)

                    if isMoreThanReloadTime then
                        -- Reload(battery, battery.weaponDBID)
                        Reload(
                            battery,
                            CONFIG.c['ground'][platform].ammunitionSections[battery.ammunitionSection],
                            battery.weaponDBID
                        )
                    end

                    -- if not IsGroupRunOutOfAmmunition(group, battery.weaponDBID) then toFringPosition(battery, group) end
                end
            else
                if battery.reloadStartTime == nil then
                    battery.reloadStartTime = ScenEdit_CurrentTime() +
                        CONFIG[field]['ground'][platform].const.reloadTime * 100
                    -- battery.reloadStartTime = nil
                end

                local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
                local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, isRepositioningAutomatically)
                local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG[field]['ground'][platform].const.reloadTime)
                    and result.isMet
                    and IsWpnNumLessThan(group, battery.wpnNumLessThan, battery.weaponDBID)

                if isMoreThanReloadTime then
                    -- Reload(battery, battery.weaponDBID)
                    Reload(
                        battery,
                        CONFIG[field]['ground'][platform].ammunitionSections[battery.ammunitionSection],
                        battery.weaponDBID
                    )
                    if CONFIG.isDevMode then ScenEdit_MsgBox('Missile reload is finished', 1) end
                end
            end
        end
    end
end

function IsMetWithAmmoTrucks(CONFIG, unit, side, platform, isRepositioningAutomatically)
    local key = 't'

    if side == 'China' then
        key = 'c'
    end
    local group = SE_GetUnit({ guid = unit.group.guid })

    if group then
        for _, battery in pairs(CONFIG[key].ground[platform].batteries) do
            local isTrue = true

            if isRepositioningAutomatically then
                isTrue = battery.state == CONFIG.const.batteryState.REPOSITIONING
            end

            if battery.guid == group.guid and isTrue then
                local ammoTrucks = SE_GetUnit({ guid = battery.ammunitionSection })

                for _, p in pairs(CONFIG[key].ground[platform].const.position) do
                    local isMetWithAmmoTrucks = unit:inArea(p.assemblyArea.area)
                        and (ammoTrucks and ammoTrucks:inArea(p.assemblyArea.area))
                    if isMetWithAmmoTrucks then
                        return { isMet = true, battery = battery }
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
    local ammoSec = CONFIG[field].ground[platform].ammunitionSections[unit.group.guid]

    if ammoSec and ammoSec.wpnCurrent > 0 then
        if (ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitNum) < 0 then
            ammoSec.wpnCurrent = 0
        else
            ammoSec.wpnCurrent = ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitNum
        end
    end
end
