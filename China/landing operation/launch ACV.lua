local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

local contacts = ScenEdit_GetContacts('China')
local ship = ScenEdit_UnitX()

if ship and (ship.dbid == CONFIG.const.platformBDID7
        or ship.dbid == CONFIG.const.platformBDID8
        or ship.dbid == CONFIG.const.platformBDID9) then
    if ship.group then
        local group = SE_GetUnit({ guid = ship.group.guid })

        if group and GetCount(group.course) > 0 then
            group.course = nil
            group.manualSpeed = 0
            group.holdposition = true
        end
    end

    for _, zone in ipairs(CONFIG.c.landingOperation.const.operationalZones) do
        if ship:inArea(zone.ACV.area) then
            LaunchACV({
                ship = ship,
                num = 3,
                bearing = zone.ACV.bearing,
                distance = zone.ACV.distance,
                speed = zone.ACV.speed,
                destination = zone.ACV.destination
            })
        end
    end
end

if ship and ship.dbid == CONFIG.const.platformBDID48 then
    if ship.group and contacts then
        local filteredContacts = FilterContacts(contacts, function(contact)
            return contact:inArea(CONFIG.c.landingOperation.const.sag[ship.group.guid].area)
                and (contact.typed == 8)
        end)

        if GetCount(filteredContacts) > 0 then
            local launchedNum = AttackContacts(
                filteredContacts,
                440 // GetCount(filteredContacts),
                { ship },
                2691
            )
        end
    end
end
