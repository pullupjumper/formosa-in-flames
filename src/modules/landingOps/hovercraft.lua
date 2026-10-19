local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local RoutePlanner = require("src.modules.landingOps.routePlanner")

---Route loaded Type 726A hovercraft from the LHD and LPDs through cleared lanes to a parking slot.
---Route each hovercraft once. After it arrives, the cargo mission takes over.
local Hovercraft = {}

-- ============================================================================
-- Constants
-- ============================================================================

---@type table<number, true>
local MOTHERSHIP_DBIDS = {
  [constants.PLATFORMS.TYPE_075] = true,
  [constants.PLATFORMS.TYPE_076] = true,
  [constants.PLATFORMS.TYPE_071] = true,
}

-- ============================================================================
-- Helpers
-- ============================================================================

---Check if a unit carries any cargo
---@param unit CMO__Unit
---@return boolean # True if the unit carries any cargo
local function hasCargo(unit)
  return unit.cargo ~= nil and unit.cargo[1] ~= nil and unit.cargo[1].cargo ~= nil and #unit.cargo[1].cargo > 0
end

---Find the cargo mission to fill next: the first mission below its unit count, else the last mission
---@param zone SBJ__OperationalZoneDescriptor
---@param hovercraftMap table<string, SBJ__HovercraftState>
---@return string
local function findMissionName(zone, hovercraftMap)
  local missions = zone.landing.hovercraft.missions
  local counts = {}
  for _, entry in pairs(hovercraftMap) do
    counts[entry.missionName] = (counts[entry.missionName] or 0) + 1
  end

  for _, mission in ipairs(missions) do
    if (counts[mission.name] or 0) < mission.unitCount then
      return mission.name
    end
  end
  return missions[#missions].name
end

---Find the hovercraft on one mothership that are ready, loaded, and not yet routed
---@param ship CMO__Unit
---@param hovercraftMap table<string, SBJ__HovercraftState>
---@return CMO__Unit[]
local function findReadyHovercraft(ship, hovercraftMap)
  local ready = {}
  local embarked = ship.embarkedUnits and ship.embarkedUnits[constants.PLATFORM_TYPES.BOATS] or {}

  for _, guid in ipairs(embarked) do
    if not hovercraftMap[guid] then
      local craft = GameApi.ScenEdit_GetUnit(guid)
      if craft and craft.dbid == constants.PLATFORMS.TYPE_726A and craft.readytime_v == 0 and hasCargo(craft) then
        table.insert(ready, craft)
      end
    end
  end

  return ready
end

-- ============================================================================
-- Public API
-- ============================================================================

---Route and launch ready hovercraft from the motherships anchored in the zone. Set the course first, then launch.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ships CMO__SideUnit[]
function Hovercraft.launchHovercraft(amphibOps, zone, zoneState, ships)
  if not zoneState.lanes then
    return
  end

  zoneState.hovercraft = zoneState.hovercraft or {}
  zoneState.queueCounters = zoneState.queueCounters or {}
  zoneState.laneSlots = zoneState.laneSlots or {}
  zoneState.laneSlots.hovercraft = zoneState.laneSlots.hovercraft or {}
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Launch hovercraft")

  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)

    if ship and MOTHERSHIP_DBIDS[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) then
      for _, craft in ipairs(findReadyHovercraft(ship, zoneState.hovercraft)) do
        local plan = RoutePlanner.buildRoute({
          lanes = zoneState.lanes,
          launchPos = { latitude = ship.latitude, longitude = ship.longitude },
          guid = craft.guid,
          routeConfig = amphibOps.tuning.route,
          queueCounters = zoneState.queueCounters,
          laneSlots = zoneState.laneSlots.hovercraft,
          cells = zoneState.obstacle and zoneState.obstacle.cells,
          isAlive = GameUtils.hasUnit,
        }, { isFromDeployLine = true })

        if plan then
          craft.course = plan.course
          craft.manualSpeed = zone.landing.hovercraft.speed
          craft:Launch(true)
          zoneState.hovercraft[craft.guid] = {
            missionName = findMissionName(zone, zoneState.hovercraft),
            finalPoint = plan.course[#plan.course],
            arrived = false,
          }
          if DebugFlow.isLandingTeleport(amphibOps) then
            DebugFlow.teleport(craft.guid, zoneState.hovercraft[craft.guid].finalPoint)
          end
          report.add("OK", { hovercraft = craft.guid, beachLane = plan.beachLaneId, slot = plan.slot })
        else
          report.add("SKIP", { hovercraft = craft.guid, reason = "no_cleared_lane_slot" })
        end
      end
    end
  end

  report.emit()
end

---Update the state of hovercraft that reached their parking slot
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
function Hovercraft.updateHovercraft(amphibOps, zoneState)
  local arrivalNm = amphibOps.tuning.route.arrivalNm

  for guid, entry in pairs(zoneState.hovercraft or {}) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if not entry.arrived and unit then
      local range = GameApi.Tool_Range(guid, entry.finalPoint)
      if range and range < arrivalNm then
        entry.arrived = true
        -- TODO: Assign the cargo mission in entry.missionName. The user writes this mission.
        unit.mission = entry.missionName
      end
    end
  end
end

return Hovercraft
