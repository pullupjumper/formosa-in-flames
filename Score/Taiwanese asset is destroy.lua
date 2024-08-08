local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit then
    local score = ScenEdit_GetScore("Taiwan")
    -- if unit.type == 'Aircraft' then
    --     if unit.condition == 'Parked' then
    --         ScenEdit_SetScore(
    --             "Taiwan",
    --             (score + CONFIG.s.const.aircraftIsDestroyedOnTheGround),
    --             "An aircraft is destoryed on the ground"
    --         )
    --     end
    -- end

    if unit.type == 'Facility' then
        -- if unit.dbid == CONFIG.const.platformBDID14 or unit.dbid == CONFIG.const.platformBDID15 then
        --     ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.samIsDestroyed), "A SAM battery is destoryed")
        -- end

        if unit.dbid == CONFIG.const.platformBDID26 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.undergroundShelterIsDestroyed),
                "Underground shelter has been destoryed"
            )
        end

        if unit.dbid == CONFIG.const.platformBDID27 then
            for _, battery in ipairs(CONFIG.t.srbm.batteries) do
                if unit.guid == battery.wpnStorageFacility then
                    battery.position.magazineWeapenNum = 0
                end
            end

            for _, battery in ipairs(CONFIG.t.glcm.batteries) do
                if unit.guid == battery.wpnStorageFacility then
                    battery.position.magazineWeapenNum = 0
                end
            end

            ScenEdit_SpecialMessage('Taiwan', "Weapon storage facility has been destoryed")
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
