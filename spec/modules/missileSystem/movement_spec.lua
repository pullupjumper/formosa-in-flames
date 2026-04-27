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

  local function makeFiringUnitCtx(overrides)
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

  local function makeSystemCtx(overrides)
    local ctx = {
      firingUnits = {
        ["Firing Unit Alpha"] = {
          name = "Firing Unit Alpha",
          state = constants.MISSILE_SYSTEM_STATE.RELOAD,
          reloadStartTime = 12345
        }
      },
      resupplyUnits = {
        ["Ammo Sec, Alpha"] = {
          name = "Ammo Sec, Alpha",
          state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
          reloadStartTime = 67890
        }
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
    -- Positive: sets state to REPOSITIONING
    it("should set state to REPOSITIONING", function()
      local firingUnitCtx = makeFiringUnitCtx()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    -- Positive: returns true when move is successful
    it("should return true when move is successful", function()
      local firingUnitCtx = makeFiringUnitCtx()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      local result = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_true(result)
    end)

    -- Boundary: returns false when FP positions array is empty
    it("should return false when FP positions array is empty", function()
      local firingUnitCtx = makeFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = {}
        }
      })
      local firingUnit = { guid = "F1" }

      local result = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    -- Boundary: returns false when position has no course
    it("should return false when position has no course", function()
      local firingUnitCtx = makeFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { area = { "RP-001" } } }
        }
      })
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)

      local result = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
    end)

    -- Positive: sets unit properties for a single unit
    it("should set unit properties for single unit", function()
      local firingUnitCtx = makeFiringUnitCtx()
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

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
      local firingUnitCtx = makeFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = expectedCourse } }
        }
      })
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(expectedCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Positive: iterates through all units in group
    it("should iterate through all units in group", function()
      local firingUnitCtx = makeFiringUnitCtx()
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

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    -- Boundary: skips nil units in group list
    it("should skip nil units in group list", function()
      local firingUnitCtx = makeFiringUnitCtx()
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

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: uses random position from FP array
    it("should use random position from FP array", function()
      local course1 = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } }
      local course2 = { { latitude = "N 26.00.00", longitude = "E 122.00.00" } }
      local firingUnitCtx = makeFiringUnitCtx({
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

      Movement.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(course2, stubSetUnit.calls[1].vals[1].course)
    end)
  end)

  -- ============================================================================
  -- setReloadStartTime
  -- ============================================================================

  describe("setReloadStartTime", function()
    -- Positive: sets state to RELOAD
    it("should set state to RELOAD", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitCtx.state)
    end)

    -- Positive: sets reloadStartTime to current time
    it("should set reloadStartTime to current time", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC, reloadStartTime = nil }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(67890)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(67890, firingUnitCtx.reloadStartTime)
    end)

    -- Positive: handles a single unit without group
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Positive: iterates through all units in group
    it("should iterate through all units in group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
    end)

    -- Positive: uses hold position when auto mode is enabled
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Positive: uses manual params when auto mode is disabled
    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Boundary: skips nil units in group list
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  -- ============================================================================
  -- setStateToStatic
  -- ============================================================================

  describe("setStateToStatic", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = makeSystemCtx({
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 12345
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            reloadStartTime = 67890
          }
        }
      })
    end)

    -- Boundary: does nothing when unit name is unknown
    it("should do nothing when unit name not in firingUnits or resupplyUnits", function()
      local firingUnit = { guid = "UNKNOWN-001", name = "Unknown Unit" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]

      local stubGetUnit = trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitAlpha.state)
      assert.are.equal(12345, firingUnitAlpha.reloadStartTime)
      assert.stub(stubGetUnit).was_not.called()
      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Positive: sets firing unit state to STATIC
    it("should set firingUnit state to STATIC", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, mockSystemCtx.firingUnits["Firing Unit Alpha"].state)
    end)

    -- Positive: clears firing unit reloadStartTime
    it("should clear firingUnit reloadStartTime", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.is_nil(mockSystemCtx.firingUnits["Firing Unit Alpha"].reloadStartTime)
    end)

    -- Positive: uses hold position when auto mode is enabled
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    -- Positive: uses manual params when auto mode is disabled
    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Positive: handles a single unit without group
    it("should handle single unit without group", function()
      local firingUnit = { guid = "SINGLE-001", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Positive: iterates through all units in group
    it("should iterate through all units in group", function()
      local firingUnit = {
        guid = "GROUP-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
    end)

    -- Boundary: skips nil units in group list
    it("should skip nil units in group list", function()
      local firingUnit = {
        guid = "GROUP-001",
        name = "Firing Unit Alpha",
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

      Movement.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: prioritizes firingUnits over resupplyUnits
    it("should prioritize firingUnits when unit exists in both collections", function()
      mockSystemCtx.resupplyUnits["Firing Unit Alpha"] = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.HIDE,
        reloadStartTime = 99999
      }

      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]
      local resupplyUnitAlpha = mockSystemCtx.resupplyUnits["Firing Unit Alpha"]

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitAlpha.state)
      assert.is_nil(firingUnitAlpha.reloadStartTime)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, resupplyUnitAlpha.state)
      assert.are.equal(99999, resupplyUnitAlpha.reloadStartTime)
    end)
  end)

  -- ============================================================================
  -- setStateToHide
  -- ============================================================================

  describe("setStateToHide", function()
    -- Positive: sets state to HIDE
    it("should set state to HIDE", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setStateToHide(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, firingUnitCtx.state)
    end)

    -- Positive: handles a single unit without group
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToHide(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Positive: iterates through all units in group
    it("should iterate through all units in group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToHide(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
    end)

    -- Positive: uses hold position when auto mode is enabled
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToHide(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    -- Positive: uses manual params when auto mode is disabled
    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setStateToHide(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Boundary: skips nil units in group list
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
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

      Movement.setStateToHide(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  -- ============================================================================
  -- isRepositioning
  -- ============================================================================

  describe("isRepositioning", function()
    -- Boundary: returns false when firingUnitCtx is nil
    it("should return false when firingUnitCtx is nil", function()
      assert.is_false(Movement.isRepositioning(nil, true))
      assert.is_false(Movement.isRepositioning(nil, false))
    end)

    -- Positive: returns true when auto mode and state is REPOSITIONING
    it("should return true when isAuto and state is REPOSITIONING", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING }
      assert.is_true(Movement.isRepositioning(firingUnitCtx, true))
    end)

    -- Negative: returns false when auto mode and state is not REPOSITIONING
    it("should return false when isAuto and state is not REPOSITIONING", function()
      local states = {
        constants.MISSILE_SYSTEM_STATE.STATIC,
        constants.MISSILE_SYSTEM_STATE.RELOAD,
        constants.MISSILE_SYSTEM_STATE.HIDE
      }

      for _, state in ipairs(states) do
        local firingUnitCtx = { state = state }
        assert.is_false(Movement.isRepositioning(firingUnitCtx, true))
      end
    end)

    -- Positive: always returns true when manual mode is enabled
    it("should always return true when isAuto is false", function()
      local states = {
        constants.MISSILE_SYSTEM_STATE.STATIC,
        constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        constants.MISSILE_SYSTEM_STATE.RELOAD,
        constants.MISSILE_SYSTEM_STATE.HIDE
      }

      for _, state in ipairs(states) do
        local firingUnitCtx = { state = state }
        assert.is_true(Movement.isRepositioning(firingUnitCtx, false))
      end
    end)
  end)

  -- ============================================================================
  -- setWCSToFree
  -- ============================================================================

  describe("setWCSToFree", function()
    -- Positive: sets state to STATIC
    it("should set state to STATIC", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      Movement.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitCtx.state)
    end)

    -- Positive: sets WCS to FREE when auto mode is enabled
    it("should set wcs to FREE when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    -- Positive: uses manual params when auto mode is disabled
    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Boundary: iterates group units and skips nil members
    it("should iterate group units and skip nil units", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = {
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

      Movement.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: uses air WCS for SAM units
    it("should set weapon_control_status_air for SAM unit", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "SAM-001", side = "Taiwan", dbid = constants.PLATFORMS.PAC3 }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      Movement.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_air)
      assert.is_nil(stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)
  end)
end)
