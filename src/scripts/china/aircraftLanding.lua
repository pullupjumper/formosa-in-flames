local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()

if unit then
  if unit.dbid == config.platform.J20
      or unit.dbid == config.platform.J16
      or unit.dbid == config.platform.SU30
      or unit.dbid == config.platform.H6K
      or unit.dbid == config.platform.J35
      or unit.dbid == config.platform.J10C then
    -- if unit.mission then
    --   local mission = ScenEdit_GetMission('China', unit.mission.guid)

    --   if mission then
    --     for _, u in ipairs(mission.unitlist) do
    --       local actualUnit = ScenEdit_GetUnit({ guid = u })

    --       if actualUnit and actualUnit.dbid == config.platform.Y_9 then
    --         actualUnit:RTB(true)
    --         actualUnit.mission = ''
    --       end

    --       if actualUnit and actualUnit.loadoutdbid == 25378 then
    --         actualUnit:RTB(true)
    --         actualUnit.mission = ''
    --       end
    --     end

    --     if #mission.unitlist == 1 then
    --       ScenEdit_DeleteMission(mission.side, mission.guid)
    --     end
    --   end
    -- end

    unit.readytime = config.readytime
    unit.mission = ''
  end

  -- if unit.dbid == config.platform.Z_18 then
  --     ScenEdit_SpecialMessage('China', tostring(unit.base.guid) .. tostring(unit.name))
  --     -- updateCargo(unit.base, unit, CONFIG.c.landingOperation.cargoItemForTransferForHelicapter)

  --     -- transferCargo(
  --     --     unit.base.guid,
  --     --     'Aircraft',
  --     --     unit.dbid,
  --     --     CONFIG.c.landingOperation.cargoItemForTransferForHelicapter
  --     -- )
  --     ScenEdit_UpdateUnitCargo({
  --         guid = unit.base.guid,
  --         mode = 'remove_cargo',
  --         cargo = { {
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.num,
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.dbid,
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.type
  --         } }
  --     })

  --     local result = ScenEdit_UpdateUnitCargo({
  --         guid = unit.guid,
  --         mode = 'add_cargo',
  --         cargo = { {
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.num,
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.dbid,
  --             CONFIG.c.landingOperation.cargoItemForTransferForHelicapter.type
  --         } }
  --     })
  --     ScenEdit_SpecialMessage('China', tostring(result.cargo))
  -- end
end
