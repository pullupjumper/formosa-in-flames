---@param x_latitude number
---@param x_longitude number
---@param max_radius number
---@return CMO__Location
function CircularRandomPosition(x_latitude, x_longitude, max_radius)
  local randomisationCircle = World_GetCircleFromPoint({
    latitude = x_latitude,
    longitude = x_longitude,
    radius = (math.random(0, max_radius * 10) / 10),
    numpoints = 72
  })
  local randomisedPoint = randomisationCircle[math.random(1, #randomisationCircle)]
  return randomisedPoint
end

---@param params SBJ__Location_Params
---@return table <number, CMO__Location>
function GenerateLocations(params)
  local numTemp = params.num
  local bearingTemp = params.bearing
  local distanceTemp = 0
  local firstDistance = params.firstDistance
  local locations = {}
  local locationTemp = params.initialLocation

  if numTemp == 0 then
    return {}
  end

  for i = 1, numTemp, 1 do
    if i > 1 then
      distanceTemp = params.distance
    elseif i == 1 and firstDistance then
      distanceTemp = params.firstDistance
    end

    locationTemp = World_GetPointFromBearing({
      LATITUDE = locationTemp.latitude,
      LONGITUDE = locationTemp.longitude,
      BEARING = bearingTemp,
      DISTANCE = distanceTemp
    })

    table.insert(locations, locationTemp)
  end

  return locations
end

---@param position CMO__Location
---@param mode SBJ__AreaMode
---@return table <integer, CMO__ReferencePoint>|boolean
function NewArea(position, mode)
  local side = mode.side
  local shape = mode.shape
  if side == nil or shape == nil then return false end
  local name = (mode.name or "RP")
  local bear_offset = (mode.bear_offset or 0)
  local rpTable = {}
  local a = 1
  --Circle
  if shape == 'circle' then
    local distance = mode.distance
    for i = 0, 359, 45 do
      local location = World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = i
      })
      local rp = ScenEdit_AddReferencePoint({
        side = side,
        latitude = location.latitude,
        longitude = location.longitude
      })
      a = a + 1
      table.insert(rpTable, rp.name)
    end
  elseif shape == 'square' then
    local distance = mode.distance
    for i = 0, 3 do
      local b = 45 + (90 * i) + bear_offset
      local location = World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = b
      })
      local rp = ScenEdit_AddReferencePoint({
        side = side,
        latitude = location.latitude,
        longitude = location.longitude
      })
    end
  end

  return (rpTable)
end

---@param side string @The side the message is visible to (sidename may also be used in place of side)
---@param ... string @Variable number of string arguments to be printed inside the box
function PrintBox(side, ...)
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
