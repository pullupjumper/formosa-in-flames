NASAMS_POSITIONS = {
    { lat = 'N 25.04.34', lon = 'E 121.14.06' },
    { lat = 'N 25.03.26', lon = 'E 121.20.34' },
    { lat = 'N 25.04.14', lon = 'E 121.33.09' },
}

for index, value in ipairs(NASAMS_POSITIONS) do
    local unit = ScenEdit_AddUnit({
        side = 'Taiwan',
        type = 'Facility',
        name = 'NASAMS #'..index,
        dbid = 2261,
        LATITUDE = value.lat,
        LONGITUDE = value.lon,
    })

    ScenEdit_SetUnitIntermittentEmissionConfig(unit.guid, 'Green',
        {
            UseEmissionInterval = 1,
            EmissionDuration = 60,
            EmissionInterval = 120,
            WakeWhenDetectingThreat = 1,
            SleepModeDelay = 30
        })
    
end
