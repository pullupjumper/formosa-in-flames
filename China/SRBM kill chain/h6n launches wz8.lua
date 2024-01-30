local unit = ScenEdit_UnitX()
local STRIKE_ON_SAM = gKH.State.LoadTableFromKey("STRIKE_ON_SAM")

if unit ~= nil then
    local wz8 = launchWZ8(unit, STRIKE_ON_SAM.WZ8_COURSE, nil)
    table.insert(STRIKE_ON_SAM.RECON_WZ8, { unit = wz8.guid })
    -- LAST_RECON_TIME = ScenEdit_CurrentTime() + 60 * 10
end

if STRIKE_ON_SAM ~= nil then
    gKH.State.SaveTableToKey(STRIKE_ON_SAM, "STRIKE_ON_SAM")
end
