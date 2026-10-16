---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps LaneGeometry Unit Tests
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local constants = require("src.core.constants")

describe("LaneGeometry", function()
  local ORIGIN = { latitude = 25.0, longitude = 121.0 }
  local BEARING = 150

  ---@param overrides? table
  ---@return SBJ__RouteConfig
  local function makeRouteConfig(overrides)
    local routeConfig = {
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
      arrivalNm = 0.1,
    }
    if overrides then
      for k, v in pairs(overrides) do routeConfig[k] = v end
    end
    return routeConfig
  end

  ---@param count integer
  ---@return SBJ__LanePlanState
  local function buildLanes(count)
    return LaneGeometry.buildLanes({
      origin = ORIGIN,
      bearing = BEARING,
      count = count,
      inlandDepthM = 400,
      areaMarginM = 60,
      routeConfig = makeRouteConfig(),
    })
  end

  local frame = { origin = ORIGIN, bearing = BEARING }

  ---@param pos CMO__Location
  ---@return number along
  ---@return number lateral
  local function project(pos)
    return LaneGeometry.projectPoint(frame, pos)
  end

  -- ============================================================================
  -- buildPoint / projectPoint
  -- ============================================================================

  describe("buildPoint", function()
    -- Positive: lane coordinates survive a round trip
    it("should round-trip along and lateral meters through projectPoint", function()
      local along, lateral = project(LaneGeometry.buildPoint(frame, -3000, 250))

      assert.is_near(-3000, along, 0.01)
      assert.is_near(250, lateral, 0.01)
    end)
  end)

  -- ============================================================================
  -- buildLanes
  -- ============================================================================

  describe("buildLanes", function()
    -- Positive: four sweepers give four water lanes and sixteen beach lanes
    it("should build 4 water lanes and 16 beach lanes for 4 sweepers", function()
      local lanes = buildLanes(4)
      local beachCount = 0
      for _, waterLane in ipairs(lanes.waterLanes) do
        beachCount = beachCount + #waterLane.beachLanes
      end

      assert.are.equal(4, #lanes.waterLanes)
      assert.are.equal(16, beachCount)
    end)

    -- Boundary: one sweeper gives one water lane on the center line
    it("should build 1 water lane with 4 beach lanes on the center line for 1 sweeper", function()
      local lanes = buildLanes(1)
      local _, lateral = project(lanes.waterLanes[1].launchPoint)

      assert.are.equal(1, #lanes.waterLanes)
      assert.are.equal(4, #lanes.waterLanes[1].beachLanes)
      assert.is_near(0, lateral, 0.01)
    end)

    -- Positive: water lanes are 750 m apart and symmetric about the center
    it("should space water lanes 750 m apart symmetric about the lane center", function()
      local lanes = buildLanes(4)
      local laterals = {}
      for _, waterLane in ipairs(lanes.waterLanes) do
        local _, lateral = project(waterLane.launchPoint)
        table.insert(laterals, lateral)
      end

      assert.is_near(-1125, laterals[1], 0.01)
      assert.is_near(-375, laterals[2], 0.01)
      assert.is_near(375, laterals[3], 0.01)
      assert.is_near(1125, laterals[4], 0.01)
    end)

    -- Positive: inner beach lanes are 120 m apart, outer ones 120 m further
    it("should offset beach lanes -180/-60/+60/+180 m from their water lane", function()
      local waterLane = buildLanes(1).waterLanes[1]
      local expected = { -180, -60, 60, 180 }

      for j, beachLane in ipairs(waterLane.beachLanes) do
        local _, lateral = project(beachLane.assaultPoint)
        assert.is_near(expected[j], lateral, 0.01)
      end
    end)

    -- Positive: lane points sit on the configured lines
    it("should place deploy, launch, assault, shore and end points on their lines", function()
      local waterLane = buildLanes(1).waterLanes[1]
      local beachLane = waterLane.beachLanes[1]

      assert.is_near(-12 * 1852, (project(waterLane.deployPoint)), 0.01)
      assert.is_near(-3 * 1852, (project(waterLane.launchPoint)), 0.01)
      assert.is_near(-2 * 1852, (project(waterLane.assaultPoint)), 0.01)
      assert.is_near(-100, (project(beachLane.shorePoint)), 0.01)
      assert.is_near(400, (project(beachLane.endPoint)), 0.01)
      assert.are.equal("W1-B1", beachLane.id)
      assert.is_false(beachLane.isCleared)
    end)

    -- Positive: the sweep course runs the water lane then the serpentine
    it("should build the sweep course as water lane then A-S-S-A-A-S-S-A serpentine", function()
      local waterLane = buildLanes(1).waterLanes[1]
      local b = waterLane.beachLanes
      local expected = {
        waterLane.deployPoint, waterLane.launchPoint, waterLane.assaultPoint,
        b[1].assaultPoint, b[1].shorePoint, b[2].shorePoint, b[2].assaultPoint,
        b[3].assaultPoint, b[3].shorePoint, b[4].shorePoint, b[4].assaultPoint,
      }

      assert.are.same(expected, waterLane.sweepCourse)
    end)

    -- Positive: mission area spans deploy line to shore and outer lanes plus margin
    it("should build a 4-corner sweep mission area around the beach lanes", function()
      local area = buildLanes(1).waterLanes[1].missionArea
      local along1, lateral1 = project(area[1])
      local along3, lateral3 = project(area[3])

      assert.are.equal(4, #area)
      assert.is_near(-12 * 1852, along1, 0.01)
      assert.is_near(-240, lateral1, 0.01)
      assert.is_near(-100, along3, 0.01)
      assert.is_near(240, lateral3, 0.01)
    end)
  end)

  -- ============================================================================
  -- calculateInlandDepthM
  -- ============================================================================

  describe("calculateInlandDepthM", function()
    -- Positive: deepest polygon vertex along the bearing
    it("should return the deepest polygon vertex along the bearing", function()
      local polygon = {
        LaneGeometry.buildPoint(frame, 50, -500),
        LaneGeometry.buildPoint(frame, 320, -500),
        LaneGeometry.buildPoint(frame, 250, 500),
      }

      assert.is_near(320, LaneGeometry.calculateInlandDepthM(frame, polygon), 0.01)
    end)
  end)

  -- ============================================================================
  -- segmentsIntersect
  -- ============================================================================

  describe("segmentsIntersect", function()
    ---@param x number
    ---@param y number
    local function p(x, y) return { longitude = x, latitude = y } end

    -- Positive: crossing segments
    it("should detect crossing segments", function()
      assert.is_true(LaneGeometry.segmentsIntersect(p(0, 0), p(2, 2), p(0, 2), p(2, 0)))
    end)

    -- Boundary: touching at an endpoint counts
    it("should count an endpoint touching the other segment", function()
      assert.is_true(LaneGeometry.segmentsIntersect(p(0, 0), p(1, 1), p(1, 1), p(2, 0)))
      assert.is_true(LaneGeometry.segmentsIntersect(p(0, 0), p(2, 0), p(1, 0), p(1, 5)))
    end)

    -- Boundary: collinear overlap counts
    it("should count collinear overlapping segments", function()
      assert.is_true(LaneGeometry.segmentsIntersect(p(0, 0), p(2, 0), p(1, 0), p(3, 0)))
    end)

    -- Negative: separate segments
    it("should not report parallel or separated segments", function()
      assert.is_false(LaneGeometry.segmentsIntersect(p(0, 0), p(2, 0), p(0, 1), p(2, 1)))
      assert.is_false(LaneGeometry.segmentsIntersect(p(0, 0), p(1, 0), p(2, 0), p(3, 0)))
      assert.is_false(LaneGeometry.segmentsIntersect(p(0, 0), p(1, 1), p(2, 0), p(3, -5)))
    end)
  end)

  -- ============================================================================
  -- buildObstacleCells / isRouteClear
  -- ============================================================================

  describe("buildObstacleCells", function()
    local polygon = {
      LaneGeometry.buildPoint(frame, 0, 0),
      LaneGeometry.buildPoint(frame, 0, 100),
      LaneGeometry.buildPoint(frame, 200, 100),
      LaneGeometry.buildPoint(frame, 200, 0),
    }

    -- Positive: a 200 x 100 m rectangle is tiled by 8 cells of 50 m
    it("should tile the polygon with intact 50 m cells", function()
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)

      assert.are.equal(8, #cells)
      for _, cell in ipairs(cells) do
        assert.are.equal(4, #cell.corners)
        assert.are.equal(constants.OBSTACLE_CELL_STATES.INTACT, cell.state)
      end
    end)

    -- Boundary: degenerate polygons produce no cells
    it("should return no cells for fewer than 3 points", function()
      assert.are.same({}, LaneGeometry.buildObstacleCells(frame, { polygon[1], polygon[2] }, 50))
    end)

    -- Positive: route through intact cells is blocked until they are cleared
    it("should block a route through intact cells and allow it once they are cleared", function()
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)
      local route = { LaneGeometry.buildPoint(frame, -100, 60), LaneGeometry.buildPoint(frame, 300, 60) }

      assert.is_false(LaneGeometry.isRouteClear(route, cells))

      for _, cell in ipairs(cells) do
        if LaneGeometry.isSegmentTouchingCell(route[1], route[2], cell) then
          cell.state = constants.OBSTACLE_CELL_STATES.CLEARED
        end
      end

      assert.is_true(LaneGeometry.isRouteClear(route, cells))
    end)

    -- Negative: route beside the area is clear
    it("should allow a route that never touches a cell", function()
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)
      local route = { LaneGeometry.buildPoint(frame, -100, 300), LaneGeometry.buildPoint(frame, 300, 300) }

      assert.is_true(LaneGeometry.isRouteClear(route, cells))
    end)
  end)
end)
