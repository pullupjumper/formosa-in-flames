AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")

local ship = ScenEdit_UnitX()

if ship and (ship.dbid == CONFIG.platformDBID7
      or ship.dbid == CONFIG.platformDBID8
      or ship.dbid == CONFIG.platformDBID9
      or ship.dbid == CONFIG.platformDBID10
      or ship.name == 'Ferry') then
  if ship.group then
    local group = SE_GetUnit({ guid = ship.group.guid })

    if group and GetCount(group.course) > 0 then
      group.course = nil
      group.manualSpeed = 0
      group.holdposition = true
    end
  end

  for _, zone in ipairs(CONFIG.c.PHIBOP.operationalZones) do
    if ship:inArea(zone.ACV.area) then
      local result = AmphibiousAssault.LaunchACV({
        ship = ship,
        num = 5,
        bearing = zone.ACV.bearing + 90,
        distance = zone.ACV.distance,
        speed = zone.ACV.speed,
        destination = zone.ACV.destination
      })

      if result == 0 then
        ScenEdit_HostUnitToParent({
          HostedUnitNameOrID = ship.guid,
          SelectedBaseNameOrID = zone.baseGUID
        })
        ship:RTB(true)
      end
    end
  end
end
