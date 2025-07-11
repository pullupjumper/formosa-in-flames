local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()

-- for _, runway in ipairs(CONFIG.c.srbm.contingencyRunways) do
--     local contact = ScenEdit_GetContact({ side = "China", guid = runway.base.guid })

--     if contact then
--         if unit and unit.base.guid == contact.actualunitid then
--             unit.readytime = CONFIG.readytime
--             -- ScenEdit_SpecialMessage('Taiwan', tostring(unit.readytime))
--         end
--     end
-- end

unit.readytime = config.readytime
-- unit.mission = ''
