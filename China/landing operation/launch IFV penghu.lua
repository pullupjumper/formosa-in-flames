local ship = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if ship == nil then
    return
end

local cargoDBID = nil

if ship.cargo[1] then
    cargoDBID = ship.cargo[1].cargo[1].dbid
end

if ship.dbid == 4601 and cargoDBID and cargoDBID == 3 then
    LaunchAmphibiousIFV({
        ship = ship,
        num = 10,
        bearing = CONFIG.c.landingOperation.const.shipInfo.heading.penghu.horizontal,
        distance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleHorizontalDistance,
        transitDistance = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleTransitDistance,
        transitBearing = CONFIG.c.landingOperation.const.shipInfo.heading.penghu.vertical,
        speed = CONFIG.c.landingOperation.const.shipInfo.amphibiousVehicleSpeed
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
