function WhenRunwayIsDamaged(side)
    local field = (side == 'China') and 'c' or 't'
    local unit = ScenEdit_UnitX()
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage(side, 'CONFIG == nil')
        return
    end

    if not CONFIG[field].repairRunway.isActivated then
        CONFIG[field].repairRunway.isActivated = true
    end

    for _, value in ipairs(CONFIG[field].repairRunway.runways) do
        if unit and unit.guid == value.guid and value.startTime == nil then
            value.startTime = ScenEdit_CurrentTime()
        end
    end

    gKH.State.SaveTableToKey(CONFIG, "CONFIG")
end

function RepairRunway(side)
    local field = (side == 'China') and 'c' or 't'
    local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

    if CONFIG == nil then
        ScenEdit_SpecialMessage(side, 'CONFIG == nil')
        return
    end

    for _, value in ipairs(CONFIG[field].repairRunway.runways) do
        local runway = SE_GetUnit({ guid = value.guid })

        if runway and value.startTime ~= nil then
            ScenEdit_SetUnitDamage({
                guid = runway.guid,
                dp = -runway.damage.startdp * CONFIG[field].repairRunway.const.percentagePerHour / 12 / 100,
                fires = 'NoFire'
            })

            -- ScenEdit_SpecialMessage(side, runway.damage.dp_percent_now)
        end
    end
end
