-- ---@param d number
-- ---@return {detection: number, targeting: number, evasion: number}
-- function GetOODA(d)
--   return {
--     detection = math.random(10 * d, 30 * d),
--     targeting = math.random(20 * d, 20 * d),
--     evasion = math.random(90 * d, 120 * d)
--   }
-- end
local Utils = {}

--- Generate a random string of uppercase letters
---@param numLetters number -- The number of letters to generate
---@return string -- A string containing random uppercase letters
function Utils.randomTxt(numLetters)
  local totTxt = ""
  for i = 1, numLetters do
    totTxt = totTxt .. string.char(math.random(65, 90))
  end
  return totTxt
end

--- Get the count of items in a list
---@param list table -- The list to count items in
---@return number -- The number of items in the list
function Utils.getCount(list)
  if list == nil then return 0 end
  local count = 0

  for k, v in pairs(list) do
    count = count + 1
  end

  return count
end

--- Insert a list of items into another list
---@param list table -- The list to insert into
---@param insertedList table -- The list of items to insert
---@return table -- The updated list with items inserted
function Utils.insertList(list, insertedList)
  local count = Utils.getCount(insertedList)

  for i = 1, count, 1 do
    table.insert(list, insertedList[i])
  end

  return list
end

---Parse a datetime string in the format "YYYY-MM-DD HH:MM:SS" to a UTC timestamp
---@param datetimeStr string -- The datetime string in the format "YYYY-MM-DD HH:MM:SS"
---@return number -- The UTC timestamp corresponding to the datetime string
function Utils.parseDatetimeToTimestamp(datetimeStr)
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
---@return any|nil --The result of the function call, or nil if an error occurred
---@return string|nil --An error message if an error occurred, or nil if the call was successful
---Example usage: local result, err = Utils.SafeCall("MyFunction", MyFunction, arg1, arg2)
function Utils.safeCall(funcName, func, ...)
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

---comment
---@param y number
---@param x number
---@return number
function Utils.atan2(y, x)
  if x > 0 then
    return math.atan(y / x)
  elseif x < 0 then
    if y >= 0 then
      return math.atan(y / x) + math.pi
    else
      return math.atan(y / x) - math.pi
    end
  elseif x == 0 then
    if y > 0 then
      return math.pi / 2
    elseif y < 0 then
      return -math.pi / 2
    else
      return 0 -- undefined (0,0), default to 0
    end
  end

  return 0
end

---comment
---@param coords table<number,{latitude: number, longitude: number}>
---@return {latitude: number, longitude: number}|nil
function Utils.calculateSphericalCenter(coords)
  -- 檢查輸入是否有效
  if not coords or #coords < 4 then
    return nil
  end

  -- 初始化笛卡爾座標總和
  local xSum = 0
  local ySum = 0
  local zSum = 0

  -- 將經緯度轉換為笛卡爾座標並計算總和
  for _, point in ipairs(coords) do
    if not point.latitude or not point.longitude then
      return nil
    end

    -- 將角度轉換為弧度
    local latRad = math.rad(point.latitude)
    local lonRad = math.rad(point.longitude)

    -- 轉換到笛卡爾座標
    local x = math.cos(latRad) * math.cos(lonRad)
    local y = math.cos(latRad) * math.sin(lonRad)
    local z = math.sin(latRad)

    xSum = xSum + x
    ySum = ySum + y
    zSum = zSum + z
  end

  -- 計算平均值
  local count = #coords
  local xAvg = xSum / count
  local yAvg = ySum / count
  local zAvg = zSum / count

  -- 將平均笛卡爾座標轉回經緯度
  local hyp = math.sqrt(xAvg * xAvg + yAvg * yAvg)
  local centerLat = math.deg(Utils.atan2(zAvg, hyp))
  local centerLon = math.deg(Utils.atan2(yAvg, xAvg))

  return {
    latitude = centerLat,
    longitude = centerLon
  }
end

--- Deep copy a table recursively
---@param original table The table to deep copy
---@return table -- A deep copy of the original table
function Utils.deepCopy(original)
  if type(original) ~= 'table' then
    return original
  end

  local copy = {}
  for key, value in pairs(original) do
    copy[Utils.deepCopy(key)] = Utils.deepCopy(value)
  end

  return copy
end

--- Round timestamp to nearest minutes interval
---@param timestamp number The timestamp to round
---@param minutes number The minute interval to round to (e.g., 5 for 5-minute intervals)
---@return number -- The rounded timestamp
function Utils.roundToNearestMinutes(timestamp, minutes)
  local secondsInInterval = minutes * 60
  return math.ceil(timestamp / secondsInInterval) * secondsInInterval
end

return Utils
