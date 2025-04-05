local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end


if CONFIG.c.ground.glcm.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'glcm', true)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, true)
    end
end

if CONFIG.c.ground.mlrs.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'mlrs', true)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, true)
    end
end

if CONFIG.c.ground.srbm.isStrikeActivated then
    local result = IsMetWithAmmoTrucks(CONFIG, unit, 'srbm', true)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, true)
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
