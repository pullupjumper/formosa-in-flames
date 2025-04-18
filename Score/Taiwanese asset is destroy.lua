local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end

if unit then
    local score = ScenEdit_GetScore("Taiwan")
    -- if unit.type == 'Aircraft' then
    --     if unit.condition == 'Parked' then
    --         ScenEdit_SetScore(
    --             "Taiwan",
    --             (score + CONFIG.s.aircraftIsDestroyedOnTheGround),
    --             "An aircraft is destoryed on the ground"
    --         )
    --     end
    -- end

    if unit.type == 'Facility' then
        -- if unit.dbid == CONFIG.platformDBID14 or unit.dbid == CONFIG.platformDBID15 then
        --     ScenEdit_SetScore("Taiwan", (score + CONFIG.s.samIsDestroyed), "A SAM battery is destoryed")
        -- end

        if unit.dbid == CONFIG.platformDBID26 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.undergroundShelterIsDestroyed),
                "Underground shelter has been destoryed"
            )
        end

        -- if unit.dbid == CONFIG.platformDBID27 then
        --     for _, battery in ipairs(CONFIG.t.ground.srbm.batteries) do
        --         if unit.guid == battery.wpnStorageFacility then
        --             battery.position.magazineWeapenNum = 0
        --         end
        --     end

        --     for _, battery in ipairs(CONFIG.t.ground.glcm.batteries) do
        --         if unit.guid == battery.wpnStorageFacility then
        --             battery.position.magazineWeapenNum = 0
        --         end
        --     end

        --     ScenEdit_SpecialMessage('Taiwan', "Weapon storage facility has been destoryed")
        -- end

        if unit.dbid == CONFIG.platformDBID50 then
            DestroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
            DestroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
            DestroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
            ScenEdit_SpecialMessage('Taiwan', "An ammunition section has been destoryed.")
        end

        if unit.dbid == CONFIG.platformDBID53 then
            DestroyAmmoSecHandler(unit, 'Taiwan', 'mlrs', saveData)
            DestroyAmmoSecHandler(unit, 'Taiwan', 'srbm', saveData)
            DestroyAmmoSecHandler(unit, 'Taiwan', 'glcm', saveData)
            ScenEdit_SpecialMessage('Taiwan', "An ammunition has been destoryed.")
        end
    end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
