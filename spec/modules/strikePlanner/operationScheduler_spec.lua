-- OperationScheduler Unit Tests
local OperationScheduler = require("src.modules.strikePlanner.operationScheduler")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local BaseConfig = require("src.core.config")

describe("OperationScheduler", function()
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub

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
    errorStub = trackStub(stub(Logger, "error"))
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
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      },
    }
    cfg.c.recon.frontlineRedirect = {
      enabled = false,
      attritionThresholdPct = 50,
      frontlineBaseNames = {},
      mappings = {
        { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
      },
    }
    cfg.c.packageTemplates = {}
    cfg.c.fireSupportTaskTemplates = {
      GND_STRIKE_C2_N_1 = { {
        name = "FST-C2-1",
        firingUnits = {},
        missileSystem = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
      GND_STRIKE_C2_N_2 = { {
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
  ---@param reconTriggeredOperationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
  ---@param LACMContext SBJ__LACMContext LACM context data
  ---@param fireSupportOnHold? boolean Whether SRBM-driven mappings should be skipped
  ---@return SBJ__ReconQueueProcessingContext
  local function makeProcessingContext(config, reconContext, reconTriggeredOperationBatches, LACMContext, fireSupportOnHold)
    return {
      config = config,
      reconContext = reconContext,
      reconTriggeredOperationBatches = reconTriggeredOperationBatches,
      LACMContext = LACMContext,
      fireSupportOnHold = fireSupportOnHold == true
    }
  end

  ---Stub recurring OperationScheduler calls used by scheduler.
  local function stubRecurringHelpers()
    trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
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

  ---Find a Logger.error call matching the given message pattern.
  ---@param pattern string
  ---@return boolean
  local function hasErrorCall(pattern)
    for _, call in ipairs(errorStub.calls) do
      if string.find(call.vals[1], pattern) then
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

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(0, #operations)
      assert.is_true(hasErrorCall("%[ERROR%].*reason=strike_mappings_by_recon_objective_not_found"))
      assert.stub(logStub).was_not.called()
    end)

    -- Positive: satellite entries resolve mappings by reconObjectiveId.
    it("should resolve satellite mappings by reconObjectiveId", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("GND/STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Negative: unmapped objectives are skipped.
    it("should log SKIP when no mappings match the entry's recon objective", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()

      OperationScheduler.schedule(
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
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "SIGINT", reconObjectiveId = "C2_EMITTER_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("GND/STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Positive: mixed mappings can schedule new operations and next operations.
    it("should process multiple strikeMappings with mixed new, skip, and next", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").invokes(function(_, name, opType)
        if name == "GND/STRIKE/C2/N/1" and opType == "ground" then return false, nil, nil end
        if name == "AIR/STRIKE/AB/E/1" and opType == "air" then return false, nil, nil end
        if name == "GND/STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(2, #operations[1].operations)
    end)

    -- Negative: GND/STRIKE/INFRA/ALL/* mappings are skipped while fire support is on hold.
    it("should skip GND/STRIKE/INFRA/ALL/* mappings when fireSupportOnHold is true", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "GND/STRIKE/INFRA/ALL/1", type = "ground" },
        { name = "AIR/STRIKE/AB/W/1",           type = "air" },
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(true), true),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(1, #operations[1].operations)
      assert.are.equal("AIR/STRIKE/AB/W/1", operations[1].operations[1].template.name)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[HOLD%].*operation=GND/STRIKE/INFRA/ALL/1.*reason=fire_support_on_hold"))
    end)

    -- Negative: the LACM strike stays out of the batch until the LACM context activates.
    it("should skip AIR/STRIKE/AB/E/1 when LACM is not enabled", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      -- The sibling mapping stays, so the gate dropped E/1 alone rather than the whole batch
      assert.are.equal(1, #operations)
      assert.are.equal(1, #operations[1].operations)
      assert.are.equal("AIR/STRIKE/AB/W/1", operations[1].operations[1].template.name)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[SKIP%].*operation=AIR/STRIKE/AB/E/1.*reason=lacm_not_active"))
    end)

    -- Positive: the same mapping schedules once LACM is active, proving the gate is conditional
    it("should schedule AIR/STRIKE/AB/E/1 when LACM is enabled", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal(1, #operations[1].operations)
      assert.are.equal("AIR/STRIKE/AB/E/1", operations[1].operations[1].template.name)
    end)

    -- Negative: scope metadata belongs to the summary action, not the entry rollup.
    it("should keep scope metadata out of the entry counts", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "AIR/STRIKE/AB/W/1", type = "air" } }
      cfg.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.stub(logStub).was.called(1)
      local message = logStub.calls[1].vals[2]

      -- One mapping produced exactly one entry; context fields must not inflate the rollup.
      assert.is_not_nil(string.find(message, "total=1 ok=1", 1, true))
      -- Scope metadata sits on the report header, not in an entry.
      assert.is_not_nil(string.find(message, "scheduled=1", 1, true))
      assert.is_not_nil(string.find(message, "airOps=0", 1, true))
      assert.is_nil(string.find(message, "state=context", 1, true))
      -- Scope label aligns with the air/ground operation emitters.
      assert.is_not_nil(string.find(message, "dynamicOperationScheduling: Schedule dynamic operations", 1, true))
    end)

    -- Positive: GND/STRIKE/INFRA/ALL/* mappings are inserted when hold is off.
    it("should insert GND/STRIKE/INFRA/ALL/* mappings when fireSupportOnHold is false", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/INFRA/ALL/1", type = "ground" } }
      cfg.c.fireSupportTaskTemplates.GND_STRIKE_INFRA_ALL_1 = { {
        name = "FST-INFRA-1",
        firingUnits = {},
        missileSystem = "",
        target = { contactAge = 0, minTargetCount = 1, list = {} },
      } }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("GND/STRIKE/INFRA/ALL/1", operations[1].operations[1].template.name)
    end)

    -- Negative: non-INFRASTRUCTURE mappings are unaffected by fire support hold.
    it("should not gate non-INFRASTRUCTURE mappings even when fireSupportOnHold is true", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), true),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("GND/STRIKE/C2/N/1", operations[1].operations[1].template.name)
    end)

    -- Boundary: pending next waves are deduplicated.
    it("should not schedule a duplicate next wave when an identical one is already pending", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operations = {
        {
          time = "2026-02-14 07:00:00",
          type = "UAV",
          delay = 0,
          executed = false,
          operations = { { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } } },
        }
      }
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").invokes(function(_, name, opType)
        if name == "GND/STRIKE/C2/N/1" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        if name == "GND/STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operations)
      assert.are.equal("GND/STRIKE/C2/N/2", operations[1].operations[1].template.name)
    end)

    -- Positive: active frontline redirect rewrites matching strike mappings.
    it("should apply frontline redirect mappings when sticky flag is active", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_W_AAR_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-AAR-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      cfg.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").returns(false, nil, nil))

      OperationScheduler.schedule(
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
      assert.are.equal("AIR/STRIKE/AB/E/1", names[1])
      assert.are.equal("AIR/STRIKE/AB/W/AAR/1", names[2])
    end)

    -- Negative: an underivable next wave must not re-queue the already-executed source
    it("should warn instead of scheduling when generateNextOperation cannot derive a next wave", function()
      local cfg = makeConfig()
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").invokes(function(_, name, opType)
        if name == "GND/STRIKE/C2/N/1" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        if name == "GND/STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      -- PARSE_ERROR hands back a copy of the source operation; scheduling it would duplicate the wave
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/1" } }, "PARSE_ERROR"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(0, #operations)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "%[WARN%]"))
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=parse_error"))
      assert.is_false(hasErrorCall("."))
    end)

    -- Positive: the domain status is lowercased into the status field
    it("should emit the next operation status as a snake_case token", function()
      local cfg = makeConfig()
      local operations = {}
      stubRecurringHelpers()
      trackStub(stub(OperationScheduler, "hasOperation").invokes(function(_, name, opType)
        if name == "GND/STRIKE/C2/N/1" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        if name == "GND/STRIKE/C2/N/" and opType == "ground" then
          return true, { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }, nil
        end
        return false, nil, nil
      end))
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(cfg, makeReconContext(), operations, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "status=found_next"))
    end)
  end)

  do
    ---Create a single operation for scheduler helper tests.
    ---@param overrides? table
    ---@return table
    local function makeOperation(overrides)
      local op = {
        type = "air",
        executed = false,
        template = { name = "AIR/STRIKE/AB/W/1" }
      }
      if overrides then
        for k, v in pairs(overrides) do op[k] = v end
      end
      return op
    end

    ---Create a reconnaissance-triggered operation batch for scheduler helper tests.
    ---@param overrides? table
    ---@return table
    local function makeOperationBatch(overrides)
      local entry = {
        time = "2026-02-14 08:00:00",
        type = "satellite",
        executed = false,
        operations = {
          makeOperation(),
        }
      }
      if overrides then
        for k, v in pairs(overrides) do entry[k] = v end
      end
      return entry
    end

    -- ============================================================================
    -- getLastExecutedOperationsAndNextTime
    -- ============================================================================

    describe("getLastExecutedOperationsAndNextTime", function()
      -- Positive: finds most recent past entry and classifies operations
      it("should find most recent past entry and classify operations", function()
        local airOp = makeOperation({ type = "air" })
        local groundOp = makeOperation({ type = "ground" })
        local schedule = {
          makeOperationBatch({
            time = "2026-02-14 06:00:00",
            operations = { makeOperation({ type = "air" }) }
          }),
          makeOperationBatch({
            time = "2026-02-14 08:00:00",
            operations = { airOp, groundOp }
          }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal(1, #result.air)
        assert.are.equal(1, #result.ground)
        assert.are.equal(airOp, result.air[1])
        assert.are.equal(groundOp, result.ground[1])
        assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
      end)

      -- Positive: finds next recon time
      it("should find next recon time from future entries", function()
        local schedule = {
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
          makeOperationBatch({ time = "2026-02-14 12:00:00" }),
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal("2026-02-14 12:00:00", result.nextOperationBatchTime)
        assert.are.equal("2026-02-14 06:00:00", result.mostRecentTime)
      end)

      -- Positive: picks latest past entry from unordered schedule
      it("should pick latest past entry when schedule is not in time order", function()
        local laterOp = makeOperation({ type = "air" })
        local schedule = {
          makeOperationBatch({ time = "2026-02-14 10:00:00", operations = { laterOp } }),
          makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { makeOperation() } }),
          makeOperationBatch({ time = "2026-02-14 08:00:00", operations = { makeOperation() } }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 12:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal(1, #result.air)
        assert.are.equal(laterOp, result.air[1])
        assert.are.equal("2026-02-14 10:00:00", result.mostRecentTime)
      end)

      -- Positive: picks earliest future entry as nextOperationBatchTime
      it("should pick earliest future entry as nextOperationBatchTime when schedule is unordered", function()
        local schedule = {
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
          makeOperationBatch({ time = "2026-02-14 14:00:00" }),
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal("2026-02-14 14:00:00", result.nextOperationBatchTime)
        assert.are.equal("2026-02-14 06:00:00", result.mostRecentTime)
      end)

      -- Negative: nil schedule
      it("should return empty result for nil schedule", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(nil)

        assert.are.equal(0, #result.air)
        assert.are.equal(0, #result.ground)
        assert.is_nil(result.nextOperationBatchTime)
        assert.is_nil(result.mostRecentTime)
      end)

      -- Negative: empty schedule
      it("should return empty result for empty schedule", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime({})

        assert.are.equal(0, #result.air)
        assert.are.equal(0, #result.ground)
        assert.is_nil(result.nextOperationBatchTime)
        assert.is_nil(result.mostRecentTime)
      end)

      -- Negative: GameApi returns nil
      it("should return empty result when GameApi returns nil", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(nil))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime({
          makeOperationBatch()
        })

        assert.are.equal(0, #result.air)
        assert.are.equal(0, #result.ground)
        assert.is_nil(result.mostRecentTime)
      end)

      -- Boundary: all entries in future
      it("should return no operations but has nextOperationBatchTime when all entries are in future", function()
        local schedule = {
          makeOperationBatch({ time = "2026-02-14 12:00:00" }),
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 06:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal(0, #result.air)
        assert.are.equal(0, #result.ground)
        assert.are.equal("2026-02-14 12:00:00", result.nextOperationBatchTime)
        assert.is_nil(result.mostRecentTime)
      end)

      -- Boundary: all entries in past
      it("should return no nextOperationBatchTime when all entries are in past", function()
        local schedule = {
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
          makeOperationBatch({ time = "2026-02-14 08:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 20:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.is_nil(result.nextOperationBatchTime)
        assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
      end)

      -- Boundary: entry with nil operations
      it("should handle entry with nil operations", function()
        local entry = makeOperationBatch({ time = "2026-02-14 08:00:00" })
        entry.operations = nil
        local schedule = { entry }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal(0, #result.air)
        assert.are.equal(0, #result.ground)
        assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
      end)

      -- Boundary: entry at exactly current time
      it("should handle entry at exactly current time as past", function()
        local op = makeOperation({ type = "ground" })
        local exactTime = "2026-02-14 08:00:00"
        local schedule = {
          makeOperationBatch({ time = exactTime, operations = { op } }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp(exactTime)))

        local result = OperationScheduler.getLastExecutedOperationsAndNextTime(schedule)

        assert.are.equal(1, #result.ground)
      end)
    end)

    -- ============================================================================
    -- hasOperation
    -- ============================================================================

    describe("hasOperation", function()
      -- Positive: exact match
      it("should find exact match by template name and type", function()
        local op = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local entry = makeOperationBatch({ operations = { op } })

        local exists, foundOp, foundEntry = OperationScheduler.hasOperation(
          { entry }, "AIR/STRIKE/AB/W/1", "air")

        assert.is_true(exists)
        assert.are.equal(op, foundOp)
        assert.are.equal(entry, foundEntry)
      end)

      -- Positive: searches across multiple entries
      it("should search across multiple entries and operations", function()
        local targetOp = makeOperation({ type = "ground", template = { name = "INFRA/2" } })
        local schedule = {
          makeOperationBatch({
            operations = { makeOperation({ type = "air", template = { name = "STRIKE/1" } }) }
          }),
          makeOperationBatch({
            time = "2026-02-14 10:00:00",
            operations = {
              makeOperation({ type = "air", template = { name = "SEAD/1" } }),
              targetOp
            }
          }),
        }

        local exists, foundOp = OperationScheduler.hasOperation(schedule, "INFRA/2", "ground")

        assert.is_true(exists)
        assert.are.equal(targetOp, foundOp)
      end)

      -- Negative: type mismatch
      it("should not match when type differs", function()
        local op = makeOperation({ type = "ground", template = { name = "AIR/STRIKE/AB/W/1" } })
        local schedule = { makeOperationBatch({ operations = { op } }) }

        local exists = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/1", "air")

        assert.is_false(exists)
      end)

      -- Negative: name mismatch
      it("should not match when name differs", function()
        local op = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local schedule = { makeOperationBatch({ operations = { op } }) }

        local exists = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/2", "air")

        assert.is_false(exists)
      end)

      -- Negative: nil operation batches
      it("should return false when operation batches are nil", function()
        assert.is_false(OperationScheduler.hasOperation(nil, "STRIKE/1", "air"))
      end)

      -- Negative: nil template
      it("should skip operations with nil template", function()
        local op = makeOperation({ template = nil })
        local schedule = { makeOperationBatch({ operations = { op } }) }

        local exists = OperationScheduler.hasOperation(schedule, "STRIKE/1", "air")

        assert.is_false(exists)
      end)

      -- Negative: nil operations
      it("should skip entries with nil operations", function()
        local schedule = { makeOperationBatch({ operations = nil }) }

        local exists = OperationScheduler.hasOperation(schedule, "STRIKE/1", "air")

        assert.is_false(exists)
      end)

      -- Positive: prefix search finds highest number
      it("should find highest number with prefix search", function()
        local op1 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local op3 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/3" } })
        local op2 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })

        local schedule = {
          makeOperationBatch({ operations = { op1, op3, op2 } })
        }

        local exists, foundOp = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_true(exists)
        assert.are.equal(op3, foundOp)
      end)

      -- Positive: prefix search picks latest time on same number
      it("should pick latest time when prefix search finds same max number", function()
        local olderOp = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })
        local newerOp = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })

        local schedule = {
          makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { olderOp } }),
          makeOperationBatch({ time = "2026-02-14 12:00:00", operations = { newerOp } }),
        }

        local exists, foundOp, foundEntry = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert(foundEntry ~= nil)
        assert.is_true(exists)
        assert.are.equal(newerOp, foundOp)
        assert.are.equal("2026-02-14 12:00:00", foundEntry.time)
      end)

      -- Negative: prefix search skips operations that are not yet executed
      it("should skip unexecuted operations in prefix search", function()
        local pendingOp = makeOperation({
          executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" },
        })
        local schedule = { makeOperationBatch({ operations = { pendingOp } }) }

        local exists, foundOp = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_false(exists)
        assert.is_nil(foundOp)
      end)

      -- Positive: prefix search picks the highest executed number, ignoring unexecuted ones
      it("should ignore unexecuted higher-numbered ops and pick highest executed", function()
        local executedOp1 = makeOperation({
          executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" },
        })
        local pendingOp3 = makeOperation({
          executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" },
        })
        local schedule = { makeOperationBatch({ operations = { executedOp1, pendingOp3 } }) }

        local exists, foundOp = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_true(exists)
        assert.are.equal(executedOp1, foundOp)
      end)

      -- Positive: exact match is not affected by executed gate
      it("should still find unexecuted operations via exact match", function()
        local pendingOp = makeOperation({
          executed = false, type = "ground", template = { name = "GND/STRIKE/INFRA/ALL/1" },
        })
        local schedule = { makeOperationBatch({ operations = { pendingOp } }) }

        local exists, foundOp = OperationScheduler.hasOperation(
          schedule, "GND/STRIKE/INFRA/ALL/1", "ground"
        )

        assert.is_true(exists)
        assert.are.equal(pendingOp, foundOp)
      end)

      -- Negative: prefix search no matches
      it("should return false for prefix search with no matches", function()
        local op = makeOperation({ type = "air", template = { name = "SEAD/1" } })
        local schedule = { makeOperationBatch({ operations = { op } }) }

        local exists = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_false(exists)
      end)

      -- Negative: prefix search ignores non-numeric suffix
      it("should ignore non-numeric suffix in prefix search", function()
        local op = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/abc" } })
        local schedule = { makeOperationBatch({ operations = { op } }) }

        local exists = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_false(exists)
      end)

      -- Negative: prefix search filters by type
      it("should filter by type in prefix search", function()
        local groundOp = makeOperation({ executed = true, type = "ground", template = { name = "AIR/STRIKE/AB/W/5" } })
        local schedule = { makeOperationBatch({ operations = { groundOp } }) }

        local exists = OperationScheduler.hasOperation(schedule, "AIR/STRIKE/AB/W/", "air")

        assert.is_false(exists)
      end)
    end)

    -- ============================================================================
    -- hasPendingOperation
    -- ============================================================================

    describe("hasPendingOperation", function()
      -- Positive: a matching unexecuted operation exists
      it("should return true when a matching unexecuted operation exists", function()
        local schedule = {
          makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/2" } }) } }),
        }

        assert.is_true(OperationScheduler.hasPendingOperation(schedule, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: the matching operation is already executed
      it("should return false when the matching operation is already executed", function()
        local schedule = {
          makeOperationBatch({
            operations = { makeOperation({ executed = true, template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_false(OperationScheduler.hasPendingOperation(schedule, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: the operation type differs
      it("should return false when the operation type differs", function()
        local schedule = {
          makeOperationBatch({
            operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_false(OperationScheduler.hasPendingOperation(schedule, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: no operation name matches
      it("should return false when no operation name matches", function()
        local schedule = {
          makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/1" } }) } }),
        }

        assert.is_false(OperationScheduler.hasPendingOperation(schedule, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Positive: executed prior wave plus pending next wave across separate entries
      it("should find a pending operation across multiple schedule entries", function()
        local schedule = {
          makeOperationBatch({
            executed = true,
            operations = { makeOperation({ type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }) }
          }),
          makeOperationBatch({
            operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_true(OperationScheduler.hasPendingOperation(schedule, "GND/STRIKE/C2/N/2", "ground"))
      end)

      -- Boundary: empty schedule
      it("should return false for an empty schedule", function()
        assert.is_false(OperationScheduler.hasPendingOperation({}, "GND/STRIKE/C2/N/2", "air"))
      end)
    end)

    -- ============================================================================
    -- generateNextOperation
    -- ============================================================================

    describe("generateNextOperation", function()
      -- Positive: finds next air template
      it("should find next air template and increment number", function()
        local operation = makeOperation({
          type = "air",
          template = {
            name = "AIR/STRIKE/AB/W/1",
            isFirstWave = true,
            strikeInterval = 120,
            packages = { { striker = {} } }
          }
        })
        local config = {
          c = {
            packageTemplates = {
              AIR_STRIKE_AB_W_2 = { { striker = { baseGUID = "NEW-BASE" } } }
            }
          }
        }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("AIR/STRIKE/AB/W/2", result.template.name)
        assert.are.equal("air", result.type)
        assert.is_false(result.executed)
        assert.is_false(result.template.isFirstWave)
        assert.are.equal(120, result.template.strikeInterval)
        assert.is_table(result.template.packages)
        assert.are.equal("FOUND_NEXT", status)
      end)

      -- Positive: finds next ground template
      it("should find next ground template and increment number", function()
        local operation = makeOperation({
          type = "ground",
          template = {
            name = "INFRASTRUCTURE/1",
            strikeInterval = 60,
            fireSupportTasks = { { name = "FST-1" } }
          }
        })
        local config = {
          c = {
            fireSupportTaskTemplates = {
              INFRASTRUCTURE_2 = { { name = "FST-2-NEW" } }
            }
          }
        }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("INFRASTRUCTURE/2", result.template.name)
        assert.are.equal("ground", result.type)
        assert.is_false(result.executed)
        assert.is_false(result.template.isFirstWave)
        assert.are.equal(60, result.template.strikeInterval)
        assert.are.equal("FOUND_NEXT", status)
      end)

      -- Positive: sets isFirstWave to false
      it("should set isFirstWave to false in generated operation", function()
        local operation = makeOperation({
          type = "air",
          template = {
            name = "STRIKE/1",
            isFirstWave = true,
            strikeInterval = 100,
            packages = {}
          }
        })
        local config = {
          c = { packageTemplates = { STRIKE_2 = { { striker = {} } } } }
        }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.is_false(result.template.isFirstWave)
        assert.are.equal("FOUND_NEXT", status)
      end)

      -- Positive: handles multi-digit numbers
      it("should handle multi-digit number increments", function()
        local operation = makeOperation({
          type = "air",
          template = {
            name = "STRIKE/AB/99",
            isFirstWave = false,
            strikeInterval = 0,
            packages = {}
          }
        })
        local config = {
          c = { packageTemplates = { STRIKE_AB_100 = { { striker = {} } } } }
        }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("STRIKE/AB/100", result.template.name)
        assert.are.equal("FOUND_NEXT", status)
      end)

      -- Negative: reuses current air template when next not found
      it("should reuse current template when next is not found for air", function()
        local originalPackages = { { striker = { baseGUID = "BASE-1" } } }
        local operation = makeOperation({
          type = "air",
          template = {
            name = "AIR/STRIKE/AB/W/5",
            isFirstWave = true,
            strikeInterval = 90,
            packages = originalPackages
          }
        })
        local config = { c = { packageTemplates = {} } }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("AIR/STRIKE/AB/W/5", result.template.name)
        assert.are.equal(originalPackages, result.template.packages)
        assert.are.equal("REUSED_CURRENT", status)
      end)

      -- Negative: reuses current ground template when next not found
      it("should reuse current template when next is not found for ground", function()
        local originalTasks = { { name = "FST-ORIGINAL" } }
        local operation = makeOperation({
          type = "ground",
          template = {
            name = "ANTISHIP/3",
            strikeInterval = 0,
            fireSupportTasks = originalTasks
          }
        })
        local config = { c = { fireSupportTaskTemplates = {} } }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("ANTISHIP/3", result.template.name)
        assert.are.equal(originalTasks, result.template.fireSupportTasks)
        assert.are.equal("REUSED_CURRENT", status)
      end)

      -- Negative: unparseable template name
      it("should return deep copy when template name is unparseable", function()
        local operation = makeOperation({
          type = "air",
          template = { name = "NO-NUMBER-SUFFIX" }
        })
        local config = { c = { packageTemplates = {} } }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("air", result.type)
        assert.is_not.equal(operation, result)
        assert.are.equal("PARSE_ERROR", status)
      end)

      -- Negative: unknown operation type
      it("should return deep copy for unknown operation type", function()
        local operation = makeOperation({
          type = "naval",
          template = { name = "BLOCKADE/1" }
        })
        local config = { c = { packageTemplates = {}, fireSupportTaskTemplates = {} } }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.is_not.equal(operation, result)
        assert.are.equal("UNKNOWN_TYPE", status)
      end)

      -- Boundary: nil strikeInterval defaults to 0 for ground
      it("should default ground strikeInterval to 0 when nil in original", function()
        local operation = makeOperation({
          type = "ground",
          template = {
            name = "INFRASTRUCTURE/1",
            strikeInterval = nil,
            fireSupportTasks = {}
          }
        })
        local config = {
          c = { fireSupportTaskTemplates = { INFRASTRUCTURE_2 = { { name = "FST" } } } }
        }

        local result, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal(0, result.template.strikeInterval)
        assert.are.equal("FOUND_NEXT", status)
      end)
    end)
  end
end)
