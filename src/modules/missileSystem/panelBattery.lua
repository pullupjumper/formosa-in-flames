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

---Build the operational area one control panel entry draws, under a random 3-letter name
---Only the first RL path is used; SHRL shares the reload zone. The inverse of buildPlacement.
---@param entry SBJ__MissileSystemResult
---@return SBJ__OperationalArea
function PanelBattery.buildOperationalArea(entry)
  local tacticalAreas = entry.tacticalAreas
  local paths = entry.paths
  local operationalArea = {
    RL = { { course = buildCourse(paths.RL[1]), area = tacticalAreas.reloadArea } },
    FP = {},
    ATP = { { course = buildCourse(paths.ATP), area = tacticalAreas.atpArea } },
    HA = { { course = buildCourse(paths.HA), area = tacticalAreas.hideArea } },
    SHRL = { { course = buildCourse(paths.SHRL), area = tacticalAreas.reloadArea } },
    uShapeVertices = tacticalAreas.uShapeVertices,
    shelterPoints = tacticalAreas.shelterPoints,
    name = "#" .. Utils.buildRandomText(3)
  }

  for index, firePoint in ipairs(paths.FP) do
    table.insert(operationalArea.FP, { course = buildCourse(firePoint), area = tacticalAreas.firePoints[index] })
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

---Draw an operational area the way the control panel map draws a placement
---An area stores one course per zone that already includes the reload leg, so the HA and ATP paths are
---stitched back from the RL course, and each RL path starts where its fire point course ends. The inverse
---of buildOperationalArea.
---@param operationalArea SBJ__OperationalArea
---@param sideName string
---@return SBJ__BatteryPlacement
function PanelBattery.buildPlacement(operationalArea, sideName)
  local reloadCourse = operationalArea.RL[1].course
  local uShapeVertices = GameUtils.findAreaLocations(sideName, operationalArea.mask.area)
  if #uShapeVertices == 0 then
    uShapeVertices = operationalArea.uShapeVertices or {}
  end

  local firePoints, firePaths, reloadPaths = {}, {}, {}
  for index, position in ipairs(operationalArea.FP) do
    local course = position.course or {}
    firePoints[index] = GameUtils.findAreaLocations(sideName, position.area)
    firePaths[index] = { waypoints = course }
    reloadPaths[index] = { waypoints = joinWaypoints({ course[#course] }, reloadCourse) }
  end

  local shelterLoop = operationalArea.SHRL and operationalArea.SHRL[1]

  return {
    center = calculateCentroid(uShapeVertices),
    openingAngle = 0,
    tacticalAreas = {
      uShapeVertices = uShapeVertices,
      atpArea = GameUtils.findAreaLocations(sideName, operationalArea.ATP[1].area),
      hideArea = GameUtils.findAreaLocations(sideName, operationalArea.HA[1].area),
      reloadArea = GameUtils.findAreaLocations(sideName, operationalArea.RL[1].area),
      firePoints = firePoints,
      shelterPoints = operationalArea.shelterPoints
    },
    paths = {
      FP = firePaths,
      HA = { waypoints = joinWaypoints(reloadCourse, operationalArea.HA[1].course) },
      ATP = { waypoints = joinWaypoints(reloadCourse, operationalArea.ATP[1].course) },
      RL = reloadPaths,
      SHRL = { waypoints = shelterLoop and shelterLoop.course or {} }
    }
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
---Config pairs every firing unit with a resupply unit and its canister stock, and every deploy sets the
---states of all three.
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@param firingUnitDescriptor SBJ__FiringUnitDescriptor
---@param currentTime number
---@return SBJ__BatteryStatus|nil # nil before the battery's first deploy
local function buildBatteryStatus(systemConfig, systemState, firingUnitDescriptor, currentTime)
  local firingUnitState = systemState.firingUnits[firingUnitDescriptor.name]
  if not firingUnitState then
    return nil
  end

  local resupplyUnitDescriptor = systemConfig.resupplyUnits[firingUnitDescriptor.resupplyUnit]
  local canisterStockDescriptor = systemConfig.canisterStocks[resupplyUnitDescriptor.canisterStock]
  local resupplyUnitState = systemState.resupplyUnits[resupplyUnitDescriptor.name]
  local canisterStockState = systemState.canisterStocks[canisterStockDescriptor.name]

  return {
    firingPosture = formatState(firingUnitState.state),
    resupplyPosture = formatState(resupplyUnitState.state),
    resupplyMissiles = resupplyUnitState.weaponCountCurrent,
    resupplyMissilesDefault = resupplyUnitDescriptor.weaponCountDefault,
    canisterMissiles = canisterStockState.weaponCountCurrent,
    canisterMissilesDefault = canisterStockDescriptor.weaponCountDefault,
    firingReloadMinutes = calculateReloadMinutes(firingUnitState.reloadStartTime, currentTime),
    resupplyReloadMinutes = calculateReloadMinutes(resupplyUnitState.reloadStartTime, currentTime),
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

    for _, descriptor in pairs(systemConfig.firingUnits) do
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
