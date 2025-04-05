local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

local ship = ScenEdit_UnitX()

if ship and ship.name == 'Barge' then
    if CONFIG.c.PHIBOP.barges[ship.guid] and CONFIG.c.PHIBOP.barges[ship.guid].bridgeGUID then
        local bridge = SE_GetUnit({ guid = CONFIG.c.PHIBOP.barges[ship.guid].bridgeGUID })
        if bridge == nil then goto continue end

        for index, guid in ipairs(CONFIG.c.PHIBOP.barges[ship.guid].roros) do
            local roro = SE_GetUnit({ guid = guid })
            if roro == nil then goto continue end

            for _, zone in ipairs(CONFIG.c.PHIBOP.const.operationalZones) do
                local d = Tool_Range(roro.guid, ship.guid)

                if roro:inArea(zone.ACV.area) and ship:inArea(zone.ACV.area) and d < 1 then
                    OffloadVehicles({
                        ship = roro,
                        num = 20,
                        bearing = zone.ACV.bearing + 90,
                        distance = zone.ACV.distance,
                        firstDistance = 1
                    })
                end
            end

            ::continue::
        end

        ::continue::
    else
        ship.course = nil
        ship.manualSpeed = 0
        ship.holdposition = true
        local bridge = ScenEdit_AddUnit({
            side      = 'China',
            type      = 'Facility',
            latitude  = ship.latitude,
            longitude = ship.longitude,
            dbid      = CONFIG.const.platformBDID71,
            unitname  = 'bridge',
        })

        if bridge then
            CONFIG.c.PHIBOP.barges[ship.guid].bridgeGUID = bridge.guid
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
