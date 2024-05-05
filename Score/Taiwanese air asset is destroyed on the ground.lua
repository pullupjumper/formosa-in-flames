local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit == nil then
    return
end

-- ScenEdit_MsgBox(unit.base.guid, 1)


if unit.condition == 'Parked' then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.const.aircraftIsDestroyedOnTheGround),
        "An aircraft is destoryed on the ground"
    )
end

if unit.base.guid == CONFIG.c.slcm.const.baseGUID then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore(
        "Taiwan",
        (score + CONFIG.s.const.aircraftIsDestroyedInHangar),
        "An aircraft is destoryed in hangar."
    )
end
