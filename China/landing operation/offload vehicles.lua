local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end

local ship = ScenEdit_UnitX()

if ship and ship.name == 'Barge' then
    if saveData.c.PHIBOP.barges[ship.guid] and saveData.c.PHIBOP.barges[ship.guid].bridgeGUID then
        local bridge = SE_GetUnit({ guid = saveData.c.PHIBOP.barges[ship.guid].bridgeGUID })
        if bridge == nil then goto continue end

        for index, guid in ipairs(saveData.c.PHIBOP.barges[ship.guid].roros) do
            local roro = SE_GetUnit({ guid = guid })
            if roro == nil then goto continue end

            for _, zone in ipairs(CONFIG.c.PHIBOP.operationalZones) do
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
            dbid      = CONFIG.platformDBID71,
            unitname  = 'bridge',
        })

        if bridge then
            saveData.c.PHIBOP.barges[ship.guid].bridgeGUID = bridge.guid
        end
    end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
