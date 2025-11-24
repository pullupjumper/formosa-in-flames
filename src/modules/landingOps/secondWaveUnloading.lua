local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")

local SecondWaveUnloading = {}

--- Calculate course for barge to reach offload area
--- Projects the barge's position onto the LST approach bearing line
--- Uses spherical geometry to find the nearest point on the approach path
---@param zone SBJ__OperationZoneDescriptor Operation zone with offload area and LST settings
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

--- Calculate course for RORO ship to follow barge to beach
--- RORO ships follow barges to establish a logistics chain
--- First waypoint is LST approach distance, second waypoint is barge destination
---@param zone SBJ__OperationZoneDescriptor Operation zone with LST settings
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

--- Initiate second wave unloading operations
--- Directs barges to offload areas and RORO ships to follow barges
--- Creates logistics chain: RORO -> Barge -> Beach for vehicle delivery
--- Tracks barge-RORO relationships in saveData for bridge creation
---@param config SBJ__CONFIG Global configuration (unused but kept for consistency)
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param saveData SBJ__SaveData Save data to track barge-RORO relationships
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if second wave unloading successfully started
function SecondWaveUnloading.startSecondWaveUnloading(config, amphibOpsConfig, saveData, units)
  local operationalZones = amphibOpsConfig.operationalZones
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

--- Offload vehicles from ship cargo to the beach
--- Deletes cargo from ship and spawns facility units at calculated positions
--- Vehicles are placed in a line formation based on bearing and spacing
--- Used for unloading heavy equipment that cannot use ACVs
---@param params SBJ__VehicleOffloadParams Offload parameters (ship, number, bearing, distances)
---@return number|nil # Number of vehicles successfully offloaded, or nil on error
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
    table.insert(cargoList, { guid = v.guid, dbid = v.dbid, name = v.name, type = v.Type })
    count = count + 1

    if count == params.num then
      break
    end
  end

  for index, v in ipairs(cargoList) do
    ship:deleteUnitCargo(v.guid)

    local type = 'Facility'

    if v.type == 2 then
      type = 'Ground unit'
    end

    local u = GameApi.ScenEdit_AddUnit({
      side      = 'China',
      type      = type,
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

--- Check if a barge's logistics bridge has been destroyed
--- The bridge is a facility unit connecting barge to shore
--- Returns true if bridge GUID exists but unit is destroyed
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if bridge was created but is now destroyed
function SecondWaveUnloading.isBridgeDestroyed(saveData, ship)
  if saveData.c.PHIBOP.barges[ship.guid] and saveData.c.PHIBOP.barges[ship.guid].bridgeGUID then
    local bridge = GameApi.ScenEdit_GetUnit(saveData.c.PHIBOP.barges[ship.guid].bridgeGUID)

    if not bridge then
      Logger.log("PHIBOP", 'Bridge is destroyed')
      return true
    end

    return false
  end

  return true
end

--- Check if a barge has an extended logistics bridge
--- Bridge is created when barge reaches offload position
--- Used to determine if barge is ready for vehicle transfer operations
---@param saveData SBJ__SaveData Save data containing barge bridge tracking
---@param ship CMO__Unit Barge ship to check
---@return boolean # True if barge has an active bridge GUID
function SecondWaveUnloading.hasExtendedBridge(saveData, ship)
  return saveData.c.PHIBOP.barges[ship.guid].bridgeGUID ~= nil
end

--- Get the operational zone for a barge-RORO pair
--- Checks if both units are in the same ACV deployment area and within 1nm of each other
--- Used to determine which zone configuration applies to the logistics chain
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param barge CMO__Unit Barge ship
---@param roro CMO__Unit RORO ship
---@return SBJ__OperationZoneDescriptor|nil # Operation zone descriptor, or nil if units not properly positioned
function SecondWaveUnloading.getBargeROROZone(amphibOpsConfig, barge, roro)
  for _, zone in ipairs(amphibOpsConfig.operationalZones) do
    local d = GameApi.Tool_Range(roro.guid, barge.guid)

    if d and roro:inArea(zone.ACV.area) and barge:inArea(zone.ACV.area) and d < 1 then
      return zone
    end
  end

  return nil
end

return SecondWaveUnloading
