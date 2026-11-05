local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

local ControlPanelLayout = {}

---Position types whose zones are resolved to vertices for the control panel
local SETUP_POSITION_TYPES = { "HA", "FP", "RL", "AHA", "SHRL" }
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

---Build a battery layout from one control panel entry
---@param entry SBJ__MissileSystemResult
---@param areaName string
---@return SBJ__MissileSystemLayout # Layout accepted by MissileSystem.redeployFromControlPanel
local function buildLayout(entry, areaName)
  local tacticalAreas = entry.tacticalAreas
  local paths = entry.paths
  local operationalArea = {
    RL = { { course = buildCourse(paths.RL[1]), area = tacticalAreas.reloadArea } },
    FP = {},
    AHA = { { course = buildCourse(paths.AHA), area = tacticalAreas.ammoArea } },
    HA = { { course = buildCourse(paths.HA), area = tacticalAreas.hideArea } },
    SHRL = { { course = buildCourse(paths.SHRL), area = tacticalAreas.reloadArea } },
    uShapeVertices = tacticalAreas.uShapeVertices,
    shelterPoints = tacticalAreas.shelterPoints,
    name = areaName
  }

  for index, firePoint in ipairs(paths.FP) do
    table.insert(operationalArea.FP, { course = buildCourse(firePoint), area = tacticalAreas.firePoints[index] })
  end

  return {
    missileSystemType = entry.missileSystemType,
    unitname = entry.unitname,
    operationalArea = operationalArea
  }
end

---Build battery layouts from control panel entries, giving each a random operational area name
---@param entries SBJ__MissileSystemResult[]
---@return SBJ__MissileSystemLayout[] # Layouts accepted by MissileSystem.redeployFromControlPanel
function ControlPanelLayout.buildLayouts(entries)
  local layouts = {}

  for _, entry in ipairs(entries) do
    table.insert(layouts, buildLayout(entry, "#" .. Utils.buildRandomText(3)))
  end

  return layouts
end

---@param weaponDBID number | number[]
---@return number|nil # Max land range in nautical miles; nil if the weapon has no land range
local function findWeaponRange(weaponDBID)
  local id = weaponDBID
  local dbid
  if type(id) == "table" then
    dbid = id[1]
  else
    dbid = id
  end
  local weaponInfo = GameApi.ScenEdit_QueryDB("weapon", dbid)
  return tonumber(weaponInfo and weaponInfo.ranges and weaponInfo.ranges.land and weaponInfo.ranges.land.max)
end

---Build the control panel's missile system rows, with zone names resolved to vertices
---Each firing unit is drawn where its battery is now (GroundStateStore.resolveOperationalArea):
---its saved state's area, or its config area before its first deploy.
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig> # Copies without resupply units and ammunitions, keyed by system type
function ControlPanelLayout.buildDeploymentSystems(missileSystemConfigMap, groundState, sideName)
  local rows = {}

  for key, system in pairs(missileSystemConfigMap) do
    local copy = Utils.deepCopy(system)
    copy.resupplyUnits = nil
    copy.ammunitions = nil

    for name, descriptor in pairs(copy.firingUnits) do
      ---@cast descriptor SBJ__FiringUnitWithWeaponRangeDescriptor
      local operationalArea = Utils.deepCopy(
        GroundStateStore.resolveOperationalArea(groundState, key, system.firingUnits[name])
      )
      descriptor.operationalArea = operationalArea
      descriptor.weaponRange = findWeaponRange(descriptor.weaponDBID) or 0

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
    end

    rows[key] = copy
  end

  return rows
end

return ControlPanelLayout
