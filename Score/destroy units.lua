local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
    return
end

if unit then
    local score = ScenEdit_GetScore("Taiwan")

    if unit.type == 'Aircraft' then
        if unit.condition == 'Parked' and unit.dbid == CONFIG.platformDBID5 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.destroyingAircraftOnTheGround),
                "Destroyed an helicopter on the ground."
            )
        elseif unit.dbid == CONFIG.platformDBID12 or unit.dbid == CONFIG.platformDBID13 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.uav),
                "Destroyed a recon UAV."
            )
        end
    end

    if unit.type == 'Ship' then
        if unit.dbid == CONFIG.platformDBID7
            or unit.dbid == CONFIG.platformDBID8
            or unit.dbid == CONFIG.platformDBID9
            or unit.dbid == CONFIG.platformDBID10 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.lst), "You have destroyed a ship (LST).")
        elseif unit.dbid == CONFIG.platformDBID6 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.lhd), "You have destroyed a ship (LHD).")
        elseif unit.dbid == CONFIG.platformDBID11 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.cv), "You have destroyed a carrier.")
        else
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.ddg), "You have destroyed a ship.")
        end
    end

    if unit.type == 'Submarine' then
        ScenEdit_SetScore(
            "Taiwan",
            (score + CONFIG.s.sub),
            "You have destroyed a submarine."
        )
    end

    if unit.type == 'Facility' then
        if unit.dbid == CONFIG.platformDBID23 then
            -- ScenEdit_SetScore(
            --     "Taiwan",
            --     (score + CONFIG.s.destroyingSupply),
            --     "You have destroyed a landed supply."
            -- )

            -- CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = CONFIG.c.mlrs.batteries[2].position
            --     .magazineWeapenNum - 72

            -- if CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum < 0 then
            --     CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = 0
            -- end
        elseif unit.dbid == CONFIG.platformDBID22 or unit.dbid == CONFIG.platformDBID24 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.mlrs),
                "You have destroyed a MLRS."
            )
        elseif unit.dbid == CONFIG.platformDBID25 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.mlrs),
                "You have destroyed a GPS jammer."
            )
            TurnOffGPSEffectByUnit(unit)
        elseif unit.dbid == CONFIG.platformDBID27 then
            -- for _, battery in ipairs(CONFIG.c.glcm.batteries) do
            --     if unit.guid == battery.wpnStorageFacility then
            --         battery.position.magazineWeapenNum = 0
            --     end
            -- end

            -- for _, battery in ipairs(CONFIG.c.mlrs.batteries) do
            --     if unit.guid == battery.wpnStorageFacility then
            --         battery.position.magazineWeapenNum = 0
            --     end
            -- end

            ScenEdit_SpecialMessage('Taiwan', "You have destroyed a weapon storage facility.")
        elseif unit.dbid == CONFIG.platformDBID50 then
            DestroyAmmoSecHandler(unit, 'China', 'mlrs', saveData)
            DestroyAmmoSecHandler(unit, 'China', 'srbm', saveData)
            DestroyAmmoSecHandler(unit, 'China', 'glcm', saveData)
            ScenEdit_SpecialMessage('Taiwan', "You have destroyed an ammunition section.")
        end
    end

    if unit.type == 'Ground unit' then

    end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
