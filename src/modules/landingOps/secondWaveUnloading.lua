local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local SecondWaveUnloading = {}

---comment
---@param zone SBJ__OperationalZone
---@param unit CMO__Unit
---@return CMO__Waypoint[]|nil
local function createCourseForBarge(zone, unit)
  local points = GameApi.ScenEdit_GetReferencePoints({ side = "China", area = zone.offloadArea })

  if not points then
    return nil
  end

  local centerPoint = Utils.calculateSphericalCenter(points)

  if centerPoint then
    local d1 = GameApi.Tool_Range({ latitude = unit.latitude, longitude = unit.longitude }, centerPoint)

    if not d1 then
      return nil
    end

    local b1 = GameApi.Tool_Bearing({ latitude = unit.latitude, longitude = unit.longitude }, centerPoint)

    if not b1 then
      return nil
    end

    local b2 = math.abs(zone.LSTSettings.course.bearing - b1)
    local d2 = d1 * math.cos(b2 * 2 * math.pi / 360)
    local destination = GameApi.World_GetPointFromBearing({
      latitude = unit.latitude,
      longitude = unit.longitude,
      distance = d2,
      bearing = zone.LSTSettings.course.bearing
    })

    if not destination then
      return nil
    end

    return destination
  end

  return nil
end

---comment
---@param zone SBJ__OperationalZone
---@param unit CMO__Unit
---@param bargeDest CMO__Waypoint[]
---@return CMO__Waypoint[]|nil
local function createCourseForRORO(zone, unit, bargeDest)
  local destination = GameApi.World_GetPointFromBearing({
    latitude = unit.latitude,
    longitude = unit.longitude,
    distance = zone.LSTSettings.course.distance,
    bearing = zone.LSTSettings.course.bearing
  })

  if not destination then
    return nil
  end

  return { destination, bargeDest }
end

---comment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param units CMO__SideUnit
---@return boolean
function SecondWaveUnloading.startSecondWaveUnloading(config, saveData, units)
  local operationalZones = config.c.PHIBOP.operationalZones
  local roros = {}
  local barges = {}

  for _, item in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(item.guid)

    if unit then
      for _, zone in ipairs(operationalZones) do
        if unit.name == 'Barge' and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
          local destination = createCourseForBarge(zone, unit)
          if destination then
            unit.course = { destination }
            unit.manualSpeed = zone.LSTSettings.speed
            table.insert(barges, { unit = unit, zone = zone, dest = destination })
            saveData.c.PHIBOP.barges[unit.guid] = { guid = unit.guid, roros = {} }
          end
        end

        if unit.name == 'RORO' and unit.type == 'Ship' and unit:inArea(zone.LSTAnchorageArea) then
          table.insert(roros, { unit = unit, zone = zone })
        end
      end
    end
  end

  for _, item in ipairs(roros) do
    for _, barge in ipairs(barges) do
      if barge.unit:inArea(item.zone.LSTAnchorageArea) then
        table.insert(saveData.c.PHIBOP.barges[barge.unit.guid].roros, item.unit.guid)
        local course = createCourseForRORO(item.zone, item.unit, barge.dest)
        if course then
          item.unit.course = course
          item.unit.manualSpeed = item.zone.LSTSettings.speed
        end
      end
    end
  end

  return true
end

---@param params SBJ__OffloadVehicles_Params
---@return number|nil
function SecondWaveUnloading.offloadVehicles(params)
  local ship = params.ship
  if ship == nil or ship.IsDestroyed then return end
  local ACVlocations = GameUtils.generateLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance,
    firstDistance = params.firstDistance
  })
  local cargoList = {}
  local count = 0
  local resultCount = 0

  for _, v in ipairs(ship.cargo[1].cargo) do
    table.insert(cargoList, { guid = v.guid, dbid = v.dbid, name = v.name })
    count = count + 1

    if count == params.num then
      break
    end
  end

  for index, v in ipairs(cargoList) do
    ship:deleteUnitCargo(v.guid)

    local u = GameApi.ScenEdit_AddUnit({
      side      = 'China',
      type      = 'Facility',
      latitude  = ACVlocations[index].latitude,
      longitude = ACVlocations[index].longitude,
      dbid      = v.dbid,
      unitname  = v.name,
    })

    if not u then
      return
    end

    resultCount = resultCount + 1
  end

  return resultCount
end

---comment
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean
function SecondWaveUnloading.isBridgeDestroyed(saveData, ship)
  if saveData.c.PHIBOP.barges[ship.guid] and saveData.c.PHIBOP.barges[ship.guid].bridgeGUID then
    local bridge = GameApi.ScenEdit_GetUnit(saveData.c.PHIBOP.barges[ship.guid].bridgeGUID)

    if not bridge then
      Logger.log('Bridge is destroyed')
      return true
    end

    return false
  end

  return true
end

---comment
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean
function SecondWaveUnloading.hasExtendedBridge(saveData, ship)
  return saveData.c.PHIBOP.barges[ship.guid].bridgeGUID ~= nil
end

---comment
---@param config SBJ__CONFIG
---@param barge CMO__Unit
---@param roro CMO__Unit
---@return SBJ__OperationalZone|nil
function SecondWaveUnloading.getBargeROROZone(config, barge, roro)
  for _, zone in ipairs(config.c.PHIBOP.operationalZones) do
    local d = GameApi.Tool_Range(roro.guid, barge.guid)

    if d and roro:inArea(zone.ACV.area) and barge:inArea(zone.ACV.area) and d < 1 then
      return zone
    end
  end

  return nil
end

return SecondWaveUnloading
