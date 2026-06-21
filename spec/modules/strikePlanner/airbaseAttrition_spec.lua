-- AirbaseAttrition Unit Tests
local AirbaseAttrition = require("src.modules.strikePlanner.airbaseAttrition")
local GameApi = require("src.utils.gameApi")

describe("AirbaseAttrition", function()
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
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Build a side mock whose `unitsBy` returns the given aircraft GUID list.
  ---@param aircraftGuids string[]
  local function makeSideMock(aircraftGuids)
    local list = {}
    for _, guid in ipairs(aircraftGuids) do
      table.insert(list, { guid = guid })
    end
    return { unitsBy = function(_, _) return list end }
  end

  ---Stub GameApi.ScenEdit_GetUnit with a GUID -> unit map.
  ---@param map table<string, table|nil>
  local function stubGetUnit(map)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      return map[guid]
    end))
  end

  -- ============================================================================
  -- calculate
  -- ============================================================================

  describe("calculate", function()
    -- Positive: multiple bases are aggregated into one summary.
    it("should aggregate attrition across multiple bases", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 3 }, { num = 1 } } } }
        },
        {
          name = "Base B",
          baseGUID = "BASE-B",
          embarkedUnits = { { dbid = 2001, loadouts = { { num = 2 } } } }
        }
      }

      stubGetUnit({
        ["BASE-A"] = { guid = "BASE-A" },
        ["BASE-B"] = { guid = "BASE-B" },
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A2"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A3"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["B1"] = { dbid = 2001, base = { guid = "BASE-B" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1", "A2", "A3", "B1" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A", "Base B" })

      assert.are.equal(2, #result.bases)
      assert.are.equal(6, result.expectedTotal)
      assert.are.equal(4, result.currentTotal)
      assert.are.equal(2, result.lossTotal)
      assert.are.equal((2 / 6) * 100, result.attritionPct)
      assert.are.equal(0, #result.missingBases)
      assert.is_false(result.bases[1].isDestroyed)
      assert.is_false(result.bases[2].isDestroyed)
    end)

    -- Negative: missing base names are reported without aborting the summary.
    it("should collect missing bases and still return summary", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 2 } } } }
        }
      }

      stubGetUnit({
        ["BASE-A"] = { guid = "BASE-A" },
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A", "Base Z" })

      assert.are.equal(1, #result.bases)
      assert.are.equal(1, #result.missingBases)
      assert.are.equal("Base Z", result.missingBases[1])
      assert.are.equal(2, result.expectedTotal)
      assert.are.equal(1, result.currentTotal)
      assert.are.equal(1, result.lossTotal)
    end)

    -- Positive: airborne aircraft still count when their home base is alive.
    it("should count airborne aircraft as still combat-capable", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 4 } } } }
        }
      }

      stubGetUnit({
        ["BASE-A"] = { guid = "BASE-A" },
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A2"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A3"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A4"] = { dbid = 1001, base = { guid = "BASE-A" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1", "A2", "A3", "A4" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A" })

      assert.are.equal(4, result.expectedTotal)
      assert.are.equal(4, result.currentTotal)
      assert.are.equal(0, result.lossTotal)
      assert.are.equal(0, result.attritionPct)
      assert.is_false(result.bases[1].isDestroyed)
    end)

    -- Negative: a destroyed airbase zeroes the whole wing.
    it("should treat destroyed airbase as total wing loss", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 4 } } } }
        }
      }

      stubGetUnit({
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A2"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A3"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A4"] = { dbid = 1001, base = { guid = "BASE-A" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1", "A2", "A3", "A4" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A" })

      assert.are.equal(1, #result.bases)
      assert.is_true(result.bases[1].isDestroyed)
      assert.are.equal(4, result.expectedTotal)
      assert.are.equal(0, result.currentTotal)
      assert.are.equal(4, result.lossTotal)
      assert.are.equal(100, result.attritionPct)
    end)

    -- Boundary: aircraft are attributed by current base.guid.
    it("should attribute aircraft to current base.guid", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 2 } } } }
        },
        {
          name = "Base B",
          baseGUID = "BASE-B",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 2 } } } }
        }
      }

      stubGetUnit({
        ["BASE-A"] = { guid = "BASE-A" },
        ["BASE-B"] = { guid = "BASE-B" },
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A2"] = { dbid = 1001, base = { guid = "BASE-B" } },
        ["B1"] = { dbid = 1001, base = { guid = "BASE-B" } },
        ["B2"] = { dbid = 1001, base = { guid = "BASE-B" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1", "A2", "B1", "B2" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A", "Base B" })

      assert.are.equal(1, result.bases[1].currentTotal)
      assert.are.equal(1, result.bases[1].lossTotal)
      assert.are.equal(3, result.bases[2].currentTotal)
      assert.are.equal(0, result.bases[2].lossTotal)
    end)

    -- Boundary: unplanned aircraft DBIDs are ignored.
    it("should ignore aircraft of unrelated DBID", function()
      local deployments = {
        {
          name = "Base A",
          baseGUID = "BASE-A",
          embarkedUnits = { { dbid = 1001, loadouts = { { num = 2 } } } }
        }
      }

      stubGetUnit({
        ["BASE-A"] = { guid = "BASE-A" },
        ["A1"] = { dbid = 1001, base = { guid = "BASE-A" } },
        ["A2"] = { dbid = 9999, base = { guid = "BASE-A" } }
      })
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ "A1", "A2" })))

      local result = AirbaseAttrition.calculate(deployments, { "Base A" })

      assert.are.equal(2, result.expectedTotal)
      assert.are.equal(1, result.currentTotal)
      assert.are.equal(1, result.lossTotal)
    end)
  end)
end)
