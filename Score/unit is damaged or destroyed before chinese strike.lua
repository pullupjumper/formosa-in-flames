local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if unit then
    local score = ScenEdit_GetScore("Taiwan")
    ScenEdit_SetScore(
        "Taiwan", (score + CONFIG.s.const.attackBeforeTheHHour),
        "Attacked before the Chinese missile strike."
    )
    ScenEdit_SpecialMessage(
        'Taiwan',
        'You have attacked first and caused a military esclaion.',
        { latitude = unit.latitude, longitude = unit.longitude }
    )
end
-- ScenEdit_SpecialMessage('Taiwan', 'enter')
-- if unit then
--     local targets = unit.targetedBy

--     for _, guid in ipairs(targets) do
--         local target = SE_GetUnit({ guid = guid })

--         if target then
--             ScenEdit_SpecialMessage('Taiwan', tostring(target.name))

--             if (target.type ~= 'Submarine') and (target.dbid ~= CONFIG.s.const.weaponDBID) then
--                 local score = ScenEdit_GetScore("Taiwan")
--                 ScenEdit_SetScore(
--                     "Taiwan", (score + CONFIG.s.const.attackBeforeTheHHour),
--                     "Attack before the H hour."
--                 )
--                 ScenEdit_SpecialMessage(
--                     'Taiwan',
--                     'You have attacked first and caused a military esclaion.',
--                     { latitude = unit.latitude, longitude = unit.longitude }
--                 )
--             end
--         end
--     end
-- end
