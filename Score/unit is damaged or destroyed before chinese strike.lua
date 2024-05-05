local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit then
    local targets = unit.targetedBy
    -- ScenEdit_MsgBox(tostring(targets[1]), 1)
    -- ScenEdit_MsgBox(tostring(unit.pickedUpBy), 1)


    for _, guid in ipairs(targets) do
        local target = SE_GetUnit({ guid = guid })

        if target then
            if (target.type ~= 'Submarine') and (target.dbid ~= CONFIG.s.const.weaponDBID) then
                local score = ScenEdit_GetScore("Taiwan")
                ScenEdit_SetScore(
                    "Taiwan", (score + CONFIG.s.const.attackBeforeTheHHour),
                    "Attack before the H hour."
                )
                ScenEdit_SpecialMessage(
                    'Taiwan',
                    CONFIG.s.const.msg.attackBeforeTheHHour,
                    { latitude = unit.latitude, longitude = unit.longitude }
                )
            end
        end
    end
end
