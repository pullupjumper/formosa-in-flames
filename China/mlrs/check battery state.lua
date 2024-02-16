local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if not CONFIG.c.mlrs.onMobileUnit.isStrikeActivated then
    return
end

local function isRunOutOfAmmo(group)
    local result = true

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit ~= nil and isRunOutOfAmmunition(unit.mounts, CONFIG.c.mlrs.onMobileUnit.const.weaponDBID) == false then
            result = false
            break
        end
    end

    return result
end

local function toFringPosition(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING
    local courseIdx = math.random(getCount(battery.position.firingpositions))

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit == nil then
            ScenEdit_MsgBox(tostring(unit) .. ' is nil', 1)
            return
        end

        ScenEdit_SetUnit({
            guid = unit.guid,
            manualthrottle = 'Flank',
            manualSpeed = 30,
            course = battery.position.firingpositions[courseIdx].course
        })
    end
end

local function toAssemblyArea(battery, group)
    battery.state = CONFIG.const.batteryState.REPOSITIONING

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit == nil then
            ScenEdit_MsgBox(tostring(unit) .. ' is nil', 1)
            return
        end

        ScenEdit_SetUnit({
            guid = unit.guid,
            manualthrottle = 'Flank',
            manualSpeed = 30,
            course = battery.position.assemblyArea.course
        })
        ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
    end
end

-- ----------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.c.mlrs.onMobileUnit.batteries) do
    local group = SE_GetUnit({ guid = battery.guid })

    if group == nil then
        ScenEdit_MsgBox('Is nil', 1)
        return
    end

    if battery.state == CONFIG.const.batteryState.STATIC then
        if isRunOutOfAmmo(group) then toAssemblyArea(battery, group) end
    end

    if battery.state == CONFIG.const.batteryState.RESUPPLY then
        if battery.reloadStartTime == nil then
            battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.c.mlrs.onMobileUnit.const.reloadTime
        end

        local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
        local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG.c.mlrs.onMobileUnit.const.reloadTime)
            and group:inArea(battery.position.assemblyArea.area)
            and isRunOutOfAmmo(group)

        if isMoreThanReloadTime then
            resupply(battery, CONFIG.c.mlrs.onMobileUnit.const.weaponDBID)
            if CONFIG.isDevMode then ScenEdit_MsgBox('After resupply', 1) end
        end

        if not isRunOutOfAmmo(group) then toFringPosition(battery, group) end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
