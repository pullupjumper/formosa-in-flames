local function getY(x)
    if x <= 60 then
        return 1
    elseif x >= math.random(300, 340) then
        return 0
    else
        -- return 2.71 ^ ((-math.log(0, 3 * x) / 450) * x ^ 0.8)
        return 2.71 ^ ((-1 / 450) * x ^ 0.8)
    end
end
local function getD(x)
    -- return (0.00007937 * x ^ 3.8518) * 10 ^ -6.1 +
    --     (math.random(-120 * x ^ 1.8 / 15000, 120 * x ^ 1.8 / 15000) / 10 ^ 5 * (x ^ 2.25 / 10 ^ 2.4))
    return (0.00007937 * x ^ 3.8518) / (10 ^ 6.1) +
        ((math.random(-120 * x, 120 * x) ^ 2 / 1500000) / 10 ^ 5 * (x ^ 2.25 / 10 ^ 2.4))
end
print('--------')
print(getY(200))
print(getD(200))
-- print(math.log(16, 4))
-- print((math.random(-120 * 200, 120 * 200)) ^ 2)
-- print(getD(200))
local list = {
    ['ee'] = 2,
    ['ff'] = 2
}
for key, value in pairs(list) do
    print(key, value)
end
