GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall

function CalculateSphericalCenter(coords)
  -- 檢查輸入是否有效
  if not coords or #coords < 4 then
    return nil, "需要至少4個座標點來形成四方形"
  end

  -- 初始化笛卡爾座標總和
  local xSum = 0
  local ySum = 0
  local zSum = 0

  -- 將經緯度轉換為笛卡爾座標並計算總和
  for _, point in ipairs(coords) do
    if not point.latitude or not point.longitude then
      return nil, "每個座標點必須包含latitude和longitude屬性"
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
  local centerLat = math.deg(math.atan2(zAvg, hyp))
  local centerLon = math.deg(math.atan2(yAvg, xAvg))

  return {
    latitude = centerLat,
    longitude = centerLon
  }
end

---comment
---@param zone any
---@param unit CMO__Unit
---@return CMO__Waypoint[]|nil
function _createCourseForBarge(zone, unit)
  local points, err = SafeCall("GameApi.ScenEdit_GetReferencePoints", GameApi.ScenEdit_GetReferencePoints,
    { side = "China", area = zone.offloadArea })

  if not points then
    Logger.error("Failed to get reference points for area '" .. zone.offloadArea .. "': " .. err)
    return nil
  end

  local centerPoint = CalculateSphericalCenter(points)

  if centerPoint then
    local d1, err = SafeCall(
      "GameApi.Tool_Range",
      GameApi.Tool_Range,
      { latitude = unit.latitude, longitude = unit.longitude },
      centerPoint
    )

    if not d1 then
      Logger.error("Failed to calculate range between points: " .. err)
      return nil
    end

    local b1, err = SafeCall(
      "GameApi.Tool_Bearing",
      GameApi.Tool_Bearing,
      { latitude = unit.latitude, longitude = unit.longitude },
      centerPoint
    )

    if not b1 then
      Logger.error("Failed to calculate bearing between points: " .. err)
      return nil
    end

    local b2 = math.abs(zone.LSTSettings.course.bearing - b1)
    local d2 = d1 * math.cos(b2 * 2 * math.pi / 360)
    local destination, err = SafeCall(
      "GameApi.World_GetPointFromBearing",
      GameApi.World_GetPointFromBearing,
      {
        latitude = unit.latitude,
        longitude = unit.longitude,
        distance = d2,
        bearing = zone.LSTSettings.course.bearing
      }
    )

    if not destination then
      Logger.error("Failed to calculate destination point: " .. err)
      return nil
    end

    return destination
  end

  return nil
end

function SecondWaveUnloading(CONFIG, saveData, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones
  local roros = {}
  local barges = {}

  for _, item in ipairs(units) do
    -- local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, item.guid)
    local unit = GameApi.ScenEdit_GetUnit(item.guid)
    -- if not unit then
    --   Logger.error("Failed to get unit '" .. item.name .. "': " .. err)
    --   return false
    -- end

    for _, zone in ipairs(operationalZones) do
      if unit.name == 'Barge' and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
        local destination = _createCourseForBarge(zone, unit)
        unit.course = { destination }
        unit.manualSpeed = zone.LSTSettings.speed
        table.insert(barges, { unit = unit, zone = zone, dest = destination })
        saveData.c.PHIBOP.barges[unit.guid] = { guid = unit.guid, roros = {} }
      end

      if unit.name == 'RORO' and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
        table.insert(roros, { unit = unit, zone = zone })
      end
    end
  end
end
