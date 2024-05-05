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
                "A helicopter is destroyed on the ground."
            )
        elseif unit.dbid == CONFIG.const.platformBDID12 or unit.dbid == CONFIG.const.platformBDID13 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.uav),
                "A recon UAV is destroyed."
            )
        end
    end

    if unit.type == 'Ship' then
        if unit.dbid == CONFIG.const.platformBDID7
            or unit.dbid == CONFIG.const.platformBDID8
            or unit.dbid == CONFIG.const.platformBDID9
            or unit.dbid == CONFIG.const.platformBDID10 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lst), "A LST is destroyed.")
        elseif unit.dbid == CONFIG.const.platformBDID6 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.lhd), "A LHD is destroyed.")
        elseif unit.dbid == CONFIG.const.platformBDID11 then
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.cv), "A carrier is destroyed.")
        else
            ScenEdit_SetScore("Taiwan", (score + CONFIG.s.const.ddg), "A ship is destroyed.")
        end
    end

    if unit.type == 'Submarine' then
        ScenEdit_SetScore(
            "Taiwan",
            (score + CONFIG.s.const.sub),
            "A submarine is destroyed."
        )
    end

    if unit.type == 'Facility' then
        if unit.dbid == CONFIG.const.platformBDID23 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.destroyingSupply),
                "A landed supply is destroyed."
            )

            CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = CONFIG.c.mlrs.batteries[2].position
                .magazineWeapenNum - 72

            if CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum < 0 then
                CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = 0
            end
        elseif unit.dbid == CONFIG.const.platformBDID22 or unit.dbid == CONFIG.const.platformBDID24 then
            ScenEdit_SetScore(
                "Taiwan",
                (score + CONFIG.s.const.mlrs),
                "A MLRS launcher is destroyed."
            )
        end
    end

    if unit.type == 'Ground unit' then

    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
