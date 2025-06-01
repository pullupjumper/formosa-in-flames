local contacts = ScenEdit_GetContacts('China')
local ship = ScenEdit_UnitX()

if ship and ship.dbid == CONFIG.platformDBID48 then
  -- local check = SE_GetUnit({ guid = ship.guid })
  -- ScenEdit_SpecialMessage('China', ship.name)

  if ship.group and contacts then
    -- ScenEdit_SpecialMessage('China', ship.group.name)

    -- local filteredContacts = FilterContacts(contacts, function(contact)
    --   return contact:inArea(CONFIG.c.PHIBOP.sag[ship.group.name].area)
    --       and (contact.typed == 8)
    -- end)
    local filteredContacts = {}

    for _, contact in ipairs(contacts) do
      if contact:inArea(CONFIG.c.PHIBOP.sag[ship.group.name].area) and (contact.typed == 8) then
        table.insert(filteredContacts, contact)
      end
    end

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
