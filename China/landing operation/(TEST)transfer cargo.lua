local units = VP_GetSide({ Side = 'China' }).units
local LANDING_OPERATION = gKH.State.LoadTableFromKey("LANDING_OPERATION")


for index, info in ipairs(LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER) do
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

LANDING_OPERATION.IS_AMPHIBIOUS_LANDING_ATTACK_LAUNCHED = true

if LANDING_OPERATION ~= nil then
    gKH.State.SaveTableToKey(LANDING_OPERATION, "LANDING_OPERATION")
end
