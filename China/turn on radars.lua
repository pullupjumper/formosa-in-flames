local unit = ScenEdit_UnitX()
local units = VP_GetSide({ Side = 'China' }).units
local temp = { unit = nil, distance = 10000000000000 }
ScenEdit_MsgBox(tostring(unit.name), 1)

for index, value in ipairs(units) do
    local u = SE_GetUnit({ guid = value.guid })

    if u ~= nil then
        local distance = Tool_Range(u.guid, unit.guid)

        if (u.dbid == 2537 or u.dbid == 2538) then
            ScenEdit_MsgBox(tostring(u.name), 1)
            if distance < temp.distance then
                temp.unit = u
                temp.distance = distance
            end
        end
    end
end

local result = ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
ScenEdit_MsgBox(tostring(result), 1)
