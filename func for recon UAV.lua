---@param num number
---@param list table<number, CMO__Unit>
function IsDestroyedOrRTB(list, num)
    local times = 0

    for index, value in ipairs(list) do
        local unit = SE_GetUnit({ guid = value.unit })

        if unit == nil or (unit.unitstate == 'RTB_Manual' or unit.unitstate == 'RTB') then
            times = times + 1
        end

        if times >= num then
            return true
        end
    end

    return false
end

---@param baseGUID string
---@param course CMO__TableOfWaypoints
---@param num number
---@param unitDBID string
---@param unitType string @ Aircraft or Boats
function LaunchUnits(baseGUID, course, num, unitDBID, unitType)
    local base = ScenEdit_GetUnit({ guid = baseGUID })
    local count = 0
    local temp = {}
    if base == nil or base.embarkedUnits[unitType] == nil then return end

    for k, v in ipairs(base.embarkedUnits[unitType]) do
        local unit = ScenEdit_GetUnit({ guid = v })
        if unit == nil then goto continue end

        if unit.dbid == unitDBID and unit.readytime_v == 0 and count < num then
            unit:Launch(true)
            unit.course = course
            -- ScenEdit_SetUnit({ guid = unit.guid, course = course })
            count = count + 1
            table.insert(temp, { unit = unit.guid, hasLaunched = false })
        end

        if count >= num then break end
        ::continue::
    end

    return temp
end

---@param h6n CMO__Unit
---@param course CMO__TableOfWaypoints
---@param contact CMO__Contact
function LaunchWZ8(h6n, course, contact)
    local wz8 = ScenEdit_AddUnit({
        side = 'China',
        type = 'Aircraft',
        name = 'WZ-8',
        dbid = 6642,
        LATITUDE = h6n.latitude,
        LONGITUDE = h6n.longitude,
        loadoutid = 32885,
        altitude = 20574,
        heading = 180,
        speed = 3300
    })

    if wz8 == nil then
        ScenEdit_MsgBox('wz8 is nil', 1)
        return
    end

    -- local arcT = { 'PB1', 'PB2', 'SB1', 'SB2', 'SMF1', 'PMF2' };
    -- ScenEdit_UpdateUnit({ guid = wz8.guid, mode = 'add_sensor', dbid = 6073, arc_detect = arcT, arc_track = arcT })
    ScenEdit_SetEMCON('Unit', wz8.guid, 'Radar=Active')

    if course == nil and contact ~= nil then
        ScenEdit_SetDoctrine(
            { guid = wz8.guid },
            { weapon_control_status_air = 1, fuel_state_rtb = 0, withdraw_on_fuel = 0, automatic_evasion = 0 }
        )

        local distance = Tool_Range(h6n.guid, contact.guid)
        local shortDistance = distance / 2
        local bearing = Tool_Bearing(h6n.guid, contact.guid)
        local initialPosition = World_GetPointFromBearing({
            latitude = h6n.latitude,
            longitude = h6n.longitude,
            distance = shortDistance,
            bearing = bearing
        })
        local finalPosition = World_GetPointFromBearing({
            latitude = h6n.latitude,
            longitude = h6n.longitude,
            distance = distance,
            bearing = bearing
        })
        course = {
            { lat = 'N 27.04.39', lon = 'E 122.14.20', desiredAltitude = 30480, desiredSpeed = 3300 },
            { lat = 'N 24.57.09', lon = 'E 121.31.35', desiredAltitude = 30480, desiredSpeed = 3300 },
        }

        course[1].lat = initialPosition.latitude
        course[1].lon = initialPosition.longitude
        course[2].lat = finalPosition.latitude
        course[2].lon = finalPosition.longitude
    end

    wz8.course = course
    h6n:RTB(true)
    return wz8
end
