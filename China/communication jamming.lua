local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

local function getCommsLevel(unitGUID)
    local comm_bonif = 0

    for _, value in ipairs(CONFIG.c.commsJamming.jammers) do
        local jammer = SE_GetUnit({ guid = value.guid })

        if jammer and jammer.condition == 'Airborne' and jammer.jammer then
            comm_bonif = -120 + Tool_Range(unitGUID, jammer.guid) ^ 1.04 + comm_bonif
        end
    end

    for _, value in ipairs(CONFIG.t.aircraft.AEW) do
        local AEW = SE_GetUnit({ guid = value.guid })

        if AEW and AEW.condition == 'Airborne' then
            local d = Tool_Range(unitGUID, AEW.guid)
            if d < 100 then
                comm_bonif = comm_bonif + 400 + math.random(-1, 1)
            elseif d < 200 then
                comm_bonif = comm_bonif + 350 + math.random(-3, 3)
            elseif d < 300 then
                comm_bonif = comm_bonif + 250 + math.random(-6, 6)
            elseif d < 400 then
                comm_bonif = comm_bonif + 150 + math.random(-10, 10)
            end
        end
    end

    for ROCCGuid, value in pairs(CONFIG.t.IADS.ROCC) do
        local ROCC = SE_GetUnit({ guid = ROCCGuid })

        if ROCC then
            local d = Tool_Range(unitGUID, ROCC.guid)
            if d < 100 then
                comm_bonif = comm_bonif + 400 + math.random(-1, 1)
            elseif d < 200 then
                comm_bonif = comm_bonif + 350 + math.random(-3, 3)
            elseif d < 300 then
                comm_bonif = comm_bonif + 250 + math.random(-6, 6)
            elseif d < 400 then
                comm_bonif = comm_bonif + 150 + math.random(-10, 10)
            end
            break
        end
    end

    return math.floor(comm_bonif)
end

local function commsJamming(CONFIG, u, jammer, jammed_num)
    if u.isOutOfComms then
        if u.outofcomms <= math.random(15, 25) then
            local unit = SE_SetUnit({ guid = u.guid, outofcomms = true })
            u.outofcomms = u.outofcomms + 1
        else
            local unit = SE_SetUnit({ guid = u.guid, outofcomms = false })
            u.outofcomms = 0
            u.isOutOfComms = false
        end
    elseif u.isOutOfComms == false then
        local unit = SE_GetUnit({ guid = u.guid })

        if unit and unit.outOfComms then
            local unit = SE_SetUnit({ guid = u.guid, outofcomms = false })
            u.outofcomms = 0
        end
    end

    if jammer and jammer.condition == 'Airborne' and jammer.jammer then
        if u.isOutOfComms == false then
            if u.outofcomms < math.random(5, 10) and u.outofcomms >= 0 and jammed_num < CONFIG.c.commsJamming.const.jammingLimit then
                local d = Tool_Range(jammer.guid, u.guid)
                local n = 1 * math.sqrt(1 - (d ^ 1.9 / CONFIG.c.commsJamming.const.jammingRange ^ 1.8))

                if n == n and n > (math.random() / 2) then
                    local unit = SE_SetUnit({ guid = u.guid, outofcomms = true })
                    u.outofcomms = u.outofcomms + 1
                    jammed_num = jammed_num + 1
                else
                    local unit = SE_SetUnit({ guid = u.guid, outofcomms = false })
                    u.outofcomms = 0
                    jammed_num = jammed_num + 1
                end
            elseif u.outofcomms < 0 then
                local unit = SE_SetUnit({ guid = u.guid, outofcomms = false })
                u.outofcomms = u.outofcomms + 1
            else
                local unit = SE_SetUnit({ guid = u.guid, outofcomms = false })
                u.outofcomms = math.random(-5, -1)
            end
        end
    end

    return jammed_num
end

if CONFIG.c.commsJamming.isActivated then
    local jammer = nil
    local jammed_num = 0

    for _, j in ipairs(CONFIG.c.commsJamming.jammers) do
        local unit = SE_GetUnit({ guid = j.guid })

        if unit and unit.condition == 'Airborne' and unit.jammer then
            jammer = unit
            break
        end
    end

    local units = {}

    for key, item in pairs(CONFIG.t.IADS.ROCC) do
        for index, value in pairs(item.SAM) do
            units[value.guid] = value
        end
        for index, value in pairs(item.radar) do
            units[value.guid] = value
        end
    end

    for key, item in pairs(CONFIG.t.IADS.TAAOC) do
        for index, value in pairs(item.SAM) do
            units[value.guid] = value
        end
    end

    table.sort(units, function(a, b)
        local da = Tool_Range(jammer.guid, a.guid)
        local db = Tool_Range(jammer.guid, b.guid)
        return da < db
    end)

    for index, value in pairs(units) do
        for key, item in pairs(CONFIG.t.IADS.ROCC) do
            if item.SAM[value.guid] then
                jammed_num = commsJamming(CONFIG, item.SAM[value.guid], jammer, jammed_num)
            end

            if item.radar[value.guid] then
                jammed_num = commsJamming(CONFIG, item.radar[value.guid], jammer, jammed_num)
            end
        end

        for key, item in pairs(CONFIG.t.IADS.TAAOC) do
            if item.SAM[value.guid] then
                jammed_num = commsJamming(CONFIG, item.SAM[value.guid], jammer, jammed_num)
            end
        end
    end

    -- for key, item in pairs(CONFIG.t.IADS.ROCC) do
    --     for index, value in pairs(item.SAM) do
    --         jammed_num = commsJamming(CONFIG, value, jammer, jammed_num)
    --     end
    --     for index, value in pairs(item.radar) do
    --         jammed_num = commsJamming(CONFIG, value, jammer, jammed_num)
    --     end
    -- end

    -- for key, item in pairs(CONFIG.t.IADS.TAAOC) do
    --     for index, value in pairs(item.SAM) do
    --         jammed_num = commsJamming(CONFIG, value, jammer, jammed_num)
    --     end
    -- end

    for _, value in ipairs(CONFIG.t.aircraft.AC) do
        local unit = SE_GetUnit({ guid = value.guid })

        if unit and unit.condition == 'Airborne' then
            value.comms_level = value.comms_base + getCommsLevel(unit.guid)
            -- ScenEdit_SpecialMessage('Taiwan', tostring(value.comms_level))

            if value.comms_level < value.comms_threshold then
                ScenEdit_SetUnit({ guid = value.guid, outofcomms = true, RTB = true })
            end
        end
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
