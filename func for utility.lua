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
---@return table
function Reverse(list)
    local count = GetCount(list)
    local temp = {}

    for i = count, 1, -1 do
        table.insert(temp, list[i])
    end

    return temp
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
