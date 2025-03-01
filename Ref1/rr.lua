require('func for array')
local arr = { 1, 2, 3 }

local result = Array_utils.new(arr)
    :map(function(x) return x * 2 end)
    :value()
print(result[1])

local arr2 = { 1, 2, 3 }
print(arr2)
local arr3 = { ['aaa.bb/44'] = 6 }
print(arr3['aaa.bb/44'])
