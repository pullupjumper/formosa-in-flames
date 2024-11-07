local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")
local units = VP_GetSide({ Side = 'China' }).units

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if unit then
    unit.group = '5th Bn, 73rd Arty Bde'
    unit.holdposition = true
    ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })

    if CONFIG.c.ground.mlrs.batteries[unit.group.guid] == nil then
        CONFIG.c.ground.mlrs.batteries[unit.group.guid] = {
            name = '5th Bn, 73rd Arty Bde',
            guid = unit.group.guid,
            reloadStartTime = nil,
            state = CONFIG.const.batteryState.RESUPPLY,
            position = CONFIG.c.ground.mlrs.const.position.penghu,
            weaponDBID = 4471,
            wpnStorageFacility = ''
        }
    end

    if GetCount(CONFIG.c.ground.mlrs.ammunitionSections) == 1 then
        for _, val in ipairs(units) do
            local supply = SE_GetUnit({ guid = val.guid })

            if supply and supply.dbid == CONFIG.const.platformBDID50 then
                supply.group = 'Ammo Sec, 5th Bn, 73rd Arty Bde'

                if CONFIG.c.ground.mlrs.ammunitionSections[supply.group.guid] == nil then
                    CONFIG.c.ground.mlrs.ammunitionSections[supply.group.guid] = {
                        name = 'Ammo Sec, 5th Bn, 73rd Arty Bde',
                        guid = supply.group.guid,
                        wpnCurrent = 0,
                        wpnDefault = 64,
                        unitNum = 2
                    }
                end

                CONFIG.c.ground.mlrs.ammunitionSections[supply.group.guid].wpnCurrent = CONFIG.c.ground.mlrs
                    .ammunitionSections[supply.group.guid].wpnCurrent + 32
            end
        end
    end


    if CONFIG.c.ground.mlrs.packages[2] == nil then
        CONFIG.c.ground.mlrs.packages[2] = {
            name = '',
            targetList = {},
            batteries = {
                { name = '5th Bn, 73rd Arty Bde', guid = unit.group.guid }
            },
            area = { 'RP-8016', 'RP-8017', 'RP-8018', 'RP-8019' },
            num = 8,
            index = 1,
            isFinished = false
        }
        CONFIG.c.ground.mlrs.packages[2].targetList[1] = InitTargetList('China', 'STRIKE/C2/SOUTH')
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
