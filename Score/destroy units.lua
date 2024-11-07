local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit then
    local score = ScenEdit_GetScore("Taiwan")

    if unit.type == 'Aircraft' then
        if unit.condition == 'Parked' and unit.dbid == CONFIG.const.platformBDID5 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.destroyingAircraftOnTheGround),
                "Destroyed an helicopter on the ground."
            )
        elseif unit.dbid == CONFIG.const.platformBDID12 or unit.dbid == CONFIG.const.platformBDID13 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.uav),
                "Destroyed a recon UAV."
            )
        end
    end

    if unit.type == 'Ship' then
        if unit.dbid == CONFIG.const.platformBDID7
            or unit.dbid == CONFIG.const.platformBDID8
            or unit.dbid == CONFIG.const.platformBDID9
            or unit.dbid == CONFIG.const.platformBDID10 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lst), "You have destroyed a ship (LST).")
        elseif unit.dbid == CONFIG.const.platformBDID6 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lhd), "You have destroyed a ship (LHD).")
        elseif unit.dbid == CONFIG.const.platformBDID11 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.cv), "You have destroyed a carrier.")
        else
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.ddg), "You have destroyed a ship.")
        end
    end

    if unit.type == 'Submarine' then
        ScenEdit_SetScore(
            "Taiwan",
            (score + CONFIG.s.const.sub),
            "You have destroyed a submarine."
        )
    end

    if unit.type == 'Facility' then
        if unit.dbid == CONFIG.const.platformBDID23 then
            -- ScenEdit_SetScore(
            --     "Taiwan",
            --     (score + CONFIG.s.const.destroyingSupply),
            --     "You have destroyed a landed supply."
            -- )

            -- CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = CONFIG.c.mlrs.batteries[2].position
            --     .magazineWeapenNum - 72

            -- if CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum < 0 then
            --     CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = 0
            -- end
        elseif unit.dbid == CONFIG.const.platformBDID22 or unit.dbid == CONFIG.const.platformBDID24 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.mlrs),
                "You have destroyed a MLRS."
            )
        elseif unit.dbid == CONFIG.const.platformBDID25 then
            for _, value in ipairs(CONFIG.c.GPSJamming.jammers) do
                if unit.guid == value.guid then
                    local event = ScenEdit_GetEvent(value.eventName)

                    if event then
                        event.isActive = false
                        ScenEdit_SetScore(
                            "Taiwan",
                            (score + CONFIG.s.const.mlrs),
                            "You have destroyed a GPS jammer."
                        )
                    end
                end
            end
        elseif unit.dbid == CONFIG.const.platformBDID27 then
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
        elseif unit.dbid == CONFIG.const.platformBDID50 then
            DestroyAmmoSecHandler(unit, 'China', 'mlrs')
            DestroyAmmoSecHandler(unit, 'China', 'srbm')
            DestroyAmmoSecHandler(unit, 'China', 'glcm')
            ScenEdit_SpecialMessage('Taiwan', "You have destroyed an ammunition section.")
        end
    end

    if unit.type == 'Ground unit' then

    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
