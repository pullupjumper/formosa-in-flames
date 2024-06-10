local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")
local units = VP_GetSide({ Side = 'China' }).units


if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if unit then
    unit.group = 'MLRS (73th Artillery Brigade 6th Battalion)'
    unit.holdposition = true
    ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })

    if CONFIG.c.mlrs.batteries[2] == nil then
        CONFIG.c.mlrs.batteries[2] = {
            name = 'MLRS (73th Artillery Brigade 6th Battalion)',
            guid = unit.group.guid,
            reloadStartTime = nil,
            state = CONFIG.const.batteryState.RESUPPLY,
            position = CONFIG.c.mlrs.const.position.penghu,
            weaponDBID = 3471,
            wpnStorageFacility = ''
        }
    end

    if CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum == 0 then
        for _, val in ipairs(units) do
            local supply = SE_GetUnit({ guid = val.guid })

            if supply and supply.dbid == CONFIG.const.platformBDID23 then
                CONFIG.c.mlrs.batteries[2].position.magazineWeapenNum = CONFIG.c.mlrs.batteries[2].position
                    .magazineWeapenNum + 72
            end
        end
    end

    if CONFIG.c.mlrs.packages[2] == nil then
        CONFIG.c.mlrs.packages[2] = {
            name = '',
            targetList = {},
            batteries = {
                { name = 'MLRS (73th Artillery Brigade 6th Battalion)', guid = unit.group.guid }
            },
            area = { 'RP-8016', 'RP-8017', 'RP-8018', 'RP-8019' }
        }
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
