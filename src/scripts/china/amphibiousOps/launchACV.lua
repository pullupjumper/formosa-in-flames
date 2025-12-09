local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end

if AmphibiousAssault.isFerryOrLST(ship) then
  local zone = AmphibiousAssault.getShipZone(config.c.PHIBOP, ship)

  if zone then
    local count = AmphibiousAssault.launchACV({
      ship = ship,
      num = 5,
      bearing = zone.ACV.bearing + 90,
      distance = zone.ACV.distance,
      speed = zone.ACV.speed,
      destination = zone.ACV.destination
    })

    if count == 0 then
      local result = GameApi.ScenEdit_HostUnitToParent({
        HostedUnitNameOrID = ship.guid,
        SelectedBaseNameOrID = zone.baseGUID
      })

      if not result then
        return
      end

      ship:RTB(true)
    end
  end
end
