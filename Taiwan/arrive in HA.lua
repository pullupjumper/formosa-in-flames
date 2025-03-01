local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")
local contacts = ScenEdit_GetContacts('China')

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if contacts then
    for _, contact in ipairs(contacts) do
        if unit and unit.guid == contact.actualunitid then
            contact:DropContact()
        end
    end
end
