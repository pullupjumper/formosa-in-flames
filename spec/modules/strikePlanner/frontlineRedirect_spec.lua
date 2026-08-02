-- FrontlineRedirect Unit Tests
local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
local AirbaseAttrition = require("src.modules.strikePlanner.airbaseAttrition")
local Utils = require("src.utils.utils")
local BaseConfig = require("src.core.config")

describe("FrontlineRedirect", function()
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

  ---Create a minimal config with frontline redirect settings.
  ---@param redirectOverrides? table
  ---@return SBJ__Config
  local function makeConfig(redirectOverrides)
    local cfg = Utils.deepCopy(BaseConfig)
    cfg.c.air.landBased.deployedACs = {
      {
        name = "Frontline Base",
        baseGUID = "BASE-FRONT",
        embarkedUnits = { {
          name = "",
          side = "",
          platformName = "",
          type = "",
          dbid = 1001,
          loadouts = { { num = 4, loadoutId = 1 } }
        } }
      }
    }
    cfg.c.recon.frontlineRedirect = {
      enabled = true,
      attritionThresholdPct = 50,
      frontlineBaseNames = { "Frontline Base" },
      mappings = {
        { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
      },
    }
    if redirectOverrides then
      for k, v in pairs(redirectOverrides) do
        cfg.c.recon.frontlineRedirect[k] = v
      end
    end
    return cfg
  end

  ---Create a minimal recon context.
  ---@param overrides? table
  ---@return SBJ__ReconContext
  local function makeReconContext(overrides)
    local ctx = { queue = {}, frontlineRedirected = false }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  -- ============================================================================
  -- evaluate
  -- ============================================================================

  describe("evaluate", function()
    -- Negative: disabled redirect does not compute attrition.
    it("should not activate when frontline redirect is disabled", function()
      local cfg = makeConfig({ enabled = false })
      local calculateStub = trackStub(stub(AirbaseAttrition, "calculate").returns({
        expectedTotal = 4,
        currentTotal = 0,
        lossTotal = 4,
        attritionPct = 100,
      }))

      local isRedirected, message = FrontlineRedirect.evaluate(cfg, makeReconContext())

      assert.is_false(isRedirected)
      assert.is_nil(message)
      assert.stub(calculateStub).was_not.called()
    end)

    -- Negative: attrition below threshold keeps the sticky flag false.
    it("should keep redirect inactive when attrition is below threshold", function()
      local cfg = makeConfig({ attritionThresholdPct = 50 })
      local reconContext = makeReconContext()
      trackStub(stub(AirbaseAttrition, "calculate").returns({
        expectedTotal = 4,
        currentTotal = 4,
        lossTotal = 0,
        attritionPct = 0,
      }))

      local isRedirected, message = FrontlineRedirect.evaluate(cfg, reconContext)

      assert.is_false(isRedirected)
      assert.is_nil(message)
      assert.is_false(reconContext.frontlineRedirected)
    end)

    -- Positive: threshold breach activates the sticky flag.
    it("should set sticky flag and return activation message when attrition reaches threshold", function()
      local cfg = makeConfig({ attritionThresholdPct = 50 })
      local reconContext = makeReconContext()
      trackStub(stub(AirbaseAttrition, "calculate").returns({
        expectedTotal = 4,
        currentTotal = 0,
        lossTotal = 4,
        attritionPct = 100,
      }))

      local isRedirected, activationFields = FrontlineRedirect.evaluate(cfg, reconContext)
      assert.is_true(isRedirected)
      assert.is_true(reconContext.frontlineRedirected)
      assert.are.equal("attrition_threshold_reached", activationFields.reason)
      assert.are.equal("100.0", activationFields.attritionPct)
    end)

    -- Positive: sticky flag skips recomputing attrition.
    it("should skip attrition recompute when sticky flag is already true", function()
      local cfg = makeConfig()
      local reconContext = makeReconContext({ frontlineRedirected = true })
      local calculateStub = trackStub(stub(AirbaseAttrition, "calculate").returns({
        expectedTotal = 4,
        currentTotal = 4,
        lossTotal = 0,
        attritionPct = 0,
      }))

      local isRedirected, message = FrontlineRedirect.evaluate(cfg, reconContext)

      assert.is_true(isRedirected)
      assert.is_nil(message)
      assert.stub(calculateStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Mapping Rewrite
  -- ============================================================================

  describe("rewriteMappings", function()
    -- Positive: matching prefixes are rewritten on a copied mapping list.
    it("should rewrite only mappings matching prefix and type", function()
      local mappings = {
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
        { name = "AIR/STRIKE/AB/W/1", type = "ground" },
      }
      local rules = {
        { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
      }

      local result = FrontlineRedirect.rewriteMappings(mappings, rules)

      assert.are.equal("AIR/STRIKE/AB/W/AAR/1", result[1].name)
      assert.are.equal("AIR/STRIKE/AB/E/1", result[2].name)
      assert.are.equal("AIR/STRIKE/AB/W/1", result[3].name)
      assert.are.equal("AIR/STRIKE/AB/W/1", mappings[1].name)
    end)
  end)

  describe("applyMappings", function()
    -- Positive: active sticky redirect applies configured rewrites.
    it("should apply configured mapping rewrites when redirect is active", function()
      local cfg = makeConfig()
      local mappings = { { name = "AIR/STRIKE/AB/W/1", type = "air" } }

      local result = FrontlineRedirect.applyMappings(cfg, makeReconContext({ frontlineRedirected = true }), mappings)

      assert.are.equal("AIR/STRIKE/AB/W/AAR/1", result[1].name)
      assert.are.equal("AIR/STRIKE/AB/W/1", mappings[1].name)
    end)

    -- Negative: inactive redirect returns the original mapping list.
    it("should keep original mappings when redirect is inactive", function()
      local cfg = makeConfig()
      local mappings = { { name = "AIR/STRIKE/AB/W/1", type = "air" } }

      local result = FrontlineRedirect.applyMappings(cfg, makeReconContext(), mappings)

      assert.are.equal(mappings, result)
      assert.are.equal("AIR/STRIKE/AB/W/1", result[1].name)
    end)
  end)
end)
