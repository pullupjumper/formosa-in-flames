---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps RoutePlanner Unit Tests
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local constants = require("src.core.constants")

describe("RoutePlanner", function()
  local ORIGIN = { latitude = 25.0, longitude = 121.0 }
  local BEARING = 150
  local frame = { origin = ORIGIN, bearing = BEARING }

  ---@return SBJ__RouteConfig
  local function makeRouteConfig()
    return {
      deployLineNm = 12,
      launchLineNm = 3,
      assaultLineNm = 2,
      waterLaneSpacingM = 750,
      beachLaneOffsetsM = { -180, -60, 60, 180 },
      shoreStandoffM = 100,
      inlandMarginM = 100,
      columnSpacingM = 100,
      queueDepth = 5,
      queueSpacingM = 50,
      laneTieNm = 0.5,
      laneTieM = 100,
      arrivalNm = 0.1,
    }
  end

  ---@param count integer
  ---@return SBJ__LanePlanState
  local function makeLanes(count)
    return LaneGeometry.buildLanes({
      origin = ORIGIN,
      bearing = BEARING,
      count = count,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = makeRouteConfig(),
    })
  end

  ---@param lanes SBJ__LanePlanState
  local function clearAll(lanes)
    for _, waterLane in ipairs(lanes.waterLanes) do
      for _, beachLane in ipairs(waterLane.beachLanes) do
        beachLane.isCleared = true
      end
    end
  end

  ---@param lanes SBJ__LanePlanState
  ---@param overrides? table
  ---@return SBJ__BuildRouteParams
  local function makeParams(lanes, overrides)
    local params = {
      lanes = lanes,
      launchPos = LaneGeometry.buildPoint(frame, -4 * 1852, -1125),
      guid = "ACV-1",
      routeConfig = makeRouteConfig(),
      queueCounters = {},
      laneSlots = {},
      cells = {},
      isAlive = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do params[k] = v end
    end
    return params
  end

  -- ============================================================================
  -- chooseWaterLane
  -- ============================================================================

  describe("chooseWaterLane", function()
    -- Positive: nearest water lane wins
    it("should choose the nearest water lane", function()
      local lanes = makeLanes(4)
      local pos = LaneGeometry.buildPoint(frame, -3 * 1852, 300)

      local waterLane = RoutePlanner.chooseWaterLane(pos, lanes.waterLanes, {}, 0.1)

      assert.are.equal("W3", waterLane.id)
    end)

    -- Boundary: within the tie band the less-loaded lane wins
    it("should choose the less-loaded lane when distances are within the tie band", function()
      local lanes = makeLanes(4)
      local pos = LaneGeometry.buildPoint(frame, -3 * 1852, 0)

      local waterLane = RoutePlanner.chooseWaterLane(pos, lanes.waterLanes, { W3 = 2, W2 = 0 }, 0.5)

      assert.are.equal("W2", waterLane.id)
    end)

    -- Negative: load is ignored outside the tie band
    it("should ignore load when the other lane is outside the tie band", function()
      local lanes = makeLanes(4)
      local pos = LaneGeometry.buildPoint(frame, -3 * 1852, 375)

      local waterLane = RoutePlanner.chooseWaterLane(pos, lanes.waterLanes, { W3 = 9 }, 0.1)

      assert.are.equal("W3", waterLane.id)
    end)
  end)

  -- ============================================================================
  -- buildRoute
  -- ============================================================================

  describe("buildRoute", function()
    -- Positive: course runs entry, L_i, A_i, A_lane, S_lane, slot
    it("should build the full course and reserve slot 1 at E_lane", function()
      local lanes = makeLanes(4)
      clearAll(lanes)
      local params = makeParams(lanes)

      local plan = RoutePlanner.buildRoute(params)
      local waterLane, beachLane = RoutePlanner.findBeachLane(lanes, plan.beachLaneId)

      assert.are.equal("W1", plan.waterLaneId)
      assert.are.equal(1, plan.slot)
      assert.are.equal(6, #plan.course)
      assert.are.same(waterLane.launchPoint, plan.course[2])
      assert.are.same(waterLane.assaultPoint, plan.course[3])
      assert.are.same(beachLane.assaultPoint, plan.course[4])
      assert.are.same(beachLane.shorePoint, plan.course[5])
      assert.are.same(beachLane.endPoint, plan.course[6])
      assert.are.equal("ACV-1", params.laneSlots[plan.beachLaneId][1])
    end)

    -- Positive: queue entry points step back seaward
    it("should stagger entry points seaward for units sent together", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local params = makeParams(lanes, { launchPos = LaneGeometry.buildPoint(frame, -3 * 1852, 0) })

      local first = RoutePlanner.buildRoute(params)
      params.guid = "ACV-2"
      local second = RoutePlanner.buildRoute(params)

      assert.is_near(-3 * 1852, (LaneGeometry.projectPoint(frame, first.course[1])), 0.5)
      assert.is_near(-3 * 1852 - 100, (LaneGeometry.projectPoint(frame, second.course[1])), 0.5)
      assert.are.equal(2, params.queueCounters.W1)
    end)

    -- Positive: rotating through beach lanes and slots stay on the lane center line
    it("should fill slots back from E_lane along the lane center line", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local beachLane = lanes.waterLanes[1].beachLanes[1]
      local params = makeParams(lanes, { launchPos = LaneGeometry.buildPoint(frame, -3 * 1852, 0) })
      params.laneSlots[beachLane.id] = { "OTHER-1" }
      params.queueCounters.W1 = 4 -- next rotation starts at beach lane 1

      local plan = RoutePlanner.buildRoute(params)
      local along, lateral = LaneGeometry.projectPoint(frame, plan.course[#plan.course])

      assert.are.equal(beachLane.id, plan.beachLaneId)
      assert.are.equal(2, plan.slot)
      assert.is_near(350, along, 0.5)
      assert.is_near(-180, lateral, 0.5)
    end)

    -- Positive: a slot held by a destroyed unit is reused
    it("should reuse a slot whose holder no longer exists", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local beachLane = lanes.waterLanes[1].beachLanes[1]
      local params = makeParams(lanes, {
        isAlive = function(guid) return guid ~= "DEAD-1" end,
      })
      params.laneSlots[beachLane.id] = { "DEAD-1" }
      params.queueCounters.W1 = 4

      local plan = RoutePlanner.buildRoute(params)

      assert.are.equal(1, plan.slot)
      assert.are.equal("ACV-1", params.laneSlots[beachLane.id][1])
    end)

    -- Positive: slots past S_lane drop the S_lane waypoint
    it("should skip S_lane when the slot is seaward of it", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local beachLane = lanes.waterLanes[1].beachLanes[1]
      local slots = {}
      for i = 1, 11 do slots[i] = "HOLD-" .. i end -- slots 1-11 cover 400 m .. -100 m
      local params = makeParams(lanes)
      params.laneSlots[beachLane.id] = slots
      params.queueCounters.W1 = 4

      local plan = RoutePlanner.buildRoute(params)

      assert.are.equal(12, plan.slot)
      assert.are.equal(5, #plan.course)
      assert.are.same(beachLane.assaultPoint, plan.course[4])
    end)

    -- Positive: released abeam of the lane, the course never heads back out to sea
    it("should enter the lane abeam of the launch position without backtracking", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local launchPos = LaneGeometry.buildPoint(frame, -2.5 * 1852, -900)

      local plan = RoutePlanner.buildRoute(makeParams(lanes, { launchPos = launchPos }))
      local alongs = {}
      for i, point in ipairs(plan.course) do
        alongs[i] = LaneGeometry.projectPoint(frame, point)
      end

      assert.are.same(lanes.waterLanes[1].assaultPoint, plan.course[2])
      assert.is_true(math.abs(alongs[1] - (-2.5 * 1852)) < 1)
      for i = 2, #alongs do
        assert.is_true(alongs[i] >= alongs[i - 1] - 1)
      end
    end)

    -- Negative: the entry never goes seaward of the deploy line
    it("should clamp the entry to the deploy line", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local launchPos = LaneGeometry.buildPoint(frame, -20 * 1852, 0)

      local plan = RoutePlanner.buildRoute(makeParams(lanes, { launchPos = launchPos }))
      local entryAlong = LaneGeometry.projectPoint(frame, plan.course[1])

      assert.is_true(math.abs(entryAlong - (-12 * 1852)) < 1)
    end)

    -- Positive: a unit beside the lane field takes the sideways-nearest lane
    it("should pick the water lane nearest sideways, whatever the along distance", function()
      local lanes = makeLanes(4)
      clearAll(lanes)
      local launchPos = LaneGeometry.buildPoint(frame, -2 * 1852, 300)

      local plan = RoutePlanner.buildRoute(makeParams(lanes, { launchPos = launchPos }))

      assert.are.equal("W3", plan.waterLaneId)
    end)

    -- Negative: only cleared beach lanes are used
    it("should only route into cleared beach lanes", function()
      local lanes = makeLanes(4)
      lanes.waterLanes[3].beachLanes[2].isCleared = true
      local params = makeParams(lanes)

      local plan = RoutePlanner.buildRoute(params)

      assert.are.equal("W3-B2", plan.beachLaneId)
    end)

    -- Negative: nothing cleared means no route
    it("should return nil when no beach lane is cleared", function()
      assert.is_nil(RoutePlanner.buildRoute(makeParams(makeLanes(4))))
    end)

    -- Negative: a course through intact obstacle cells is rejected
    it("should reject a course that touches intact obstacle cells", function()
      local lanes = makeLanes(1)
      clearAll(lanes)
      local polygon = {
        LaneGeometry.buildPoint(frame, 0, -1000),
        LaneGeometry.buildPoint(frame, 0, 1000),
        LaneGeometry.buildPoint(frame, 200, 1000),
        LaneGeometry.buildPoint(frame, 200, -1000),
      }
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)

      assert.is_nil(RoutePlanner.buildRoute(makeParams(lanes, { cells = cells })))

      for _, cell in ipairs(cells) do cell.state = constants.OBSTACLE_CELL_STATES.CLEARED end
      assert.is_not_nil(RoutePlanner.buildRoute(makeParams(lanes, { cells = cells })))
    end)

    -- Positive: units from far offshore start at the deployment line
    it("should prepend the deploy point when isFromDeployLine is set", function()
      local lanes = makeLanes(1)
      clearAll(lanes)

      local plan = RoutePlanner.buildRoute(makeParams(lanes), { isFromDeployLine = true })

      assert.are.same(lanes.waterLanes[1].deployPoint, plan.course[1])
      assert.are.equal(7, #plan.course)
    end)
  end)

  -- ============================================================================
  -- buildBoatRoute
  -- ============================================================================

  describe("buildBoatRoute", function()
    local boatPos = LaneGeometry.buildPoint(frame, -3.5 * 1852, -375)

    -- Positive: boat course ends at S_lane regardless of clearance
    it("should end at S_lane of the paired beach lane", function()
      local lanes = makeLanes(4)
      local queueCounters = {}

      local course = RoutePlanner.buildBoatRoute(lanes, "W2-B3", boatPos, queueCounters, makeRouteConfig())
      local waterLane, beachLane = RoutePlanner.findBeachLane(lanes, "W2-B3")

      assert.are.equal(5, #course)
      assert.are.same(waterLane.launchPoint, course[2])
      assert.are.same(beachLane.shorePoint, course[5])
      assert.are.equal(1, queueCounters.W2)
    end)

    -- Positive: a boat released shoreward of L_i skips it instead of backtracking
    it("should skip lane points already behind the launch position", function()
      local lanes = makeLanes(4)
      local pos = LaneGeometry.buildPoint(frame, -2.5 * 1852, -375)

      local course = RoutePlanner.buildBoatRoute(lanes, "W2-B3", pos, {}, makeRouteConfig())
      local waterLane, beachLane = RoutePlanner.findBeachLane(lanes, "W2-B3")

      assert.are.equal(4, #course)
      assert.are.same(waterLane.assaultPoint, course[2])
      assert.are.same(beachLane.shorePoint, course[4])
    end)

    -- Negative: unknown beach lane
    it("should return nil for an unknown beach lane id", function()
      assert.is_nil(RoutePlanner.buildBoatRoute(makeLanes(1), "W9-B9", boatPos, {}, makeRouteConfig()))
    end)
  end)
end)
