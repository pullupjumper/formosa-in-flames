local unit = ScenEdit_UnitX()
local contacts = ScenEdit_GetContacts('China')

if contacts then
    for _, contact in ipairs(contacts) do
        if unit and unit.guid == contact.actualunitid then
            contact:DropContact()
        end
    end
end
