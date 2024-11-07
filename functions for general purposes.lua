local function getCurrentWeaponNum(guid, weaponDBID)
    local unit = SE_GetUnit({ guid = guid })

    if unit then
        for _, mount in ipairs(unit.mounts) do
            for _, w in ipairs(mount['mount_weapons']) do
                if w["wpn_dbid"] == weaponDBID and w["wpn_current"] > 0 then
                    return w["wpn_current"]
                end
            end
        end
    end

    return 0
end

-- RenameUnitsFromBase('6Z8LM5-0HMIJ3QGCRQ5F', 12, 3413, '41st Air Brigade')
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
            if count >= mission.num then
                break
            end

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

-- ---@param fromUnit string
-- ---@param platformType string
-- ---@param platformDBID number
-- ---@param missionList table<number, string>
-- function AssignEmbarkedUnitsToEachMissionByMissionNum(fromUnit, platformType, platformDBID, missionList)
--     local base = ScenEdit_GetUnit({ guid = fromUnit })
--     if base == nil then return end
--     local platforms = base.embarkedUnits[platformType]
--     local count = GetCount(missionList)
--     local index = 1
--     local filteredPlatforms = {}

--     for _, value in ipairs(platforms) do
--         local unit = SE_GetUnit({ guid = value })
--         if unit ~= nil and unit.dbid == platformDBID then
--             unit.manualSpeed = 'OFF'
--             table.insert(filteredPlatforms, unit)
--         end
--     end

--     local platformNum = GetCount(filteredPlatforms) // count
--     for idx, item in ipairs(filteredPlatforms) do
--         ScenEdit_AssignUnitToMission(item.guid, missionList[index])
--         if idx % platformNum == 0 and platformNum > 1 then
--             index = index + 1
--         end
--     end
-- end

-- function AssignEmbarkedUnitToMissionByWeapon(fromUnit, num, weaponDBID, platformType, missionName, course)
--     local base = ScenEdit_GetUnit({ guid = fromUnit })
--     local count = 0
--     local temp = {}
--     if base == nil or base.embarkedUnits[platformType] == nil then return end

--     for _, item in ipairs(base.embarkedUnits[platformType]) do
--         local unit = ScenEdit_GetUnit({ guid = item })

--         if unit then
--             local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
--             local weaponNum = 0

--             if weapons then
--                 for _, w in ipairs(weapons) do
--                     if w["wpn_dbid"] == weaponDBID then
--                         weaponNum = w["wpn_current"]
--                     end
--                 end
--             end

--             if weaponNum > 0 and unit.readytime_v == 0 and count < num then
--                 ScenEdit_AssignUnitToMission(unit.guid, missionName)

--                 if course ~= nil then
--                     unit.course = course
--                 end

--                 count = count + 1
--                 table.insert(temp, unit)
--             end
--         end

--         if count >= num then
--             break
--         end
--     end
--     return temp
-- end

-- ---@param fromUnit string
-- ---@param num number
-- ---@param platformDBID number
-- ---@param platformType string
-- ---@param missionName string
-- ---@return table | nil
-- function AssignEmbarkedUnitToMissionByUnitNum(fromUnit, num, platformDBID, platformType, missionName)
--     local base = ScenEdit_GetUnit({ guid = fromUnit })
--     local count = 0
--     local temp = {}
--     if base == nil or base.embarkedUnits[platformType] == nil then return nil end
--     for _, item in ipairs(base.embarkedUnits[platformType]) do
--         local unit = ScenEdit_GetUnit({ guid = item })

--         if unit ~= nil and unit.dbid == platformDBID and unit.readytime_v == 0 and count < num then
--             ScenEdit_AssignUnitToMission(unit.guid, missionName)
--             count = count + 1
--             table.insert(temp, unit)
--         end

--         if count >= num then
--             break
--         end
--     end
--     return temp
-- end

---@param fromUnit string
---@param num number
---@param weaponDBID number | 0
---@param unitDBID number | nil
---@param missionName string
---@param isEscort boolean
---@param course? CMO__TableOfWaypoints|nil
function AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort, course)
    local airbase = ScenEdit_GetUnit({ guid = fromUnit })
    if airbase == nil or airbase.embarkedUnits['Aircraft'] == nil then return end
    local m = ScenEdit_GetMission(airbase.side, missionName)
    if m == nil then return end
    m.isactive = false
    local temp = {}
    local count = 0

    for _, item in ipairs(airbase.embarkedUnits.Aircraft) do
        local unit = ScenEdit_GetUnit({ guid = item })

        if unit then
            local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
            local weaponNum = 0

            if weapons and GetCount(weapons) > 0 then
                for _, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID then
                        weaponNum = w["wpn_current"]
                    end
                end
            end


            if unit.readytime_v == 0 and unit.mission == nil and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
                -- if unit.readytime_v == 0 and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
                if isEscort then
                    ScenEdit_AssignUnitToMission(unit.guid, missionName, true)
                else
                    ScenEdit_AssignUnitToMission(unit.guid, missionName)
                end

                if course then
                    unit.course = course
                end

                count = count + 1
                table.insert(temp, { unit = unit.guid })

                if count >= num then
                    break
                end
            end
        end
    end
    if not m.isactive then m.isactive = true end
    return temp
end

---@param contact CMO__Contact
---@param qty number
---@param batteries table<CONFIG__Battery>
---@param btyIdx number
---@param grpIdx number
---@param weaponDBID? number|nil
---@return table
function AttackContact(contact, qty, batteries, btyIdx, grpIdx, weaponDBID)
    local launchedNum = 0
    local count = 0
    if btyIdx == nil then btyIdx = 1 end
    if grpIdx == nil then grpIdx = 1 end

    while btyIdx <= GetCount(batteries) do
        local group = ScenEdit_GetUnit({ guid = batteries[btyIdx].guid })

        if group then
            -- determine if it's a group or unit
            if group.group then
                while grpIdx <= GetCount(group.group.unitlist) do
                    local guid = group.group.unitlist[grpIdx]
                    local unit = ScenEdit_GetUnit({ guid = guid })

                    if unit then
                        local totalWpnCurrentNum = 0
                        local totalWpnDefaultNum = 0
                        local totalQtyAssigned = 0
                        local defaultNum = 1
                        local mountDBID = unit.mounts[1]['mount_dbid']
                        local mountIndex = 1
                        local wpnIndex = 1
                        local isHold = ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == 2
                            or ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == '2'

                        for _, mount in ipairs(unit.mounts) do
                            if weaponDBID ~= nil and type(weaponDBID) == "number" then
                                for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                                    if wpn['wpn_dbid'] == weaponDBID then
                                        wpnIndex = wpnIdx
                                        mountIndex = _
                                        mountDBID = mount['mount_dbid']
                                        totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                                        totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                                    end
                                end
                            end
                        end

                        if weaponDBID == nil then
                            weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
                        end

                        for _, item in ipairs(ScenEdit_WeaponAllocation(guid, '', '')) do
                            totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
                        end

                        local isLessThan = totalQtyAssigned < totalWpnDefaultNum

                        if totalWpnCurrentNum > 0 and not isHold and isLessThan then
                            local result = ScenEdit_AttackContact(
                                guid,
                                contact.guid,
                                { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
                            )

                            if result then launchedNum = launchedNum + defaultNum end
                        end

                        if (grpIdx + 1) > GetCount(group.group.unitlist) then
                            grpIdx = 1
                            btyIdx = btyIdx + 1
                        else
                            grpIdx = grpIdx + 1
                        end

                        if btyIdx > GetCount(batteries) then btyIdx = 1 end
                        count = count + 1

                        if launchedNum >= qty or count >= 50 then
                            return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
                        end
                    end
                end
            else
                local totalWpnCurrentNum = 0
                local totalWpnDefaultNum = 0
                local totalQtyAssigned = 0
                local defaultNum = 1
                local mountDBID = group.mounts[1]['mount_dbid']
                local mountIndex = 1
                local wpnIndex = 1
                local isHold = ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == 2
                    or ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == '2'

                for _, mount in ipairs(group.mounts) do
                    if weaponDBID ~= nil and type(weaponDBID) == "number" then
                        for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                            if wpn['wpn_dbid'] == weaponDBID then
                                wpnIndex = wpnIdx
                                mountIndex = _
                                mountDBID = mount['mount_dbid']
                                totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
                                totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
                            end
                        end
                    end
                end

                if weaponDBID == nil then
                    weaponDBID = group.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
                end

                for _, item in ipairs(ScenEdit_WeaponAllocation(group.guid, '', '')) do
                    totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
                end

                local isLessThan = totalQtyAssigned < totalWpnDefaultNum

                -- local isLessThan = GetCount(ScenEdit_WeaponAllocation(group.guid, '', '')) < totalWpnDefaultNum

                if totalWpnCurrentNum > 0 and not isHold and isLessThan then
                    local result = ScenEdit_AttackContact(
                        group.guid,
                        contact.guid,
                        { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
                    )

                    if result then launchedNum = launchedNum + defaultNum end
                end

                btyIdx = btyIdx + 1
                if btyIdx > GetCount(batteries) then btyIdx = 1 end
                count = count + 1

                if launchedNum >= qty or count >= 50 then
                    return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
                end
            end
        end
    end

    return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = 0 }
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

        totalLaunchedNum = totalLaunchedNum + result.launchedNum
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
