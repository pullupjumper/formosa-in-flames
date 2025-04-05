local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

-- for _, runway in ipairs(CONFIG.c.srbm.const.contingencyRunways) do
--     local contact = ScenEdit_GetContact({ side = "China", guid = runway.base.guid })

--     if contact then
--         if unit and unit.base.guid == contact.actualunitid then
--             unit.readytime = CONFIG.const.readytime
--             -- ScenEdit_SpecialMessage('Taiwan', tostring(unit.readytime))
--         end
--     end
-- end

unit.readytime = CONFIG.const.readytime
-- unit.mission = ''
