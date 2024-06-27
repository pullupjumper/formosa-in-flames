---@param list table
---@param fn function
function ForEach(list, fn)
    for index, item in ipairs(list) do
        local result = fn(index, item)

        if result == true then
            break
        end
    end
end

table.forEach = function(list, fn)
    for index, item in ipairs(list) do
        local result = fn(index, item)

        if result == true then
            break
        end
    end
end

local list = { 5, 6, 7, 8 }
local count = 0
local handler = function(idx, item)
    print(item)
    count = count + 1
    if count >= 2 then
        print('fff' .. tostring(count))
        return true
    end
end

table.forEach(list, handler)
