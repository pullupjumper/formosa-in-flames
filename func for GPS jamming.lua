function NewArea(position, mode)
    local side = mode.side
    local shape = mode.shape
    if side == nil or shape == nil then return false end
    local name = (mode.name or "RP")
    local bear_offset = (mode.bear_offset or 0)
    local rpTable = {}
    local a = 1
    --Circle
    if shape == 'circle' then
        local distance = mode.distance
        for i = 0, 359, 45 do
            local location = World_GetPointFromBearing({
                latitude = position.latitude,
                longitude = position.longitude,
                distance = distance,
                bearing = i
            })
            local rp = ScenEdit_AddReferencePoint({
                side = side,
                latitude = location.latitude,
                longitude = location.longitude
            })
            a = a + 1
            table.insert(rpTable, rp.name)
        end
    elseif shape == 'square' then
        local distance = mode.distance
        for i = 0, 3 do
            local b = 45 + (90 * i) + bear_offset
            local location = World_GetPointFromBearing({
                latitude = position.latitude,
                longitude = position.longitude,
                distance = distance,
                bearing = b
            })
            local rp = ScenEdit_AddReferencePoint({
                side = side,
                latitude = location.latitude,
                longitude = location.longitude
            })
        end
    end

    return (rpTable)
end

-- function UnitEntersAreaEvent(name, FilterType, area, script, mode, exit, isRepeatable, isActive)
--     if isRepeatable == nil then isRepeatable = false end
--     if isActive == nil then isActive = true end
--     if exit == nil then exit = false end
--     if mode == 'add' then
--         local retval, result = pcall(ScenEdit_SetTrigger,
--             {
--                 description = name .. '',
--                 mode = 'add',
--                 type = 'UnitEntersArea',
--                 TargetFilter = FilterType,
--                 Area =
--                     area,
--                 ExitArea = exit
--             })
--         if not retval then
--             print("[ERROR]:" .. result .. " - trigger:" .. name)
--             return false
--         end
--         local retval, result = pcall(ScenEdit_SetAction,
--             { mode = 'add', type = 'LuaScript', name = name .. '', ScriptText = script })
--         if not retval then
--             print("[ERROR]: " .. result .. '- trigger:' .. name)
--             return false
--         end
--         ScenEdit_SetEvent(name, { mode = 'add', IsRepeatable = isRepeatable, isActive = isActive, isShown = true })
--         ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '' })
--         ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '' })
--     elseif mode == 'update' then
--         if area ~= nil then
--             ScenEdit_SetTrigger({
--                 description = name .. '',
--                 mode = 'update',
--                 type = 'UnitEntersArea',
--                 TargetFilter = FilterType,
--                 Area = area,
--                 ExitArea = exit
--             })
--         end
--         if script ~= nil then
--             ScenEdit_SetAction({ mode = 'update', type = 'LuaScript', name = name .. '', ScriptText = script })
--         end
--     elseif mode == 'remove' then
--         ScenEdit_SetTrigger({ description = name .. '', mode = 'remove' })
--         ScenEdit_SetAction({ description = name .. '', mode = 'remove' })
--         ScenEdit_SetEvent(name, { mode = 'remove' })
--     end
-- end

-- function GPSJamming()
--     local weapon = UnitX() -- Unit that trigger the events
--     local weaponU

--     if weapon then
--         weaponU = SE_GetUnit({ guid = weapon.guid }) --Unit Wrapper of the Unit
--     end
--     -- ScenEdit_MsgBox(tostring(CONFIG.c.GPSJamming.GPSGuidedWeapons[1]),1)

--     for _, wpn in ipairs(CONFIG.c.GPSJamming.GPSGuidedWeapons) do
--         if weaponU and weaponU.dbid == wpn.dbid then
--             if math.random(100) > wpn.jammingResistance then
--                 if weaponU.course then
--                     local count = GetCount(weaponU.course)
--                     local last_waypoint

--                     if count == 0 then
--                         last_waypoint = { latitude = weaponU.target.latitude, longitude = weaponU.target.longitude }
--                     else
--                         last_waypoint = weaponU.course[count]
--                     end

--                     local lat = last_waypoint.latitude
--                     local lon = last_waypoint.longitude
--                     --Amount of deviation

--                     lat = lat + math.random(-100, 100) / 10 ^ 4
--                     lon = lon + math.random(-100, 100) / 10 ^ 4
--                     -- We change the course of the weapon assigning the new latitude and longitude info
--                     if count == 1 or count == 0 then -- If the unit only has the terminal point
--                         weaponU.target = { latitude = lat, longitude = lon, GUID = 'BOL' }
--                         weaponU.course = { { latitude = lat, longitude = lon, TypeOf = 'TerminalPoint' } }
--                     else -- For weapons with a predefined course of waypoints, we maintain all the waypoints
--                         local newCourse = {}
--                         for k, v in ipairs(weaponU.course) do
--                             if k ~= count then
--                                 newCourse[k] = v
--                             else
--                                 newCourse[k] = { latitude = lat, longitude = lon, TypeOf = 'TerminalPoint' }
--                             end
--                         end
--                         weaponU.course = newCourse
--                         weaponU.target = { latitude = lat, longitude = lon, GUID = 'BOL' }
--                     end
--                 end
--             end
--         end
--     end
-- end

function RemoveJammingZones()
    local s = VP_GetSide({ name = 'China' })
    if s == nil then return end

    for _, zone in ipairs(s.standardzones) do
        for _, jammer in ipairs(CONFIG.c.GPSJamming.jammers) do
            if zone.description == jammer.zoneName then
                local myz = s:getstandardzone(zone.guid)

                for _, area in ipairs(myz.area) do
                    ScenEdit_DeleteReferencePoint({ side = "China", name = area.name })
                end

                ScenEdit_RemoveZone('China', -925, { Description = myz.description })
                ScenEdit_DeleteUnit({ side = "China", unitname = jammer.name })
            end
        end
    end
end

-- function AddGPSJammingZones()
--     for _, jammer in ipairs(CONFIG.c.GPSJamming.jammers) do
--         local point = CircularRandomPosition(jammer.point.lat, jammer.point.lon, jammer.randomRadius)
--         local unit = ScenEdit_AddUnit({
--             type = 'Facility',
--             unitname = jammer.name,
--             dbid = 764,
--             side = 'China',
--             Lat = point.latitude,
--             Lon = point.longitude,
--             autodetectable = false
--         })

--         if unit then
--             ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')
--             local area = NewArea(point, { side = 'China', shape = 'circle', distance = jammer.radius })
--             local zone = ScenEdit_AddZone('China', -925, { description = jammer.zoneName, area = area, })
--             zone.enablers = { GNSS_GLONASS = true, GNSS_GPS = false, GNSS_BeiDou = true, GNSS_NavIC = true }
--         end
--     end
-- end

function TryAddJammerUnit(jammer, attempt, max_attempts)
    attempt = attempt or 1
    max_attempts = max_attempts or 50

    local point = CircularRandomPosition(jammer.point.lat, jammer.point.lon, jammer.randomRadius)
    local unit = ScenEdit_AddUnit({
        type = 'Facility',
        unitname = jammer.name,
        dbid = 764,
        side = 'China',
        Lat = point.latitude,
        Lon = point.longitude,
        autodetectable = false
    })

    if unit then
        return unit, point
    elseif attempt < max_attempts then
        return TryAddJammerUnit(jammer, attempt + 1, max_attempts)
    else
        print("Failed to create jammer unit after " .. max_attempts .. " attempts: " .. jammer.name)
        return nil, nil
    end
end

function AddGPSJammingZones()
    for _, jammer in ipairs(CONFIG.c.GPSJamming.jammers) do
        local unit, point = TryAddJammerUnit(jammer)

        if unit then
            ScenEdit_SetEMCON('Unit', unit.guid, 'OECM=Active')

            local area = NewArea(point, {
                side = 'China',
                shape = 'circle',
                distance = jammer.radius
            })

            local zone = ScenEdit_AddZone('China', -925, {
                description = jammer.zoneName,
                area = area
            })

            zone.enablers = {
                GNSS_GLONASS = true,
                GNSS_GPS = false,
                GNSS_BeiDou = true,
                GNSS_NavIC = true
            }
        end
    end
end

function TurnOffGPSEffectByUnit(unit)
    local s = VP_GetSide({ name = 'China' })
    if s == nil then return end

    for index, jammer in ipairs(CONFIG.c.GPSJamming.jammers) do
        if unit.name ~= jammer.name then goto continue end

        for _, zone in ipairs(s.standardzones) do
            if zone.description == jammer.zoneName then
                local myz = s:getstandardzone(zone.guid)
                myz.enablers = { GNSS_GLONASS = true, GNSS_GPS = true, GNSS_BeiDou = true, GNSS_NavIC = true }
            end
        end

        ::continue::
    end
end
