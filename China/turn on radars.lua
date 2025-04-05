local unit = ScenEdit_UnitX()
local units = VP_GetSide({ Side = 'China' }).units
local temp = { unit = nil, distance = CONFIG.const.radarDistance }

if unit == nil then
    ScenEdit_SpecialMessage('China', 'unit == nil')
    return
end

local latitude = unit.latitude
local longitude = unit.longitude

for _, value in ipairs(units) do
    local u = SE_GetUnit({ guid = value.guid })
    if u == nil then goto continue end
    local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

    if (u.dbid == CONFIG.const.platformBDID16 or u.dbid == CONFIG.const.platformBDID17) then
        if distance < temp.distance then
            temp.unit = u
            temp.distance = distance
        end
    end

    ::continue::
end

if temp.unit == nil then
    for _, value in ipairs(units) do
        local u = SE_GetUnit({ guid = value.guid })
        if u == nil then goto continue end

        local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

        if u.dbid == CONFIG.const.platformBDID18
            or u.dbid == CONFIG.const.platformBDID19
            or u.dbid == CONFIG.const.platformBDID20
            or u.dbid == CONFIG.const.platformBDID21 then
            if distance < temp.distance then
                temp.unit = u
                temp.distance = distance
            end
        end

        ::continue::
    end
end

if temp.unit ~= nil then
    ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    printBox('China', tostring(temp.unit.name) .. '\'s radar is activated.')
end
