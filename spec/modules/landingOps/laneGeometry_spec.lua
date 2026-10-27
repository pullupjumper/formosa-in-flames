---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps LaneGeometry Unit Tests
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local constants = require("src.core.constants")

describe("LaneGeometry", function()
  local ORIGIN = { latitude = 25.0, longitude = 121.0 }
  local BEARING = 150

  ---@param overrides? table
  ---@return SBJ__RouteConfig
  local function buildRouteConfig(overrides)
    local routeConfig = {
      deployLineNm = 12,
      launchLineNm = 3,
      assaultLineNm = 2,
      waterLaneSpacingM = 750,
      waterLaneMinSpacingM = 500,
      waterLaneMaxSpacingM = 1000,
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
      routeConfig = buildRouteConfig(),
    })
  end

  local frame = { origin = ORIGIN, bearing = BEARING }

  ---@param pos CMO__Location
  ---@return number along
  ---@return number lateral
  local function project(pos)
    return LaneGeometry.projectPoint(frame, pos)
  end

  describe("buildPoint", function()
    it("should round-trip along and lateral meters through projectPoint", function()
      local along, lateral = project(LaneGeometry.buildPoint(frame, -3000, 250))

      assert.is_near(-3000, along, 0.01)
      assert.is_near(250, lateral, 0.01)
    end)
  end)

  describe("mine cells", function()
    -- One corridor per water lane and per beach lane, cells 50 m long from end to end
    it("should cut each water and beach lane into 50 m cells", function()
      local lanes = buildLanes(1)
      local corridors = LaneGeometry.buildMineCorridors(lanes, 50)

      assert.are.equal(5, #corridors)
      -- water lane: deploy line 12 nm to assault line 2 nm = 18520 m
      assert.are.equal(371, #corridors[1].cells)
      -- beach lane: assault line 2 nm to S_lane 100 m = 3604 m
      assert.are.equal(73, #corridors[2].cells)
      assert.are.equal(4, #corridors[1].cells[1].corners)
    end)

    it("should find the cell containing a position on the lane center line", function()
      local lanes = buildLanes(1)
      local corridors = LaneGeometry.buildMineCorridors(lanes, 50)
      local pos = LaneGeometry.buildPoint(frame, -12 * 1852 + 120, 0)

      local cell = LaneGeometry.findMineCell(frame, corridors, pos)

      assert.are.same(corridors[1].cells[3], cell)
    end)

    it("should return nil for positions outside every lane", function()
      local corridors = LaneGeometry.buildMineCorridors(buildLanes(1), 50)

      assert.is_nil(LaneGeometry.findMineCell(frame, corridors, LaneGeometry.buildPoint(frame, -5000, 100)))
      assert.is_nil(LaneGeometry.findMineCell(frame, corridors, LaneGeometry.buildPoint(frame, -13 * 1852, 0)))
    end)

    -- The cell edge is inclusive and the last cell takes the shore end
    it("should accept the lane end and the half width edge", function()
      local lanes = buildLanes(1)
      local corridors = LaneGeometry.buildMineCorridors(lanes, 50)

      assert.is_not_nil(LaneGeometry.findMineCell(frame, corridors, lanes.waterLanes[1].assaultPoint))
      assert.is_not_nil(LaneGeometry.findMineCell(frame, corridors, LaneGeometry.buildPoint(frame, -5000, 24.9)))
    end)
  end)

  describe("buildWaterLaneLaterals", function()
    it("should put lanes at the midpoints of the ship gaps", function()
      local laterals = LaneGeometry.buildWaterLaneLaterals({ 750, -750, 0 }, 2, buildRouteConfig())

      assert.are.same({ -375, 375 }, laterals)
    end)

    it("should choose the run of gaps nearest the lane center", function()
      local laterals = LaneGeometry.buildWaterLaneLaterals({ -1500, -750, 0, 750, 1500, 2250 }, 2, buildRouteConfig())

      assert.are.same({ -375, 375 }, laterals)
    end)

    it("should return nil when the gaps are too narrow", function()
      assert.is_nil(LaneGeometry.buildWaterLaneLaterals({ -100, 100 }, 1, buildRouteConfig()))
    end)

    it("should return nil when neighboring lanes would exceed the maximum spacing", function()
      assert.is_nil(LaneGeometry.buildWaterLaneLaterals({ -1000, 0, 1500 }, 2, buildRouteConfig()))
    end)

    it("should accept a gap exactly at the minimum width", function()
      assert.are.same({ 250 }, LaneGeometry.buildWaterLaneLaterals({ 0, 500 }, 1, buildRouteConfig()))
    end)

    it("should return nil when there are fewer gaps than lanes", function()
      assert.is_nil(LaneGeometry.buildWaterLaneLaterals({ 0, 750 }, 2, buildRouteConfig()))
    end)
  end)

  describe("buildLanes", function()
    it("should build 4 water lanes and 16 beach lanes for 4 sweepers", function()
      local lanes = buildLanes(4)
      local beachCount = 0
      for _, waterLane in ipairs(lanes.waterLanes) do
        beachCount = beachCount + #waterLane.beachLanes
      end

      assert.are.equal(4, #lanes.waterLanes)
      assert.are.equal(16, beachCount)
    end)

    it("should build 1 water lane with 4 beach lanes on the center line for 1 sweeper", function()
      local lanes = buildLanes(1)
      local _, lateral = project(lanes.waterLanes[1].launchPoint)

      assert.are.equal(1, #lanes.waterLanes)
      assert.are.equal(4, #lanes.waterLanes[1].beachLanes)
      assert.is_near(0, lateral, 0.01)
    end)

    it("should place water lanes at the given laterals", function()
      local lanes = LaneGeometry.buildLanes({
        origin = ORIGIN, bearing = BEARING, count = 2, laterals = { -300, 420 },
        inlandDepthM = 400, areaMarginM = 60, routeConfig = buildRouteConfig(),
      })
      local _, left = project(lanes.waterLanes[1].launchPoint)
      local _, right = project(lanes.waterLanes[2].launchPoint)

      assert.is_near(-300, left, 0.01)
      assert.is_near(420, right, 0.01)
    end)

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

    -- Inner beach lanes are 120 m apart, outer ones 120 m further
    it("should offset beach lanes -180/-60/+60/+180 m from their water lane", function()
      local waterLane = buildLanes(1).waterLanes[1]
      local expected = { -180, -60, 60, 180 }

      for j, beachLane in ipairs(waterLane.beachLanes) do
        local _, lateral = project(beachLane.assaultPoint)
        assert.is_near(expected[j], lateral, 0.01)
      end
    end)

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

    it("should build the sweep course as water lane then A-S-S-A-A-S-S-A serpentine", function()
      local waterLane = buildLanes(1).waterLanes[1]
      local beachLanes = waterLane.beachLanes
      local expected = {
        waterLane.deployPoint, waterLane.launchPoint, waterLane.assaultPoint,
        beachLanes[1].assaultPoint, beachLanes[1].shorePoint, beachLanes[2].shorePoint, beachLanes[2].assaultPoint,
        beachLanes[3].assaultPoint, beachLanes[3].shorePoint, beachLanes[4].shorePoint, beachLanes[4].assaultPoint,
      }

      assert.are.same(expected, waterLane.sweepCourse)
    end)

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

  describe("calculateInlandDepthM", function()
    it("should return the deepest polygon vertex along the bearing", function()
      local polygon = {
        LaneGeometry.buildPoint(frame, 50, -500),
        LaneGeometry.buildPoint(frame, 320, -500),
        LaneGeometry.buildPoint(frame, 250, 500),
      }

      assert.is_near(320, LaneGeometry.calculateInlandDepthM(frame, polygon), 0.01)
    end)
  end)

  describe("isSegmentIntersecting", function()
    ---@param x number
    ---@param y number
    local function p(x, y) return { longitude = x, latitude = y } end

    it("should detect crossing segments", function()
      assert.is_true(LaneGeometry.isSegmentIntersecting(p(0, 0), p(2, 2), p(0, 2), p(2, 0)))
    end)

    it("should count an endpoint touching the other segment", function()
      assert.is_true(LaneGeometry.isSegmentIntersecting(p(0, 0), p(1, 1), p(1, 1), p(2, 0)))
      assert.is_true(LaneGeometry.isSegmentIntersecting(p(0, 0), p(2, 0), p(1, 0), p(1, 5)))
    end)

    it("should count collinear overlapping segments", function()
      assert.is_true(LaneGeometry.isSegmentIntersecting(p(0, 0), p(2, 0), p(1, 0), p(3, 0)))
    end)

    it("should not report parallel or separated segments", function()
      assert.is_false(LaneGeometry.isSegmentIntersecting(p(0, 0), p(2, 0), p(0, 1), p(2, 1)))
      assert.is_false(LaneGeometry.isSegmentIntersecting(p(0, 0), p(1, 0), p(2, 0), p(3, 0)))
      assert.is_false(LaneGeometry.isSegmentIntersecting(p(0, 0), p(1, 1), p(2, 0), p(3, -5)))
    end)
  end)

  describe("buildObstacleCells", function()
    local polygon = {
      LaneGeometry.buildPoint(frame, 0, 0),
      LaneGeometry.buildPoint(frame, 0, 100),
      LaneGeometry.buildPoint(frame, 200, 100),
      LaneGeometry.buildPoint(frame, 200, 0),
    }

    -- A 200 x 100 m rectangle is tiled by 8 cells of 50 m
    it("should tile the polygon with intact 50 m cells", function()
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)

      assert.are.equal(8, #cells)
      for _, cell in ipairs(cells) do
        assert.are.equal(4, #cell.corners)
        assert.are.equal(constants.OBSTACLE_CELL_STATES.INTACT, cell.state)
      end
    end)

    it("should return no cells for fewer than 3 points", function()
      assert.are.same({}, LaneGeometry.buildObstacleCells(frame, { polygon[1], polygon[2] }, 50))
    end)

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

    it("should allow a route that never touches a cell", function()
      local cells = LaneGeometry.buildObstacleCells(frame, polygon, 50)
      local route = { LaneGeometry.buildPoint(frame, -100, 300), LaneGeometry.buildPoint(frame, 300, 300) }

      assert.is_true(LaneGeometry.isRouteClear(route, cells))
    end)
  end)
end)
