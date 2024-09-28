function IsRunOutOfAmmunition(mounts, weaponDBID, magazines)
    local isRunOutOfAmmo = true

    if mounts == nil then
        return
    end

    for _, mount in ipairs(mounts) do
        local weaponCurrentNum = 0
        local wpnIndex = 1

        if weaponDBID ~= nil and type(weaponDBID) == "number" then
            for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                if wpn['wpn_dbid'] == weaponDBID then
                    wpnIndex = wpnIdx
                    break
                end
            end
        end

        weaponCurrentNum = mount['mount_weapons'][wpnIndex]['wpn_current']

        if weaponCurrentNum > 0 then
            isRunOutOfAmmo = false
            break
        end
    end

    if magazines == nil then
        return isRunOutOfAmmo
    end

    for _, magazine in ipairs(magazines) do
        local weaponCurrentNum = 0
        local wpnIndex = 1

        if weaponDBID ~= nil and type(weaponDBID) == "number" then
            for wpnIdx, wpn in ipairs(magazine['mag_weapons']) do
                if wpn['wpn_dbid'] == weaponDBID then
                    wpnIndex = wpnIdx
                    break
                end
            end
        end

        weaponCurrentNum = magazine['mag_weapons'][wpnIndex]['wpn_current']

        if weaponCurrentNum > 0 then
            isRunOutOfAmmo = false
            break
        end
    end

    return isRunOutOfAmmo
end

function Reload(battery, weaponDBID)
    local group = SE_GetUnit({ guid = battery.guid })
    if group == nil then return end

    for index, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit and unit.mounts then
            for mountIndex, mount in ipairs(unit.mounts) do
                local _weaponDBID = 0
                local weaponDefaultNum = 1
                local wpnIndex = 1

                if weaponDBID ~= nil and type(weaponDBID) == "number" then
                    for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                        if wpn['wpn_dbid'] == weaponDBID then
                            wpnIndex = wpnIdx
                            break
                        end
                    end
                end

                _weaponDBID = mount['mount_weapons'][wpnIndex]['wpn_dbid']

                if mount['mount_weapons'][wpnIndex]['wpn_default'] > weaponDefaultNum then
                    weaponDefaultNum = mount['mount_weapons'][wpnIndex]['wpn_default']
                end

                if battery.position.magazineWeapenNum >= weaponDefaultNum then
                    ScenEdit_AddReloadsToUnit({
                        guid = unit.guid,
                        wpn_dbid = _weaponDBID,
                        number = weaponDefaultNum
                    })
                    battery.position.magazineWeapenNum = battery.position.magazineWeapenNum -
                        weaponDefaultNum
                end
            end

            if unit.magazines then
                -- for magazineIndex, magazine in ipairs(unit.magazines) do
                --     local _weaponDBID = 0
                --     local weaponDefaultNum = 0
                --     local wpnIndex = 1

                --     if weaponDBID ~= nil and type(weaponDBID) == "number" then
                --         for magaWeaponIdx, magaWeapon in ipairs(magazine['mag_weapons']) do
                --             if magaWeapon['wpn_dbid'] == weaponDBID then
                --                 wpnIndex = magaWeaponIdx
                --             end
                --         end
                --     end

                --     _weaponDBID = magazine['mag_weapons'][wpnIndex]['wpn_dbid']
                --     weaponDefaultNum = magazine['mag_weapons'][wpnIndex]['wpn_default']
                --     ScenEdit_AddWeaponToUnitMagazine({
                --         guid = unit.guid,
                --         wpn_dbid = _weaponDBID,
                --         number = weaponDefaultNum
                --     })
                --     battery.position.magazineWeapenNum = battery.position.magazineWeapenNum -
                --         weaponDefaultNum
                -- end
            end
        end
    end
end

function SetReloadStartTime(battery, group)
    battery.state = CONFIG.const.batteryState.RESUPPLY
    battery.reloadStartTime = ScenEdit_CurrentTime()

    for _, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
        end
    end
end

function SetWCSToFree(battery, group)
    battery.state = CONFIG.const.batteryState.STATIC
    -- ScenEdit_MsgBox(battery.name .. ' enters into firing position', 1)

    for _, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u then
            ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
            ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 })
        end
    end
end

local function isGroupRunOutOfAmmunition(group, weaponDBID)
    local result = true

    for _, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit and IsRunOutOfAmmunition(unit.mounts, weaponDBID) == false then
            result = false
            break
        end
    end

    return result
end

local function toFringPosition(battery, group)
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
                -- manualSpeed = 30,
                -- course = battery.position.firingpositions[courseIdx].course,
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
                -- manualSpeed = 30,
                -- course = battery.position.assemblyArea.course,
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

    for _, battery in ipairs(batteries) do
        local group = SE_GetUnit({ guid = battery.guid })

        if group then
            if isRepositioningAutomatically then
                if battery.state == CONFIG.const.batteryState.STATIC then
                    if isGroupRunOutOfAmmunition(group, battery.weaponDBID) then toAssemblyArea(battery, group) end
                end

                if battery.state == CONFIG.const.batteryState.RESUPPLY then
                    if battery.reloadStartTime == nil then
                        battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c[platform].const.reloadTime
                    end

                    local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
                    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG.c[platform].const.reloadTime)
                        and group:inArea(battery.position.assemblyArea.area)
                        and isGroupRunOutOfAmmunition(group, battery.weaponDBID)

                    if isMoreThanReloadTime then
                        Reload(battery, battery.weaponDBID)
                    end

                    if not isGroupRunOutOfAmmunition(group, battery.weaponDBID) then toFringPosition(battery, group) end
                end
            else
                if battery.reloadStartTime == nil then
                    battery.reloadStartTime = ScenEdit_CurrentTime() + CONFIG[field][platform].const.reloadTime * 100
                    -- battery.reloadStartTime = nil
                end

                local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
                local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG[field][platform].const.reloadTime)
                    and group:inArea(battery.position.assemblyArea.area)
                    and isGroupRunOutOfAmmunition(group, battery.weaponDBID)

                if isMoreThanReloadTime then
                    Reload(battery, battery.weaponDBID)
                    if CONFIG.isDevMode then ScenEdit_MsgBox('Missile reload is finished', 1) end
                end
            end
        end
    end
end
