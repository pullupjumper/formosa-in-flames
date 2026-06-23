-- ReconOperationScheduler Unit Tests
local ReconOperationScheduler = require("src.modules.strikePlanner.reconOperationScheduler")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local BaseConfig = require("src.core.config")

describe("ReconOperationScheduler", function()
  local activeStubs
  ---@type luassert.spy
  local logStub

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
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

  ---Create a minimal config for scheduling tests.
  ---@return SBJ__Config
  local function makeConfig()
    local cfg = Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
    cfg.c.recon.strikeMappingsByReconObjective = {
      C2_NORTH_TARGETING = {
        { name = "STRIKE/C2/N/1", type = "ground" },
      },
    }
    cfg.c.recon.frontlineRedirect = {
      enabled = false,
      attritionThresholdPct = 50,
      frontlineBaseNames = {},
      mappings = {
        { fromPrefix = "STRIKE/AB/W/", toPrefix = "STRIKE/AB/W/AAR/", type = "air" },
      },
    }
    cfg.c.packageTemplates = {}
    cfg.c.fireSupportTaskTemplates = {
      STRIKE_C2_N_1 = { {
        name = "FST-C2-1",
        firingUnits = {},
        missileSystem = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
      STRIKE_C2_N_2 = { {
        name = "FST-C2-2",
        firingUnits = {},
        missileSystem = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
    }
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

  ---Create a reconnaissance queue entry.
  ---@param overrides? table
  ---@return SBJ__ReconQueueEntry
  local function makeReconEntry(overrides)
    local entry = {
      type = "satellite",
      reconObjectiveId = "FIXED_SITE_TARGETING",
      endTime = "2026-02-14 08:00:00",
      isFinished = false,
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a minimal LACM context.
  ---@param enabled? boolean
  ---@return SBJ__LACMContext
  local function makeLACMContext(enabled)
    return { enabled = enabled or false, startTime = "2026-02-14 06:00:00" }
  end

  ---Create a reconnaissance queue processing context.
  ---@param config SBJ__Config Configuration data
  ---@param reconContext SBJ__ReconContext Reconnaissance runtime context
  ---@param reconTriggeredOperations SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
  ---@param LACMContext SBJ__LACMContext LACM context data
  ---@param fireSupportOnHold? boolean Whether SRBM-driven mappings should be skipped
  ---@return SBJ__ReconQueueProcessingContext
  local function makeProcessingContext(config, reconContext, reconTriggeredOperations, LACMContext, fireSupportOnHold)
    return {
      config = config,
      reconContext = reconContext,
      reconTriggeredOperations = reconTriggeredOperations,
      LACMContext = LACMContext,
      fireSupportOnHold = fireSupportOnHold == true
    }
  end

  ---Stub recurring DynamicOperationsUtils calls used by scheduler.
  local function stubRecurringHelpers()
    trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
      air = {}, ground = {}, mostRecentTime = nil, nextOperationBatchTime = nil,
    }))
  end

  ---Find a Logger.log call matching the given tag and message pattern.
  ---@param logTag string
  ---@param pattern string
  ---@return boolean
  local function hasLogCall(logTag, pattern)
    for _, call in ipairs(logStub.calls) do
      if call.vals[1] == logTag and string.find(call.vals[2], pattern) then
        return true
      end
    end
    return false
  end

  -- ============================================================================
  -- schedule
  -- ============================================================================

  describe("schedule", function()
    -- Negative: missing mapping config does not schedule operations.
    it("should handle missing strikeMappingsByReconObjective config", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective = nil
      local operations = {}
      stubRecurringHelpers()

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(0, #operations)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[ERROR%].*reason=strike_mappings_by_recon_objective_not_found"))
    end)

    -- Positive: satellite entries resolve mappings by reconObjectiveId.
    it("should resolve satellite mappings by reconObjectiveId", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
          { { name = "STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Negative: unmapped objectives are skipped.
    it("should log SKIP when no mappings match the entry's recon objective", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
          { { name = "STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "UNKNOWN_OBJECTIVE" })
      )

      assert.are.equal(0, #operations)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[SKIP%].*type=satellite objective=UNKNOWN_OBJECTIVE reason=strike_mapping_not_found"))
    end)

    -- Positive: SIGINT entries resolve mappings by reconObjectiveId.
    it("should resolve SIGINT mappings by reconObjectiveId", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_EMITTER_TARGETING =
          { { name = "STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "SIGINT", reconObjectiveId = "C2_EMITTER_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Positive: mixed mappings can schedule new operations and next operations.
    it("should process multiple strikeMappings with mixed new, skip, and next", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "STRIKE/C2/N/1", type = "ground" },
        { name = "STRIKE/AB/E/1", type = "air" },
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").invokes(function(_, name, opType)
        if name == "STRIKE/C2/N/1" and opType == "ground" then return false, nil, nil end
        if name == "STRIKE/AB/E/1" and opType == "air" then return false, nil, nil end
        if name == "STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", template = { name = "STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      trackStub(stub(DynamicOperationsUtils, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(2, #operations[1].operations)
    end)

    -- Negative: STRIKE/INFRASTRUCTURE/* mappings are skipped while fire support is on hold.
    it("should skip STRIKE/INFRASTRUCTURE/* mappings when fireSupportOnHold is true", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "STRIKE/INFRASTRUCTURE/1", type = "ground" },
        { name = "STRIKE/AB/W/1",           type = "air" },
      }
      cfg.c.packageTemplates.STRIKE_AB_W_1 = {
        { name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(true), true),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(1, #operations[1].operations)
      assert.are.equal("STRIKE/AB/W/1", operations[1].operations[1].template.name)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[HOLD%].*operation=STRIKE/INFRASTRUCTURE/1.*reason=fire_support_on_hold"))
    end)

    -- Positive: STRIKE/INFRASTRUCTURE/* mappings are inserted when hold is off.
    it("should insert STRIKE/INFRASTRUCTURE/* mappings when fireSupportOnHold is false", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
          { { name = "STRIKE/INFRASTRUCTURE/1", type = "ground" } }
      cfg.c.fireSupportTaskTemplates.STRIKE_INFRASTRUCTURE_1 = { {
        name = "FST-INFRA-1",
        firingUnits = {},
        missileSystem = "",
        target = { contactAge = 0, minTargetCount = 1, list = {} },
      } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("STRIKE/INFRASTRUCTURE/1", operations[1].operations[1].template.name)
    end)

    -- Negative: non-INFRASTRUCTURE mappings are unaffected by fire support hold.
    it("should not gate non-INFRASTRUCTURE mappings even when fireSupportOnHold is true", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "STRIKE/C2/N/1", type = "ground" },
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), true),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Boundary: pending next waves are deduplicated.
    it("should not schedule a duplicate next wave when an identical one is already pending", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "STRIKE/C2/N/1", type = "ground" },
      }
      local operations = {
        {
          time = "2026-02-14 07:00:00",
          type = "UAV",
          delay = 0,
          executed = false,
          operations = { { type = "ground", executed = false, template = { name = "STRIKE/C2/N/2" } } },
        }
      }
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").invokes(function(_, name, opType)
        if name == "STRIKE/C2/N/1" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "STRIKE/C2/N/1" } }, nil
        end
        if name == "STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      trackStub(stub(DynamicOperationsUtils, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      ReconOperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("STRIKE/C2/N/2", operations[1].operations[1].template.name)
    end)

    -- Positive: active frontline redirect rewrites matching strike mappings.
    it("should apply frontline redirect mappings when sticky flag is active", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "STRIKE/AB/W/1", type = "air" },
        { name = "STRIKE/AB/E/1", type = "air" },
      }
      cfg.c.packageTemplates.STRIKE_AB_W_AAR_1 = {
        { name = "PKG-AB-W-AAR-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      cfg.c.packageTemplates.STRIKE_AB_E_1 = {
        { name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false, nil, nil))

      ReconOperationScheduler.schedule(
        makeProcessingContext(
          cfg,
          makeReconContext({ frontlineRedirected = true }),
          operations,
          makeLACMContext(true),
          false
        ),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(2, #operations[1].operations)
      local names = {
        operations[1].operations[1].template.name,
        operations[1].operations[2].template.name,
      }
      table.sort(names)
      assert.are.equal("STRIKE/AB/E/1", names[1])
      assert.are.equal("STRIKE/AB/W/AAR/1", names[2])
    end)
  end)
end)
