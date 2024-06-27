---@param submarines table
---@param weaponDBID number
---@param allocation number
---@param targetList table<number, CONFIG__TargetList>
function LaunchSLCM(submarines, weaponDBID, allocation, targetList)
    local subs = {}
    local index = 1

    for _, v in ipairs(submarines) do
        local sub = SE_GetUnit({ guid = v.guid })

        if sub then
            table.insert(subs, sub)
        end
    end

    for _, sub in ipairs(subs) do
        ScenEdit_AttackContact(
            sub.guid,
            targetList[index].guid,
            { mode = '1', weapon = weaponDBID, qty = allocation }
        )

        index = index + 1

        if index > GetCount(targetList) then
            index = GetCount(targetList)
        end
    end
end

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
---@field course CMO__TableOfWaypoints
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
        unit.course = course

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
---@param missionList table<number, string>
function AssignEmbarkedUnitsToEachMissionByMissionNum(fromUnit, platformType, platformDBID, missionList)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    if base == nil then return end
    local platforms = base.embarkedUnits[platformType]
    local count = GetCount(missionList)
    local index = 1
    local filterHandler = function(idx, item)
        local unit = SE_GetUnit({ guid = item })
        if unit ~= nil and unit.dbid == platformDBID then
            return true
        end
        return false
    end
    local filteredPlatforms = Filter(platforms, filterHandler)
    local platformNum = GetCount(filteredPlatforms) // count
    for idx, item in ipairs(filteredPlatforms) do
        ScenEdit_AssignUnitToMission(item.guid, missionList[index])
        if idx % platformNum == 0 and platformNum > 1 then
            index = index + 1
        end
    end
end

---@param fromUnit string
---@param num number
---@param platformDBID number
---@param platformType string
---@param missionName string
function AssignEmbarkedUnitToMissionByUnitNum(fromUnit, num, platformDBID, platformType, missionName)
    local base = ScenEdit_GetUnit({ guid = fromUnit })
    local count = 0
    if base == nil or base.embarkedUnits[platformType] == nil then return end
    for _, item in ipairs(base.embarkedUnits[platformType]) do
        local unit = ScenEdit_GetUnit({ guid = item })

        if unit ~= nil and unit.dbid == platformDBID and unit.readytime_v == 0 and count < num then
            ScenEdit_AssignUnitToMission(unit.guid, missionName)
            count = count + 1
        end

        if count >= num then
            break
        end
    end
end

---@param fromUnit string
---@param num number
---@param weaponDBID number
---@param missionName string
---@param isEscort boolean
---@param course? CMO__TableOfWaypoints|nil
function AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, missionName, isEscort, course)
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

            if weapons then
                for _, w in ipairs(weapons) do
                    if w["wpn_dbid"] == weaponDBID then
                        weaponNum = w["wpn_current"]
                    end
                end
            end

            if unit.readytime_v == 0 and unit.mission == nil and count < num and weaponNum > 0 then
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
---@param batteryIndex number
---@param groupIndex number
---@param weaponDBID? number|nil
---@return table
function AttackContact(contact, qty, batteries, batteryIndex, groupIndex, weaponDBID)
    local launchedNum = 0

    if batteryIndex == nil then
        batteryIndex = 1
    end

    if groupIndex == nil then
        groupIndex = 1
    end

    for i = batteryIndex, GetCount(batteries) do
        local group = ScenEdit_GetUnit({ guid = batteries[i].guid })

        if group then
            for j = groupIndex, GetCount(group.group.unitlist) do
                local guid = group.group.unitlist[j]
                local unit = ScenEdit_GetUnit({ guid = guid })

                if unit then
                    local _weaponDBID = 0
                    local weaponCurrentNum = 0
                    local defaultNum = 1
                    local mountDBID = unit.mounts[1]['mount_dbid']
                    local wpnIndex = 1
                    local isHold = ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == 2
                        or ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == '2'

                    for _, mount in ipairs(unit.mounts) do
                        if weaponDBID ~= nil and type(weaponDBID) == "number" then
                            for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
                                if wpn['wpn_dbid'] == weaponDBID then
                                    wpnIndex = wpnIdx
                                    break
                                end
                            end
                        end

                        weaponCurrentNum = weaponCurrentNum + mount['mount_weapons'][wpnIndex]['wpn_current']
                    end

                    _weaponDBID = unit.mounts[1]['mount_weapons'][wpnIndex]['wpn_dbid']

                    if weaponCurrentNum > 0 and not isHold then
                        local result = ScenEdit_AttackContact(
                            guid,
                            contact.guid,
                            { mode = '1', qty = defaultNum, mount = mountDBID, weapon = _weaponDBID }
                        )

                        if result then
                            launchedNum = launchedNum + defaultNum
                        end
                    end

                    if (j + 1) > GetCount(group.group.unitlist) then
                        groupIndex = 1
                        batteryIndex = i + 1
                    else
                        groupIndex = j + 1
                        batteryIndex = i
                    end

                    if batteryIndex > GetCount(batteries) then
                        batteryIndex = 1
                    end

                    if launchedNum >= qty then
                        return { batteryIndex = batteryIndex, groupIndex = groupIndex, isLaunched = true }
                    end
                end
            end
        end
    end

    return { batteryIndex = batteryIndex, groupIndex = groupIndex, isLaunched = false }
end

---@param side string
---@param missionName string
---@return table<number, CONFIG__TargetList>
function InitTargetList(side, missionName)
    local m = ScenEdit_GetMission(side, missionName)
    local temp = {}

    if m == nil then
        return temp
    end

    for _, value in ipairs(m.targetlist) do
        ---@class CONFIG__TargetList
        ---@field guid string
        ---@field strikeTimes number
        table.insert(temp, { guid = value, strikeTimes = 0 })
    end

    return temp
end
