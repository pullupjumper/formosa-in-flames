-- MissileSystem Init Unit Tests
---@diagnostic disable: undefined-field
local stub = require("luassert.stub")
local MissileSystem = require("src.modules.missileSystem.init")
local Movement = require("src.modules.missileSystem.movement")
local Cycle = require("src.modules.missileSystem.cycle")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem", function()
  local activeStubs

  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
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
    -- Negative: logs and returns false when movement fails
    it("should log an error and return false when movement fails", function()
      trackStub(Movement, "moveToFiringPoint").returns(false, "boom")

      local result = MissileSystem.moveToFiringPoint({}, {})

      assert.is_false(result)
      assert.stub(Logger.error).was.called_with(constants.TAGS.MISSILE_SYSTEM .. ": [FAIL] boom")
    end)

    -- Positive: returns true when delegated movement succeeds
    it("should return true when delegated movement succeeds", function()
      trackStub(Movement, "moveToFiringPoint").returns(true)

      assert.is_true(MissileSystem.moveToFiringPoint({}, {}))
    end)
  end)

  -- ============================================================================
  -- checkMissileSystemState
  -- ============================================================================

  describe("checkMissileSystemState", function()
    -- Positive: logs aggregated reload cycle results
    it("should log reload cycle summary when process returns results", function()
      trackStub(Cycle, "process").returns({
        { tag = "OK", unitName = "Firing Unit Alpha", action = "Missile reload finished" },
        { tag = "OK", unitName = "Ammo Sec, Alpha", action = "Ammo transload finished" },
      })

      MissileSystem.checkMissileSystemState("systemCtx", true, "Taiwan")

      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: does not log when no reload events occurred
    it("should not log when process returns no results", function()
      trackStub(Cycle, "process").returns({})

      MissileSystem.checkMissileSystemState("systemCtx", false, "Taiwan")

      assert.stub(Logger.log).was_not.called()
    end)
  end)
end)
