function Reload(battery, ammunitionSection, weaponDBID)
    local group = SE_GetUnit({ guid = battery.guid })
    if group == nil then return end

    for index, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit == nil or unit.mounts == nil then goto continue end

        for _, mount in ipairs(unit.mounts) do
            local totalWpnCurrentNum = 0
            local totalWpnDefaultNum = 0
            -- local mountIndex = 1
            -- local wpnIndex = 1

            for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                if wpn['wpn_dbid'] == weaponDBID then
                    -- wpnIndex = wpnIdx
                    -- mountIndex = _
                    totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                    totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                end
            end

            -- if weaponDBID ~= nil and type(weaponDBID) == "number" then
            --     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
            --         if wpn['wpn_dbid'] == weaponDBID then
            --             wpnIndex = wpnIdx
            --             mountIndex = _
            --             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
            --             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
            --         end
            --     end
            -- end

            -- if weaponDBID == nil then
            --     weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
            -- end

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

        ::continue::
    end

    battery.reloadStartTime = nil

    if CONFIG.isDevMode then
        printBox('China', 'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
        printBox('Taiwan', 'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
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

-- function IsLowAmmo(group, percentage, weaponDBID)
--     local totalWpnCurrentNum = 0
--     local totalWpnDefaultNum = 0

--     if group.group == nil then
--         local unit = SE_GetUnit({ guid = group.guid })

--         if unit then
--             for _, mount in ipairs(unit.mounts) do
--                 -- if weaponDBID ~= nil and type(weaponDBID) == "number" then
--                 --     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                 --         if wpn['wpn_dbid'] == weaponDBID then
--                 --             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                 --             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                 --         end
--                 --     end
--                 -- end
--                 for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                     if wpn['wpn_dbid'] == weaponDBID then
--                         totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                         totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                     end
--                 end
--             end
--         end
--     else
--         for _, guid in ipairs(group.group.unitlist) do
--             local unit = SE_GetUnit({ guid = guid })

--             if unit then
--                 for _, mount in ipairs(unit.mounts) do
--                     -- if weaponDBID ~= nil and type(weaponDBID) == "number" then
--                     --     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                     --         if wpn['wpn_dbid'] == weaponDBID then
--                     --             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                     --             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                     --         end
--                     --     end
--                     -- end
--                     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                         if wpn['wpn_dbid'] == weaponDBID then
--                             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     if totalWpnCurrentNum / totalWpnDefaultNum * 100 <= percentage then
--         return true
--     end

--     return false
-- end

function IsLowAmmo(group, percentage, weaponDBID)
    -- Calculate total weapon counts for a specific weapon type
    -- Returns true if the percentage of current weapons is <= the threshold percentage

    local totalWpnCurrentNum = 0
    local totalWpnDefaultNum = 0

    -- Helper function to process a single unit
    local function processUnit(unit)
        if not unit then return end

        -- Iterate through all mounts on the unit
        for _, mount in ipairs(unit.mounts) do
            -- Check all weapons in the mount
            for _, weapon in ipairs(mount.mount_weapons) do
                -- Only count weapons matching the specified weapon ID
                if weapon.wpn_dbid == weaponDBID then
                    totalWpnCurrentNum = totalWpnCurrentNum + weapon.wpn_current
                    totalWpnDefaultNum = totalWpnDefaultNum + weapon.wpn_maxcap
                end
            end
        end
    end

    -- Process either a single unit or a group of units
    if group.group == nil then
        -- Single unit case
        local unit = SE_GetUnit({ guid = group.guid })
        processUnit(unit)
    else
        -- Group of units case
        for _, guid in ipairs(group.group.unitlist) do
            local unit = SE_GetUnit({ guid = guid })
            processUnit(unit)
        end
    end

    local currentPercentage = (totalWpnCurrentNum / totalWpnDefaultNum) * 100
    return currentPercentage <= percentage
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

local function toRL(battery, group)
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
        printBox('China', 'func/toAHA/' .. tostring(section.name))
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

    section.reloadStartTime = nil

    if CONFIG.isDevMode then
        printBox('China', 'func/transload/Remaining ammunition/' .. tostring(ammunition.wpnCurrent))
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
        printBox('China', 'func/ammoSecToRL/' .. section.name)
    end
end

-- function CheckBatteryState(CONFIG, platform, batteries, side, isRepositioningAutomatically)
--     local field = 't'

--     if side == 'China' then
--         field = 'c'
--     end

--     for _, battery in pairs(batteries) do
--         local group = SE_GetUnit({ guid = battery.guid })

--         if group then
--             if isRepositioningAutomatically then
--                 if battery.state == CONFIG.const.batteryState.STATIC then
--                     if IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
--                         toAssemblyArea(battery, group)
--                     end
--                 end

--                 if battery.state == CONFIG.const.batteryState.RELOAD then
--                     if battery.reloadStartTime == nil then
--                         battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c['ground'][platform].const.reloadTime
--                     end

--                     local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
--                     local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, false)
--                     local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= CONFIG.c['ground'][platform].const.reloadTime)
--                         and result.isMet
--                         and IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID)

--                     if CONFIG.isDevMode then
--                         printBox({
--                             'func/CheckBatteryState',
--                             'name:' .. battery.name,
--                             'elapsedTime:' .. tostring(elapsedTime),
--                             'isMet:' .. tostring(result.isMet),
--                             'isMoreThanReloadTime:' .. tostring(isMoreThanReloadTime)
--                         }, 'China')
--                     end

--                     if isMoreThanReloadTime then
--                         Reload(
--                             battery,
--                             CONFIG.c['ground'][platform].ammunitionSections[battery.ammunitionSection],
--                             battery.weaponDBID
--                         )
--                         toHA(battery, group)
--                     end
--                 end
--             else
--                 if battery.reloadStartTime == nil then
--                     battery.reloadStartTime = ScenEdit_CurrentTime() +
--                         CONFIG[field]['ground'][platform].const.reloadTime * 100
--                 end

--                 local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
--                 local result = IsMetWithAmmoTrucks(CONFIG, group, side, platform, isRepositioningAutomatically)
--                 local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and elapsedTime >= CONFIG[field]['ground'][platform].const.reloadTime)
--                     and result.isMet
--                     and IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID)
--                 if isMoreThanReloadTime then
--                     Reload(
--                         battery,
--                         CONFIG[field]['ground'][platform].ammunitionSections[battery.ammunitionSection],
--                         battery.weaponDBID
--                     )
--                     if CONFIG.isDevMode then ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1) end
--                 end
--             end
--         end
--     end

--     for _, section in pairs(CONFIG[field]['ground'][platform].ammunitionSections) do
--         local group = SE_GetUnit({ guid = section.guid })

--         if group then
--             if isRepositioningAutomatically then
--                 if section.state == CONFIG.const.batteryState.STATIC then
--                     if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
--                         toAHA(section, group)
--                     end
--                 end

--                 if section.state == CONFIG.const.batteryState.RELOAD then
--                     local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
--                     local result = IsMetWithAmmo(CONFIG, group, side, platform, false)
--                     local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= CONFIG[field]['ground'][platform].const.reloadTime)
--                         and section.wpnCurrent == 0
--                         and result.isMet
--                     if isMoreThanReloadTime then
--                         transload(section, CONFIG[field]['ground'][platform].ammunitions[section.ammunition])
--                         ammoSecToRL(section, group)
--                         if CONFIG.isDevMode then ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1) end
--                     end
--                 end
--             else
--                 if section.reloadStartTime == nil then
--                     section.reloadStartTime = ScenEdit_CurrentTime() +
--                         CONFIG[field]['ground'][platform].const.reloadTime * 100
--                 end

--                 local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
--                 local result = IsMetWithAmmo(CONFIG, group, side, platform, false)
--                 local isMoreThanReloadTime = (section.reloadStartTime ~= nil and elapsedTime >= CONFIG[field]['ground'][platform].const.reloadTime)
--                     and section.wpnCurrent == 0
--                     and result.isMet
--                 if isMoreThanReloadTime then
--                     transload(section, CONFIG[field]['ground'][platform].ammunitions[section.ammunition])
--                     if CONFIG.isDevMode then ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1) end
--                 end
--             end
--         end
--     end
-- end

function CheckBatteryState(CONFIG, platform, side, isRepositioningAutomatically)
    -- Determine which configuration field to use based on side
    local field = (side == 'China') and 'c' or 't'
    local platformConfig = CONFIG[field]['ground'][platform]

    -- Process all batteries
    ProcessBatteries(CONFIG, platformConfig, platform, isRepositioningAutomatically)

    -- Process all ammunition sections
    ProcessAmmunitionSections(CONFIG, platformConfig, platform, isRepositioningAutomatically)
end

-- Process all batteries' states and actions
function ProcessBatteries(CONFIG, platformConfig, platform, isRepositioningAutomatically)
    for _, battery in pairs(platformConfig.batteries) do
        local group = SE_GetUnit({ guid = battery.guid })
        if not group then goto continue end

        if isRepositioningAutomatically then
            HandleAutomaticBatteryRepositioning(CONFIG, platformConfig, platform, battery, group,
                isRepositioningAutomatically)
        else
            HandleManualBatteryReload(CONFIG, platformConfig, platform, battery, group, isRepositioningAutomatically)
        end

        ::continue::
    end
end

-- Handle automatic battery repositioning logic
function HandleAutomaticBatteryRepositioning(CONFIG, platformConfig, platform, battery, group,
                                             isRepositioningAutomatically)
    -- Handle STATIC state batteries
    if battery.state == CONFIG.const.batteryState.STATIC then
        if IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
            toRL(battery, group)
        end
    end

    -- Handle RELOAD state batteries
    if battery.state == CONFIG.const.batteryState.RELOAD then
        -- Initialize reload start time if needed
        if battery.reloadStartTime == nil then
            battery.reloadStartTime = ScenEdit_CurrentTime() - platformConfig.const.reloadTime
        end

        -- Check if reload conditions are met
        local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
        local result = IsMetWithAmmoTrucks(CONFIG, group, platform, isRepositioningAutomatically)
        local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and
            elapsedTime >= platformConfig.const.reloadTime and
            result.isMet and
            IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

        -- Log debug information if dev mode is enabled
        LogBatteryDebugInfo(CONFIG, battery, elapsedTime, result, isMoreThanReloadTime)

        -- Perform reload if conditions are met
        if isMoreThanReloadTime then
            Reload(battery, platformConfig.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
            toHA(battery, group)
        end
    end
end

-- Handle manual battery reload logic
function HandleManualBatteryReload(CONFIG, platformConfig, platform, battery, group, isRepositioningAutomatically)
    -- Initialize reload start time if needed
    if battery.reloadStartTime == nil then
        battery.reloadStartTime = ScenEdit_CurrentTime() + platformConfig.const.reloadTime * 100
    end

    -- Check if reload conditions are met
    local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
    local result = IsMetWithAmmoTrucks(CONFIG, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and
        elapsedTime >= platformConfig.const.reloadTime and
        result.isMet and
        IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

    -- Perform reload if conditions are met
    if isMoreThanReloadTime then
        Reload(battery, platformConfig.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)

        if CONFIG.isDevMode then
            ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1)
        end
    end
end

-- Log debug information for battery operations
function LogBatteryDebugInfo(CONFIG, battery, elapsedTime, result, isMoreThanReloadTime)
    if CONFIG.isDevMode then
        printBox(
            'China',
            'func/CheckBatteryState',
            'name:' .. battery.name,
            'elapsedTime:' .. tostring(elapsedTime),
            'isMet:' .. tostring(result.isMet),
            'isMoreThanReloadTime:' .. tostring(isMoreThanReloadTime)
        )
    end
end

-- Process all ammunition sections' states and actions
function ProcessAmmunitionSections(CONFIG, platformConfig, platform, isRepositioningAutomatically)
    for _, section in pairs(platformConfig.ammunitionSections) do
        local group = SE_GetUnit({ guid = section.guid })
        if not group then goto continue end

        if isRepositioningAutomatically then
            HandleAutomaticSectionRepositioning(CONFIG, platformConfig, platform, section, group,
                isRepositioningAutomatically)
        else
            HandleManualSectionReload(CONFIG, platformConfig, platform, section, group, isRepositioningAutomatically)
        end

        ::continue::
    end
end

-- Handle automatic ammunition section repositioning logic
function HandleAutomaticSectionRepositioning(CONFIG, platformConfig, platform, section, group,
                                             isRepositioningAutomatically)
    -- Handle STATIC state sections
    if section.state == CONFIG.const.batteryState.STATIC then
        if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
            toAHA(section, group)
        end
    end

    -- Handle RELOAD state sections
    if section.state == CONFIG.const.batteryState.RELOAD then
        local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
        local result = IsMetWithAmmo(CONFIG, group, platform, isRepositioningAutomatically)
        local isMoreThanReloadTime = (section.reloadStartTime ~= nil and
            elapsedTime >= platformConfig.const.reloadTime and
            section.wpnCurrent == 0 and
            result.isMet)

        if isMoreThanReloadTime then
            transload(section, platformConfig.ammunitions[section.ammunition])
            ammoSecToRL(section, group)

            if CONFIG.isDevMode then
                ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
            end
        end
    end
end

-- Handle manual ammunition section reload logic
function HandleManualSectionReload(CONFIG, platformConfig, platform, section, group, isRepositioningAutomatically)
    -- Initialize reload start time if needed
    if section.reloadStartTime == nil then
        section.reloadStartTime = ScenEdit_CurrentTime() + platformConfig.const.reloadTime * 100
    end

    -- Check if reload conditions are met
    local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
    local result = IsMetWithAmmo(CONFIG, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (section.reloadStartTime ~= nil and
        elapsedTime >= platformConfig.const.reloadTime and
        section.wpnCurrent == 0 and
        result.isMet)

    -- Perform reload if conditions are met
    if isMoreThanReloadTime then
        transload(section, platformConfig.ammunitions[section.ammunition])

        if CONFIG.isDevMode then
            ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
        end
    end
end

-- function IsMetWithAmmoTrucks(CONFIG, unit, platform, isRepositioningAutomatically)
--     local side = unit.side
--     local key = 't'

--     if side == 'China' then
--         key = 'c'
--     end

--     if unit.group then
--         local group = SE_GetUnit({ guid = unit.group.guid })

--         if group then
--             local field1 = 'batteries'
--             local field3 = 'ammunitionSections'

--             if string.find(group.name, 'Ammo') ~= nil or string.find(group.name, 'SUPP') ~= nil then
--                 field1 = 'ammunitionSections'
--                 field3 = 'batteries'
--             end

--             for _, battery in pairs(CONFIG[key].ground[platform][field1]) do
--                 local isTrue = true

--                 if isRepositioningAutomatically then
--                     isTrue = battery.state == CONFIG.const.batteryState.REPOSITIONING or
--                         battery.state == CONFIG.const.batteryState.RELOAD
--                 end

--                 if battery.guid == group.guid and isTrue then
--                     local area = nil

--                     for _, p in pairs(CONFIG[key].ground[platform].const.position) do
--                         if unit:inArea(p.RL.area) then
--                             area = p.RL.area
--                             break
--                         end
--                     end

--                     for _, section in pairs(CONFIG[key].ground[platform][field3]) do
--                         local ammoSec = SE_GetUnit({ guid = section.guid })

--                         if ammoSec and area and ammoSec:inArea(area) then
--                             return { isMet = true, battery = battery }
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     return { isMet = false, battery = nil }
-- end

-- function IsMetWithAmmo(CONFIG, unit, platform, isRepositioningAutomatically)
--     local side = unit.side
--     local key = 't'

--     if side == 'China' then
--         key = 'c'
--     end

--     if unit.group then
--         local group = SE_GetUnit({ guid = unit.group.guid })

--         if group then
--             for _, section in pairs(CONFIG[key].ground[platform].ammunitionSections) do
--                 local isTrue = true

--                 if isRepositioningAutomatically then
--                     isTrue = section.state == CONFIG.const.batteryState.REPOSITIONING or
--                         section.state == CONFIG.const.batteryState.RELOAD
--                 end

--                 if section.guid == group.guid and isTrue then
--                     local ammo = SE_GetUnit({ guid = section.ammunition })

--                     for _, p in pairs(CONFIG[key].ground[platform].const.position) do
--                         local isMetWithAmmo = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))

--                         if isMetWithAmmo then
--                             return { isMet = true, battery = section }
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     return { isMet = false, battery = nil }
-- end

-- Check if a unit has met with ammo trucks
function IsMetWithAmmoTrucks(CONFIG, unit, platform, isRepositioningAutomatically)
    -- Get unit's side and corresponding config key
    local side = unit.side
    local key = (side == 'China') and 'c' or 't'

    -- If unit has no group, return not met
    if not unit.group then
        return { isMet = false, battery = nil }
    end

    -- Get the unit's group
    local group = SE_GetUnit({ guid = unit.group.guid })
    if not group then return { isMet = false, battery = nil } end

    -- Determine field names based on group name
    local batteryField, ammunitionField = 'batteries', 'ammunitionSections'
    if string.find(group.name, 'Ammo') or string.find(group.name, 'SUPP') then
        batteryField, ammunitionField = 'ammunitionSections', 'batteries'
    end

    -- Get configuration information
    local config = CONFIG[key].ground[platform]

    -- Iterate through batteries
    for _, battery in pairs(config[batteryField]) do
        -- Check if conditions are met
        local isStateValid = true
        if isRepositioningAutomatically then
            local repoState = CONFIG.const.batteryState.REPOSITIONING
            local reloadState = CONFIG.const.batteryState.RELOAD
            isStateValid = (battery.state == repoState or battery.state == reloadState)
        end

        -- If matching group found and state is valid
        if battery.guid == group.guid and isStateValid then
            -- Find the area where unit is located
            local area = FindUnitArea(unit, config.const.position)
            if not area then
                return { isMet = false, battery = nil }
            end

            -- Check if ammo is in the same area
            for _, section in pairs(config[ammunitionField]) do
                local ammoSec = SE_GetUnit({ guid = section.guid })
                if ammoSec and ammoSec:inArea(area) then
                    return { isMet = true, battery = battery }
                end
            end
        end
    end

    return { isMet = false, battery = nil }
end

-- Check if a unit has met with ammo
function IsMetWithAmmo(CONFIG, unit, platform, isRepositioningAutomatically)
    -- Get unit's side and corresponding config key
    local side = unit.side
    local key = (side == 'China') and 'c' or 't'

    -- If unit has no group, return not met
    if not unit.group then return { isMet = false, battery = nil } end

    -- Get the unit's group
    local group = SE_GetUnit({ guid = unit.group.guid })
    if not group then return { isMet = false, battery = nil } end

    -- Get configuration information
    local config = CONFIG[key].ground[platform]

    -- Iterate through ammunition sections
    for _, section in pairs(config.ammunitionSections) do
        -- Check if conditions are met
        local isStateValid = true
        if isRepositioningAutomatically then
            local repoState = CONFIG.const.batteryState.REPOSITIONING
            local reloadState = CONFIG.const.batteryState.RELOAD
            isStateValid = (section.state == repoState or section.state == reloadState)
        end

        -- If matching group found and state is valid
        if section.guid == group.guid and isStateValid then
            local ammo = SE_GetUnit({ guid = section.ammunition })

            -- Check if unit and ammo are in the same area
            for _, p in pairs(config.const.position) do
                local isInSameArea = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))
                if isInSameArea then
                    return { isMet = true, battery = section }
                end
            end
        end
    end

    return { isMet = false, battery = nil }
end

-- Helper function: Find the area where a unit is located
function FindUnitArea(unit, positions)
    for _, p in pairs(positions) do
        if unit:inArea(p.RL.area) then
            return p.RL.area
        end
    end
    return nil
end

function DestroyAmmoSecHandler(unit, side, platform)
    local field = (side == 'China') and 'c' or 't'
    if unit.group == nil then return end
    local ammoSec = CONFIG[field].ground[platform].ammunitionSections[unit.group.guid]

    if ammoSec and ammoSec.wpnCurrent > 0 then
        if (ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount) < 0 then
            ammoSec.wpnCurrent = 0
        else
            ammoSec.wpnCurrent = ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount
        end
    end
end
