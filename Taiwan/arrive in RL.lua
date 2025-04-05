local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end


if CONFIG.t.ground.mlrs.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'mlrs', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end

if CONFIG.t.ground.glcm.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'glcm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end

if CONFIG.t.ground.srbm.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'srbm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end

if CONFIG.t.ground.ascm.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'ascm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
