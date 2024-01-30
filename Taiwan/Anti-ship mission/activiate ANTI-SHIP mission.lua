-- local unit = ScenEdit_UnitX()
local contacts = ScenEdit_GetContacts('Taiwan')
local event = ScenEdit_EventX()
local temp = {}
local ANTI_SHIP = gKH.State.LoadTableFromKey("ANTI_SHIP")

-- local mission = ScenEdit_GetMission('Taiwan', 'NAVAL STRIKE')
-- local reconMission = ScenEdit_GetMission('Taiwan', 'RECON4')
-- local targetList = {}

if ANTI_SHIP.IS_ANTI_SHIP_MISSION_ACTIVATED == false and contacts ~= nil then
    for index, value in ipairs(contacts) do
        if value:inArea(ANTI_SHIP.NAI_1) and value.typed == 2 then
            table.insert(temp, value)
        end

        -- if value:inArea(NAI_3) and value.typed == 2 then
        --     table.insert(targetList, value)
        -- end
    end

    if getCount(temp) > ANTI_SHIP.SHIP_NUM_IN_NAI_1 then
        setAntiShipMissionStartTime()

        -- for index, target in ipairs(targetList) do
        --     target.posture = 'H'
        --     ScenEdit_AssignUnitAsTarget(target, mission.guid)
        -- end

        -- local currentTime = ScenEdit_CurrentTime()
        -- local antiShipStartTime = os.date("%m/%d/%Y %I:%M:%S %p", currentTime)
        -- local totTime = os.date("%m/%d/%Y %I:%M:%S %p", currentTime + 12)
        -- mission.TimeOnTargetStation = totTime
        -- mission.starttime = antiShipStartTime


        ANTI_SHIP.IS_ANTI_SHIP_MISSION_ACTIVATED = true
        event.isActive = false
        ScenEdit_MsgBox('Launch ANT-SHIP mission', 0)
    end
end


if ANTI_SHIP ~= nil then
    gKH.State.SaveTableToKey(ANTI_SHIP, "ANTI_SHIP")
end
