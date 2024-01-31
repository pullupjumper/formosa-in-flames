local ship = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

--launchAmphibiousIFV(ship, transitDistanceIFV, degree3, speedIFV)
if ship == nil then
    return
end

if ship.dbid == CONFIG.const.platformBDID7 then
    launchAmphibiousIFV({
        ship = ship,
        num = 40,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.south.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.south.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed
    })
elseif ship.dbid == CONFIG.const.platformBDID8 or ship.dbid == CONFIG.const.platformBDID9 then
    launchAmphibiousIFV({
        ship = ship,
        num = 10,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.south.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.south.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed
    })
end


-- launchAmphibiousIFV({
--     ship = ship,
--     num = 10,
--     bearing = degree4,
--     distance = 0.05,
--     transitDistance = transitDistanceIFV,
--     transitBearing = degree3,
--     speed = speedIFV
-- })
