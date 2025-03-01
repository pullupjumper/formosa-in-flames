local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if unit and CONFIG.t.IADS.isActivated then
    if CONFIG.t.IADS.ROCC[unit.guid] then
        for _, data in pairs(CONFIG.t.IADS.ROCC[unit.guid].radar) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.ROCC)
                local detect = data.OODA.detection
                local target = data.OODA.targeting
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                data.currOODA = u.OODA
            end
        end

        for _, data in pairs(CONFIG.t.IADS.ROCC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.ROCC)
                local detect = data.OODA.detection
                local target = data.OODA.targeting
                -- ScenEdit_SpecialMessage('China', 'BEFORE ' .. tostring(u.OODA.detection))
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                data.currOODA = u.OODA
                -- ScenEdit_SpecialMessage('China', 'AFTER ' .. tostring(u.OODA.detection))
            end
        end
    end

    if CONFIG.t.IADS.TAAOC[unit.guid] then
        for _, data in pairs(CONFIG.t.IADS.TAAOC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.TAAOC)
                local detect = data.OODA.detection
                local target = data.OODA.targeting
                -- ScenEdit_SpecialMessage('China', tostring(u.OODA.detection))
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                data.currOODA = u.OODA
                -- ScenEdit_SpecialMessage('China', tostring(u.OODA.detection))
            end
        end
    end
end
gKH.State.SaveTableToKey(CONFIG, "CONFIG")
