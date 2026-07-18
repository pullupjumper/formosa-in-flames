local TankerMission = require("src.modules.strikePlanner.tankerMission")

describe("TankerMission", function()
  -- ============================================================================
  -- normalizeCreationParams
  -- ============================================================================

  describe("normalizeCreationParams", function()
    -- Positive: normalize one mission object
    it("should wrap a single mission object in an array", function()
      local missionParams = { name = "AAR-1", type = "support", opts = {} }

      local result, isSingle = TankerMission.normalizeCreationParams(missionParams)

      assert.are.equal(1, #result)
      assert.are.equal(missionParams, result[1])
      assert.is_true(isSingle)
    end)

    -- Positive: preserve mission arrays
    it("should return a mission array unchanged", function()
      local missionParams = {
        { name = "AAR-1", type = "support", opts = {} },
        { name = "AAR-2", type = "support", opts = {} }
      }

      local result, isSingle = TankerMission.normalizeCreationParams(missionParams)

      assert.are.equal(missionParams, result)
      assert.is_false(isSingle)
    end)

    -- Boundary: recognize partial single-object fixtures
    it("should recognize an opts-only table as a single mission object", function()
      local missionParams = { opts = { zone = { "RP-1" } } }

      local result, isSingle = TankerMission.normalizeCreationParams(missionParams)

      assert.are.equal(missionParams, result[1])
      assert.is_true(isSingle)
    end)

    -- Boundary: nil parameters
    it("should return an empty array for nil parameters", function()
      local result, isSingle = TankerMission.normalizeCreationParams(nil)

      assert.are.equal(0, #result)
      assert.is_false(isSingle)
    end)

    -- Boundary: empty mission array
    it("should preserve an empty mission array", function()
      local missionParams = {}

      local result, isSingle = TankerMission.normalizeCreationParams(missionParams)

      assert.are.equal(missionParams, result)
      assert.is_false(isSingle)
    end)
  end)
end)
