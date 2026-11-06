local constants = require("src.core.constants")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

local ControlPanelLayout = {}

---Position types whose zones are resolved to vertices for the control panel
local SETUP_POSITION_TYPES = { "HA", "FP", "RL", "ATP", "SHRL" }
---@cast SETUP_POSITION_TYPES SBJ__PositionType[]

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
---Only the first RL path is used; SHRL shares the reload zone.
---@param entry SBJ__MissileSystemResult
---@return SBJ__OperationalArea
function ControlPanelLayout.buildOperationalArea(entry)
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

---Build the control panel's missile system rows, with zone names resolved to vertices
---Each firing unit is drawn where its battery is now (GroundStateStore.resolveOperationalArea):
---its saved state's area, or its config area before its first deploy.
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
---@param sideName string
---@return SBJ__PanelMissileSystemSet # Firing units only, keyed by system type
function ControlPanelLayout.buildPanelMissileSystems(missileSystemConfigMap, groundState, sideName)
  local rows = {}

  for key, system in pairs(missileSystemConfigMap) do
    local firingUnits = {}

    for name, descriptor in pairs(system.firingUnits) do
      local operationalArea = Utils.deepCopy(GroundStateStore.resolveOperationalArea(groundState, key, descriptor))

      for _, attr in ipairs(SETUP_POSITION_TYPES) do
        local positions = operationalArea[attr]

        if positions then
          for _, position in ipairs(positions) do
            if position.area then
              local vertices = GameUtils.findAreaLocations(sideName, position.area)

              if #vertices > 0 then
                position.area = vertices
              end
            end
          end
        end
      end

      local uShapeVertices = GameUtils.findAreaLocations(sideName, operationalArea.mask.area)

      if #uShapeVertices > 0 then
        operationalArea.uShapeVertices = uShapeVertices
      end

      firingUnits[name] = {
        name = descriptor.name,
        missileSystem = descriptor.missileSystem,
        weaponRange = GameUtils.findWeaponRange(descriptor.weaponDBID) or 0,
        operationalArea = operationalArea
      }
    end

    rows[key] = { firingUnits = firingUnits }
  end

  return rows
end

return ControlPanelLayout
