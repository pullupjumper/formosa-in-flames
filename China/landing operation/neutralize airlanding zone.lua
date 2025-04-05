local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

local contacts = ScenEdit_GetContacts('China')
local ship = ScenEdit_UnitX()

if ship and ship.dbid == CONFIG.const.platformBDID48 then
    -- local check = SE_GetUnit({ guid = ship.guid })
    -- ScenEdit_SpecialMessage('China', ship.name)

    if ship.group and contacts then
        -- ScenEdit_SpecialMessage('China', ship.group.name)

        local filteredContacts = FilterContacts(contacts, function(contact)
            return contact:inArea(CONFIG.c.PHIBOP.const.sag[ship.group.name].area)
                and (contact.typed == 8)
        end)

        if GetCount(filteredContacts) > 0 then
            local launchedNum = AttackContacts(
                filteredContacts,
                440 // GetCount(filteredContacts),
                { ship },
                2691
            )
            -- ScenEdit_SpecialMessage('China', launchedNum .. ' launched')
        end
    end
end
