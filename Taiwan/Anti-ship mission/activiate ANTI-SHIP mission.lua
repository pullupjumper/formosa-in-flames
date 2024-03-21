-- local unit = ScenEdit_UnitX()
local contacts = ScenEdit_GetContacts('Taiwan')
local event = ScenEdit_EventX()
local temp = {}
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

local function setAntiShipMissionStartTime()
    local currentTime = ScenEdit_CurrentTime()
    local antiShipStartTime = os.date("%m/%d/%Y %I:%M:%S %p", currentTime)
    local reconStartTime3 = os.date("%m/%d/%Y %I:%M:%S %p", (currentTime + 5 * 60))
    ScenEdit_GetMission('Taiwan', 'ANTI-SHIP WEST').starttime = antiShipStartTime
    ScenEdit_GetMission('Taiwan', 'ANTI-SHIP NORTH').starttime = antiShipStartTime
    ScenEdit_GetMission('Taiwan', 'RECON3').starttime = reconStartTime3
end

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if CONFIG.t.asm.isAntishipMissionActivated == false and contacts ~= nil then
    for index, value in ipairs(contacts) do
        if value:inArea(CONFIG.t.asm.const.nai1) and value.typed == 2 then
            table.insert(temp, value)
        end
    end

    if getCount(temp) > CONFIG.t.asm.const.shipNumInNai1 then
        setAntiShipMissionStartTime()
        CONFIG.t.asm.isAntishipMissionActivated = true
        event.isActive = false
        ScenEdit_MsgBox('Launch ANT-SHIP mission', 0)
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
