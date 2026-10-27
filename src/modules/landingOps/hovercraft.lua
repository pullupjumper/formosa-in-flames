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

---@enum SBJ__HovercraftPhaseType
local PHASE = {
  ENROUTE   = "enroute",
  UNLOADING = "unloading",
  RETURNING = "returning",
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

---Check if any mothership in the zone still holds a loaded hovercraft that is not routed yet
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ships CMO__SideUnit[]
---@return boolean # True if a ready hovercraft is still on its mothership
function Hovercraft.hasUnlaunchedHovercraft(zone, zoneState, ships)
  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)
    if ship and constants.MOTHERSHIP_DBID_SET[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) and
        #findReadyHovercraft(ship, zoneState.hovercraft or {}) > 0 then
      return true
    end
  end

  return false
end

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
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Launch hovercraft")

  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)

    if ship and constants.MOTHERSHIP_DBID_SET[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) then
      for _, craft in ipairs(findReadyHovercraft(ship, zoneState.hovercraft)) do
        local plan = RoutePlanner.buildRoute({
          lanes = zoneState.lanes,
          launchPos = { latitude = ship.latitude, longitude = ship.longitude },
          guid = craft.guid,
          routeConfig = amphibOps.tuning.route,
          queueCounters = zoneState.queueCounters,
          laneSlots = zoneState.laneSlots,
          cells = zoneState.obstacle and zoneState.obstacle.cells,
          isAlive = GameUtils.hasUnit,
        }, { isFromDeployLine = true })

        if plan then
          craft.course = plan.course
          craft.manualSpeed = zone.landing.hovercraft.speed
          craft:Launch(true)
          zoneState.hovercraft[craft.guid] = {
            missionName = zone.landing.hovercraft.missionName,
            finalPoint = plan.course[#plan.course],
            phase = PHASE.ENROUTE,
          }

          report.add("OK", { hovercraft = craft.guid, beachLane = plan.beachLaneId, slot = plan.slot })
        else
          report.add("SKIP", { hovercraft = craft.guid, reason = "no_cleared_lane_slot" })
        end
      end
    end
  end

  report.emit()
end

---Update one hovercraft through unloading: at its parking slot unload the cargo, then head home
---@param amphibOps SBJ__AmphibOpsConfig
---@param craft CMO__Unit
---@param entry SBJ__HovercraftState
local function updateHovercraftPhase(amphibOps, craft, entry)
  if entry.phase == PHASE.ENROUTE then
    if DebugFlow.isLandingTeleport(amphibOps) then
      craft.course = nil
      DebugFlow.teleport(craft.guid, entry.finalPoint)
    end

    local range = GameApi.Tool_Range(craft.guid, entry.finalPoint)

    if range and range < amphibOps.tuning.route.arrivalNm then
      GameApi.ScenEdit_UnloadCargo(craft.guid)
      entry.phase = PHASE.UNLOADING
    end
  elseif entry.phase == PHASE.UNLOADING and GameUtils.isCargoUnloaded(craft) then
    craft:RTB(true)
    entry.phase = PHASE.RETURNING
  end
end

---Update the hovercraft: unload at the parking slot, then return to base once the cargo is out
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
function Hovercraft.updateHovercraft(amphibOps, zoneState)
  for guid, entry in pairs(zoneState.hovercraft or {}) do
    local craft = GameApi.ScenEdit_GetUnit(guid)

    if craft then
      updateHovercraftPhase(amphibOps, craft, entry)
    end
  end
end

return Hovercraft
