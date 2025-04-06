local unit = ScenEdit_UnitX()
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
    ScenEdit_SpecialMessage('China', 'saveData is nil')
    return
end

if unit and saveData.c.IADS.isActivated then
    if saveData.c.IADS.C2[unit.guid] then
        for _, data in pairs(saveData.c.IADS.C2[unit.guid].radar) do
            local u = SE_GetUnit({ guid = data.guid })

            if u == nil then goto continue end
            local OODA = GetOODA(CONFIG.c.IADS.values.C2)
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

        for _, data in pairs(saveData.c.IADS.C2[unit.guid].SAM) do
            local u = SE_GetUnit({ guid = data.guid })

            if u == nil then goto continue end

            local OODA = GetOODA(CONFIG.c.IADS.values.C2)
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
gKH.State.SaveTableToKey(saveData, "SaveData")
