function WhenRunwayIsDamaged(side)
    local field = (side == 'China') and 'c' or 't'
    local unit = ScenEdit_UnitX()
    local saveData = gKH.State.LoadTableFromKey("SaveData")

    if saveData == nil then
        ScenEdit_SpecialMessage(side, 'saveData is nil')
        return
    end

    if not saveData[field].repairRunway.isActivated then
        saveData[field].repairRunway.isActivated = true
    end

    for _, runway in ipairs(saveData[field].repairRunway.runways) do
        if unit and unit.guid == runway.guid and runway.startTime == nil then
            runway.startTime = ScenEdit_CurrentTime()
        end
    end

    gKH.State.SaveTableToKey(saveData, "SaveData")
end

function RepairRunway(side)
    local field = (side == 'China') and 'c' or 't'
    local saveData = gKH.State.LoadTableFromKey("SaveData")

    if saveData == nil then
        ScenEdit_SpecialMessage(side, 'saveData is nil')
        return
    end

    for _, runway in ipairs(saveData[field].repairRunway.runways) do
        local actualRunway = SE_GetUnit({ guid = runway.guid })

        if actualRunway and runway.startTime ~= nil then
            ScenEdit_SetUnitDamage({
                guid = actualRunway.guid,
                dp = -actualRunway.damage.startdp * CONFIG[field].repairRunway.percentagePerHour / 12 / 100,
                fires = 'NoFire'
            })

            -- ScenEdit_SpecialMessage(side, runway.damage.dp_percent_now)
        end
    end
end
