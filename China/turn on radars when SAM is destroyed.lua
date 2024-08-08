local unit = ScenEdit_UnitX()
local units = VP_GetSide({ Side = 'China' }).units
local temp = { unit = nil, distance = CONFIG.const.radarDistance }

if unit == nil then
    ScenEdit_SpecialMessage('China', 'unit == nil')
    return
end

local latitude = unit.latitude
local longitude = unit.longitude
local isDestroyed = false

for _, component in ipairs(unit.components) do
    if (component['comp_dbid'] == CONFIG.const.sensorBDID1
            or component['comp_dbid'] == CONFIG.const.sensorBDID2
            or component['comp_dbid'] == CONFIG.const.sensorBDID3
            or component['comp_dbid'] == CONFIG.const.sensorBDID4
            or component['comp_dbid'] == CONFIG.const.sensorBDID5
            or component['comp_dbid'] == CONFIG.const.sensorBDID6)
        and component['comp_status'] == 'Destroyed' then
        ScenEdit_SpecialMessage('China', tostring(unit.name .. '\'s radar is damaged'))
        ScenEdit_SpecialMessage('China', tostring(component['comp_dbid']))
        ScenEdit_SpecialMessage('China', tostring(component['comp_status']))
        isDestroyed = true
    end
end

if isDestroyed then
    for _, value in ipairs(units) do
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
    ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    ScenEdit_SpecialMessage('China', tostring(temp.unit.name) .. '\'s radar is activated.')
end
