local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if unit and CONFIG.c.IADS.isActivated then
    if CONFIG.c.IADS.C2[unit.guid] then
        for _, data in pairs(CONFIG.c.IADS.C2[unit.guid].radar) do
            local u = SE_GetUnit({ guid = data.guid })

            if u == nil then goto continue end
            local OODA = GetOODA(CONFIG.c.IADS.const.values.C2)
            local detect = data.OODA.detection
            local target = data.OODA.targeting
            u.OODA = {
                detection = detect + OODA.detection,
                targeting = target + OODA.targeting,
                evasion = OODA.evasion
            }
            data.currOODA = u.OODA

            ::continue::
        end

        for _, data in pairs(CONFIG.c.IADS.C2[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u == nil then goto continue end

            local OODA = GetOODA(CONFIG.c.IADS.const.values.C2)
            local detect = data.OODA.detection
            local target = data.OODA.targeting
            -- ScenEdit_SpecialMessage('Taiwan', tostring(u.OODA.detection))
            u.OODA = {
                detection = detect + OODA.detection,
                targeting = target + OODA.targeting,
                evasion = OODA.evasion
            }
            data.currOODA = u.OODA
            -- ScenEdit_SpecialMessage('Taiwan', tostring(u.OODA.detection))

            ::continue::
        end
    end
end
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
