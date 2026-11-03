---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Movement Unit Tests
local stub = require("luassert.stub")
local Movement = require("src.modules.missileSystem.movement")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Movement", function()
  ---@type luassert.spy[]
  local activeStubs
  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  local function makeFiringUnitState(overrides)
    local ctx = {
      name = "Firing Unit Alpha",
      state = constants.MISSILE_SYSTEM_STATE.STATIC,
      operationalArea = {
        name = "OPAREA-1",
        FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
      }
    }

    if overrides then
      for k, v in pairs(overrides) do
        ctx[k] = v
      end
    end

    return ctx
  end

  before_each(function()
    activeStubs = {}
    table.insert(activeStubs, stub(Logger, "log"))
    table.insert(activeStubs, stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- moveToFiringPoint
  -- ============================================================================

  describe("moveToFiringPoint", function()
    -- Positive: the state change is left to Transitions, which records it only after a successful order
    it("should leave the unit state unchanged", function()
      local firingUnitState = makeFiringUnitState()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitState.state)
    end)

    -- Positive: returns true when move is successful
    it("should return true when move is successful", function()
      local firingUnitState = makeFiringUnitState()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      local result = Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.is_true(result)
    end)

    -- Boundary: returns false when FP positions array is empty
    it("should return false when FP positions array is empty", function()
      local firingUnitState = makeFiringUnitState({
        operationalArea = {
          name = "OPAREA-1",
          FP = {}
        }
      })
      local firingUnit = { guid = "F1" }

      local result = Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.is_false(result)
    end)

    -- Boundary: returns false when position has no course
    it("should return false when position has no course", function()
      local firingUnitState = makeFiringUnitState({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { area = { "RP-001" } } }
        }
      })
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)

      local result = Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.is_false(result)
    end)

    -- Positive: sets unit properties for a single unit
    it("should set unit properties for single unit", function()
      local firingUnitState = makeFiringUnitState()
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("F1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal(constants.THROTTLES.FULL, stubSetUnit.calls[1].vals[1].manualthrottle)
      assert.are.equal(constants.SPEEDS.NORMAL, stubSetUnit.calls[1].vals[1].manualSpeed)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Positive: sets course from selected position
    it("should set course from selected position", function()
      local expectedCourse = {
        { latitude = "N 25.00.00", longitude = "E 121.00.00" },
        { latitude = "N 25.01.00", longitude = "E 121.01.00" }
      }
      local firingUnitState = makeFiringUnitState({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = expectedCourse } }
        }
      })
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.are.same(expectedCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Positive: iterates through all units in group
    it("should iterate through all units in group", function()
      local firingUnitState = makeFiringUnitState()
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    -- Boundary: skips nil units in group list
    it("should skip nil units in group list", function()
      local firingUnitState = makeFiringUnitState()
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: uses random position from FP array
    it("should use random position from FP array", function()
      local course1 = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } }
      local course2 = { { latitude = "N 26.00.00", longitude = "E 122.00.00" } }
      local firingUnitState = makeFiringUnitState({
        operationalArea = {
          name = "OPAREA-1",
          FP = {
            { course = course1 },
            { course = course2 }
          }
        }
      })
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(2)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitState, firingUnit)

      assert.are.same(course2, stubSetUnit.calls[1].vals[1].course)
    end)
  end)

  -- ============================================================================
  -- applyMode
  -- ============================================================================

  describe("applyMode", function()
    -- Positive: handles a single unit without group
    it("should set a single unit without group", function()
      local unit = { guid = "SINGLE-001", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return unit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, true, constants.WCS.HOLD)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Boundary: iterates group units and skips nil members
    it("should iterate group units and skip nil units", function()
      local unit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, true, constants.WCS.HOLD)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: holds position when auto mode is enabled
    it("should hold position when isAuto is true", function()
      local unit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, true, constants.WCS.HOLD)

      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Positive: releases position when auto mode is disabled
    it("should not hold position when isAuto is false", function()
      local unit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, false, constants.WCS.HOLD)

      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Positive: sets land WCS for ground units
    it("should set weapon_control_status_land for a ground unit", function()
      local unit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, true, constants.WCS.FREE)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    -- Positive: uses air WCS for SAM units
    it("should set weapon_control_status_air for SAM unit", function()
      local unit = { guid = "SAM-001", side = "Taiwan", dbid = constants.PLATFORMS.PAC3 }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.applyMode(unit, true, constants.WCS.FREE)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_air)
      assert.is_nil(stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)
  end)
end)
