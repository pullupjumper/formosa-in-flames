-- RenameUnitsFromBase('6Z8LM5-0HMIJ3QGCRQ5F', 12, 683, '603rd Air Cavalry Bde')
---@param fromUnit string
---@param num number
---@param weaponDBID number
---@param name string
function RenameUnitsFromBase(fromUnit, num, weaponDBID, name)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits['Aircraft']
    if platforms == nil then return end
    local filteredPlatforms = {}

    for _, v in ipairs(platforms) do
        local unit = SE_GetUnit({ guid = v })

        if unit then
            local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons

            if weapons then
                for _, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID and w["wpn_current"] > 0 then
                        table.insert(filteredPlatforms, unit)
                    end
                end
            end
        end

        if GetCount(filteredPlatforms) >= num then
            break
        end
    end

    for k, unit in ipairs(filteredPlatforms) do
        unit.name = name .. ' #' .. tostring(k)
    end
end

---@class Package:table
---@field fromUnit string
---@field num number
---@field weaponDBID number
---@field allocation number
---@field course CMO__TableOfWaypoints|nil
---@field targetList table<number, string>
---@param package Package
function HandleStrikePackagesWithoutMission(package)
    local fromUnit = package.fromUnit
    local num = package.num
    local weaponDBID = package.weaponDBID
    local allocation = package.allocation
    local course = package.course
    local targetList = package.targetList
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits['Aircraft']
    if platforms == nil then return end
    local aircraftNumPerTarget = num // GetCount(targetList)
    local index = 1
    local filteredPlatforms = {}

    for _, v in ipairs(platforms) do
        local unit = SE_GetUnit({ guid = v })

        if unit then
            local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons

            if weapons then
                for _, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID and w["wpn_current"] > 0 then
                        table.insert(filteredPlatforms, unit)
                    end
                end
            end
        end

        if GetCount(filteredPlatforms) >= num then
            break
        end
    end

    for k, unit in ipairs(filteredPlatforms) do
        local contact = ScenEdit_GetContact({ side = 'China', guid = targetList[index].guid })
        unit:Launch(true)

        if course ~= nil then
            unit.course = course
        end

        if contact then
            ScenEdit_AttackContact(
                unit.guid,
                targetList[index].guid,
                { mode = '1', weapon = weaponDBID, qty = allocation }
            )
        end

        unit:RTB(true)

        if k % aircraftNumPerTarget == 0 and aircraftNumPerTarget > 1 then
            index = index + 1
        end
    end
end

---@param fromUnit string
---@param platformType string
---@param platformDBID number
---@param missions table<number, string>
function AssignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits[platformType]
    local filteredPlatforms = {}

    for _, value in ipairs(platforms) do
        local unit = SE_GetUnit({ guid = value })
        if unit ~= nil and unit.dbid == platformDBID then
            unit.manualSpeed = 'OFF'
            table.insert(filteredPlatforms, unit)
        end
    end

    for _, mission in ipairs(missions) do
        local count = 0

        for idx, unit in ipairs(filteredPlatforms) do
            if count >= mission.num then break end

            if mission.loadoutId == 0 then
                if not unit.mission then
                    ScenEdit_AssignUnitToMission(unit.guid, mission.name)
                    count = count + 1
                end
            else
                if unit.loadoutdbid == mission.loadoutId and not unit.mission then
                    ScenEdit_AssignUnitToMission(unit.guid, mission.name)
                    count = count + 1
                end
            end
        end
    end
end

---@param fromUnit string
---@param num number
---@param weaponDBID number | 0
---@param unitDBID number | nil
---@param missionName string
---@param isEscort boolean
---@param course? CMO__TableOfWaypoints|nil
function AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort, course)
    local airbase = ScenEdit_GetUnit({ guid = fromUnit })

    if airbase == nil then
        airbase = ScenEdit_GetUnit({ unitname = fromUnit })
    end

    if airbase == nil or airbase.embarkedUnits['Aircraft'] == nil then return end
    local m = ScenEdit_GetMission(airbase.side, missionName)
    if m == nil then return end
    m.isactive = false
    local temp = {}
    local count = 0

    for _, item in ipairs(airbase.embarkedUnits.Aircraft) do
        local unit = ScenEdit_GetUnit({ guid = item })
        if unit == nil then goto continue end

        local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
        local weaponNum = 0

        if weapons and #weapons > 0 then
            for _, w in ipairs(weapons) do
                if w["wpn_dbid"] == weaponDBID then weaponNum = w["wpn_current"] end
            end
        end

        if unit.readytime_v == 0 and unit.mission == nil and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
            -- if unit.readytime_v == 0 and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
            if isEscort then
                ScenEdit_AssignUnitToMission(unit.guid, missionName, true)
            else
                ScenEdit_AssignUnitToMission(unit.guid, missionName)
            end

            if course then unit.course = course end
            count = count + 1
            table.insert(temp, { unit = unit.guid })
            if count >= num then break end
        end

        ::continue::
    end
    if not m.isactive then m.isactive = true end
    return temp
end

-- ---@param contact CMO__Contact
-- ---@param qty number
-- ---@param batteries table<CONFIG__Battery>
-- ---@param btyIdx number
-- ---@param grpIdx number
-- ---@param weaponDBID? number|nil
-- ---@return table
-- function AttackContact(contact, qty, batteries, btyIdx, grpIdx, weaponDBID)
--     local launchedNum = 0
--     local count = 0
--     if btyIdx == nil then btyIdx = 1 end
--     if grpIdx == nil then grpIdx = 1 end

--     while btyIdx <= #batteries do
--         local group = ScenEdit_GetUnit({ guid = batteries[btyIdx].guid })

--         if group then
--             -- determine if it's a group or unit
--             if group.group then
--                 while grpIdx <= #group.group.unitlist do
--                     local guid = group.group.unitlist[grpIdx]
--                     local unit = ScenEdit_GetUnit({ guid = guid })

--                     if unit then
--                         local totalWpnCurrentNum = 0
--                         local totalWpnDefaultNum = 0
--                         local totalQtyAssigned = 0
--                         local toatalQtyFired = 0
--                         local defaultNum = 1
--                         local mountDBID = unit.mounts[1]['mount_dbid']
--                         local mountIndex = 1
--                         local wpnIndex = 1
--                         local isHold = ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == 2
--                             or ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == '2'

--                         for _, mount in ipairs(unit.mounts) do
--                             for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                                 if wpn['wpn_dbid'] == weaponDBID then
--                                     wpnIndex = wpnIdx
--                                     mountIndex = _
--                                     mountDBID = mount['mount_dbid']
--                                     totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                                     totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                                 end
--                             end
--                         end

--                         if weaponDBID == nil then
--                             weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
--                         end

--                         for _, item in ipairs(ScenEdit_WeaponAllocation(guid, '', '')) do
--                             totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
--                             toatalQtyFired = toatalQtyFired + item.qtyFired
--                         end

--                         local isLessThanTotalWpnDefault = totalQtyAssigned < totalWpnDefaultNum
--                         -- local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned
--                         local qtyAssignedOnTarget = 0
--                         local isQtyAssignedOnTargetMoreThan = false

--                         if #ScenEdit_WeaponAllocation('', contact.guid, group.side) > 0 then
--                             for index, item in ipairs(ScenEdit_WeaponAllocation('', contact.guid, group.side)) do
--                                 qtyAssignedOnTarget = qtyAssignedOnTarget + item.qtyAssigned
--                             end

--                             isQtyAssignedOnTargetMoreThan = qtyAssignedOnTarget >= qty
--                         end

--                         if totalWpnCurrentNum >= qty then
--                             defaultNum = qty
--                         else
--                             defaultNum = totalWpnCurrentNum
--                         end

--                         if totalWpnCurrentNum > 0 and not isHold and isLessThanTotalWpnDefault and not isQtyAssignedOnTargetMoreThan then
--                             local result = ScenEdit_AttackContact(
--                                 guid,
--                                 contact.guid,
--                                 { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
--                             )

--                             if result then launchedNum = launchedNum + defaultNum end
--                         end

--                         if (grpIdx + 1) > #group.group.unitlist then
--                             grpIdx = 1
--                             btyIdx = btyIdx + 1
--                         else
--                             grpIdx = grpIdx + 1
--                         end

--                         if btyIdx > #batteries then btyIdx = 1 end
--                         count = count + 1

--                         if launchedNum >= qty or count >= 50 then
--                             return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
--                         end
--                     end
--                 end
--             else
--                 local totalWpnCurrentNum = 0
--                 local totalWpnDefaultNum = 0
--                 local totalQtyAssigned = 0
--                 local toatalQtyFired = 0
--                 local defaultNum = 1
--                 local mountDBID = group.mounts[1]['mount_dbid']
--                 local mountIndex = 1
--                 local wpnIndex = 1
--                 local isHold = ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == 2
--                     or ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == '2'

--                 for _, mount in ipairs(group.mounts) do
--                     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                         if wpn['wpn_dbid'] == weaponDBID then
--                             wpnIndex = wpnIdx
--                             mountIndex = _
--                             mountDBID = mount['mount_dbid']
--                             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                         end
--                     end
--                 end

--                 if weaponDBID == nil then
--                     weaponDBID = group.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
--                 end

--                 for _, item in ipairs(ScenEdit_WeaponAllocation(group.guid, '', '')) do
--                     totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
--                     toatalQtyFired = toatalQtyFired + item.qtyFired
--                 end

--                 local isLessThanTotalWpnDefault = totalQtyAssigned < totalWpnDefaultNum
--                 -- local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned
--                 local isQtyAssignedOnTargetMoreThan = false
--                 local qtyAssignedOnTarget = 0

--                 if #ScenEdit_WeaponAllocation('', contact.guid, group.side) > 0 then
--                     for index, item in ipairs(ScenEdit_WeaponAllocation('', contact.guid, group.side)) do
--                         qtyAssignedOnTarget = qtyAssignedOnTarget + item.qtyAssigned
--                     end

--                     isQtyAssignedOnTargetMoreThan = qtyAssignedOnTarget >= qty
--                 end

--                 if totalWpnCurrentNum >= qty then
--                     defaultNum = qty
--                 else
--                     defaultNum = totalWpnCurrentNum
--                 end

--                 if totalWpnCurrentNum > 0 and not isHold and isLessThanTotalWpnDefault and not isQtyAssignedOnTargetMoreThan then
--                     local result = ScenEdit_AttackContact(
--                         group.guid,
--                         contact.guid,
--                         { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
--                     )

--                     if result then launchedNum = launchedNum + defaultNum end
--                 end

--                 btyIdx = btyIdx + 1
--                 if btyIdx > #batteries then btyIdx = 1 end
--                 count = count + 1

--                 if launchedNum >= qty or count >= 50 then
--                     return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
--                 end
--             end
--         else
--             break
--         end
--     end

--     return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = 0 }
-- end

---@param contact CMO__Contact The target contact to attack
---@param ammoToAllocate number Total amount of ammunition to allocate for this attack
---@param batteries table<CONFIG__Battery> Array of batteries to use for attack
---@param btyIdx number Starting battery index
---@param grpIdx number Starting group index
---@param weaponDBID? number|nil Optional specific weapon DBID to use
---@return table Results including next indices and number of weapons launched
function AttackContact(contact, ammoToAllocate, batteries, btyIdx, grpIdx, weaponDBID)
    -- Initialize variables
    local totalAmmoAllocated = 0
    local attemptCount = 0
    local maxAttempts = 50

    -- Set default values if not provided
    btyIdx = btyIdx or 1
    grpIdx = grpIdx or 1

    -- Process each battery until we've allocated enough ammo or tried all batteries
    while btyIdx <= #batteries and totalAmmoAllocated < ammoToAllocate and attemptCount < maxAttempts do
        local unit = ScenEdit_GetUnit({ guid = batteries[btyIdx].guid })

        if not unit then
            break -- Battery not found, exit loop
        end

        -- Handle differently based on whether it's a group or individual unit
        if unit.group then
            -- Track if we need to advance to next battery
            local advanceBattery, ammoAllocated = processUnitGroup(
                unit, contact, ammoToAllocate, totalAmmoAllocated, weaponDBID, grpIdx
            )

            -- Update our tracking variables
            totalAmmoAllocated = totalAmmoAllocated + ammoAllocated
            attemptCount = attemptCount + 1 -- Count each unit processing as one attempt

            if advanceBattery then
                btyIdx = btyIdx + 1
                grpIdx = 1
            else
                grpIdx = grpIdx + 1
            end

            -- Wrap around to first battery if needed
            if btyIdx > #batteries then btyIdx = 1 end

            -- Check if we've allocated enough ammo
            if totalAmmoAllocated >= ammoToAllocate then
                break
            end
        else
            -- Handle single unit
            local unitResult = processSingleUnit(unit, contact, ammoToAllocate, weaponDBID)
            totalAmmoAllocated = totalAmmoAllocated + unitResult.ammoAllocated
            attemptCount = attemptCount + 1

            -- Move to next battery
            btyIdx = btyIdx + 1
            if btyIdx > #batteries then btyIdx = 1 end

            -- Check if we've allocated enough ammo
            if totalAmmoAllocated >= ammoToAllocate then
                break
            end
        end
    end

    return { btyIdx = btyIdx, grpIdx = grpIdx, ammoAllocated = totalAmmoAllocated }
end

---Process a group unit and attempt to allocate weapons for attack
---@param groupUnit table The group unit to process
---@param contact table The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param ammoAlreadyAllocated number Amount of ammunition already allocated in this attack
---@param weaponDBID number|nil Specific weapon DBID to use
---@param grpIdx number Current group index
---@return boolean Whether to advance to next battery
---@return number Number of weapons allocated
function processUnitGroup(groupUnit, contact, totalAmmoRequested, ammoAlreadyAllocated, weaponDBID, grpIdx)
    local ammoAllocated = 0
    local advanceBattery = false

    -- Check if we have a valid unit at the current group index
    if grpIdx > #groupUnit.group.unitlist then
        return true, 0 -- Move to next battery, no weapons allocated
    end

    local guid = groupUnit.group.unitlist[grpIdx]
    local unit = ScenEdit_GetUnit({ guid = guid })

    if not unit then
        return true, 0 -- Unit not found, move to next, no weapons allocated
    end

    -- Find weapon info and check availability
    local weaponInfo = getWeaponInfo(unit, weaponDBID)
    weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

    -- Check if unit can fire
    if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
        -- Determine how many weapons to allocate for this attack
        local ammoNeeded = totalAmmoRequested - ammoAlreadyAllocated
        local ammoToAllocate = math.min(ammoNeeded, weaponInfo.availableWeapons)

        -- Attack the contact
        local result = ScenEdit_AttackContact(
            guid,
            contact.guid,
            { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
        )

        if result then
            ammoAllocated = ammoToAllocate
        end
    end

    -- Check if this was the last unit in the group
    if grpIdx >= #groupUnit.group.unitlist then
        advanceBattery = true
    end

    return advanceBattery, ammoAllocated
end

---Process a single unit and attempt to allocate weapons for attack
---@param unit table The unit to process
---@param contact table The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param weaponDBID number|nil Specific weapon DBID to use
---@return table Results including allocated weapons
function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
    -- Find weapon info and check availability
    local weaponInfo = getWeaponInfo(unit, weaponDBID)
    weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

    -- Check if unit can fire
    if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
        -- Determine how many weapons to allocate for this attack
        local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)

        -- Attack the contact
        local result = ScenEdit_AttackContact(
            unit.guid,
            contact.guid,
            { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
        )

        if result then
            return { ammoAllocated = ammoToAllocate }
        end
    end

    return { ammoAllocated = 0 }
end

---Get weapon information for a unit
---@param unit table The unit to check
---@param weaponDBID number|nil Specific weapon DBID to look for
---@return table Weapon information
function getWeaponInfo(unit, weaponDBID)
    local availableWeapons = 0
    local maxWeaponCapacity = 0
    local mountDBID = unit.mounts[1]['mount_dbid']
    local mountIndex = 1
    local wpnIndex = 1

    -- Find the specified weapon or use the first available weapon with ammo
    for mountIdx, mount in ipairs(unit.mounts) do
        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
            if (weaponDBID == nil and wpn['wpn_default'] > 0) or wpn['wpn_dbid'] == weaponDBID then
                wpnIndex = wpnIdx
                mountIndex = mountIdx
                mountDBID = mount['mount_dbid']
                availableWeapons = availableWeapons + wpn['wpn_current']
                maxWeaponCapacity = maxWeaponCapacity + wpn['wpn_maxcap']
            end
        end
    end

    -- If no weaponDBID was provided, use the one we found
    if weaponDBID == nil then
        weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
    end

    -- Get currently assigned weapons
    local alreadyAllocatedWeapons = 0
    for _, item in ipairs(ScenEdit_WeaponAllocation(unit.guid, '', '')) do
        alreadyAllocatedWeapons = alreadyAllocatedWeapons + item.qtyAssigned
    end

    return {
        weaponDBID = weaponDBID,
        mountDBID = mountDBID,
        availableWeapons = availableWeapons,
        maxWeapons = maxWeaponCapacity,
        assignedWeapons = alreadyAllocatedWeapons
    }
end

---Check if a unit can fire at a contact
---@param unit table The unit to check
---@param contact table The target contact
---@param weaponInfo table Weapon information
---@param totalAmmoRequested number Total amount of ammunition requested for attack
---@return boolean Whether the unit can fire
function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
    -- Check if unit is on hold
    local doctrine = ScenEdit_GetDoctrine({ guid = unit.guid })
    local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == '2'

    if isHold then
        return false
    end

    -- Check if we have any weapons available
    if weaponInfo.availableWeapons <= 0 then
        printBox('China', 'func/AttackContact/No weapons available, no need to fire more')
        return false
    end

    -- Check if we've reached maximum weapon allocation
    if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
        printBox('China', 'func/AttackContact/Maximum weapon allocation reached, no need to fire more')
        return false
    end

    -- Check if total weapons already allocated to this target meets requirements
    local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

    if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
        printBox('China', 'func/AttackContact/Target already has sufficient weapons allocated, no need to fire more')
        return false -- Target already has sufficient weapons allocated, no need to fire more
    end

    return true
end

---Get total ammunition already allocated for attacking a specific target
---@param contactGuid string The target contact's unique identifier
---@param side string The attacking side's name
---@return number Total ammunition currently allocated to attack this target
function getAmmoAllocatedForTarget(contactGuid, side)
    local totalTargetAmmoCount = 0

    local weaponAllocations = ScenEdit_WeaponAllocation('', contactGuid, side)
    if #weaponAllocations > 0 then
        for _, allocation in ipairs(weaponAllocations) do
            totalTargetAmmoCount = totalTargetAmmoCount + allocation.qtyAssigned
        end
    end

    return totalTargetAmmoCount
end

function AttackContacts(contacts, qty, batteries, weaponDBID)
    local result = { btyIdx = 1, grpIdx = 1, launchedNum = 0 }
    local totalLaunchedNum = 0

    for _, contact in ipairs(contacts) do
        result = AttackContact(
            contact,
            qty,
            batteries,
            result.btyIdx,
            result.grpIdx,
            weaponDBID
        )

        totalLaunchedNum = totalLaunchedNum + result.ammoAllocated
    end

    return totalLaunchedNum
end

---@param side string
---@param missionName string
---@return table<number, CONFIG__TargetList>
function InitTargetList(side, missionName)
    local m = ScenEdit_GetMission(side, missionName)
    local temp = {}
    if m == nil then return temp end

    for _, value in ipairs(m.targetlist) do
        ---@class CONFIG__TargetList
        ---@field guid string
        ---@field strikeTimes number
        table.insert(temp, { guid = value, strikeTimes = 0 })
    end

    return temp
end

function GetOODA(d)
    return {
        detection = math.random(10 * d, 30 * d),
        targeting = math.random(20 * d, 20 * d),
        evasion = math.random(90 * d, 120 * d)
    }
end

function CountUnitsInEachArea()
    local unitsFromChina = VP_GetSide({ Side = 'China' }).units
    local result = {}

    for _, zone in ipairs(CONFIG.c.PHIBOP.const.operationalZones) do
        local item = {
            ['ZBD-05'] = 0,
            ['ZTD-05'] = 0,
            ['PLL-05'] = 0,
            ['PLZ-96'] = 0,
            ['PGZ-09'] = 0,
            ['PGZ-95'] = 0,
            ['SA-15'] = 0,
            ['AirborneCorps'] = 0,
            ['HMMWV'] = 0,
            ['ZBD-03'] = 0
        }
        for index, value in ipairs(unitsFromChina) do
            local unit = SE_GetUnit({ guid = value.guid })

            if unit and unit:inArea(zone.area) then
                if unit.dbid == CONFIG.const.platformBDID58 then
                    item['ZBD-05'] = item['ZBD-05'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID59 then
                    item['ZTD-05'] = item['ZTD-05'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID60 then
                    item['PLL-05'] = item['PLL-05'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID61 then
                    item['PLZ-96'] = item['PLZ-96'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID62 then
                    item['PGZ-09'] = item['PGZ-09'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID63 then
                    item['PGZ-95'] = item['PGZ-95'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID66 then
                    item['SA-15'] = item['SA-15'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID65 then
                    item['AirborneCorps'] = item['AirborneCorps'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID64 then
                    item['HMMWV'] = item['HMMWV'] + 1
                end

                if unit.dbid == CONFIG.const.platformBDID39 then
                    item['ZBD-03'] = item['ZBD-03'] + 1
                end
            end
        end

        result[zone.name] = item
    end

    return result
end

function ToggleUnitForm()
    local result = CountUnitsInEachArea()

    local HTMLTemplate = [[
    <!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }
        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }
        th {
            background-color: #333;
        }
    </style>
</head>
<body>

    <table id="dataTable">
        <thead>
            <tr>
                <th>Area</th>
                <th>Unit Type</th>
                <th>Count</th>
            </tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableBody = document.getElementById("tableBody");

        Object.keys(data).forEach(area => {
            const unitTypes = Object.keys(data[area]);
            unitTypes.forEach((unitType, index) => {
                let row = document.createElement("tr");

                if (index === 0) {
                    let areaCell = document.createElement("td");
                    areaCell.textContent = area;
                    areaCell.rowSpan = unitTypes.length;
                    row.appendChild(areaCell);
                }

                let typeCell = document.createElement("td");
                typeCell.textContent = unitType;
                row.appendChild(typeCell);

                let countCell = document.createElement("td");
                countCell.textContent = data[area][unitType];
                row.appendChild(countCell);

                tableBody.appendChild(row);
            });
        });
    </script>
</body>
</html>
    ]]
    local msg = string.format(HTMLTemplate, gKH.json.stringify(result))
    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function ToggleC2Form(side)
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
        return
    end

    local createDataString = function(side, ...)
        local key = 't'

        if side == 'China' then
            key = 'c'
        end

        local rows = {}
        local types = { ... }

        for _, type in pairs(types) do
            for index, item in pairs(CONFIG[key].IADS[type]) do
                if rows[type] == nil then
                    rows[type] = {}
                end

                rows[type][item.guid] = { name = item.name }

                if item.SAM then
                    rows[type][item.guid]['SAM'] = {}

                    for _, sam in pairs(item.SAM) do
                        local unit = SE_GetUnit({ guid = sam.guid })
                        local isDestroyed = unit == nil
                        rows[type][item.guid]['SAM'][sam.guid] = {
                            name = sam.name,
                            OODADetection = tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
                            OODATargeting = tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
                            isOutOfComms = sam.isOutOfComms,
                            EMCON_Setting = sam.EMCON_Setting,
                            isDestroyed = isDestroyed
                        }
                    end
                end

                if item.radar then
                    rows[type][item.guid]['radar'] = { name = item.name }

                    for _, radar in pairs(item.radar) do
                        local unit = SE_GetUnit({ guid = radar.guid })
                        local isDestroyed = unit == nil
                        rows[type][item.guid]['radar'][radar.guid] = {
                            name = radar.name,
                            OODADetection = tostring(radar.currOODA.detection) .. '/' .. tostring(radar.OODA.detection),
                            OODATargeting = tostring(radar.currOODA.targeting) .. '/' .. tostring(radar.OODA.targeting),
                            isOutOfComms = radar.isOutOfComms,
                            EMCON_Setting = radar.EMCON_Setting,
                            isDestroyed = isDestroyed
                        }
                    end
                end
            end
        end

        return gKH.json.stringify(rows)
    end

    local HTMLTemplate = [[
   <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }

        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th,
        td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }

        th {
            background-color: #333;
        }
    </style>
</head>

<body>

    <table id="dataTable">
        <thead>
            <tr id="tableHead"></tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableHead = document.getElementById("tableHead");
        let tableBody = document.getElementById("tableBody");

        let headers = ["C2 Node", "Name", "OODA Detection", "OODA Targeting", "Out of Comms", "EMCON Setting", "Destroyed"];
        headers.forEach(header => {
            let th = document.createElement("th");
            th.textContent = header;
            tableHead.appendChild(th);
        });

        Object.keys(data).forEach(area => {
            Object.keys(data[area]).forEach(subArea => {
                let unitTypes = Object.keys(data[area][subArea]).filter(type => type !== "name");
                let totalUnits = unitTypes.reduce((sum, type) => sum + Object.keys(data[area][subArea][type]).length, 0);
                let firstRow = true;

                unitTypes.forEach(type => {
                    Object.keys(data[area][subArea][type]).forEach((unitName) => {
                        let unit = data[area][subArea][type][unitName];
                        let row = document.createElement("tr");

                        if (firstRow) {
                            let areaCell = document.createElement("td");
                            areaCell.textContent = data[area][subArea].name;
                            areaCell.rowSpan = totalUnits;
                            row.appendChild(areaCell);
                            firstRow = false;
                        }

                        ["name", "OODADetection", "OODATargeting", "isOutOfComms", "EMCON_Setting", "isDestroyed"].forEach(key => {
                            let cell = document.createElement("td");
                            cell.textContent = typeof unit[key] === "boolean" ? (unit[key] ? "YES" : "NO") : unit[key];
                            row.appendChild(cell);
                        });

                        tableBody.appendChild(row);
                    });
                });
            });
        });
    </script>

</body>

</html>
    ]]
    local str
    if side == 'China' then
        str = createDataString(side, 'C2')
    else
        str = createDataString(side, 'ROCC', 'TAAOC')
    end
    local msg = string.format(HTMLTemplate, str)
    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function ToggleBtyStatusForm(side)
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
        return
    end

    local createDataString = function(side, ...)
        local key = 't'
        local types = { ... }

        if side == 'China' then
            key = 'c'
        end

        local rows = {}

        for index, type in pairs(types) do
            if CONFIG[key].ground[type].ammunitionSections then
                for k, value in pairs(CONFIG[key].ground[type].ammunitionSections) do
                    rows[k] = {}
                end
            end
        end

        for index, type in pairs(types) do
            if CONFIG[key].ground[type].batteries then
                for _, bty in pairs(CONFIG[key].ground[type].batteries) do
                    local name = bty.name
                    local status = ''
                    local remainingAmmoInVehicles = CONFIG[key].ground[type].ammunitionSections[bty.ammunitionSection]
                        .wpnCurrent
                    local ammoSec = CONFIG[key].ground[type].ammunitionSections[bty.ammunitionSection]
                    local reloadTime = CONFIG[key].ground[type].const.reloadTime / 60
                    local remainingAmmo = CONFIG[key].ground[type].ammunitions
                        [CONFIG[key].ground[type].ammunitionSections[bty.ammunitionSection].ammunition].wpnCurrent
                    local reloadingRemainingTime = nil
                    local transloadingRemainingTime = nil

                    if bty.state == 0 then
                        status = 'STATIC'
                    elseif bty.state == 1 then
                        status = 'REPOSITIONING'
                    elseif bty.state == 2 then
                        status = 'RELOAD'
                    else
                        status = 'HIDE'
                    end

                    if bty.reloadStartTime ~= nil then
                        reloadingRemainingTime = math.floor(((ScenEdit_CurrentTime() - bty.reloadStartTime) / 60) * 100 +
                                0.5) /
                            100

                        if reloadingRemainingTime < 0 then
                            reloadingRemainingTime = 0
                        end
                    end

                    if bty.reloadStartTime == nil then
                        reloadingRemainingTime = 0
                    end

                    if ammoSec.reloadStartTime ~= nil then
                        transloadingRemainingTime = math.floor(((ScenEdit_CurrentTime() - ammoSec.reloadStartTime) / 60) *
                            100 +
                            0.5) / 100

                        if transloadingRemainingTime < 0 then
                            transloadingRemainingTime = 0
                        end
                    end

                    if ammoSec.reloadStartTime == nil then
                        transloadingRemainingTime = 0
                    end

                    if side == 'China' then
                        table.insert(rows[bty.ammunitionSection], {
                            name = name,
                            type = type,
                            status = status,
                            remainingAmmoInVehicles = remainingAmmoInVehicles,
                            remainingAmmo = remainingAmmo,
                            reloadTimeForBty = reloadingRemainingTime,
                            reloadTimeForAmmoSec = transloadingRemainingTime,
                            defaultReloadTime = reloadTime
                        })
                    else
                        table.insert(rows[bty.ammunitionSection], {
                            name = name,
                            type = type,
                            remainingAmmoInVehicles = remainingAmmoInVehicles,
                            remainingAmmo = remainingAmmo,
                            reloadTimeForBty = reloadingRemainingTime,
                            reloadTimeForAmmoSec = transloadingRemainingTime,
                            defaultReloadTime = reloadTime
                        })
                    end
                end
            end
        end

        return gKH.json.stringify(rows)
    end

    local HTMLTemplate = [[
   <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }

        table {
            width: 100%%;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th,
        td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }

        th {
            background-color: #333;
        }

        .progress-container {
            width: 100px;
            background-color: #555;
            border-radius: 5px;
            overflow: hidden;
            position: relative;
        }

        .progress-bar {
            height: 14px;
            background-color: #4caf50;
        }

        .progress-text {
            position: absolute;
            width: 120px;
            top: 50%% ;
            left: 50%% ;
            transform: translate(-50%%, -50%%);
            font-size: 9px;
            color: white;
        }
    </style>
</head>

<body>

    <table id="dataTable">
        <thead>
            <tr id="tableHead"></tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableHead = document.getElementById("tableHead");
        let tableBody = document.getElementById("tableBody");

        let headers = ["Name", "Type", "Status", "Reload Time (Bty)", "Reload Time (Ammo Sec)", "Ammo in Vehicles", "Remaining Ammo"];
        headers.forEach(header => {
            let th = document.createElement("th");
            th.textContent = header;
            tableHead.appendChild(th);
        });

        Object.keys(data).forEach(area => {
            let areaUnits = data[area];
            areaUnits.forEach((unit, index) => {
                let row = document.createElement("tr");

                ["name", "type", "status"].forEach(key => {
                    let cell = document.createElement("td");
                    cell.textContent = key === "type" ? unit[key].toUpperCase() : unit[key];
                    row.appendChild(cell);
                });

                ["reloadTimeForBty", "reloadTimeForAmmoSec"].forEach(key => {
                    let progressCell = document.createElement("td");
                    let progressContainer = document.createElement("div");
                    progressContainer.classList.add("progress-container");

                    let progressBar = document.createElement("div");
                    progressBar.classList.add("progress-bar");
                    let percentage = (unit[key] / unit.defaultReloadTime) * 100;
                    progressBar.style.width = percentage + "%%";

                    let progressText = document.createElement("div");
                    progressText.classList.add("progress-text");
                    progressText.textContent = `${unit[key]} / ${unit.defaultReloadTime} mins`;

                    progressContainer.appendChild(progressBar);
                    progressContainer.appendChild(progressText);
                    progressCell.appendChild(progressContainer);
                    row.appendChild(progressCell);
                });

                if (index === 0) {
                    ["remainingAmmoInVehicles", "remainingAmmo"].forEach(key => {
                        let ammoCell = document.createElement("td");
                        ammoCell.textContent = unit[key];
                        ammoCell.rowSpan = areaUnits.length;
                        row.appendChild(ammoCell);
                    });
                }

                tableBody.appendChild(row);
            });
        });
    </script>

</body>

</html>
    ]]
    local str = createDataString(side, 'srbm', 'mlrs', 'glcm', 'ascm')
    local msg = string.format(HTMLTemplate, str)
    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function PopulateMagazineInBasesTable(side)
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
        return
    end

    local createDataString = function(side)
        local key = 't'

        if side == 'China' then
            key = 'c'
        end

        local rows = {}

        for index, item in ipairs(CONFIG[key].air.landBased.const.ACInfo) do
            local base = SE_GetUnit({ guid = item.baseGUID })

            if base and item.loadouts then
                local obj = { name = item.name, wpns = {} }

                for _, magazine in ipairs(base.magazines) do
                    for _, wpn in ipairs(magazine['mag_weapons']) do
                        table.insert(obj.wpns, {
                            name = wpn['wpn_name'],
                            currWpn = wpn['wpn_current'],
                        })
                    end
                end

                table.insert(rows, obj)
            end
        end

        return gKH.json.stringify(rows)
    end

    local HTMLTemplate = [[
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Weapon Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }
        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }
        th {
            background-color: #333;
        }
    </style>
</head>
<body>

    <table id="dataTable">
        <thead>
            <tr>
                <th>Base</th>
                <th>Weapon Name</th>
                <th>Current Weapon Count</th>
            </tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableBody = document.getElementById("tableBody");

        data.forEach(base => {
            base.wpns.forEach((weapon, index) => {
                let row = document.createElement("tr");

                if (index === 0) {
                    let baseCell = document.createElement("td");
                    baseCell.textContent = base.name;
                    baseCell.rowSpan = base.wpns.length;
                    row.appendChild(baseCell);
                }

                let weaponCell = document.createElement("td");
                weaponCell.textContent = weapon.name;
                row.appendChild(weaponCell);

                let countCell = document.createElement("td");
                countCell.textContent = weapon.currWpn;
                row.appendChild(countCell);

                tableBody.appendChild(row);
            });
        });
    </script>

</body>
</html>

    ]]

    local str = createDataString(side)
    local msg = string.format(HTMLTemplate, str)
    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function SetWCSToHold()
    local units = VP_GetSide({ Side = 'Taiwan' }).units
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        print('CONFIG == nil')
        ScenEdit_MsgBox('CONFIG == nil', 1)
        return
    end

    local HTMLTemplate = [[
    <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Set WCS to hold</title>
    <style>
        body {
            background-color: #1a1a1a;
            color: #ffffff;
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }

        .container {
            background-color: #2d2d2d;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
        }

        h1 {
            text-align: center;
            color: #ffffff;
            margin-bottom: 2rem;
        }

        .checkbox-group {
            margin: 1rem 0;
            display: flex;
            align-items: center;
        }

        input[type="checkbox"] {
            appearance: none;
            width: 20px;
            height: 20px;
            background-color: #404040;
            border: 2px solid #666;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }

        input[type="checkbox"]:checked {
            background-color: #00cc00;
            position: relative;
        }

        input[type="checkbox"]:checked::after {
            content: '✔';
            position: absolute;
            color: #fff;
            left: 4px;
            top: 0;
        }

        label {
            font-size: 1.1rem;
            cursor: pointer;
        }

        label:hover {
            color: #cccccc;
        }
    </style>
</head>

<body>
    <div class="container">
        <h2>EMCON Settings</h2>
        <div class="checkbox-group">
            <input type="checkbox" id="pac23" name="pac23">
            <label for="pac23">Pac-2/3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="skybow3" name="skybow3">
            <label for="skybow3">Sky Bow-3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="tc2" name="tc2">
            <label for="tc2">TC-2</label>
        </div>
    </div>
</body>

</html>
    ]]

    local msg = string.format(HTMLTemplate)
    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })

    if form['pressed'] and form['pressed'] == 'Done' then
        if form['pac23'] and string.gsub(form['pac23'], "%'", "") == 'on' then
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID15 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
                    )
                end
            end
        else
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID15 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
                    )
                end
            end
        end

        if form['skybow3'] and string.gsub(form['skybow3'], "%'", "") == 'on' then
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID14 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
                    )
                end
            end
        else
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID14 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
                    )
                end
            end
        end

        if form['tc2'] and string.gsub(form['tc2'], "%'", "") == 'on' then
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID33 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
                    )
                end
            end
        else
            for index, value in ipairs(units) do
                local unit = ScenEdit_GetUnit({ guid = value.guid })

                if unit and unit.dbid == CONFIG.const.platformBDID33 then
                    ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
                    ScenEdit_SetUnitIntermittentEmissionConfig(
                        unit.guid,
                        'Green',
                        { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
                    )
                end
            end
        end
    end
end
