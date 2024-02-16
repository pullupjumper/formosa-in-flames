local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not CONFIG.c.mlrs.onMobileUnit.isStrikeActivated then
    return
end

local function setReloadStartTime(battery, unit)
    battery.state = CONFIG.const.batteryState.RESUPPLY
    battery.reloadStartTime = ScenEdit_CurrentTime()
    ScenEdit_SetUnit({ guid = unit.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
end

-------------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.c.mlrs.onMobileUnit.batteries) do
    if unit == nil then
        ScenEdit_MsgBox('Is nil', 1)
        return
    end

    if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
        setReloadStartTime(battery, unit)
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
