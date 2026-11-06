local constants = require("src.core.constants")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

local PanelBattery = {}

---Turn a control panel path into a fast-moving course
---@param path SBJ__MovementPath
---@return CMO__Waypoint[] # Waypoints at fast speed and flank throttle
local function buildCourse(path)
  local course = {}

  for _, waypoint in ipairs(path.waypoints) do
    table.insert(course, {
      latitude = waypoint.latitude,
      longitude = waypoint.longitude,
      desiredSpeed = constants.SPEEDS.FAST,
      presetThrottle = constants.THROTTLES.FLANK
    })
  end

  return course
end

---Pair each control panel path with the zone at the same position
---@param paths SBJ__MovementPath[]
---@param areas CMO__Location[][]
---@return SBJ__Position[]
local function buildPositions(paths, areas)
  local positions = {}

  for index, path in ipairs(paths) do
    positions[index] = { course = buildCourse(path), area = areas[index] }
  end

  return positions
end

---Build the operational area a control panel placement draws, under a random 3-letter name
---A shelter loop ends in the reload area at its own position; without one the area has no SHRL, so
---transloaders leave their shelter along RL. The inverse of buildPlacement.
---@param placement SBJ__BatteryPlacement
---@return SBJ__OperationalArea
function PanelBattery.buildOperationalArea(placement)
  local tacticalAreas = placement.tacticalAreas
  local paths = placement.paths
  local operationalArea = {
    RL = buildPositions(paths.RL, tacticalAreas.RL),
    FP = buildPositions(paths.FP, tacticalAreas.FP),
    ATP = buildPositions(paths.ATP, tacticalAreas.ATP),
    HA = buildPositions(paths.HA, tacticalAreas.HA),
    uShapeVertices = tacticalAreas.uShapeVertices,
    shelterPoints = tacticalAreas.shelterPoints,
    name = "#" .. Utils.buildRandomText(3)
  }

  if #paths.SHRL > 0 then
    operationalArea.SHRL = buildPositions(paths.SHRL, tacticalAreas.RL)
  end

  return operationalArea
end

---@param vertices CMO__Location[]
---@return CMO__Location
local function calculateCentroid(vertices)
  local latitudeSum, longitudeSum = 0, 0

  for _, vertex in ipairs(vertices) do
    latitudeSum = latitudeSum + vertex.latitude
    longitudeSum = longitudeSum + vertex.longitude
  end

  return { latitude = latitudeSum / #vertices, longitude = longitudeSum / #vertices }
end

---@param ... CMO__Location[]
---@return CMO__Location[]
local function joinWaypoints(...)
  local waypoints = {}

  for _, part in ipairs({ ... }) do
    for _, waypoint in ipairs(part) do
      table.insert(waypoints, waypoint)
    end
  end

  return waypoints
end

---Resolve each position's zone to the vertices the map draws
---@param sideName string
---@param positions SBJ__Position[]
---@return CMO__Location[][]
local function findPositionAreas(sideName, positions)
  local areas = {}

  for index, position in ipairs(positions) do
    areas[index] = GameUtils.findAreaLocations(sideName, position.area)
  end

  return areas
end

---Draw an operational area the way the control panel map draws a placement
---An area stores one course per zone that already includes the reload leg, so the HA and ATP paths are
---stitched back from the first RL course. The inverse of buildOperationalArea.
---@param operationalArea SBJ__OperationalArea
---@param sideName string
---@return SBJ__BatteryPlacement
function PanelBattery.buildPlacement(operationalArea, sideName)
  local reloadCourse = operationalArea.RL[1].course
  local uShapeVertices = GameUtils.findAreaLocations(sideName, operationalArea.mask.area)
  if #uShapeVertices == 0 then
    uShapeVertices = operationalArea.uShapeVertices or {}
  end

  local paths = { FP = {}, HA = {}, ATP = {}, RL = {}, SHRL = {} }
  for index, position in ipairs(operationalArea.FP) do
    paths.FP[index] = { waypoints = position.course or {} }
  end
  for index, position in ipairs(operationalArea.HA) do
    paths.HA[index] = { waypoints = joinWaypoints(reloadCourse, position.course) }
  end
  for index, position in ipairs(operationalArea.ATP) do
    paths.ATP[index] = { waypoints = joinWaypoints(reloadCourse, position.course) }
  end
  for index, position in ipairs(operationalArea.RL) do
    paths.RL[index] = { waypoints = position.course }
  end
  for index, position in ipairs(operationalArea.SHRL or {}) do
    paths.SHRL[index] = { waypoints = position.course }
  end

  return {
    center = calculateCentroid(uShapeVertices),
    openingAngle = 0,
    tacticalAreas = {
      uShapeVertices = uShapeVertices,
      FP = findPositionAreas(sideName, operationalArea.FP),
      HA = findPositionAreas(sideName, operationalArea.HA),
      ATP = findPositionAreas(sideName, operationalArea.ATP),
      RL = findPositionAreas(sideName, operationalArea.RL),
      shelterPoints = operationalArea.shelterPoints
    },
    paths = paths
  }
end

---Display labels for missile system states
local STATE_LABELS = {
  [constants.MISSILE_UNIT_POSTURE.STATIC] = "STATIC",
  [constants.MISSILE_UNIT_POSTURE.REPOSITIONING] = "REPOSITIONING",
  [constants.MISSILE_UNIT_POSTURE.HIDE] = "HIDE",
  [constants.MISSILE_UNIT_POSTURE.RELOAD] = "RELOAD",
}

---Convert a missile system state enum to its display label
---@param state missileUnitPosture
---@return string # STATIC/REPOSITIONING/HIDE/RELOAD, or UNKNOWN
local function formatState(state)
  return STATE_LABELS[state] or "UNKNOWN"
end

---Calculate minutes elapsed since a reload started
---@param reloadStartTime number|nil Reload start time in seconds, nil when not reloading
---@param currentTime number
---@return number # Elapsed minutes rounded to 2 decimal places, never negative; 0 when not reloading
local function calculateReloadMinutes(reloadStartTime, currentTime)
  if reloadStartTime == nil then
    return 0
  end

  local minutes = math.floor(((currentTime - reloadStartTime) / 60) * 100 + 0.5) / 100
  if minutes < 0 then
    return 0
  end

  return minutes
end

---Build a battery's status from its saved state
---Config pairs every launcher with a transloader and its canister stock, and every deploy sets the
---states of all three.
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@param launcherDescriptor SBJ__LauncherDescriptor
---@param currentTime number
---@return SBJ__BatteryStatus|nil # nil before the battery's first deploy
local function buildBatteryStatus(systemConfig, systemState, launcherDescriptor, currentTime)
  local launcherState = systemState.launchers[launcherDescriptor.name]
  if not launcherState then
    return nil
  end

  local transloaderDescriptor = systemConfig.transloaders[launcherDescriptor.transloader]
  local canisterStockDescriptor = systemConfig.canisterStocks[transloaderDescriptor.canisterStock]
  local transloaderState = systemState.transloaders[transloaderDescriptor.name]
  local canisterStockState = systemState.canisterStocks[canisterStockDescriptor.name]

  return {
    launcherPosture = formatState(launcherState.state),
    transloaderPosture = formatState(transloaderState.state),
    transloaderMissiles = transloaderState.weaponCountCurrent,
    transloaderMissilesDefault = transloaderDescriptor.weaponCountDefault,
    canisterMissiles = canisterStockState.weaponCountCurrent,
    canisterMissilesDefault = canisterStockDescriptor.weaponCountDefault,
    launcherReloadMinutes = calculateReloadMinutes(launcherState.reloadStartTime, currentTime),
    transloaderReloadMinutes = calculateReloadMinutes(transloaderState.reloadStartTime, currentTime),
    reloadMinutesDefault = systemConfig.reloadTime / 60
  }
end

---Build the batteries the control panel lists, each placed where it is now
---A battery is placed at its saved state's area, or its config area before its first deploy
---(GroundStateStore.resolveOperationalArea), and carries a status once it has a saved state.
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
---@param sideName string
---@param currentTime number
---@return SBJ__PanelBattery[]
function PanelBattery.buildPanelBatteries(missileSystemConfigMap, groundState, sideName, currentTime)
  local batteries = {}

  for missileSystemType, systemConfig in pairs(missileSystemConfigMap) do
    local systemState = groundState.missileSystemTypes[missileSystemType]

    for _, descriptor in pairs(systemConfig.launchers) do
      local operationalArea = GroundStateStore.resolveOperationalArea(groundState, missileSystemType, descriptor)

      table.insert(batteries, {
        name = descriptor.name,
        missileSystem = descriptor.missileSystem,
        missileSystemType = missileSystemType,
        weaponRange = GameUtils.findWeaponRange(descriptor.weaponDBID) or 0,
        placement = PanelBattery.buildPlacement(operationalArea, sideName),
        status = systemState and buildBatteryStatus(systemConfig, systemState, descriptor, currentTime)
      })
    end
  end

  return batteries
end

return PanelBattery
