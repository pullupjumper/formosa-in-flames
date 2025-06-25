AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
Utils = require("src.utils.utils")
GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")

local ship, err = Utils.SafeCall("GameApi.ScenEdit_UnitX", GameApi.ScenEdit_UnitX)

if not ship then
  Logger.error("Error in ScenEdit_UnitX: " .. err)
  return
end

if AmphibiousAssault.IsFerryOrLST(CONFIG, ship) then
  -- if ship.group then
  --   local group = SE_GetUnit({ guid = ship.group.guid })

  --   if group and Utils.GetCount(group.course) > 0 then
  --     group.course = nil
  --     group.manualSpeed = 0
  --     group.holdposition = true
  --   end
  -- end

  local zone = AmphibiousAssault.GetShipZone(CONFIG, ship)

  if zone then
    local count = AmphibiousAssault.LaunchACV({
      ship = ship,
      num = 5,
      bearing = zone.ACV.bearing + 90,
      distance = zone.ACV.distance,
      speed = zone.ACV.speed,
      destination = zone.ACV.destination
    })

    if count == 0 then
      local result, err = Utils.SafeCall("GameApi.ScenEdit_HostUnitToParent", GameApi.ScenEdit_HostUnitToParent, {
        HostedUnitNameOrID = ship.guid,
        SelectedBaseNameOrID = zone.baseGUID
      })

      if not result then
        Logger.error("Error in ScenEdit_HostUnitToParent: " .. err)
        return
      end
      -- ScenEdit_HostUnitToParent({
      --   HostedUnitNameOrID = ship.guid,
      --   SelectedBaseNameOrID = zone.baseGUID
      -- })
      ship:RTB(true)
    end
  end
  -- for _, zone in ipairs(CONFIG.c.PHIBOP.operationalZones) do
  --   if ship:inArea(zone.ACV.area) then
  --     local result = AmphibiousAssault.LaunchACV({
  --       ship = ship,
  --       num = 5,
  --       bearing = zone.ACV.bearing + 90,
  --       distance = zone.ACV.distance,
  --       speed = zone.ACV.speed,
  --       destination = zone.ACV.destination
  --     })

  --     if result == 0 then
  --       ScenEdit_HostUnitToParent({
  --         HostedUnitNameOrID = ship.guid,
  --         SelectedBaseNameOrID = zone.baseGUID
  --       })
  --       ship:RTB(true)
  --     end
  --   end
  -- end
end
