local Utils = {}

---Generate a random string of uppercase letters
---@param numLetters number The number of letters to generate
---@return string # A string containing random uppercase letters
function Utils.randomTxt(numLetters)
  local totTxt = ""
  for i = 1, numLetters do
    totTxt = totTxt .. string.char(math.random(65, 90))
  end
  return totTxt
end

---Get the count of items in a list
---@param list table The list to count items in
---@return number # The number of items in the list
function Utils.getCount(list)
  if list == nil then return 0 end
  local count = 0

  for k, v in pairs(list) do
    count = count + 1
  end

  return count
end

---Insert a list of items into another list
---@param list table The list to insert into
---@param insertedList table The list of items to insert
---@return table # The updated list with items inserted
function Utils.insertList(list, insertedList)
  local count = Utils.getCount(insertedList)

  for i = 1, count, 1 do
    table.insert(list, insertedList[i])
  end

  return list
end

---Parse a datetime string in the format "YYYY-MM-DD HH:MM:SS" to a UTC timestamp
---@param datetimeStr string The datetime string in the format "YYYY-MM-DD HH:MM:SS"
---@return number # The UTC timestamp corresponding to the datetime string
function Utils.parseDatetimeToTimestamp(datetimeStr)
  local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = datetimeStr:match(pattern)

  if not (year and month and day and hour and min and sec) then
    error("Invalid datetime format: " .. tostring(datetimeStr))
  end

  -- First convert to UTC table
  local utcTable = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    isdst = false,
  }

  -- Calculate timestamp: we want it to be UTC → so first use os.time(utcTable) as local time
  -- Then add back offset to get the real UTC timestamp
  local localTimestamp = os.time(utcTable)
  local date = os.date("!*t")
  ---@cast date osdate
  local tzOffset = os.difftime(os.time(), os.time(date))
  return localTimestamp - tzOffset + (16 * 3600)
end

---Safely call a function with error handling
---Example usage: local result, err = Utils.safeCall("MyFunction", MyFunction, arg1, arg2)
---@param funcName string The name of the function being called
---@param func function The function to call
---@param ... any The arguments to pass to the function
---@return any|nil result The result of the function call, or nil if an error occurred
---@return string|nil err An error message if an error occurred, or nil if the call was successful
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
    -- print(result)  -- result is complete error + line number stack
    return nil, result
  end

  return result
end

---Calculate arctangent of y/x with proper quadrant handling
---Implements atan2 function for Lua (handles all quadrants correctly)
---@param y number Y coordinate
---@param x number X coordinate
---@return number # Angle in radians (-π to π)
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

---Calculate the spherical center point from a set of latitude/longitude coordinates
---Uses Cartesian coordinate transformation to find the geometric center on a sphere
---@param coords table<number, {latitude: number, longitude: number}> Array of coordinate points (minimum 4 points required)
---@return {latitude: number, longitude: number}|nil # Center point coordinates, or nil if input is invalid
function Utils.calculateSphericalCenter(coords)
  -- Check if input is valid
  if not coords or #coords < 4 then
    return nil
  end

  -- Initialize Cartesian coordinate sums
  local xSum = 0
  local ySum = 0
  local zSum = 0

  -- Convert latitude/longitude to Cartesian coordinates and calculate sum
  for _, point in ipairs(coords) do
    if not point.latitude or not point.longitude then
      return nil
    end

    -- Convert angles to radians
    local latRad = math.rad(point.latitude)
    local lonRad = math.rad(point.longitude)

    -- Convert to Cartesian coordinates
    local x = math.cos(latRad) * math.cos(lonRad)
    local y = math.cos(latRad) * math.sin(lonRad)
    local z = math.sin(latRad)

    xSum = xSum + x
    ySum = ySum + y
    zSum = zSum + z
  end

  -- Calculate average values
  local count = #coords
  local xAvg = xSum / count
  local yAvg = ySum / count
  local zAvg = zSum / count

  -- Convert average Cartesian coordinates back to latitude/longitude
  local hyp = math.sqrt(xAvg * xAvg + yAvg * yAvg)
  local centerLat = math.deg(Utils.atan2(zAvg, hyp))
  local centerLon = math.deg(Utils.atan2(yAvg, xAvg))

  return {
    latitude = centerLat,
    longitude = centerLon
  }
end

---Deep copy a table recursively
---@generic T
---@param original T The table to deep copy
---@return T # A deep copy of the original table
function Utils.deepCopy(original)
  if type(original) ~= "table" then
    return original
  end

  local copy = {}
  for key, value in pairs(original) do
    copy[Utils.deepCopy(key)] = Utils.deepCopy(value)
  end

  return copy
end

---Round timestamp to nearest minutes interval
---@param timestamp number The timestamp to round
---@param minutes number The minute interval to round to (e.g., 5 for 5-minute intervals)
---@return number # The rounded timestamp
function Utils.roundToNearestMinutes(timestamp, minutes)
  local secondsInInterval = minutes * 60
  return math.ceil(timestamp / secondsInInterval) * secondsInInterval
end

---Format datetime string to separated date and time components
---@param datetimeStr string The datetime string in the format "YYYY-MM-DD HH:MM:SS"
---@return {date: string, time: string} # Object with date in "YYYY/MM/DD" format and time in "HH:MM:SS" format
function Utils.formatDateTime(datetimeStr)
  local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = datetimeStr:match(pattern)

  if not (year and month and day and hour and min and sec) then
    error("Invalid datetime format: " .. tostring(datetimeStr))
  end

  return {
    date = string.format("%s/%s/%s", year, month, day),
    time = string.format("%s:%s:%s", hour, min, sec)
  }
end

---Parse mission name string to extract code, number, and AAR (air-to-air refueling) flag
---@param missionName string Mission name string (e.g., "STRIKE/AB/W/1" or "STRIKE/AB/W/AAR/1")
---@return string|nil code Code extracted from mission name (e.g., "W")
---@return number|nil num Number extracted from mission name
---@return boolean hasAAR Whether the mission has air-to-air refueling support
function Utils.parseMissionName(missionName)
  if not missionName or type(missionName) ~= "string" then
    return nil, nil, false
  end

  -- Split string by "/"
  local parts = {}
  for part in string.gmatch(missionName, "[^/]+") do
    table.insert(parts, part)
  end

  -- Check basic format: STRIKE/AB/...
  if #parts < 4 or parts[1] ~= "STRIKE" or parts[2] ~= "AB" then
    return nil, nil, false
  end

  local code = parts[3] -- Extract code (e.g., "W")
  local hasAAR = false
  local number = nil

  -- Check if AAR is present
  if parts[4] == "AAR" then
    hasAAR = true
    number = tonumber(parts[5])
  else
    number = tonumber(parts[4])
  end

  return code, number, hasAAR
end

return Utils
