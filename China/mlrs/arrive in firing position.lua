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


local function setWCSToFree(battery, group)
    battery.state = CONFIG.const.batteryState.STATIC

    for index, guid in ipairs(group.group.unitlist) do
        local u = SE_GetUnit({ guid = guid })

        if u == nil then
            ScenEdit_MsgBox('Is nil', 1)
            return
        end

        ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
        ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 })
    end
end


-------------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.c.mlrs.onMobileUnit.batteries) do
    if unit == nil then
        ScenEdit_MsgBox('Is nil', 1)
        return
    end

    if battery.guid == unit.guid and battery.state == CONFIG.const.batteryState.REPOSITIONING then
        setWCSToFree(battery, unit)
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
