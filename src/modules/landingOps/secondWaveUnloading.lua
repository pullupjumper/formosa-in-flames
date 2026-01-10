local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local SecondWaveUnloading = {}

---Calculate course for barge to reach offload area
---Projects barge position onto LST approach bearing line using spherical geometry
---@param zone SBJ__OperationalZoneDescriptor Operation zone with offload area and LST settings
---@param unit CMO__Unit Barge unit to calculate course for
---@return CMO__Waypoint[]|nil # Destination waypoint, or nil on error
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

---Calculate course for RORO ship to follow barge to beach
---Returns two-waypoint course: first at LST approach distance, second at barge destination
---@param zone SBJ__OperationalZoneDescriptor Operation zone with LST settings
---@param unit CMO__Unit RORO ship unit to calculate course for
---@param bargeDest CMO__Waypoint[] Barge's destination waypoint
---@return CMO__Waypoint[]|nil # Two-waypoint course (approach, then barge position), or nil on error
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

---Initiate second wave unloading operations
---Directs barges to offload areas and RORO ships to follow, creating logistics chain RORO->Barge->Beach
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data to track barge-RORO relationships
---@param filteredUnits CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if second wave unloading successfully started
function SecondWaveUnloading.startSecondWaveUnloading(amphibOpsConfig, saveData, filteredUnits)
  local operationalZones = amphibOpsConfig.operationalZones
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor }[]
  local roros = {}
  ---@type { unit: CMO__Unit, zone: SBJ__OperationalZoneDescriptor, dest: CMO__Waypoint[] }[]
  local barges = {}

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit then
      for _, zone in ipairs(operationalZones) do
        if unit.name == "Barge" and unit.type == "Ship" and unit:inArea(zone.LSTAnchorageArea) then
          local destination = createCourseForBarge(zone, unit)
          if destination then
            unit.course = { destination }
            unit.manualSpeed = zone.LSTSettings.speed
            table.insert(barges, { unit = unit, zone = zone, dest = destination })
            saveData.c.PHIBOP.barges[unit.guid] = { guid = unit.guid, roros = {} }
          end
        end

        if unit.name == "RORO" and unit.type == "Ship" and unit:inArea(zone.LSTAnchorageArea) then
          table.insert(roros, { unit = unit, zone = zone })
        end
      end
    end
  end

  for _, roro in ipairs(roros) do
    for _, barge in ipairs(barges) do
      if barge.unit:inArea(roro.zone.LSTAnchorageArea) then
        table.insert(saveData.c.PHIBOP.barges[barge.unit.guid].roros, roro.unit.guid)
        local course = createCourseForRORO(roro.zone, roro.unit, barge.dest)
        if course then
          roro.unit.course = course
          roro.unit.manualSpeed = roro.zone.LSTSettings.speed
        end
      end
    end
  end

  return true
end

---Offload vehicles from ship cargo to the beach
---Deletes cargo from ship and spawns facility units in line formation at calculated positions
---@param params SBJ__VehicleOffloadParams Offload parameters (ship, number, bearing, distances)
---@return integer|nil # Number of vehicles successfully offloaded, or nil on error
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
  ---@type { guid: string, dbid: number, name: string, type: number }[]
  local cargoItems = {}
  local count = 0
  local resultCount = 0

  for _, item in ipairs(ship.cargo[1].cargo) do
    table.insert(cargoItems, { guid = item.GUID, dbid = item.dbid, name = item.name, type = item.type })
    count = count + 1

    if count == params.num then
      break
    end
  end

  for idx, item in ipairs(cargoItems) do
    ship:deleteUnitCargo(item.guid)
    local type = "Facility"

    if item.type == 2 then
      type = "Ground unit"
    end

    local vehicle = GameApi.ScenEdit_AddUnit({
      side      = "China",
      type      = type,
      latitude  = ACVlocations[idx].latitude,
      longitude = ACVlocations[idx].longitude,
      dbid      = item.dbid,
      unitname  = item.name,
    })

    if not vehicle then
      return
    end

    resultCount = resultCount + 1
  end

  return resultCount
end

---Check if a barge's logistics bridge has been destroyed
---Returns true if bridge GUID exists but unit is destroyed
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if bridge was created but is now destroyed
function SecondWaveUnloading.isBridgeDestroyed(saveData, ship)
  if saveData.c.PHIBOP.barges[ship.guid] and saveData.c.PHIBOP.barges[ship.guid].bridgeGUID then
    local bridge = GameApi.ScenEdit_GetUnit(saveData.c.PHIBOP.barges[ship.guid].bridgeGUID)

    if not bridge then
      Logger.log("PHIBOP", "Bridge is destroyed")
      return true
    end

    return false
  end

  return true
end

---Check if a barge has an extended logistics bridge
---Bridge is created when barge reaches offload position for vehicle transfer operations
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if barge has an active bridge GUID
function SecondWaveUnloading.hasExtendedBridge(saveData, ship)
  return saveData.c.PHIBOP.barges[ship.guid].bridgeGUID ~= nil
end

---Get the operational zone for a barge-RORO pair
---Checks if both units are in same ACV area and within 1nm of each other
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param barge CMO__Unit Barge ship
---@param roro CMO__Unit RORO ship
---@return SBJ__OperationalZoneDescriptor|nil # Operation zone descriptor, or nil if units not properly positioned
function SecondWaveUnloading.getBargeROROZone(amphibOpsConfig, barge, roro)
  for _, zone in ipairs(amphibOpsConfig.operationalZones) do
    local distance = GameApi.Tool_Range(roro.guid, barge.guid)

    if distance and roro:inArea(zone.ACV.area) and barge:inArea(zone.ACV.area) and distance < 1 then
      return zone
    end
  end

  return nil
end

return SecondWaveUnloading
