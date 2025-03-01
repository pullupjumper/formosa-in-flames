local arr = { 2, 4, 3 }
local arr2 = {}
function GetCount(list)
    if list == nil then return 0 end
    local count = 0

    for k, v in pairs(list) do
        count = count + 1
    end

    return count
end

table.sort(arr, function(a, b)
    return a < b
end)

-- print(arr2)
for index, value in ipairs(arr) do
    print(value)
end
