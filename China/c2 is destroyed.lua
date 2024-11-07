local unit = ScenEdit_UnitX()
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

if unit and CONFIG.c.IADS.isActivated then
    -- ScenEdit_SpecialMessage('Taiwan', CONFIG.c.IADS.C2[unit.guid].name)

    if CONFIG.c.IADS.C2[unit.guid] then
        for _, guid in ipairs(CONFIG.c.IADS.C2[unit.guid].radar) do
            local u = SE_GetUnit({ guid = guid })

            if u then
                local OODA = GetOODA(CONFIG.c.IADS.const.values.C2)
                local detect = CONFIG.c.IADS.units[guid].OODA.detection
                local target = CONFIG.c.IADS.units[guid].OODA.targeting
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
            end
        end

        for _, guid in ipairs(CONFIG.c.IADS.C2[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = guid })

            if u then
                local OODA = GetOODA(CONFIG.c.IADS.const.values.C2)
                local detect = CONFIG.c.IADS.units[guid].OODA.detection
                local target = CONFIG.c.IADS.units[guid].OODA.targeting
                -- ScenEdit_SpecialMessage('Taiwan', tostring(u.OODA.detection))
                u.OODA = {
                    detection = detect + OODA.detection,
                    targeting = target + OODA.targeting,
                    evasion = OODA.evasion
                }
                -- ScenEdit_SpecialMessage('Taiwan', tostring(u.OODA.detection))
            end
        end
    end
end

-- if unit and CONFIG.c.C2.isActivated then
--     for _, operationalZone in ipairs(CONFIG.c.C2.operationalZones) do
--         if unit.guid == operationalZone.C2.guid then
--             for _, v in ipairs(operationalZone.C2.units) do
--                 local u = SE_GetUnit({ guid = v.guid })

--                 if u ~= nil then
--                     local OODA = GetOODA(CONFIG.c.C2.const.values.C2)
--                     local detect = v.OODA.detection
--                     local target = v.OODA.targeting
--                     u.OODA = {
--                         detection = detect + OODA.detection,
--                         targeting = target + OODA.targeting,
--                         evasion = OODA.evasion
--                     }
--                     -- ScenEdit_SpecialMessage('China', tostring(u.OODA.detection))
--                 end
--             end
--         end
--     end
-- end
