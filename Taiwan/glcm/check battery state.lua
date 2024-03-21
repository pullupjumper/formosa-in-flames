local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

local function isRunOutOfAmmo(group, weaponDBID)
    local result = true

    for idx, guid in ipairs(group.group.unitlist) do
        local unit = SE_GetUnit({ guid = guid })

        if unit and isRunOutOfAmmunition(unit.mounts, weaponDBID) == false then
            result = false
            break
        end
    end

    return result
end

---------------------------------------------------------------------------------------------------------

for _, battery in ipairs(CONFIG.t.glcm.batteries) do
    local group = SE_GetUnit({ guid = battery.guid })

    if group then
        if battery.reloadStartTime == nil then
            battery.reloadStartTime = ScenEdit_CurrentTime() - CONFIG.t.glcm.const.reloadTime
        end

        local diff = ScenEdit_CurrentTime() - battery.reloadStartTime
        local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and diff >= CONFIG.t.glcm.const.reloadTime)
            and group:inArea(battery.position.assemblyArea.area)
            and isRunOutOfAmmo(group, battery.weaponDBID)

        if isMoreThanReloadTime then
            resupply(battery, battery.weaponDBID)
            if CONFIG.isDevMode then ScenEdit_MsgBox('Missile reload is finished', 1) end
        end
    end
end


gKH.State.SaveTableToKey(CONFIG, "CONFIG")
