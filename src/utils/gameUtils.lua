local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

local GameUtils = {}

---@param x_latitude number
---@param x_longitude number
---@param max_radius number
---@return CMO__Location|nil
function GameUtils.CircularRandomPosition(x_latitude, x_longitude, max_radius)
  local randomisationCircle = GameApi.World_GetCircleFromPoint({
    latitude = x_latitude,
    longitude = x_longitude,
    radius = (math.random(0, max_radius * 10) / 10),
    numpoints = 72
  })

  if not randomisationCircle then
    return nil
  end

  local randomisedPoint = randomisationCircle[math.random(1, #randomisationCircle)]
  return randomisedPoint
end

---Generate a list of locations based on parameters
---@param params SBJ__Location_Params
---@return table<integer, CMO__Location>
function GameUtils.GenerateLocations(params)
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

    local newLocation = GameApi.World_GetPointFromBearing({
      LATITUDE = locationTemp.latitude,
      LONGITUDE = locationTemp.longitude,
      BEARING = bearingTemp,
      DISTANCE = distanceTemp
    })

    if not newLocation then
      -- If one point fails, we probably should stop.
      break
    end

    locationTemp = newLocation
    table.insert(locations, locationTemp)
  end

  return locations
end

---@param position CMO__Location
---@param mode SBJ__AreaMode
---@return table<integer, CMO__ReferencePoint>|boolean
function GameUtils.NewArea(position, mode)
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
      local location = GameApi.World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = i
      })

      if location then
        local newRp = GameApi.ScenEdit_AddReferencePoint({
          side = side,
          latitude = location.latitude,
          longitude = location.longitude
        })

        if newRp then
          a = a + 1
          table.insert(rpTable, newRp.name)
        end
      end
    end
  elseif shape == 'square' then
    local distance = mode.distance
    for i = 0, 3 do
      local b = 45 + (90 * i) + bear_offset
      local location = GameApi.World_GetPointFromBearing({
        latitude = position.latitude,
        longitude = position.longitude,
        distance = distance,
        bearing = b
      })

      if location then
        GameApi.ScenEdit_AddReferencePoint({
          side = side,
          latitude = location.latitude,
          longitude = location.longitude
        })
      end
    end
  end

  return (rpTable)
end

---@param side string @The side the message is visible to (sidename may also be used in place of side)
---@param ... string @Variable number of string arguments to be printed inside the box
function GameUtils.PrintBox(side, ...)
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
  GameApi.ScenEdit_SpecialMessage(side, boxString)
end

---@param time string @A string in the format "YYYY-MM-DD HH:MM:SS"
---@return boolean
function GameUtils.IsAfterStartTime(time)
  local result = GameApi.ScenEdit_CurrentTime()

  if not result then
    return false
  end

  return result > Utils.ParseDatetimeToTimestamp(time)
end

---comment
---@param side string
---@param name string
---@param type string
---@param opts? CMO__Mission
---@param emcon? string
---@return CMO__Mission|nil
function GameUtils.CreateMission(side, name, type, opts, emcon)
  local mission = GameApi.ScenEdit_AddMission(side, name, type, opts)

  if not mission then
    return
  end

  if opts then
    mission = GameApi.ScenEdit_SetMission(side, name, opts)
  end

  if not mission then
    return
  end

  if emcon then
    local result = GameApi.ScenEdit_SetEMCON('mission', name, emcon)

    if not result then
      return
    end
  end

  return mission
end

return GameUtils
