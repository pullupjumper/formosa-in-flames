local contact = ScenEdit_UnitC()
local units = VP_GetSide({ Side = 'China' }).units
local latitude = contact.latitude
local longitude = contact.longitude
local temp = { unit = nil, distance = CONFIG.const.radarDistance }
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")
ScenEdit_SpecialMessage('China', 'event is activated.')


if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

for _, value in ipairs(units) do
    local u = ScenEdit_GetUnit({ guid = value.guid })

    if u ~= nil then
        local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

        if u.dbid == CONFIG.const.platformBDID19
            or u.dbid == CONFIG.const.platformBDID20 then
            if u.IsDecoy == false and distance < temp.distance then
                temp.unit = u
                temp.distance = distance
            end
        end
    end
end

if temp.unit ~= nil then
    local result = ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    ScenEdit_SpecialMessage('China', tostring(temp.unit.name))
end
