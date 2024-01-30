local ship = ScenEdit_UnitX()
local LANDING_OPERATION = gKH.State.LoadTableFromKey("LANDING_OPERATION")

--launchAmphibiousIFV(ship, transitDistanceIFV, degree1, speedIFV)
if ship == nil then
    return
end

if ship.dbid == PLATFORM_DBID_7 then
    launchAmphibiousIFV({
        ship = ship,
        num = 40,
        bearing = LANDING_OPERATION.SHIP_INFO.heading.west.horizontal,
        distance = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleHorizontalDistance,
        transitDistance = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleTransitDistance,
        transitBearing = LANDING_OPERATION.SHIP_INFO.heading.west.vertical,
        speed = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleSpeed
    })
elseif ship.dbid == PLATFORM_DBID_8 or ship.dbid == PLATFORM_DBID_9 then
    launchAmphibiousIFV({
        ship = ship,
        num = 10,
        bearing = LANDING_OPERATION.SHIP_INFO.heading.west.horizontal,
        distance = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleHorizontalDistance,
        transitDistance = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleTransitDistance,
        transitBearing = LANDING_OPERATION.SHIP_INFO.heading.west.vertical,
        speed = LANDING_OPERATION.SHIP_INFO.amphibiousVehicleSpeed
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
