---@param val any @ nil
function CheckIfNil(val)
    if val == nil then
        ScenEdit_MsgBox(tostring('Val is nil'), 1)
        return
    end
end

---@param list table
---@param fn function
function ForEach(list, fn)
    for index, item in ipairs(list) do
        local isBreak = fn(index, item)

        if isBreak then
            break
        end
    end
end

---@param list table
---@return number
function GetCount(list)
    if list == nil then return 0 end
    local count = 0

    for k, v in pairs(list) do
        count = count + 1
    end

    return count
end

---@param list table
---@return table
function Reverse(list)
    local count = GetCount(list)
    local temp = {}

    for i = count, 1, -1 do
        table.insert(temp, list[i])
    end

    return temp
end

---@param list table
---@param insertedList table
function InsertList(list, insertedList)
    local count = GetCount(insertedList)

    for i = 1, count, 1 do
        table.insert(list, insertedList[i])
    end

    return list
end

---@param units table<number, CMO__Unit>
---@param name string
function FilterUnitsByName(units, name)
    local filteredUnits = {}
    if units == nil then return end

    for k, v in ipairs(units) do
        if string.find(v.name, name) then
            table.insert(filteredUnits, v)
        end
    end

    return filteredUnits
end

---@param list table
---@param fn function
function Filter(list, fn)
    local temp = {}

    if list ~= nil then
        for index, item in ipairs(list) do
            local result = fn(index, item)

            if result then
                table.insert(temp, item)
            end
        end
    end

    return temp
end

---@param contacts CMO__Contact
---@param handler function
function FilterContacts(contacts, handler)
    local temp = {}

    if contacts ~= nil then
        for index, unit in ipairs(contacts) do
            local result = handler(unit)

            if result then
                table.insert(temp, unit)
            end
        end
    end

    return temp
end

-- 定義函數：printBox
-- 參數：strings - 一個包含多個字串的 table
function printBox(side, ...)
    -- 收集所有字串參數到陣列中
    local strings = { ... }

    -- 找出最長字串的長度
    local maxLen = 0
    for _, str in ipairs(strings) do
        if #str > maxLen then
            maxLen = #str
        end
    end

    -- 計算邊框寬度
    local width = 70

    -- 構建頂部和底部邊框：連續的 -
    local border = string.rep("-", width)

    -- 構建中間行
    local middleLines = {}
    for _, str in ipairs(strings) do
        -- 構建中間行：| 空格 字串
        local middle = "| " .. str
        table.insert(middleLines, middle)
    end

    -- 組合成一個單一的字串
    local boxString = border .. "\n" .. table.concat(middleLines, "\n") .. "\n" .. border

    -- 一次性輸出
    ScenEdit_SpecialMessage(side, boxString)
end
