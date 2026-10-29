local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local CargoRun = require("src.modules.landingOps.cargoRun")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")

---Route loaded Type 726A hovercraft from the LHD and LPDs through cleared lanes to a parking slot.
---Route each hovercraft once. After it arrives, it unloads at its parking slot.
local Hovercraft = {}

-- ============================================================================
-- Helpers
-- ============================================================================

---Find the hovercraft on one mothership that are ready, loaded, and not yet routed
---@param ship CMO__Unit
---@param hovercraftMap table<string, SBJ__HovercraftState>
---@return CMO__Unit[]
local function findReadyHovercraft(ship, hovercraftMap)
  return CargoRun.findReady(ship, constants.PLATFORM_TYPES.BOATS, constants.PLATFORMS.TYPE_726A, hovercraftMap)
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
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Launch hovercraft")

  for _, u in ipairs(ships) do
    local ship = GameApi.ScenEdit_GetUnit(u.guid)

    if ship and constants.MOTHERSHIP_DBID_SET[ship.dbid] and ship:inArea(zone.movement.holdingAreas.mothership) then
      for _, craft in ipairs(findReadyHovercraft(ship, zoneState.hovercraft)) do
        local plan = RoutePlanner.reserveCourse(zoneState, {
          guid = craft.guid,
          launchPos = { latitude = ship.latitude, longitude = ship.longitude },
          routeConfig = amphibOps.tuning.route,
        }, { isFromDeployLine = true })

        if plan then
          craft.course = plan.course
          craft.manualSpeed = zone.landing.hovercraft.speed
          craft:Launch(true)
          zoneState.hovercraft[craft.guid] = {
            finalPoint = plan.course[#plan.course],
            phase = CargoRun.PHASE.ENROUTE,
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
  if entry.phase == CargoRun.PHASE.ENROUTE and DebugFlow.isLandingTeleport(amphibOps) then
    craft.course = nil
    DebugFlow.teleport(craft.guid, entry.finalPoint)
  end

  CargoRun.step(craft, entry, entry.finalPoint, amphibOps.tuning.route.arrivalNm)
end

---Update the hovercraft: unload at the parking slot, then return to base once the cargo is out
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
function Hovercraft.updateHovercraft(amphibOps, zoneState)
  for guid, entry in pairs(zoneState.hovercraft or {}) do
    local craft = TrackedUnits.findUnit(zoneState, guid)

    if craft then
      updateHovercraftPhase(amphibOps, craft, entry)
    end
  end
end

return Hovercraft
