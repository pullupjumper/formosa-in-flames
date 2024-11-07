local function getSIGINT(enemy_unit, notification, isEmitting, isShown, side, data)
    local key = 'u'
    if side == 'China' then key = 'c' end
    if isEmitting == nil then isEmitting = false end

    if not data then data = {} end
    local R = data.R or 255
    local G = data.G or 255
    local B = data.B or 255
    local lifeTime = data.lifeTime or 4
    local fontSize = data.fontSize or 16
    if enemy_unit.guid == nil then
        enemy_unit = SE_GetUnit({ guid = enemy_unit })
        if not enemy_unit then
            print("SIGINT: Enemy Unit does not exists -> " .. enemy_unit)
            return 0
        end
    end
    local function getY(x)
        if x <= 60 then
            return 1
        elseif x >= math.random(300, 340) then
            return 0
        else
            return 2.71 ^ ((-1 / 450) * x ^ 0.8)
        end
    end
    local function getD(x)
        return (0.00007937 * x ^ 3.8518) / (10 ^ 6.1) +
            ((math.random(-120 * x, 120 * x) ^ 2 / 1500000) / 10 ^ 5 * (x ^ 2.25 / 10 ^ 2.4))
    end

    for elint_guid, value in pairs(CONFIG[key].SIGINT.units) do
        local elint_u = SE_GetUnit({ guid = elint_guid })
        local distance = Tool_Range(enemy_unit.guid, elint_guid)
        if elint_u and elint_u.condition == 'Airborne' and math.random() < getY(distance) and isEmitting then
            -- local latitude = enemy_unit.latitude + getD(distance) + math.random() / 10000
            -- local longitude = enemy_unit.longitude + getD(distance) + math.random() / 10000
            local pos = World_GetPointFromBearing({
                latitude = enemy_unit.latitude,
                longitude = enemy_unit.longitude,
                distance = getD(distance),
                bearing = math.random(0, 359)
            })

            if isShown then
                ScenEdit_CreateBarkNotification_Geo(
                    pos.longitude,
                    pos.latitude,
                    notification,
                    R,
                    G,
                    B,
                    true,
                    true,
                    lifeTime,
                    fontSize
                )
            end

            return { longitude = pos.longitude, latitude = pos.latitude, isDetected = true }
        end
    end

    return { longitude = 0, latitude = 0, isDetected = false }
end


local function isInArea(point, area, side)
    local crossings = 0

    if point == nil then
        return false
    end

    local points = ScenEdit_GetReferencePoints({ side = side, area = area })
    local quad = {}

    if points then
        for _, p in ipairs(points) do
            table.insert(quad, { latitude = tonumber(p.latitude), longitude = tonumber(p.longitude) })
        end
    end

    for i = 1, 4 do
        local p1 = quad[i]
        local p2 = quad[(i % 4) + 1]

        -- Check if point is in the vertical range of the edge
        if (p1.latitude > point.latitude) ~= (p2.latitude > point.latitude) then
            -- Find the longitude where the point's latitude intersects the edge
            local intersect_lon = (p2.longitude - p1.longitude) * (point.latitude - p1.latitude) /
                (p2.latitude - p1.latitude) + p1.longitude
            if point.longitude < intersect_lon then
                crossings = crossings + 1
            end
        end
    end

    -- If the number of crossings is odd, the point is inside
    return (crossings % 2 == 1)
end

function HandleSIGINT(CONFIG, units, isShown, side)
    local field = 'u'
    local enermySide = 'China'

    if side == 'China' then
        field = 'c'
        enermySide = 'Taiwan'
    end

    for _, value in pairs(units) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit and math.random() > 0.3 then
            local isEmitting = false

            if unit.dbid and unit.dbid == CONFIG.const.platformBDID46 then
                isEmitting = true
            else
                local count = GetCount(unit.course)
                local isLeavingAssemblyArea = not isInArea(
                    unit.course[count],
                    value.position.assemblyArea.area,
                    enermySide
                )

                if count > 0 and isLeavingAssemblyArea and unit.speed > 0 then
                    isEmitting = true
                end
            end

            local result = getSIGINT(value.guid, value.name, isEmitting, isShown, side)

            if result.isDetected then
                if CONFIG[field].SIGINT.emissions[value.guid] then
                    CONFIG[field].SIGINT.emissions[value.guid].latitude = result.latitude
                    CONFIG[field].SIGINT.emissions[value.guid].longitude = result.longitude
                else
                    local type = 'mobile'

                    if string.find(value.name, 'ROCC') ~= nil or
                        string.find(value.name, 'TAAOC') ~= nil then
                        type = 'C2'
                    end

                    CONFIG[field].SIGINT.emissions[value.guid] = {
                        name = value.name,
                        guid = value.guid,
                        type = type,
                        latitude = result.latitude,
                        longitude = result.longitude,
                        contacts = {},
                        temp = 0,
                        autodetectable = false
                    }
                end

                CONFIG[field].SIGINT.emissions[value.guid].temp = CONFIG[field].SIGINT.emissions[value.guid].temp + 1

                if CONFIG[field].SIGINT.emissions[value.guid].temp > CONFIG[field].SIGINT.const.maxCount then
                    if not CONFIG[field].SIGINT.emissions[value.guid].autodetectable then
                        if unit.group then
                            for _, v in ipairs(unit.group.unitlist) do
                                SE_SetUnit({ guid = v, autodetectable = true })
                            end
                        else
                            SE_SetUnit({ guid = value.guid, autodetectable = true })
                        end

                        CONFIG[field].SIGINT.emissions[value.guid].autodetectable = true
                        -- ScenEdit_MsgBox('autodetectable = true', 0)
                    end
                end
            else
                if CONFIG[field].SIGINT.emissions[value.guid] then
                    if CONFIG[field].SIGINT.emissions[value.guid].temp > CONFIG[field].SIGINT.const.maxCount - 1 then
                        CONFIG[field].SIGINT.emissions[value.guid].temp = CONFIG[field].SIGINT.emissions[value.guid]
                            .temp - 1
                    end

                    if CONFIG[field].SIGINT.emissions[value.guid].autodetectable then
                        if unit.group then
                            for _, v in ipairs(unit.group.unitlist) do
                                SE_SetUnit({ guid = v, autodetectable = false })
                            end
                        else
                            SE_SetUnit({ guid = value.guid, autodetectable = false })
                        end

                        CONFIG[field].SIGINT.emissions[value.guid].autodetectable = false
                        -- ScenEdit_MsgBox('autodetectable = false', 0)
                    end
                end
            end
        end
    end
end
