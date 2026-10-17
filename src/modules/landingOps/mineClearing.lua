local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local constants = require("src.core.constants")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")

local MineClearing = {}

-- ============================================================================
-- Minefields
-- ============================================================================

---Lay BLUE offshore minefields at scenario start; minefields without reference points are skipped
---@param amphibOpsConfig SBJ__AmphibOpsConfig
function MineClearing.layMinefields(amphibOpsConfig)
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

---Find Type 529s anchored in the zone, ordered left to right across the landing bearing
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
-- Public API
-- ============================================================================

---Build the zone's lanes and send each Type 529 down its water lane and serpentine
---Fails (logged, nothing changed) when the lane center or obstacle area reference points are missing.
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

  for i, sweeper in ipairs(sweepers) do
    local waterLane = lanes.waterLanes[i]
    waterLane.sweepCourse[2].desiredSpeed = 5
    sweeper.course = waterLane.sweepCourse

    if DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING) then
      local copy = Utils.deepCopy(waterLane.sweepCourse)
      table.remove(copy, 1)
      -- GameApi.ScenEdit_SetUnit({
      --   guid = sweeper.guid,
      --   -- latitude = copy[1].latitude,
      --   -- longitude = copy[1].longitude,
      --   latitude = copy[#copy].latitude,
      --   longitude = copy[#copy].longitude,
      --   course = copy
      -- })
      DebugFlow.teleport(sweeper.guid, { latitude = copy[#copy].latitude, longitude = copy[#copy].longitude })
    end

    zoneState.minesweepers[sweeper.guid] = {
      waterLaneId = waterLane.id,
      missionArea = waterLane.missionArea,
      finalPoint = waterLane.sweepCourse[#waterLane.sweepCourse],
      isDone = false,
    }
    -- TODO: 建掃雷任務並 assign（使用者自己寫）。區域 4 角在 zoneState.minesweepers[guid].missionArea。
    sweeper.mission = zone.landing.sweeper.missionName
    sweeper.manualSpeed = zone.landing.sweeper.speed
    sweeper.obeyEMCON = false
    GameApi.ScenEdit_SetEMCON("Unit", sweeper.guid, "Sonar=Active")
    report.add("OK", { ship = sweeper.name or sweeper.guid, waterLane = waterLane.id })
  end

  report.emit()
  return true
end

---Send sweepers that reached the end of their serpentine home; destroyed sweepers count as done
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
      else
        isAllDone = false
      end
    end
  end

  return isAllDone
end

return MineClearing
