local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Utils = require("src.utils.utils")

local SetupLayout = {}

---Position types whose zones are resolved to vertices for the setup menu
local SETUP_POSITION_TYPES = { "HA", "FP", "RL", "AHA", "SHRL" }

---Turn a setup menu path into a fast-moving course
---@param path SBJ__MovementPath Path drawn in the setup menu
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

---Build a battery layout from one setup menu entry
---@param entry SBJ__MissileSystemSetupEntry Battery placement submitted by the setup menu
---@param areaName string Name for the new operational area
---@return SBJ__MissileSystemLayout # Layout accepted by MissileSystem.redeploy
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
    category = entry.category,
    unitname = entry.unitname,
    operationalArea = operationalArea
  }
end

---Build battery layouts from setup menu entries, giving each a random operational area name
---@param entries SBJ__MissileSystemSetupEntry[] Battery placements submitted by the setup menu
---@return SBJ__MissileSystemLayout[] # Layouts accepted by MissileSystem.redeploy
function SetupLayout.buildLayouts(entries)
  local layouts = {}

  for _, entry in ipairs(entries) do
    table.insert(layouts, buildLayout(entry, "#" .. Utils.buildRandomText(3)))
  end

  return layouts
end

---Resolve a zone's reference point names to their vertices
---@param sideName string Side owning the reference points
---@param area string[] Reference point names
---@return CMO__Location[] # Vertices, empty when none are found
local function resolveVertices(sideName, area)
  local vertices = {}
  local points = GameApi.ScenEdit_GetReferencePoints({ side = sideName, area = area })

  if points then
    for _, point in ipairs(points) do
      table.insert(vertices, { latitude = tonumber(point.latitude), longitude = tonumber(point.longitude) })
    end
  end

  return vertices
end

---Build the setup menu's missile system rows, with zone names resolved to vertices
---@param groundForceConfig SBJ__GroundForceConfig Side ground force configuration; left untouched
---@param sideName string Side owning the reference points
---@return table<string, SBJ__MissileSystemConfig> # Copies without resupply units and ammunitions, keyed by system type
function SetupLayout.buildSetupMenuRows(groundForceConfig, sideName)
  local rows = {}

  for key, system in pairs(groundForceConfig) do
    ---@cast system SBJ__MissileSystemConfig
    local copy = Utils.deepCopy(system)
    copy.resupplyUnits = nil
    copy.ammunitions = nil

    for _, descriptor in pairs(copy.firingUnits) do
      local operationalArea = descriptor.operationalArea

      for _, attr in ipairs(SETUP_POSITION_TYPES) do
        ---@type SBJ__Position[]
        local positions = operationalArea[attr]

        if positions then
          for _, position in ipairs(positions) do
            if position.area then
              local vertices = resolveVertices(sideName, position.area)

              if #vertices > 0 then
                position.area = vertices
              end
            end
          end
        end
      end

      local uShapeVertices = resolveVertices(sideName, operationalArea.mask.area)

      if #uShapeVertices > 0 then
        operationalArea.uShapeVertices = uShapeVertices
      end
    end

    rows[key] = copy
  end

  return rows
end

return SetupLayout
