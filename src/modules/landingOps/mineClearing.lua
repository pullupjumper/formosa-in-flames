local constants = require("src.core.constants")

local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")

local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")

local MineClearing = {}

-- ============================================================================
-- Minefields
-- ============================================================================

---Create the BLUE offshore minefields at scenario start. Skip minefields that have no reference points
---@param amphibOpsConfig SBJ__AmphibOpsConfig
function MineClearing.createMinefields(amphibOpsConfig)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "minefields", "Lay minefields")

  for i, minefield in ipairs(amphibOpsConfig.minefields or {}) do
    if not minefield.area or #minefield.area == 0 then
      report.add("SKIP", { minefield = i, reason = "area_not_set" })
    else
      GameApi.ScenEdit_DeleteMinefield({ side = constants.SIDES.BLUE, area = minefield.area })
      local laid = GameApi.ScenEdit_AddMinefield({
        side = constants.SIDES.BLUE,
        dbid = constants.WEAPONS.SEA_MINE,
        number = minefield.number,
        delay = minefield.delay,
        area = minefield.area,
      })
      report.add(laid and "OK" or "FAIL", { minefield = i, laid = laid or 0 })
    end
  end

  report.emit()
end

-- ============================================================================
-- Sweeper Selection
-- ============================================================================

---Find the Type 529s anchored in the zone, ordered from left to right across the landing bearing
---@param zone SBJ__OperationalZoneDescriptor
---@param frame SBJ__LaneFrame
---@param ships CMO__SideUnit[]
---@return CMO__Unit[]
local function findSweepers(zone, frame, ships)
  local entries = {}

  for _, u in ipairs(ships) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)
    if unit and unit.dbid == constants.PLATFORMS.TYPE_082
        and (unit:inArea(zone.movement.holdingAreas.deployLine) or unit:inArea(zone.movement.holdingAreas.mothership)) then
      local _, lateral = LaneGeometry.projectPoint(frame, unit)
      table.insert(entries, { unit = unit, lateral = lateral })
    end
  end

  table.sort(entries, function(a, b) return a.lateral < b.lateral end)

  local sweepers = {}
  for _, entry in ipairs(entries) do
    table.insert(sweepers, entry.unit)
  end
  return sweepers
end

-- ============================================================================
-- Fast-forward Mine Removal
-- ============================================================================

---Remove every mine that lies in a water lane or beach lane cell.
---This is the fast-forward stand-in for the sweepers. The mine cells are rebuilt on demand and never saved.
---@param amphibOps SBJ__AmphibOpsConfig
---@param lanes SBJ__LanePlanState
---@return integer # Mines deleted
local function removeMinesOnLanes(amphibOps, lanes)
  local frame = { origin = lanes.origin, bearing = lanes.bearing }
  local corridors = LaneGeometry.buildMineCorridors(lanes, amphibOps.tuning.obstacle.cellSizeM)
  local deleted = 0

  for _, minefield in ipairs(amphibOps.minefields or {}) do
    if minefield.area and #minefield.area > 0 then
      local mines = GameApi.ScenEdit_GetMinefield({ side = constants.SIDES.BLUE, area = minefield.area })
      for _, mine in pairs(mines or {}) do
        if LaneGeometry.findMineCell(frame, corridors, mine)
            and GameApi.ScenEdit_DeleteMine({ side = constants.SIDES.BLUE, guid = mine.guid }) then
          deleted = deleted + 1
        end
      end
    end
  end

  return deleted
end

-- ============================================================================
-- Lane Placement
-- ============================================================================

---Build the lateral position per water lane, in the gaps between the deploy line LSTs.
---Return nil (even spacing) when there are no LSTs or the gaps cannot hold the lanes. The second case is reported.
---@param zone SBJ__OperationalZoneDescriptor
---@param params SBJ__BuildLateralsParams
---@param report SBJ__LogReport
---@return number[]|nil
local function buildLaterals(zone, params, report)
  local shipLaterals = AmphibiousAssault.findDeployLineLSTLaterals(zone, params.frame, params.ships)
  if #shipLaterals == 0 then
    return nil
  end

  local laterals = LaneGeometry.buildWaterLaneLaterals(shipLaterals, params.count, params.routeConfig)
  if not laterals then
    report.add("WARN", { reason = "ship_gaps_cannot_hold_lanes", ships = #shipLaterals, lanes = params.count })
  end
  return laterals
end

-- ============================================================================
-- Public API
-- ============================================================================

---Start mine clearing in a zone: build the lanes and send each Type 529 down its water lane and serpentine.
---Fail (logged, nothing changed) when the lane center or obstacle area reference points are missing.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ships CMO__SideUnit[]
---@return boolean # True when lanes were built and every sweeper got its course
function MineClearing.startMineClearing(amphibOps, zone, zoneState, ships)
  local report = LogFormat.report(constants.TAGS.AMPHIBIOUS_ASSAULT, "zone=" .. zone.name, "Start mine clearing")

  local center = GameUtils.findAreaLocations(constants.SIDES.RED, zone.landing.laneCenter)[1]
  local obstacle = GameUtils.findAreaLocations(constants.SIDES.BLUE, zone.landing.obstacleArea)
  if not center or #obstacle < 3 then
    report.add("FAIL", { reason = "lane_reference_points_not_set" })
    report.emit()
    return false
  end

  local frame = { origin = center, bearing = zone.heading }
  local sweepers = findSweepers(zone, frame, ships)
  if #sweepers == 0 then
    report.add("FAIL", { reason = "no_type082_in_zone" })
    report.emit()
    return false
  end

  local lanes = LaneGeometry.buildLanes({
    origin = center,
    bearing = zone.heading,
    count = #sweepers,
    laterals = buildLaterals(zone, {
      frame = frame,
      ships = ships,
      count = #sweepers,
      routeConfig = amphibOps.tuning.route,
    }, report),
    inlandDepthM = LaneGeometry.calculateInlandDepthM(frame, obstacle) + amphibOps.tuning.route.inlandMarginM,
    areaMarginM = amphibOps.tuning.mineClearing.areaMarginM,
    routeConfig = amphibOps.tuning.route,
  })

  zoneState.lanes = lanes
  zoneState.minesweepers = {}

  local mission = GameApi.ScenEdit_GetMission(constants.SIDES.RED, zone.landing.sweeper.missionName)

  if not mission then
    GameApi.ScenEdit_AddMission(
      constants.SIDES.RED,
      zone.landing.sweeper.missionName,
      "Mineclearing",
      { zone = zone.landing.acv.area }
    )
  end

  if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
    report.add("OK", { fastForwardMinesRemoved = removeMinesOnLanes(amphibOps, lanes) })
  end

  for i, sweeper in ipairs(sweepers) do
    local waterLane = lanes.waterLanes[i]
    waterLane.sweepCourse[2].desiredSpeed = 5
    sweeper.course = waterLane.sweepCourse

    if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
      DebugFlow.teleport(sweeper.guid, waterLane.sweepCourse[#waterLane.sweepCourse])
    end

    zoneState.minesweepers[sweeper.guid] = {
      waterLaneId = waterLane.id,
      missionArea = waterLane.missionArea,
      finalPoint = waterLane.sweepCourse[#waterLane.sweepCourse],
      isDone = false,
    }
    -- TODO: Create the minesweeping mission and assign it. The user writes this step.
    -- The four corners of the area are in zoneState.minesweepers[guid].missionArea.
    sweeper.mission = zone.landing.sweeper.missionName
    sweeper.manualSpeed = zone.landing.sweeper.speed
    sweeper.obeyEMCON = false
    GameApi.ScenEdit_SetEMCON("Unit", sweeper.guid, "Sonar=Active")
    report.add("OK", { ship = sweeper.name or sweeper.guid, waterLane = waterLane.id })
  end

  report.emit()
  return true
end

---Update mine clearing: send the sweepers that reached the end of their serpentine home. Destroyed sweepers count as done
---@param amphibOps SBJ__AmphibOpsConfig
---@param zoneState SBJ__ZoneState
---@return boolean # True when every sweeper is done
function MineClearing.updateMineClearing(amphibOps, zoneState)
  local arrivalNm = amphibOps.tuning.route.arrivalNm
  local isAllDone = true

  for guid, sweeper in pairs(zoneState.minesweepers or {}) do
    if not sweeper.isDone then
      local unit = GameApi.ScenEdit_GetUnit(guid)
      local range = unit and GameApi.Tool_Range(guid, sweeper.finalPoint)

      if not unit then
        sweeper.isDone = true
      elseif range and range < arrivalNm then
        unit:RTB(true)
        sweeper.isDone = true

        if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
          DebugFlow.teleport(unit.guid, { latitude = unit.base.latitude, longitude = unit.base.longitude })
        end
      else
        isAllDone = false
      end
    end
  end

  return isAllDone
end

return MineClearing
