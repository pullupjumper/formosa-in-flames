Array_utils = {}

local Array = {}
Array.__index = Array

function Array_utils.new(array)
    return setmetatable({ items = array }, Array)
end

function Array:map(func)
    local result = {}
    for k, v in pairs(self.items) do
        result[k] = func(v, k)
    end
    self.items = result
    return self
end

function Array:filter(func)
    local result = {}
    local index = 1     -- 用於生成連續的鍵
    for _, v in pairs(self.items) do
        if func(v) then -- 不需要 k，因為我們不保留原始鍵
            result[index] = v
            index = index + 1
        end
    end
    self.items = result
    return self
end

function Array:forEach(func)
    for k, v in pairs(self.items) do
        func(v, k)
    end
    return self
end

function Array:some(func)
    for k, v in pairs(self.items) do
        if func(v, k) then
            return true
        end
    end
    return false
end

function Array:reduce(func, initial)
    local acc
    local startIndex
    if initial == nil then
        -- 找到第一個元素作為初始值
        for k, v in pairs(self.items) do
            acc = v
            startIndex = k
            break
        end
        if acc == nil then
            error("Reduce of empty array with no initial value")
        end
    else
        acc = initial
        startIndex = nil
    end

    -- 從下一個元素開始遍歷
    for k, v in pairs(self.items) do
        if startIndex == nil or k > startIndex then
            acc = func(acc, v, k)
        end
    end
    return acc
end

function Array:concat(...)
    local result = {}
    local index = 1

    -- 先複製當前陣列的元素
    for _, v in pairs(self.items) do
        result[index] = v
        index = index + 1
    end

    -- 遍歷所有傳入的參數，將它們的元素追加進來
    local args = { ... }
    for _, arg in pairs(args) do
        if type(arg) == "table" then
            -- 如果參數是一個表，遍歷它的元素
            for _, v in pairs(arg) do
                result[index] = v
                index = index + 1
            end
        elseif arg ~= nil then
            -- 如果參數不是表，直接作為單一元素添加
            result[index] = arg
            index = index + 1
        end
    end

    self.items = result
    return self
end

function Array:value()
    return self.items
end

return Array_utils
