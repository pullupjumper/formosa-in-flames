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
                        local toatalQtyFired = 0
                        local defaultNum = 1
                        local mountDBID = unit.mounts[1]['mount_dbid']
                        local mountIndex = 1
                        local wpnIndex = 1
                        local isHold = ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == 2
                            or ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == '2'

                        for _, mount in ipairs(unit.mounts) do
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

                        if weaponDBID == nil then
                            weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
                        end

                        for _, item in ipairs(ScenEdit_WeaponAllocation(guid, '', '')) do
                            totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
                            toatalQtyFired = toatalQtyFired + item.qtyFired
                        end

                        local isLessThan = totalQtyAssigned < totalWpnDefaultNum
                        local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned

                        if totalWpnCurrentNum >= qty then
                            defaultNum = qty
                        else
                            defaultNum = totalWpnCurrentNum
                        end

                        if totalWpnCurrentNum > 0 and not isHold and isLessThan and isCurrentQtyMoreThan then
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
                local toatalQtyFired = 0
                local defaultNum = 1
                local mountDBID = group.mounts[1]['mount_dbid']
                local mountIndex = 1
                local wpnIndex = 1
                local isHold = ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == 2
                    or ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == '2'

                for _, mount in ipairs(group.mounts) do
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

                if weaponDBID == nil then
                    weaponDBID = group.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
                end

                for _, item in ipairs(ScenEdit_WeaponAllocation(group.guid, '', '')) do
                    totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
                    toatalQtyFired = toatalQtyFired + item.qtyFired
                end

                local isLessThan = totalQtyAssigned < totalWpnDefaultNum
                local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned

                if totalWpnCurrentNum >= qty then
                    defaultNum = qty
                else
                    defaultNum = totalWpnCurrentNum
                end

                -- local isLessThan = GetCount(ScenEdit_WeaponAllocation(group.guid, '', '')) < totalWpnDefaultNum

                if totalWpnCurrentNum > 0 and not isHold and isLessThan and isCurrentQtyMoreThan then
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
        else
            break
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

function CountUnits(CONFIG)
    local unitsFromChina = VP_GetSide({ Side = 'China' }).units
    local result = {}

    for _, zone in ipairs(CONFIG.c.landingOperation.const.operationalZones) do
        local item = {
            zbd05 = 0,
            ztd05 = 0,
            pll05 = 0,
            plz96 = 0,
            pgz09 = 0,
            pgz95 = 0,
        }
        for index, value in ipairs(unitsFromChina) do
            local unit = SE_GetUnit({ guid = value.guid })

            if unit and unit:inArea(zone.area) then
                if unit.dbid == 241 then
                    item.zbd05 = item.zbd05 + 1
                end

                if unit.dbid == 240 then
                    item.ztd05 = item.ztd05 + 1
                end

                if unit.dbid == 318 then
                    item.pll05 = item.pll05 + 1
                end

                if unit.dbid == 319 then
                    item.plz96 = item.plz96 + 1
                end

                if unit.dbid == 2876 then
                    item.pgz09 = item.pgz09 + 1
                end

                if unit.dbid == 758 then
                    item.pgz95 = item.pgz95 + 1
                end
            end
        end

        result[zone.name] = item
    end

    for key, item in pairs(result) do
        ScenEdit_SpecialMessage('Taiwan', 'zbd05: ' .. item.zbd05)
        ScenEdit_SpecialMessage('Taiwan', 'ztd05: ' .. item.ztd05)
        ScenEdit_SpecialMessage('Taiwan', 'pll05: ' .. item.pll05)
        ScenEdit_SpecialMessage('Taiwan', 'plz96: ' .. item.plz96)
        ScenEdit_SpecialMessage('Taiwan', 'pgz09: ' .. item.pgz09)
        ScenEdit_SpecialMessage('Taiwan', 'pgz95: ' .. item.pgz95)
        ScenEdit_SpecialMessage('Taiwan', key .. '===============')
    end
end

function ToggleC2Form()
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
        return
    end

    local createRow = function(body)
        -- local key = 't'

        -- if side == 'China' then
        --     key = 'c'
        -- end

        for index, item in pairs(CONFIG.t.IADS.ROCC) do
            local len = GetCount(item.SAM) + GetCount(item.radar)
            local count = 0

            for _, sam in pairs(item.SAM) do
                local unit = SE_GetUnit({ guid = sam.guid })
                local isDestroyed = unit == nil

                if count == 0 then
                    body = body .. string.format(
                        '<tr><td rowspan="%s">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                        len,
                        item.name,
                        sam.name,
                        tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
                        tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
                        sam.isOutOfComms,
                        sam.EMCON_Setting,
                        isDestroyed
                    )
                else
                    body = body .. string.format(
                        '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                        sam.name,
                        tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
                        tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
                        sam.isOutOfComms,
                        sam.EMCON_Setting,
                        isDestroyed
                    )
                end
                count = count + 1
            end

            for _, radar in pairs(item.radar) do
                local unit = SE_GetUnit({ guid = radar.guid })
                local isDestroyed = unit == nil
                body = body .. string.format(
                    '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                    radar.name,
                    tostring(radar.currOODA.detection) .. '/' .. tostring(radar.OODA.detection),
                    tostring(radar.currOODA.targeting) .. '/' .. tostring(radar.OODA.targeting),
                    radar.isOutOfComms,
                    radar.EMCON_Setting,
                    isDestroyed
                )
            end
        end

        for index, item in pairs(CONFIG.t.IADS.TAAOC) do
            local len = GetCount(item.SAM) + GetCount(item.radar)
            local count = 0

            for _, sam in pairs(item.SAM) do
                local unit = SE_GetUnit({ guid = sam.guid })
                local isDestroyed = unit == nil
                if count == 0 then
                    body = body .. string.format(
                        '<tr><td rowspan="%s">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                        len,
                        item.name,
                        sam.name,
                        tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
                        tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
                        sam.isOutOfComms,
                        sam.EMCON_Setting,
                        isDestroyed
                    )
                else
                    body = body .. string.format(
                        '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                        sam.name,
                        tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
                        tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
                        sam.isOutOfComms,
                        sam.EMCON_Setting,
                        isDestroyed
                    )
                end
                count = count + 1
            end
        end

        return body
    end

    local msg = [[<!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Dark Themed Table</title>
        <style>
            body {
                background-color: #121212;
                color: #ffffff;
                font-family: Arial, sans-serif;
                padding: 20px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-top: 20px;
            }
            th, td {
                padding: 12px;
                text-align: left;
            }
            th {
                background-color: #333333;
                color: #ffffff;
            }
            tr:nth-child(even) {
                background-color: #1e1e1e;
            }
            tr:hover {
                background-color: #444444;
            }
            td {
                border: 1px solid #555555;
            }
        </style>
    </head>
    <body>
        <h1>Dark Themed Table</h1>
        <table>
            <thead>
                <tr>
                    <th>C2 node</th>
                    <th>Name</th>
                    <th>Current/Default OODA detection</th>
                    <th>Current/Default OODA targeting</th>
                    <th>Is out of comms</th>
                    <th>EMCON setting</th>
                    <th>Is destroyed</th>
                </tr>
            </thead>
            <tbody>
    ]]

    local body = ''
    body = createRow(body)
    msg = msg .. body .. [[</tbody>
        </table>
    </body>
    </html>
    ]]

    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function ToggleBtyStatusForm()
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
        return
    end

    local createRow = function(side, type, body)
        local key = 't'

        if side == 'China' then
            key = 'c'
        end

        local rows = {}

        for k, sec in pairs(CONFIG[key].ground[type].ammunitionSections) do
            rows[k] = {}
        end

        for _, bty in pairs(CONFIG[key].ground[type].batteries) do
            local name = bty.name
            local status = ''
            local remainingAmmoInVehicles = CONFIG[key].ground[type].ammunitionSections[bty.ammunitionSection]
                .wpnCurrent
            local remainingAmmo = CONFIG[key].ground[type].ammunitions
                [CONFIG[key].ground[type].ammunitionSections[bty.ammunitionSection].ammunition].wpnCurrent
            local reloadingRemainingTime = nil

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
                reloadingRemainingTime = ScenEdit_CurrentTime() - bty.reloadStartTime
            end

            table.insert(rows[bty.ammunitionSection], {
                name = name,
                type = type,
                status = status,
                remainingAmmoInVehicles = remainingAmmoInVehicles,
                remainingAmmo = remainingAmmo,
                reloadingRemainingTime = reloadingRemainingTime
            })
        end

        for index, row in pairs(rows) do
            for _, value in ipairs(row) do
                if _ == 1 then
                    local len = GetCount(row)
                    body = body .. string.format(
                        '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td rowspan="%s">%s</td><td rowspan="%s">%s</td></tr>',
                        value.name,
                        string.upper(value.type),
                        value.status,
                        value.reloadingRemainingTime,
                        len,
                        value.remainingAmmoInVehicles,
                        len,
                        value.remainingAmmo
                    )
                else
                    body = body .. string.format(
                        '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
                        value.name,
                        string.upper(value.type),
                        value.status,
                        value.reloadingRemainingTime
                    )
                end
            end
        end

        return body
    end

    local msg = [[<!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Dark Themed Table</title>
        <style>
            body {
                background-color: #121212;
                color: #ffffff;
                font-family: Arial, sans-serif;
                padding: 20px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-top: 20px;
            }
            th, td {
                padding: 12px;
                text-align: left;
            }
            th {
                background-color: #333333;
                color: #ffffff;
            }
            tr:nth-child(even) {
                background-color: #1e1e1e;
            }
            tr:hover {
                background-color: #444444;
            }
            td {
                border: 1px solid #555555;
            }
        </style>
    </head>
    <body>
        <h1>Dark Themed Table</h1>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Reloading time</th>
                    <th>Remaining ammo in ammo vehicles</th>
                    <th>Remaining ammo in AHA</th>
                </tr>
            </thead>
            <tbody>
    ]]

    local body = ''
    body = createRow('Taiwan', 'srbm', body)
    body = createRow('Taiwan', 'mlrs', body)
    body = createRow('Taiwan', 'glcm', body)
    body = createRow('Taiwan', 'ascm', body)
    msg = msg .. body .. [[</tbody>
        </table>
    </body>
    </html>
    ]]

    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end
