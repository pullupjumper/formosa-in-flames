function bL3.AuxFunctions.ImprovedRandomseed(quality)
    if quality == nil then quality = 3 end
    -- os.time() removes dependency on how long the software has been running currently
    -- os.clock() provides miliseconds, unlike os.time()
    -- we "chain" this with previous math.random() output
    -- and "stir" a little by repeating more than once, though not much because the execution time
    -- probably doesn't vary much between calls and spending too much time will be a waste unless we want
    -- to spend several seconds doing this.
    math.randomseed(os.time() + math.random(90071992547)) -- preserve some previous seeding if there was any
    for i = 1, quality do
        -- Retain some previous PRNG state while adding a little jitter entropy, but not much.
        -- Jitter entropy comes from thread preemption, interrupt handing, and stuff like that in the OS that is
        -- somewhat random. This means you might not get much if any on a powerful and calm system.
        -- If we had a higher precision clock with ns instead of just ms then that would be more helpful.
        math.randomseed(((os.clock() * 1000) % 1000) + math.random(900719925470000))
    end
end

function bL3.AuxFunctions.getKeys(t_table)
    local keyset = {}
    local n = 0

    for k, v in pairs(t_table) do
        n = n + 1
        keyset[n] = k
    end
    return keyset
end

function bL3.AuxFunctions.matchWithTable(str, table)
    for pattern, value in pairs(table) do
        if string.match(str, pattern) then
            return value
        end
    end
    return nil -- No se encontró coincidencia
end

function bL3.AuxFunctions.KeyRegex(tabla, regex)
    local claves = {}
    for clave, valor in pairs(tabla) do
        if string.match(clave, regex) then
            table.insert(claves, clave)
        end
    end
    return claves
end

function bL3.AuxFunctions.ACP126(rec_station, snd_station, precedence, from, to, classification, body)
    --rec_station --4 letter code (e.g. YDCX)
    --snd_station --4 letter code +/- NR 3 number (e.g. YBDN NR 270)
    --precedence --Flash (Z), Immediate (O), Priority (P), Routine (R), Flash Override (Y)
    local dtg = bL3.AuxFunctions.DTG()
    --from --e.g. MET FLT OPS
    --to --e.g. SSN 21 SEAWOLF
    --classification --Unclass +/- SBU / FOUO / NOFORN (Restricted), Confidential, Secret, Top Secret
    --body
    local _, gr = body:gsub("%S+", "")
    local sig_string = string.upper('<P><FONT face=Consolas>' .. rec_station .. ' <BR>' ..
        'DE ' .. snd_station .. ' <BR>' ..
        precedence .. ' ' .. dtg .. ' <BR>' ..
        'fm ' .. from .. ' <BR>' ..
        'to ' .. to .. ' <BR>' ..
        'wd gr' .. gr .. ' <BR>' ..
        'bt <BR>' ..
        classification .. ' <BR>' ..
        body .. ' <BR>' ..
        'bt <BR>' ..
        'nnnn </P>')
    return sig_string
end

function bL3.AuxFunctions.getUnit()
    local unit = ScenEdit_SelectedUnits().units[1].name
    return ScenEdit_GetUnit({ name = unit })
end

function bL3.AuxFunctions.RunScript(name)
    ScenEdit_RunScript('Development/Op-Allied-Force/' .. name)
end

function bL3.AuxFunctions.msg(text)
    ScenEdit_SpecialMessage('playerside', text)
end

function bL3.AuxFunctions.KillUnitEvent(luascript, mode, targetFilter)
    ScenEdit_SetTrigger({ mode = mode, type = 'UnitDestroyed', name = 'UnitDestroyed', TargetFilter = targetFilter })

    ScenEdit_SetAction({ mode = 'add', type = 'LuaScript', name = 'Lua-UnitDestroyed', ScriptText = luascript })

    ScenEdit_SetEvent('UnitIsDestroyed', { mode = mode, IsRepeatable = true })
    ScenEdit_SetEventTrigger('UnitIsDestroyed', { mode = mode, name = 'UnitDestroyed' })
    ScenEdit_SetEventAction('UnitIsDestroyed', { mode = mode, name = 'Lua-UnitDestroyed' })
end

function bL3.AuxFunctions.TimeEvent(name, trig_time, luascript, mode, Repeatable)
    local retval, retval1, retval2, event
    local rep = (Repeatable or false)
    if mode == 'add' then -- ADD
        retval, event = pcall(ScenEdit_SetTrigger,
            { mode = 'add', type = 'Time', name = name .. '-trig', time = trig_time })
        if not retval then
            print("[Error at " .. debug.getinfo(1).currentline .. "] - AddTimeEvent: Error adding the trigger. " .. event)
            return nil
        end
        retval, event = pcall(ScenEdit_SetAction,
            { mode = 'add', type = 'LuaScript', name = name .. '-action', ScriptText = luascript })
        if not retval then
            print("[Error at " .. debug.getinfo(1).currentline .. "] - AddTimeEvent: Error adding the action. " .. event)
            return nil
        end
        retval, event = pcall(ScenEdit_SetEvent, name, { mode = 'add', IsRepeatable = rep, isShown = false })
        retval1 = pcall(ScenEdit_SetEventTrigger, name, { mode = 'add', name = name .. '-trig' })
        retval2 = pcall(ScenEdit_SetEventAction, name, { mode = 'add', name = name .. '-action' })
        if retval and retval1 and retval2 then
            return event
        else
            print("[Error at " ..
            debug.getinfo(1).currentline .. "] - TimeEvent failed when creating the event: " .. event)
        end
    elseif mode == 'remove' then
        retval = pcall(ScenEdit_SetEvent, name, { mode = 'remove' })
        retval1 = pcall(ScenEdit_SetTrigger, { description = name .. '-trig', mode = 'remove' })
        retval2 = pcall(ScenEdit_SetAction, { description = name .. '-action', mode = 'remove', })
        if retval and retval1 and retval2 then
            return true
        else
            print("[Error at " ..
                debug.getinfo(1).currentline .. "] - TimeEvent failed when removing the event: " .. name)
        end
    elseif mode == 'update' then --UPDATE
        if trig_time ~= nil then
            retval = pcall(ScenEdit_SetTrigger,
                { mode = 'update', type = 'Time', name = name .. '-trig', time = trig_time })
            retval1, event = pcall(ScenEdit_SetEvent, name, { mode = 'update', isActive = true, isRepeatable = rep })
            if retval and retval1 then
                return event
            else
                print("[Error at " ..
                    debug.getinfo(1).currentline .. "] - TimeEvent failed when updating the event: " .. event)
            end
        end
        if luascript ~= nil then
            retval = pcall(ScenEdit_SetAction, {
                mode = 'update',
                type = 'LuaScript',
                name = name .. '-action',
                ScriptText = luascript
            })
            if retval then
                return true
            else
                print("[Error at " ..
                    debug.getinfo(1).currentline .. "] - TimeEvent failed when updating the event action: " .. event)
            end
        end
    elseif mode == 'remove' then
        ScenEdit_SetEvent(name, { mode = 'remove' })
        ScenEdit_SetAction({ name = name .. '-action', mode = 'remove' })
        ScenEdit_SetTrigger({ name = name .. '-trig', mode = 'remove' })
    end
end

function bL3.AuxFunctions.RegularEvent(name, interval, action, mode)
    local retval, retval1, retval2, event
    if mode == 'add' then
        retval = pcall(ScenEdit_SetTrigger, {
            description = name .. '-trig',
            mode = 'add',
            type = 'RegularTime',
            Interval = interval
        })
        if not retval then
            print("[Error at " ..
                debug.getinfo(1).currentline ..
                "] - AddRegularEvent: Error al añadir el trigger. Compruebe que el nombre del trigger sea único")
            return nil
        end
        retval = pcall(ScenEdit_SetAction,
            { mode = 'add', type = 'LuaScript', name = name .. '-action', ScriptText = action })
        if not retval then
            print("[Error at " ..
                debug.getinfo(1).currentline ..
                "] - AddRegularEvent: Error al añadir la acción. Compruebe que el nombre de la acción sea único")
            return nil
        end
        retval, event = pcall(ScenEdit_SetEvent, name, { mode = 'add', IsRepeatable = true, isShown = false })
        if not retval then
            print("[Error at " .. debug.getinfo(1).currentline .. "] - AddRegularEvent: Error al crear el evento.")
            return nil
        end
        ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '-trig' })
        ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '-action' })
        return event
    elseif mode == 'update' then
        if interval ~= nil then
            retval = pcall(ScenEdit_SetTrigger,
                { description = name .. '-trig', mode = 'update', type = 'RegularTime', Interval = interval })
            retval1, event = pcall(ScenEdit_SetEvent, name, { mode = 'update', name = name .. '-trig' })
            if retval and retval1 then
                return event
            else
                print("[Error at " .. debug.getinfo(1).currentline .. "] - UpdateEventTrigger Failed")
            end
        end
        if action ~= nil then
            retval = pcall(ScenEdit_SetAction, {
                mode = 'update',
                type = 'LuaScript',
                name = name .. '-action',
                ScriptText = action
            })
            retval1, event = pcall(ScenEdit_SetEvent, name, { mode = 'update', name = name .. '-action' })
            if retval and retval1 then
                return event
            else
                print("[Error at " .. debug.getinfo(1).currentline .. "] - UpdateEventAction Failed")
            end
        end
    elseif mode == 'delete' then
        retval = pcall(ScenEdit_SetEvent, name, { mode = 'remove' })
        retval1 = pcall(ScenEdit_SetAction, { mode = 'remove', name = name .. '-action' })
        retval2 = pcall(ScenEdit_SetTrigger, { description = name .. '-trig', mode = 'remove' })
        if not retval or not retval1 or not retval2 then
            print("[Error at " ..
                debug.getinfo(1).currentline .. "] - DeleteEvent Failed")
        else
            return true
        end
    end
end

function imprimirTabla(tabla, nivel)
    nivel = nivel or 0
    local espacio = string.rep("  ", nivel)

    local resultado = {}

    for clave, valor in pairs(tabla) do
        local tipoValor = type(valor)
        if tipoValor == "table" then
            local subtabla = imprimirTabla(valor, nivel + 1)
            table.insert(resultado, espacio .. '"' .. clave .. '": ' .. subtabla)
        elseif tipoValor == "string" then
            table.insert(resultado, espacio .. '"' .. clave .. '": "' .. valor .. '"')
        else
            table.insert(resultado, espacio .. '"' .. clave .. '": ' .. tostring(valor))
        end
    end

    if nivel == 0 then
        print("{\n" .. table.concat(resultado, ",\n") .. "\n}")
    else
        return "{\n" .. table.concat(resultado, ",\n") .. "\n" .. espacio .. "}"
    end
end

---@param name string @ The name of the event
---@param FilterType table @ {TargetSide = 'N8SI1G-0HMNTT9V9303L', TargetSubType = '9001', ShowAllTypes = 'True', TargetType = '2'}
---@param area table @ Table with RefPoints defining the area
---@param script string @ Script action when trigger
---@param exit? boolean @ if true unit Leaves area
---@param isRepeatable? boolean @ Event is repeatable, false by default
---@param isActive? boolean @ Event is active, true by default
function bL3.AuxFunctions.UnitEntersAreaEvent(name, FilterType, area, script, mode, exit, isRepeatable, isActive)
    if isRepeatable == nil then isRepeatable = false end
    if isActive == nil then isActive = true end
    if exit == nil then exit = false end
    if mode == 'add' then
        local retval, result = pcall(ScenEdit_SetTrigger,
            { description = name .. '_Entertrigg', mode = 'add', type = 'UnitEntersArea', TargetFilter = FilterType, Area =
            area, ExitArea = exit })
        if not retval then
            print("[ERROR]:" .. result .. " - trigger:" .. name)
            return false
        end
        local retval, result = pcall(ScenEdit_SetAction,
            { mode = 'add', type = 'LuaScript', name = name .. '-enteraction', ScriptText = script })
        if not retval then
            print("[ERROR]: " .. result .. '- trigger:' .. name)
            return false
        end
        ScenEdit_SetEvent(name, { mode = 'add', IsRepeatable = isRepeatable, isActive = isActive, isShown = false })
        ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '_Entertrigg' })
        ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '-enteraction' })
    elseif mode == 'update' then
        if area ~= nil then
            ScenEdit_SetTrigger({
                description = name .. '_Entertrigg',
                mode = 'update',
                type = 'UnitEntersArea',
                TargetFilter = FilterType,
                Area = area,
                ExitArea = exit
            })
        end
        if script ~= nil then
            ScenEdit_SetAction({ mode = 'update', type = 'LuaScript', name = name .. '-enteraction', ScriptText = script })
        end
    elseif mode == 'remove' then
        ScenEdit_SetTrigger({ description = name .. '_Entertrigg', mode = 'remove' })
        ScenEdit_SetAction({ description = name .. '-action', mode = 'remove' })
        ScenEdit_SetEvent(name, { mode = 'remove' })
    end
end

function bL3.AuxFunctions.UnitDetected(name, side, action, targetFilter)
    ScenEdit_SetTrigger({ name = name .. '_trig', mode = 'add', type = 'UnitDetected', DetectorSideID = VP_GetSide({ side =
    side }).guid, TargetFilter = targetFilter })
    ScenEdit_SetAction({ name = name .. '_lua', mode = 'add', type = 'LuaScript', ScriptText = action })
    ScenEdit_SetEvent(name, { mode = 'add', IsRepeatable = true, isShown = false })
    ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '_trig' })
    ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '_lua' })
end

function bL3.AuxFunctions.shuffle(t)
    bL3.AuxFunctions.ImprovedRandomseed(3)
    local n = #t
    while n > 1 do
        local k = math.random(n) -- Genera un índice aleatorio
        t[n], t[k] = t[k], t[n] -- Intercambia el elemento n con el elemento k
        n = n - 1
    end
end

function bL3.AuxFunctions.RemoveEvent(event_name)
    local event = ScenEdit_GetEvent(event_name)
    if event ~= nil then
        ScenEdit_SetEvent(event_name, { mode = 'remove' })
        for k, v in ipairs(event.actions) do
            for typ, action in pairs(v) do
                if action.ID ~= nil then
                    ScenEdit_SetAction({ description = action.ID, mode = 'remove' })
                end
            end
        end

        for k, v in ipairs(event.triggers) do
            for typ, action in pairs(v) do
                if action.ID ~= nil then
                    ScenEdit_SetTrigger({ description = action.ID, mode = 'remove' })
                end
            end
        end
    end
end

function bL3.AuxFunctions.IsUnitContact(side, unit)
    local side_guid = VP_GetSide({ side = side }).guid
    local ascontact_t = unit.ascontact
    if ascontact_t ~= nil then
        for k, v in ipairs(ascontact_t) do
            if v.side == side_guid then return true, v.guid end
        end
    end
    return false, nil
end

function bL3.AuxFunctions.UnitRemainsInAreaEvent(name, FilterType, area, script, time, isRepeatable)
    local isrep = (isRepeatable or false)
    local retval, result = pcall(ScenEdit_SetTrigger,
        { description = name .. '_trigg', mode = 'add', type = 'UnitRemainsInArea', TargetFilter = FilterType, Area =
        area, TD = time })
    if not retval then
        print("[ERROR]: " .. result .. '- trigger:' .. name)
        return false
    end
    local retval, result = pcall(ScenEdit_SetAction,
        { mode = 'add', type = 'LuaScript', name = name .. '_action', ScriptText = script })
    if not retval then
        print("[ERROR]: " .. result .. '- trigger:' .. name)
        return false
    end
    ScenEdit_SetEvent(name, { mode = 'add', IsRepeatable = isrep, isShown = false })
    ScenEdit_SetEventTrigger(name, { mode = 'add', name = name .. '_trigg' })
    ScenEdit_SetEventAction(name, { mode = 'add', name = name .. '_action' })
end

function bL3.AuxFunctions.ContactInArea(name, FilterType, DetectorSideID, area, script)
    --UNIT DETECTED
    ScenEdit_SetTrigger({ mode = 'add', type = 'UnitDetected', DetectorSideID = DetectorSideID, TargetFilter = FilterType, MCL =
    '2', name = 'UnitIsDetectedbyUS', Area = area })
end

function bL3.AuxFunctions.SetTrigToEvent(event_name, mode, FilterType, area, trig_name)
    local event = ScenEdit_GetEvent(event_name)
    if event == nil then return false end
    if mode == 'add' then

    elseif mode == 'remove' then

    elseif mode == 'update' then
    else
        return false
    end
end

---@diagnostic disable-next-line: lowercase-global
function getUnit()
    local unit = ScenEdit_SelectedUnits().units[1].name
    return ScenEdit_GetUnit({ name = unit })
end

function bL3.AuxFunctions.GetRandomPoint(latitude, longitude, options)
    local function GetPoint(minDistance, maxDistance, minBearing, maxBearing)
        local distance
        if maxDistance >= 1 then
            distance = math.random(minDistance, maxDistance - 1) + math.random()
        else
            distance = bL3.AuxFunctions.RandomFloat(minDistance, maxDistance, 9)
        end
        local bearing = math.random(minBearing, maxBearing)
        local point = World_GetPointFromBearing({ latitude = latitude, longitude = longitude, distance = distance, bearing =
        bearing })
        return point
    end
    local iter = 0
    local minDistance, maxDistance, minBearing, maxBearing = options.minDistance, options.maxDistance, options
    .minBearing, options.maxBearing
    if maxDistance == nil then maxDistance = 10 end
    if minDistance == nil then minDistance = 0 end
    if minBearing == nil then minBearing = 0 end
    if maxBearing == nil then maxBearing = 359 end
    if options.altitude == nil then options.altitude = false end
    if maxDistance < minDistance or maxBearing < minBearing then return nil end
    if options.altitude == true then
        local max_altitude = 0
        local selected_point
        for i = 1, 20 do
            ::redoPointInArea::
            local point = GetPoint(minDistance, maxDistance, minBearing, maxBearing)
            if options.area ~= nil and options.side ~= nil and not bL3.AuxFunctions.PointInArea(point, options.area, options.side) then goto redoPointInArea end
            if World_GetElevation(point) > max_altitude then
                max_altitude = World_GetElevation(point)
                selected_point = point
            end
        end
        return selected_point
    end
    ::redoPosition::
    iter = iter + 1
    if iter > 100 then
        print("No point with find")
        return nil
    end
    local point = GetPoint(minDistance, maxDistance, minBearing, maxBearing)
    if options.mode == nil then return { latitude = point.latitude, longitude = point.longitude } end
    if options.mode == 0 then
        if World_GetElevation(point) > -20 then goto redoPosition end
    else
        if World_GetElevation(point) < 0 then goto redoPosition end
    end
    if options.area ~= nil then
        if bL3.AuxFunctions.PointInArea(point, options.area, options.side) then return { latitude = point.latitude, longitude =
            point.longitude } else goto redoPosition end
    end


    return { latitude = point.latitude, longitude = point.longitude }
end

function bL3.AuxFunctions.translateCourse(course)
    if course == "N" then
        return 0
    elseif course == "S" then
        return 180
    elseif course == "E" then
        return 90
    elseif course == "W" then
        return 270
    elseif course == "NW" then
        return 315
    elseif course == "NE" then
        return 45
    elseif course == "SW" then
        return 225
    elseif course == "SE" then
        return 135
        --do
    end
end

function bL3.AuxFunctions.writeTableInOneLine(tbl)
    local result = "{"
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            result = result .. bL3.AuxFunctions.writeTableInOneLine(value) .. ","
        else
            result = result .. tostring(value) .. ","
        end
    end
    result = result:sub(1, -2) .. "}"
    return result
end

function bL3.AuxFunctions.getWayPoint(distance, ruta, p0, lat, lon)
    --distancia: distance in nm
    --p0 -> deg variance in course
    --lat -> lat orig
    --lon -> lon orig
    local bearing = bL3.AuxFunctions.translateCourse(ruta) + math.random(-p0, p0)
    local pos = World_GetPointFromBearing({ latitude = lat, longitude = lon, bearing = bearing, distance = distance })
    local course = {
        [1] = { latitude = pos.latitude, longitude = pos.longitude, TypeOf = 'ManualPlottedCourseWaypoint' }
    }

    return course
end

function bL3.AuxFunctions.SetUnitCourse(unit, orden, desv)
    local lat_original = unit.latitude
    local lon_original = unit.longitude
    local lat_act = lat_original
    local lon_act = lon_original
    local tbl_ruta = {}
    for distancia, ruta in string.gmatch(orden, "(%d+)(%a+)") do
        local way = bL3.AuxFunctions.getWayPoint(distancia, ruta, desv, lat_act, lon_act)
        lat_act = way[1].latitude
        lon_act = way[1].longitude
        table.insert(tbl_ruta, { TypeOf = 'ManualPlottedCourseWaypoint', latitude = lat_act, longitude = lon_act })
    end
    ScenEdit_SetUnit({ guid = unit.guid, course = tbl_ruta })
end

---comment
---@param position CMO__Location @latitude, longitude
---@param mode table @shape, side, bear_offset, distance
---@return table|nil
function bL3.AuxFunctions.NewArea(position, mode)
    local side = mode.side
    local shape = mode.shape
    if side == nil or shape == nil then return nil end
    local name = (mode.name or nil)
    local bear_offset = (mode.bear_offset or 0)
    local rpTable = {}
    local a = 1
    --Circle
    if shape == 'circle' then
        local distance = mode.distance
        local n = math.random(1, 9999)
        for i = 0, 359, 30 do
            local location = World_GetPointFromBearing({ latitude = position.latitude, longitude = position.longitude, distance =
            distance, bearing = i })
            if name then
                local rp = ScenEdit_AddReferencePoint({ side = side, latitude = location.latitude, longitude = location
                .longitude, name = name .. ' ' .. n })
            else
                local rp = ScenEdit_AddReferencePoint({ side = side, latitude = location.latitude, longitude = location
                .longitude })
            end
            local rp = ScenEdit_AddReferencePoint({ side = side, latitude = location.latitude, longitude = location
            .longitude })
            a = a + 1
            table.insert(rpTable, rp.name)
        end
    elseif shape == 'square' then
        local distance = mode.distance
        for i = 0, 3 do
            local b = 45 + (90 * i) + bear_offset
            local location = World_GetPointFromBearing({ latitude = position.latitude, longitude = position.longitude, distance =
            distance, bearing = i })
            local rp = ScenEdit_AddReferencePoint({ side = side, latitude = location.latitude, longitude = location
            .longitude })
            table.insert(rpTable, rp.name)
        end
    end

    return (rpTable)
end

function bL3.AuxFunctions.DeleteArea(area, side)
    for k, v in ipairs(area) do
        ScenEdit_DeleteReferencePoint({ side = side, name = v })
    end
end

function bL3.AuxFunctions.RandomTxt(numLetters)
    local totTxt = ""
    for i = 1, numLetters do
        totTxt = totTxt .. string.char(math.random(65, 90))
    end
    return totTxt
end

function bL3.AuxFunctions.RandomFloat(min, max, escala)
    if min ~= nil and max ~= nil and min < max then
        return math.random(min * (10 ^ escala), max * (10 ^ escala)) / (10 ^ escala)
    end
    print("RandomFloat: Min or Max nil or Min > Max")
    return 0
end

function bL3.AuxFunctions.RandomPar(min, max)
    local num = math.random(min, max)
    if num % 2 ~= 0 then num = num + 1 end
    return num
end

function bL3.AuxFunctions.Round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function bL3.AuxFunctions.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

---Define a function bL3.AuxFunctions.to check if a point is inside a polygon on a sphere
---@param point any
---@param polygon any
---@return boolean
function bL3.AuxFunctions.PointInArea(point, polygon, side)
    local j = #polygon
    local oddNodes = false
    for i = 1, #polygon do
        local pi = ScenEdit_GetReferencePoint({ side = side, name = polygon[i] })
        local pj = ScenEdit_GetReferencePoint({ side = side, name = polygon[j] })
        if pi == nil or pj == nil then
            print("[Error 344] In Area Function points are nil")
            return false
        end
        if (pi.latitude < point.latitude and pj.latitude >= point.latitude
                or pj.latitude < point.latitude and pi.latitude >= point.latitude) then
            if (pi.longitude + (point.latitude - pi.latitude) /
                    (pj.latitude - pi.latitude) *
                    (pj.longitude - pi.longitude) < point.longitude) then
                oddNodes = not oddNodes
            end
        end
        j = i
    end

    return oddNodes
end

function bL3.AuxFunctions.calculateArea(coords)
    local earthRadius = 6371 -- Radio de la tierra en km
    local total = 0

    if #coords < 3 then
        return 0
    end

    for i = 1, #coords - 1 do
        total = total + (coords[i].longitude - coords[i + 1].longitude) *
            (2 + math.sin(coords[i].latitude * math.pi / 180) +
                math.sin(coords[i + 1].latitude * math.pi / 180))
    end

    -- Cierre el polígono
    total = total + (coords[#coords].longitude - coords[1].longitude) *
        (2 + math.sin(coords[#coords].latitude * math.pi / 180) +
            math.sin(coords[1].latitude * math.pi / 180))

    return math.abs(total) * earthRadius ^ 2 / 2
end

function bL3.AuxFunctions.WeatherReport(outlook)
    if outlook == nil then outlook = 'next forecast at ' .. bL3.AuxFunctions.DTG(ScenEdit_CurrentTime() + 21600) end
    --Generate special message to player
    local weather = ScenEdit_GetWeather() --Get new weather parameters
    local temp, cloud, rain, sea = weather.temp, weather.undercloud, weather.rainfall, weather.seastate

    local f_temp = bL3.AuxFunctions.Round((temp * 1.8) + 32, 0) --Convert to Fahrenheit for philistines
    local precipdesc, clouddesc
    --create rain/precipitation descriptor (based on in-game descriptions)
    if rain == 0 then
        precipdesc = 'nil'
    elseif rain < 5 then
        precipdesc = 'very light'
    elseif rain < 11 then
        precipdesc = 'light'
    elseif rain < 20 then
        precipdesc = 'moderate'
    elseif rain < 30 then
        precipdesc = 'heavy'
    elseif rain < 40 then
        precipdesc = 'very heavy'
    else
        precipdesc = 'extreme'
    end

    --create cloud descriptor (based on in-game descriptions)
    if cloud == 0 then
        clouddesc = 'clear skies'
    elseif cloud < 0.2 then
        clouddesc = 'light low clouds'
    elseif cloud < 0.3 then
        clouddesc = 'light middle clouds'
    elseif cloud < 0.4 then
        clouddesc = 'light high clouds'
    elseif cloud < 0.5 then
        clouddesc = 'moderate low clouds'
    elseif cloud < 0.6 then
        clouddesc = 'moderate middle clouds'
    elseif cloud < 0.7 then
        clouddesc = 'moderate high clouds'
    elseif cloud < 0.8 then
        clouddesc = 'moderate middle clouds & light high clouds'
    elseif cloud < 0.9 then
        clouddesc = 'solid middle clouds & moderate high clouds'
    elseif cloud < 1.0 then
        clouddesc = 'thin fog & solid cloud cover'
    else
        clouddesc = 'thick fog & solid cloud cover'
    end

    --rec_station,snd_station,precedence,from,to,classification,body
    local wx_time = bL3.AuxFunctions.DTG()
    local wx_report = bL3.AuxFunctions.ACP126('TODOS', 'METOPS', 'r', 'HYDROLOGICAL AND METEOROLOGICAL OFFICE',
        'ALL STATIONS',
        'unclass',
        'WX REPORT ' ..
        wx_time ..
        ' - CONUS <BR>AVERAGE TEMP ' ..
        temp ..
        '°C / ' ..
        f_temp .. '°F <BR> SEA STATE ' .. sea .. ' <BR>' .. precipdesc .. ' PRECIPITATION <BR>' .. clouddesc ..
        ' <BR>' .. outlook)
    ScenEdit_SpecialMessage('playerside', wx_report)
    --RegisterMessage(wx_report) --turned off for testing phase
end

function bL3.AuxFunctions.WeatherDrift()
    local weatherBaseline = { undercloud = 0.3, seastate = 1, rainfall = 0, temp = 3 }
    local seastateVariability = math.random(0, 2)
    local rnd = math.random()
    if rnd < 0.4 then
        weatherBaseline.undercloud = 0
    elseif rnd < 0.6 then
        weatherBaseline.undercloud = 0.2
    else
        weatherBaseline.undercloud = 0.8
    end
    local undercloudVariability = bL3.AuxFunctions.RandomFloat(-0.2, 0.2)
    local tempVariability = math.random(-3, 4)
    local rainfallVariability = 0
    if math.random() > 0.15 then rainfallVariability = math.random(1, 4) end

    local newTemp = weatherBaseline.temp + tempVariability
    local newRainfall = weatherBaseline.rainfall + rainfallVariability
    local newUndercloud = weatherBaseline.undercloud + undercloudVariability
    local newSeastate = weatherBaseline.seastate + seastateVariability

    ScenEdit_SetWeather(
        newTemp,     --temp
        newRainfall, --rainfall
        newUndercloud, --undercloud
        newSeastate  --seastate
    )
end

function bL3.AuxFunctions.removekey(table, key)
    for k, v in ipairs(table) do
        for unit_guid, element in pairs(v) do
            if unit_guid == key then
                table[k] = nil
            end
        end
    end
    return table
end

function bL3.AuxFunctions.DTG(TimeVar)
    if TimeVar == nil then
        TimeVar = ScenEdit_CurrentTime()
    end
    local msgtime = os.date("!%d%H%M" .. "Z" .. " " .. "%b %y", TimeVar)
    ---@diagnostic disable-next-line: param-type-mismatch
    msgtime = string.upper(msgtime)
    return msgtime
end

function bL3.AuxFunctions.GetDate(LocalOrZulu)
    if LocalOrZulu == 1 then
        return os.date("%Y/%m/%d ", ScenEdit_CurrentTime())
    else
        return os.date("%Y/%m/%d", ScenEdit_CurrentTime() + bL3.Zulu * 60)
    end
end

function bL3.AuxFunctions.GetTime(LocalOrZulu)
    if LocalOrZulu == 1 then
        return os.date("%H%MZ", ScenEdit_CurrentTime())
    else
        return os.date("%H%M UTC+1", ScenEdit_CurrentTime() + bL3.Zulu * 60 * 60)
    end
end

function bL3.AuxFunctions.ConvertTimeStamp(date)
    local pattern = "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)"
    local runday, runmonth, runyear, runhour, runminute, runseconds = date:match(pattern)
    local convertedTimestamp = os.time({
        year = runyear,
        month = runmonth,
        day = runday,
        hour = runhour,
        min = runminute,
        sec = runseconds
    })
    return convertedTimestamp
end

function bL3.AuxFunctions.sortTablebyType(t, key)
    -- Convertir la tabla de hash a una tabla indexada
    local indexedTable = {}
    for _, value in pairs(t) do
        table.insert(indexedTable, value)
    end

    -- Función de comparación para ordenar por el campo 'Type'
    local function compare(a, b)
        return a[key]:upper() < b[key]:upper()
    end

    -- Ordenar la tabla indexada
    table.sort(indexedTable, compare)

    return indexedTable
end

function bL3.AuxFunctions.RemoveMounts(unit, t_Mounts)
    if t_Mounts == nil then t_Mounts = { [0] = 1 } end
    for k, v in ipairs(unit.mounts) do
        if t_Mounts[v.mount_dbid] == nil then
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_mount', dbid = v.mount_dbid })
        end
    end
end

function bL3.AuxFunctions.MakeUnitDecoy(unit)
    if unit.mounts ~= nil then
        for k, v in ipairs(unit.mounts) do
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_mount', mountid = v.mount_guid })
        end
    end
    if unit.sensors ~= nil then
        for k, v in ipairs(unit.sensors) do
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_sensor', sensorid = v.sensor_guid })
        end
    end
    if unit.magazines ~= nil then
        for k, v in ipairs(unit.magazines) do
            ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_magazine', magid = v.mag_guid })
        end
    end
end

function bL3.AuxFunctions.RemoveSensors(unit)
    for _, v in ipairs(unit.sensors) do
        ScenEdit_UpdateUnit({ guid = unit.guid, mode = 'remove_sensor', dbid = v.sensor_dbid, sensorid = v.sensor_guid })
    end
end

function bL3.AuxFunctions.table_to_json(tbl)
    local json = ""
    local is_array = (#tbl > 0)

    if is_array then
        json = "["
    else
        json = "{"
    end

    local first = true
    for k, v in pairs(tbl) do
        if not first then
            json = json .. ", "
        end
        first = false

        if is_array then
            json = json .. bL3.AuxFunctions.value_to_json(v)
        else
            json = json .. "\"" .. tostring(k) .. "\": " .. bL3.AuxFunctions.value_to_json(v)
        end
    end

    if is_array then
        json = json .. "]"
    else
        json = json .. "}"
    end

    return json
end

function bL3.AuxFunctions.value_to_json(value)
    local t = type(value)
    if t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return "\"" .. value:gsub("\"", "\\\"") .. "\""
    elseif t == "table" then
        return bL3.AuxFunctions.table_to_json(value)
    else
        error("Unsupported value type: " .. t)
    end
end

function bL3.AuxFunctions.IADS_INFO()
    local tmp = [[<!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <title>Informe de Sectores</title>
      <style>
          body {
              font-family: Arial, sans-serif;
              margin: 20px;
          }
          table {
              width: 80%%;
              border-collapse: collapse;
              margin-bottom: 20px;
          }
          .container {
            margin: auto;
            background-color: #1f1f1f;
            padding: 20px;
            border: 2px solid #ffbcbc;
            border-radius: 5px;
          }
          th, td {
              border: 1px solid #ddd;
              text-align: left;
              padding: 8px;
          }
          th {
              color: black;
              background-color: #f2f2f2;
          }
          .sector-title {
              margin-top: 20px;
              font-size: 20px;
          }
      </style>
    </head>
    <body>
      <div class="container">
      %s
      </div>
    </body>
    </html>
    ]]
    local table_tmp = [[<div class="sector" id="%s">
      <div class="sector-title">%s</div>
      <table>
          <thead>
              <tr>
                  <th>Tipo</th>
                  <th>GUID</th>
                  <th>Name</th>
                  <th>Class</th>
                  <th>Detection</th>
                  <th>Targeting</th>
              </tr>
          </thead>
          <tbody>
              %s
          </tbody>
      </table>
    </div>]]
    local row = [[<tr>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    </tr>]]
    local tables = ''
    for k, v in pairs(bL3.Units.SERB.IADS) do
        if type(v) ~= "string" then
            local rows = ''
            print(k)
            for k2, v2 in pairs(v) do
                -- print('-'..k2)
                if type(v2) == 'table' then
                    for _, u in ipairs(v2) do
                        local unit = SE_GetUnit({ guid = u })
                        if unit then
                            rows = rows ..
                            string.format(row, k2, u, unit.name, unit.classname, unit.OODA.detection, unit.OODA
                            .targeting)
                        else
                            rows = rows .. string.format(row, k2, u, 'NA', 'Kill', 'NA', 'NA')
                            -- print('\t'..u)
                            -- print('\tDetection:'..unit.OODA.detection..' | Targeting:'..unit.OODA.targeting)
                        end
                    end
                else
                    local unit = SE_GetUnit({ guid = v2 })
                    if unit then
                        rows = rows .. string.format(row, k2, v2, unit.name, unit.classname, 'NA', 'NA')
                    else
                        unit = SE_GetUnit({ guid = v2 .. '-SERB-IADS' })
                        if unit then
                            rows = rows .. string.format(row, k2, v2, unit.name, unit.classname, 'NA', 'NA')
                        else
                            rows = rows .. string.format(row, k2, v2, 'NA', 'Kill', 'NA', 'NA')
                        end
                    end
                end
            end
            tables = tables .. string.format(table_tmp, k, k, rows)
        end
    end
    local html = string.format(tmp, tables)
    ScenEdit_SpecialMessage('playerside', html)
end

bL3.AuxFunctions.ImprovedRandomseed(3)
