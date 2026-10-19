---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- GameUtils Unit Tests
local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")

describe("GameUtils", function()
  ---@type luassert.spy[]
  local activeStubs
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
  end)

  -- ============================================================================
  -- hasUnit
  -- ============================================================================

  describe("hasUnit", function()
    it("should return true when the GUID resolves to a unit", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "U-1" }))

      assert.is_true(GameUtils.hasUnit("U-1"))
    end)

    it("should return false when the GUID does not resolve", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      assert.is_false(GameUtils.hasUnit("U-GONE"))
    end)
  end)
end)
