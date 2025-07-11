local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()


if unit then
  local score = GameApi.ScenEdit_GetScore("Taiwan")
  GameApi.ScenEdit_SetScore(
    "Taiwan", (score + config.s.attackBeforeTheHHour),
    "Attacked before the Chinese missile strike."
  )
  GameApi.ScenEdit_SpecialMessage(
    'Taiwan',
    'You have attacked first to cause a military esclaion.',
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

--             if (target.type ~= 'Submarine') and (target.dbid ~= CONFIG.s.weaponDBID) then
--                 local score = ScenEdit_GetScore("Taiwan")
--                 ScenEdit_SetScore(
--                     "Taiwan", (score + CONFIG.s.attackBeforeTheHHour),
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
