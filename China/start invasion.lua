local STRIKE_ON_FACILITY = gKH.State.LoadTableFromKey("STRIKE_ON_FACILITY")
STRIKE_ON_FACILITY.IS_STRIKE_ON_FACILITY_ACTIVATED = true
ScenEdit_GetEvent('(China) (Landing operation) Landing ships move to area').isActive = true
ScenEdit_GetEvent('(China) (SRBM kill chain) Strike on SAMs').isActive = true
ScenEdit_GetEvent('(China) (SRBM kill chain) Launch H6N').isActive = true

ScenEdit_SetSidePosture("China", "Taiwan", "H")
ScenEdit_SetSidePosture("Taiwan", "China", "H")

for index, group in ipairs(SAG_OBJECT) do
    local unit = SE_GetUnit({ guid = group.guid })

    if unit ~= nil then
        unit.course = group.course
    end
end

if STRIKE_ON_FACILITY ~= nil then
    gKH.State.SaveTableToKey(STRIKE_ON_FACILITY, "STRIKE_ON_FACILITY")
end
-- local mission = ScenEdit_AddMission('China', 'AIRLANDING', 'Cargo',
--     { zone = { 'RP-328', 'RP-329', 'RP-330', 'RP-331' } })
-- local base = ScenEdit_GetUnit({ name = 'Type 075 Yushen [31 Hainan]', guid = 'X58F5H-0HMVP21FBP790' })
-- local platforms = base.embarkedUnits['Aircraft']
-- for k, v in ipairs(platforms) do
--     local unit = SE_GetUnit({ guid = v })

--     ScenEdit_AssignUnitToMission(unit.guid, 'AIRLANDING')
-- end

-- ScenEdit_SetMission('China', 'AIRLANDING', {
--     Subtype = 'delivery',
--     OneThirdRule = true,
--     TransitThrottleAircraft = 'Military',
--     TransitAltitudeAircraft = 1000,
--     StationThrottleAircraft = 'Afterburner',
--     StationAltitudeAircraft = 1000,
--     MoveAllCargo = true
-- })
