local unit = ScenEdit_UnitX()
local units = VP_GetSide({ Side = 'China' }).units
local temp = { unit = nil, distance = CONFIG.const.radarDistance }
local latitude = unit.latitude
local longitude = unit.longitude
local isDestroyed = false
-- ScenEdit_MsgBox(tostring(unit.name .. ' is damaged'), 1)

for index, component in ipairs(unit.components) do
    if (component['comp_dbid'] == CONFIG.const.sensorBDID1
            or component['comp_dbid'] == CONFIG.const.sensorBDID2
            or component['comp_dbid'] == CONFIG.const.sensorBDID3
            or component['comp_dbid'] == CONFIG.const.sensorBDID4
            or component['comp_dbid'] == CONFIG.const.sensorBDID5
            or component['comp_dbid'] == CONFIG.const.sensorBDID6)
        and component['comp_status'] == 'Destroyed' then
        ScenEdit_MsgBox(tostring(unit.name .. ' is damaged'), 1)
        ScenEdit_MsgBox(tostring(component['comp_dbid']), 1)
        ScenEdit_MsgBox(tostring(component['comp_status']), 1)
        isDestroyed = true
    end
end

if isDestroyed then
    for index, value in ipairs(units) do
        local u = ScenEdit_GetUnit({ guid = value.guid })

        if u ~= nil then
            local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

            if u.dbid == CONFIG.const.platformBDID18
                or u.dbid == CONFIG.const.platformBDID19
                or u.dbid == CONFIG.const.platformBDID20
                or u.dbid == CONFIG.const.platformBDID21 then
                for i, component in ipairs(u.components) do
                    if (component['comp_dbid'] == CONFIG.const.sensorBDID1
                            or component['comp_dbid'] == CONFIG.const.sensorBDID2
                            or component['comp_dbid'] == CONFIG.const.sensorBDID3
                            or component['comp_dbid'] == CONFIG.const.sensorBDID4
                            or component['comp_dbid'] == CONFIG.const.sensorBDID5
                            or component['comp_dbid'] == CONFIG.const.sensorBDID6)
                        and component['comp_status'] ~= 'Destroyed' then
                        if distance < temp.distance and unit.guid ~= u.guid then
                            temp.unit = u
                            temp.distance = distance
                        end
                    end
                end
            end
        end
    end
end

if temp.unit ~= nil then
    local result = ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    -- ScenEdit_MsgBox(tostring(result), 1)
    -- ScenEdit_MsgBox(tostring(temp.unit.name), 1)
end
