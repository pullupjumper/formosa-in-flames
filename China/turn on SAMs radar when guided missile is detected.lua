local contact = ScenEdit_UnitC()
local units = VP_GetSide({ Side = 'China' }).units

if contact == nil then
    ScenEdit_SpecialMessage('China', 'contact == nil')
    return
end

local latitude = contact.latitude
local longitude = contact.longitude
local temp = { unit = nil, distance = CONFIG.const.radarDistance }
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

for _, value in ipairs(units) do
    local u = ScenEdit_GetUnit({ guid = value.guid })
    if u == nil then goto continue end

    local distance = Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

    if u.dbid == CONFIG.const.platformBDID19 or u.dbid == CONFIG.const.platformBDID20 then
        if u.IsDecoy == false and distance < temp.distance then
            temp.unit = u
            temp.distance = distance
        end
    end

    ::continue::
end

if temp.unit ~= nil then
    ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    printBox('China', tostring(temp.unit.name) .. '\'s radar is activated.')
end
