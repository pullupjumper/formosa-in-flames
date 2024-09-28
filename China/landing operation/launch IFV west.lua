local ship = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

--launchAmphibiousIFV(ship, transitDistanceIFV, degree1, speedIFV)
if ship == nil then
    return
end

if ship.dbid == CONFIG.const.platformBDID7 then
    LaunchAmphibiousIFV({
        ship = ship,
        num = 40,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.west.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.west.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed,
        destination = CONFIG.c.landingOperation.const.shipInfo.heading.west.destination

    })
elseif ship.dbid == CONFIG.const.platformBDID8 or ship.dbid == CONFIG.const.platformBDID9 then
    LaunchAmphibiousIFV({
        ship = ship,
        num = 10,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.west.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.west.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed,
        destination = CONFIG.c.landingOperation.const.shipInfo.heading.west.destination

    })
end


-- launchAmphibiousIFV({
--     ship = ship,
--     num = 10,
--     bearing = degree2,
--     distance = 0.05,
--     transitDistance = transitDistanceIFV,
--     transitBearing = degree1,
--     speed = speedIFV
-- })
