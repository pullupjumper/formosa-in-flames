local ship = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end


if ship == nil then
    return
end

if ship.dbid == CONFIG.const.platformBDID7 then
    launchAmphibiousIFV({
        ship = ship,
        num = 40,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.north.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.north.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed
    })
elseif ship.dbid == CONFIG.const.platformBDID8 or ship.dbid == CONFIG.const.platformBDID9 then
    launchAmphibiousIFV({
        ship = ship,
        num = 10,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.north.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.north.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed
    })
end


-- if LANDING_OPERATION ~= nil then
--     gKH.State.SaveTableToKey(LANDING_OPERATION, "LANDING_OPERATION")
-- end
-- launchAmphibiousIFV({
--     ship = ship,
--     num = 10,
--     bearing = degree4,
--     distance = 0.05,
--     transitDistance = transitDistanceIFV,
--     transitBearing = degree3,
--     speed = speedIFV
-- })
