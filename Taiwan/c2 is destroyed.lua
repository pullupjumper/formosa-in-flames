local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
    return
end

if unit and saveData.t.IADS.isActivated then
    if saveData.t.IADS.ROCC[unit.guid] then
        for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].radar) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.values.ROCC)
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

        for _, data in pairs(saveData.t.IADS.ROCC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.values.ROCC)
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

    if saveData.t.IADS.TAAOC[unit.guid] then
        for _, data in pairs(saveData.t.IADS.TAAOC[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u then
                local OODA = GetOODA(CONFIG.t.IADS.values.TAAOC)
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
gKH.State.SaveTableToKey(saveData, "SaveData")
