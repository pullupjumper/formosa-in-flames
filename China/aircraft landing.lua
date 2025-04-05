local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if unit then
    if unit.dbid == CONFIG.const.platformBDID28
        or unit.dbid == CONFIG.const.platformBDID29
        or unit.dbid == CONFIG.const.platformBDID30
        or unit.dbid == CONFIG.const.platformBDID31
        or unit.dbid == CONFIG.const.platformBDID36
        or unit.dbid == CONFIG.const.platformBDID57 then
        unit.readytime = CONFIG.const.readytime
        unit.mission = ''

        -- if unit.mission ~= nil and unit.mission.isactive and unit.mission.subtype == 'Land Strike' then
        --     unit.mission.isactive = false
        -- end
    end

    -- if unit.dbid == CONFIG.const.platformBDID2 then
    --     ScenEdit_SpecialMessage('China', tostring(unit.base.guid) .. tostring(unit.name))
    --     -- updateCargo(unit.base, unit, CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter)

    --     -- transferCargo(
    --     --     unit.base.guid,
    --     --     'Aircraft',
    --     --     unit.dbid,
    --     --     CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
    --     -- )
    --     ScenEdit_UpdateUnitCargo({
    --         guid = unit.base.guid,
    --         mode = 'remove_cargo',
    --         cargo = { {
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.num,
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.dbid,
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.type
    --         } }
    --     })

    --     local result = ScenEdit_UpdateUnitCargo({
    --         guid = unit.guid,
    --         mode = 'add_cargo',
    --         cargo = { {
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.num,
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.dbid,
    --             CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter.type
    --         } }
    --     })
    --     ScenEdit_SpecialMessage('China', tostring(result.cargo))
    -- end
end
