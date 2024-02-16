local unit = ScenEdit_UnitX()
local units = VP_GetSide({ Side = 'China' }).units
local temp = { unit = nil, distance = CONFIG.const.radarDistance }
local latitude = unit.latitude
local longitude = unit.longitude
ScenEdit_MsgBox(tostring(unit.name .. ' is destroyed'), 1)


for index, value in ipairs(units) do
    local u = SE_GetUnit({ guid = value.guid })

    if u ~= nil then
        local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

        if (u.dbid == 2537 or u.dbid == 2538) then
            if distance < temp.distance then
                temp.unit = u
                temp.distance = distance
            end
        end
    end
end

if temp.unit == nil then
    for index, value in ipairs(units) do
        local u = SE_GetUnit({ guid = value.guid })

        if u ~= nil then
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
        end
    end
end

if temp.unit ~= nil then
    local result = ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    ScenEdit_MsgBox(tostring(result), 1)
    ScenEdit_MsgBox(tostring(temp.unit.name), 1)
end
