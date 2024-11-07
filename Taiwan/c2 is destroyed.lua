local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

if unit and CONFIG.t.IADS.isActivated then
    if CONFIG.t.IADS.ROCC[unit.guid] then
        for _, guid in ipairs(CONFIG.t.IADS.ROCC[unit.guid].radar) do
            local u = SE_GetUnit({ guid = guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.ROCC)
                local detect = CONFIG.t.IADS.units[guid].OODA.detection
                local target = CONFIG.t.IADS.units[guid].OODA.targeting
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
            end
        end

        for _, guid in ipairs(CONFIG.t.IADS.ROCC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.ROCC)
                local detect = CONFIG.t.IADS.units[guid].OODA.detection
                local target = CONFIG.t.IADS.units[guid].OODA.targeting
                -- ScenEdit_SpecialMessage('China', 'BEFORE ' .. tostring(u.OODA.detection))
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                -- ScenEdit_SpecialMessage('China', 'AFTER ' .. tostring(u.OODA.detection))
            end
        end
    end

    if CONFIG.t.IADS.TAAOC[unit.guid] then
        for _, guid in ipairs(CONFIG.t.IADS.TAAOC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.const.values.TAAOC)
                local detect = CONFIG.t.IADS.units[guid].OODA.detection
                local target = CONFIG.t.IADS.units[guid].OODA.targeting
                -- ScenEdit_SpecialMessage('China', tostring(u.OODA.detection))
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                -- ScenEdit_SpecialMessage('China', tostring(u.OODA.detection))
            end
        end
    end
end

-- if unit and CONFIG.t.C2.isActivated then
--     for _, operationalZone in ipairs(CONFIG.t.C2.operationalZones) do
--         if unit.guid == operationalZone.ROCC.guid then
--             for _, v in ipairs(operationalZone.ROCC.units) do
--                 local u = SE_GetUnit({ guid = v.guid })

--                 if u ~= nil then
--                     local OODA = GetOODA(CONFIG.t.C2.const.values.ROCC)
--                     local detect = v.OODA.detection
--                     local target = v.OODA.targeting
--                     u.OODA = {
--                         detection = detect + OODA.detection,
--                         targeting = target + OODA.targeting,
--                         evasion = OODA.evasion
--                     }
--                 end
--             end
--         end

--         if unit.guid == operationalZone.TAAOC.guid then
--             for _, v in ipairs(operationalZone.TAAOC.units) do
--                 local u = SE_GetUnit({ guid = v.guid })

--                 if u then
--                     local OODA = GetOODA(CONFIG.t.C2.const.values.TAAOC)
--                     local detect = v.OODA.detection
--                     local target = v.OODA.targeting
--                     u.OODA = {
--                         detection = detect + OODA.detection,
--                         targeting = target + OODA.targeting,
--                         evasion = OODA.evasion
--                     }
--                 end
--             end
--         end
--     end
-- end
