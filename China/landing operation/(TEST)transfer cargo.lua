local units = VP_GetSide({ Side = 'China' }).units
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

for index, info in ipairs(CONFIG.c.landingOperation.const.cargoInfoForTransfer) do
    for i, v in ipairs(units) do
        local u = SE_GetUnit({ guid = v.guid })

        if u ~= nil and u.dbid == CONFIG.const.platformBDID6 and u:inArea(info.anchorageArea) then
            transferCargo(
                u.guid,
                'Boats',
                info.boat.dbid,
                info.boat.cargoList
            )
            transferCargo(
                u.guid,
                'Aircraft',
                info.tansportHelicopter.dbid,
                info.tansportHelicopter.cargoList
            )
            assignEmbarkedUnitsToMission(
                u.guid,
                'Boats',
                info.boat.dbid,
                info.boat.missions
            )
            assignEmbarkedUnitsToMission(
                u.guid,
                'Aircraft',
                info.tansportHelicopter.dbid,
                info.tansportHelicopter.missions
            )
            assignUnitToFerryMission(
                u.guid,
                13,
                info.attackHelicopter1.dbid,
                'Aircraft',
                info.attackHelicopter1.missions[1]
            )
            assignUnitToFerryMission(
                u.guid,
                13,
                info.attackHelicopter2.dbid,
                'Aircraft',
                info.attackHelicopter2.missions[1]
            )
        end

        if u ~= nil and u.dbid == CONFIG.const.platformBDID7 and u:inArea(info.anchorageArea) then
            transferCargo(
                u.guid,
                'Boats',
                info.boat.dbid,
                info.boat.cargoList
            )
            transferCargo(
                u.guid,
                'Aircraft',
                info.tansportHelicopter.dbid,
                info.tansportHelicopter.cargoList
            )
            assignEmbarkedUnitsToMission(
                u.guid,
                'Boats',
                info.boat.dbid,
                info.boat.missions
            )
            assignEmbarkedUnitsToMission(
                u.guid,
                'Aircraft',
                info.tansportHelicopter.dbid,
                info.tansportHelicopter.missions
            )
        end
    end
end

CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = true
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
