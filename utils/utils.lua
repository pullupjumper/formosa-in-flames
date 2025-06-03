-- ---@param d number
-- ---@return {detection: number, targeting: number, evasion: number}
-- function GetOODA(d)
--   return {
--     detection = math.random(10 * d, 30 * d),
--     targeting = math.random(20 * d, 20 * d),
--     evasion = math.random(90 * d, 120 * d)
--   }
-- end

---@param numLetters number
---@return string
function RandomTxt(numLetters)
  local totTxt = ""
  for i = 1, numLetters do
    totTxt = totTxt .. string.char(math.random(65, 90))
  end
  return totTxt
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
---@param insertedList table
function InsertList(list, insertedList)
  local count = GetCount(insertedList)

  for i = 1, count, 1 do
    table.insert(list, insertedList[i])
  end

  return list
end

---@param datetimeStr string
---@return number
function ParseDatetimeToTimestamp(datetimeStr)
  local pattern = '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)'
  local year, month, day, hour, min, sec = datetimeStr:match(pattern)

  if not (year and month and day and hour and min and sec) then
    error('Invalid datetime format: ' .. tostring(datetimeStr))
  end

  -- 先轉成 UTC table
  local utcTable = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    isdst = false,
  }

  -- 算出 timestamp：我們要它是 UTC → 所以先用 os.time(utcTable) 當成本地時間
  -- 然後補回 offset，就會得到真正的 UTC timestamp
  local localTimestamp = os.time(utcTable)
  local tzOffset = os.difftime(os.time(), os.time(os.date("!*t")))
  return localTimestamp - tzOffset + (16 * 3600)
end

---Safely call a function with error handling
---@param funcName string The name of the function being called
---@param func function The function to call
---@param ... any The arguments to pass to the function
---@return any|nil The result of the function call, or nil if an error occurred
---@return string|nil An error message if an error occurred, or nil if the call was successful
---Example usage: local result, err = SafeCall("MyFunction", MyFunction, arg1, arg2)
function SafeCall(funcName, func, ...)
  local args = { ... }

  local function errorHandler(err)
    return string.format(
      "[ERROR in %s] %s\n%s",
      funcName,
      tostring(err),
      debug.traceback("", 2)
    )
  end

  local ok, result = xpcall(function() return func(table.unpack(args)) end, errorHandler)

  if not ok then
    -- print(result)  -- result 是完整錯誤 + 行號堆疊
    return nil, result
  end

  return result
end
