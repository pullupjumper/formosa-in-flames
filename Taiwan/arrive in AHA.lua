local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end


if CONFIG.t.ground.glcm.isStrikeActivated then
    local result = IsMetWithAmmo(CONFIG, unit, 'Taiwan', 'glcm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end


if CONFIG.t.ground.mlrs.isStrikeActivated then
    local result = IsMetWithAmmo(CONFIG, unit, 'Taiwan', 'mlrs', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end


if CONFIG.t.ground.srbm.isStrikeActivated then
    local result = IsMetWithAmmo(CONFIG, unit, 'Taiwan', 'srbm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end


if CONFIG.t.ground.ascm.isStrikeActivated then
    local result = IsMetWithAmmo(CONFIG, unit, 'Taiwan', 'ascm', false)

    if result.isMet then
        SetReloadStartTime(result.battery, unit, false)
    end
end

-- if CONFIG.c.ground.mlrs.isStrikeActivated then
--     local result = IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'mlrs', true)

--     if result.isMet then
--         SetReloadStartTime(result.battery, unit, true)
--     end
-- end

-- if CONFIG.c.ground.srbm.isStrikeActivated then
--     local result = IsMetWithAmmoTrucks(CONFIG, unit, 'China', 'srbm', true)

--     if result.isMet then
--         SetReloadStartTime(result.battery, unit, true)
--     end
-- end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
