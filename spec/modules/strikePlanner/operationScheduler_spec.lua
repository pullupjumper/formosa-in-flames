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
  ---@param stubObject any
  ---@return luassert.spy
  local function trackStub(stubObject)
    table.insert(activeStubs, stubObject)
    return stubObject
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
    local config = Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
    config.c.recon.strikeMappingsByReconObjective = {
      C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      },
    }
    config.c.recon.frontlineRedirect = {
      enabled = false,
      attritionThresholdPct = 50,
      frontlineBaseNames = {},
      mappings = {
        { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
      },
    }
    config.c.packageTemplates = {}
    config.c.fireSupportTaskTemplates = {
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
    return config
  end

  ---Create a minimal recon context.
  ---@param overrides? table
  ---@return SBJ__ReconContext
  local function makeReconContext(overrides)
    local reconContext = { queue = {}, frontlineRedirected = false }
    if overrides then
      for k, v in pairs(overrides) do reconContext[k] = v end
    end
    return reconContext
  end

  ---Create a reconnaissance queue entry.
  ---@param overrides? table
  ---@return SBJ__ReconQueueEntry
  local function makeReconEntry(overrides)
    local reconEntry = {
      type = "satellite",
      reconObjectiveId = "FIXED_SITE_TARGETING",
      endTime = "2026-02-14 08:00:00",
      isFinished = false,
    }
    if overrides then
      for k, v in pairs(overrides) do reconEntry[k] = v end
    end
    return reconEntry
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

  ---Stub the batch snapshot query so tests do not depend on the game clock.
  local function stubEmptyBatchSnapshot()
    trackStub(stub(OperationScheduler, "getMostRecentOperationsAndNextTime").returns({
      air = {}, ground = {}, mostRecentTime = nil, nextOperationBatchTime = nil,
    }))
  end

  ---Stub both scheduling queries so one numbered series reads as already executed.
  ---Any other mapping falls through as never scheduled, taking the first-wave path.
  ---@param templateName string Exact template name of the series, e.g. "GND/STRIKE/C2/N/1"
  ---@param operationType string Operation type of that series
  ---@return table # The operation handed back as the series' latest executed wave
  local function stubExecutedSeries(templateName, operationType)
    local seriesPrefix = templateName:match("^(.+/)%d+$")
    local executedOperation = {
      type = operationType,
      executed = true,
      template = { name = templateName },
    }

    trackStub(stub(OperationScheduler, "isOperationScheduled").invokes(function(_, name, opType)
      return name == templateName and opType == operationType
    end))
    trackStub(stub(OperationScheduler, "findLatestExecutedOperation").invokes(function(_, prefix, opType)
      if prefix == seriesPrefix and opType == operationType then
        return executedOperation
      end
      return nil
    end))

    return executedOperation
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
    -- Positive: satellite entries resolve mappings by reconObjectiveId.
    it("should resolve satellite mappings by reconObjectiveId", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal("GND/STRIKE/C2/N/1", operationBatches[1].operations[1].template.name)
    end)

    -- Negative: unmapped objectives are skipped.
    it("should log SKIP when no mappings match the entry's recon objective", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operationBatches = {}
      stubEmptyBatchSnapshot()

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "UNKNOWN_OBJECTIVE" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[SKIP%].*type=satellite objective=UNKNOWN_OBJECTIVE reason=strike_mapping_not_found"))
    end)

    -- Positive: the batch carries the recon entry's identity for the downstream builders.
    it("should stamp the batch with the recon entry's time and type", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_EMITTER_TARGETING =
      { { name = "GND/STRIKE/C2/N/1", type = "ground" } }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({
          type = "SIGINT",
          reconObjectiveId = "C2_EMITTER_TARGETING",
          endTime = "2026-02-14 09:30:00",
        })
      )

      -- atoBuilder labels rows with type@time; dynamicState skips batches already executed
      assert.are.equal("2026-02-14 09:30:00", operationBatches[1].time)
      assert.are.equal("SIGINT", operationBatches[1].type)
      assert.is_false(operationBatches[1].executed)
    end)

    -- Positive: mixed mappings can schedule new operationBatches and next operationBatches.
    -- Each mapping takes exactly one path: open a first wave, or advance an existing series.
    it("should process multiple strikeMappings with mixed new, skip, and next", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
        { name = "GND/STRIKE/C2/C/1", type = "ground" },
        { name = "AIR/STRIKE/AB/E/1", type = "air",    requiresLACM = true },
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      -- C/1 has already executed, so its mapping advances instead of opening a wave
      stubExecutedSeries("GND/STRIKE/C2/C/1", "ground")
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/C/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal(2, #operationBatches[1].operations)

      local operationNames = {
        operationBatches[1].operations[1].template.name,
        operationBatches[1].operations[2].template.name,
      }
      table.sort(operationNames)
      assert.are.equal("GND/STRIKE/C2/C/2", operationNames[1])
      assert.are.equal("GND/STRIKE/C2/N/1", operationNames[2])
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=lacm_not_committed"))
    end)

    -- Negative: GND/STRIKE/INFRA/ALL/* mappings are skipped while fire support is on hold.
    it("should skip GND/STRIKE/INFRA/ALL/* mappings when fireSupportOnHold is true", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "GND/STRIKE/INFRA/ALL/1", type = "ground" },
        { name = "AIR/STRIKE/AB/W/1",           type = "air" },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), true),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal(1, #operationBatches[1].operations)
      assert.are.equal("AIR/STRIKE/AB/W/1", operationBatches[1].operations[1].template.name)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[HOLD%].*operation=GND/STRIKE/INFRA/ALL/1.*reason=fire_support_on_hold"))
    end)

    -- Negative: the LACM strike stays out of the batch until the LACM context activates.
    it("should skip a requiresLACM mapping when LACM is not committed", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air", requiresLACM = true },
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      config.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      -- The sibling mapping stays, so the gate dropped E/1 alone rather than the whole batch
      assert.are.equal(1, #operationBatches)
      assert.are.equal(1, #operationBatches[1].operations)
      assert.are.equal("AIR/STRIKE/AB/W/1", operationBatches[1].operations[1].template.name)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS,
        "%[SKIP%].*operation=AIR/STRIKE/AB/E/1.*reason=lacm_not_committed"))
    end)

    -- Negative: the gate also covers follow-on waves, not just the first one.
    it("should skip a requiresLACM follow-on wave when LACM is not committed", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air", requiresLACM = true },
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      -- Both stubs are load-bearing: without them the mapping falls through to the
      -- first-wave path and stops on a missing template, passing for the wrong reason.
      stubExecutedSeries("AIR/STRIKE/AB/E/1", "air")
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "air", executed = false, template = { name = "AIR/STRIKE/AB/E/1" } }, "REUSED_CURRENT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=lacm_not_committed"))
    end)

    -- Positive: the same mapping schedules once LACM is active, proving the gate is conditional
    it("should schedule a requiresLACM mapping when LACM is committed", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air", requiresLACM = true },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal(1, #operationBatches[1].operations)
      assert.are.equal("AIR/STRIKE/AB/E/1", operationBatches[1].operations[1].template.name)
    end)

    -- Negative: a mapping whose config template is missing must not reach the batch.
    it("should reject a mapping with no resolved template", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/NOPE/1", type = "air" },
      }
      -- config.c.packageTemplates has no AIR_STRIKE_NOPE_1 entry
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasErrorCall("%[ERROR%].*operation=AIR/STRIKE/NOPE/1.*reason=template_not_found"))
    end)

    -- Negative: an operation type outside OPERATION_TYPE_TRAITS has no template field to fill.
    it("should reject a mapping with an unknown operation type", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "SEA/STRIKE/PORT/1", type = "naval" },
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasErrorCall("%[ERROR%].*reason=unknown_operation_type"))
    end)

    -- Positive: strikeInterval defaults come from OPERATION_TYPE_TRAITS, per operation type.
    it("should apply the configured strike interval to air waves and zero to ground waves", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      local templatesByName = {}
      for _, operation in ipairs(operationBatches[1].operations) do
        templatesByName[operation.template.name] = operation.template
      end

      assert.are.equal(config.strikeInterval, templatesByName["AIR/STRIKE/AB/W/1"].strikeInterval)
      assert.are.equal(0, templatesByName["GND/STRIKE/C2/N/1"].strikeInterval)
    end)

    -- Negative: scope metadata belongs to the summary action, not the entry rollup.
    it("should keep scope metadata out of the entry counts", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "AIR/STRIKE/AB/W/1", type = "air" } }
      config.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.stub(logStub).was.called(1)
      local message = logStub.calls[1].vals[2]

      -- One mapping produced exactly one entry; context fields must not inflate the rollup.
      assert.is_not_nil(string.find(message, "total=1 ok=1", 1, true))
      -- Scope metadata sits on the report header, not in an entry.
      assert.is_not_nil(string.find(message, "scheduled=1", 1, true))
      assert.is_not_nil(string.find(message, "airOps=0", 1, true))
      -- Scope label aligns with the air/ground operation emitters.
      assert.is_not_nil(string.find(message, "dynamicOperationScheduling: Schedule dynamic operations", 1, true))
    end)

    -- Positive: GND/STRIKE/INFRA/ALL/* mappings are inserted when hold is off.
    it("should insert GND/STRIKE/INFRA/ALL/* mappings when fireSupportOnHold is false", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING =
      { { name = "GND/STRIKE/INFRA/ALL/1", type = "ground" } }
      config.c.fireSupportTaskTemplates.GND_STRIKE_INFRA_ALL_1 = { {
        name = "FST-INFRA-1",
        firingUnits = {},
        missileSystem = "",
        target = { contactAge = 0, minTargetCount = 1, list = {} },
      } }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal("GND/STRIKE/INFRA/ALL/1", operationBatches[1].operations[1].template.name)
    end)

    -- Negative: non-INFRASTRUCTURE mappings are unaffected by fire support hold.
    it("should not gate non-INFRASTRUCTURE mappings even when fireSupportOnHold is true", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), true),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal("GND/STRIKE/C2/N/1", operationBatches[1].operations[1].template.name)
    end)

    -- Boundary: pending next waves are deduplicated.
    it("should not schedule a duplicate next wave when an identical one is already pending", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operationBatches = {
        {
          time = "2026-02-14 07:00:00",
          type = "UAV",
          delay = 0,
          executed = false,
          operations = { { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } } },
        }
      }
      stubEmptyBatchSnapshot()
      stubExecutedSeries("GND/STRIKE/C2/N/1", "ground")
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal("GND/STRIKE/C2/N/2", operationBatches[1].operations[1].template.name)
    end)

    -- Boundary: REUSED_CURRENT is deduplicated too, not only FOUND_NEXT.
    it("should not re-queue a REUSED_CURRENT wave while an identical one is still pending", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operationBatches = {
        {
          time = "2026-02-14 07:00:00",
          type = "UAV",
          delay = 0,
          executed = false,
          operations = { { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/1" } } },
        }
      }
      stubEmptyBatchSnapshot()
      stubExecutedSeries("GND/STRIKE/C2/N/1", "ground")
      -- No /2 template exists, so the scheduler falls back to the already-executed /1
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/1" } }, "REUSED_CURRENT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=already_pending"))
    end)

    -- Positive: the REUSED_CURRENT block lifts once the pending copy has executed.
    it("should re-queue a REUSED_CURRENT wave after the pending copy has executed", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      local operationBatches = {
        {
          time = "2026-02-14 07:00:00",
          type = "UAV",
          delay = 0,
          executed = true,
          operations = { { type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } } },
        }
      }
      stubEmptyBatchSnapshot()
      stubExecutedSeries("GND/STRIKE/C2/N/1", "ground")
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/1" } }, "REUSED_CURRENT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(2, #operationBatches)
      assert.are.equal("GND/STRIKE/C2/N/1", operationBatches[2].operations[1].template.name)
    end)

    -- Regression: repeated recon completions must not stack identical pending waves.
    -- Runs the real query/generateNextOperation path; before the fix this reached 3.
    it("should keep a single pending copy across repeated recon completions", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      }
      -- Drop the /2 template so every completion resolves to REUSED_CURRENT
      config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_2 = nil

      local operationBatches = {
        {
          time = "2027-06-09 01:00:00",
          type = "satellite",
          delay = 0,
          executed = true,
          operations = { {
            type = "ground",
            executed = true,
            template = {
              name = "GND/STRIKE/C2/N/1",
              isFirstWave = true,
              strikeInterval = 0,
              fireSupportTasks = config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_1,
            },
          } },
        }
      }
      stubEmptyBatchSnapshot()

      ---Count unexecuted operations carrying the given template name.
      ---@param operationBatches table[]
      ---@param templateName string
      ---@return integer
      local function countPending(operationBatches, templateName)
        local count = 0
        for _, batch in ipairs(operationBatches) do
          for _, operation in ipairs(batch.operations or {}) do
            if operation.template and operation.template.name == templateName and not operation.executed then
              count = count + 1
            end
          end
        end
        return count
      end

      for _, endTime in ipairs({ "2027-06-09 02:00:00", "2027-06-09 03:00:00", "2027-06-09 04:00:00" }) do
        OperationScheduler.schedule(
          makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
          makeReconEntry({ type = "satellite", reconObjectiveId = "C2_NORTH_TARGETING", endTime = endTime })
        )
      end

      assert.are.equal(1, countPending(operationBatches, "GND/STRIKE/C2/N/1"))
    end)

    -- Positive: active frontline redirect rewrites matching strike mappings.
    it("should apply frontline redirect mappings when sticky flag is active", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "AIR/STRIKE/AB/W/1", type = "air" },
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_W_AAR_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-AAR-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      config.c.packageTemplates.AIR_STRIKE_AB_E_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-E-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      trackStub(stub(OperationScheduler, "isOperationScheduled").returns(false))

      OperationScheduler.schedule(
        makeProcessingContext(
          config,
          makeReconContext({ frontlineRedirected = true }),
          operationBatches,
          makeLACMContext(true),
          false
        ),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.are.equal(2, #operationBatches[1].operations)
      local operationNames = {
        operationBatches[1].operations[1].template.name,
        operationBatches[1].operations[2].template.name,
      }
      table.sort(operationNames)
      assert.are.equal("AIR/STRIKE/AB/E/1", operationNames[1])
      assert.are.equal("AIR/STRIKE/AB/W/AAR/1", operationNames[2])
    end)

    -- Negative: an underivable next wave must not re-queue the already-executed source
    it("should warn instead of scheduling when generateNextOperation cannot derive a next wave", function()
      local config = makeConfig()
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      stubExecutedSeries("GND/STRIKE/C2/N/1", "ground")
      -- PARSE_ERROR hands back a copy of the source operation; scheduling it would duplicate the wave
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/1" } }, "PARSE_ERROR"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "%[WARN%]"))
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=parse_error"))
      assert.is_false(hasErrorCall("."))
    end)

    -- Positive: the domain status is lowercased into the status field
    it("should emit the next operation status as a snake_case token", function()
      local config = makeConfig()
      local operationBatches = {}
      stubEmptyBatchSnapshot()
      stubExecutedSeries("GND/STRIKE/C2/N/1", "ground")
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "GND/STRIKE/C2/N/2" } }, "FOUND_NEXT"
      ))

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLACMContext(false), false),
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
      local operation = {
        type = "air",
        executed = false,
        template = { name = "AIR/STRIKE/AB/W/1" }
      }
      if overrides then
        for k, v in pairs(overrides) do operation[k] = v end
      end
      return operation
    end

    ---Create a reconnaissance-triggered operation batch for scheduler helper tests.
    ---@param overrides? table
    ---@return table
    local function makeOperationBatch(overrides)
      local batch = {
        time = "2026-02-14 08:00:00",
        type = "satellite",
        executed = false,
        operations = {
          makeOperation(),
        }
      }
      if overrides then
        for k, v in pairs(overrides) do batch[k] = v end
      end
      return batch
    end

    -- ============================================================================
    -- getMostRecentOperationsAndNextTime
    -- ============================================================================

    describe("getMostRecentOperationsAndNextTime", function()
      -- Positive: finds most recent past entry and classifies operations
      it("should find most recent past entry and classify operations", function()
        local airOperation = makeOperation({ type = "air" })
        local groundOperation = makeOperation({ type = "ground" })
        local operationBatches = {
          makeOperationBatch({
            time = "2026-02-14 06:00:00",
            operations = { makeOperation({ type = "air" }) }
          }),
          makeOperationBatch({
            time = "2026-02-14 08:00:00",
            operations = { airOperation, groundOperation }
          }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal(1, #snapshot.air)
        assert.are.equal(1, #snapshot.ground)
        assert.are.equal(airOperation, snapshot.air[1])
        assert.are.equal(groundOperation, snapshot.ground[1])
        assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
      end)

      -- Positive: finds next recon time
      it("should find next recon time from future entries", function()
        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
          makeOperationBatch({ time = "2026-02-14 12:00:00" }),
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal("2026-02-14 12:00:00", snapshot.nextOperationBatchTime)
        assert.are.equal("2026-02-14 06:00:00", snapshot.mostRecentTime)
      end)

      -- Positive: picks latest past entry from unordered operationBatches
      it("should pick latest past entry when batches are not in time order", function()
        local laterOperation = makeOperation({ type = "air" })
        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 10:00:00", operations = { laterOperation } }),
          makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { makeOperation() } }),
          makeOperationBatch({ time = "2026-02-14 08:00:00", operations = { makeOperation() } }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 12:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal(1, #snapshot.air)
        assert.are.equal(laterOperation, snapshot.air[1])
        assert.are.equal("2026-02-14 10:00:00", snapshot.mostRecentTime)
      end)

      -- Positive: picks earliest future entry as nextOperationBatchTime
      it("should pick earliest future entry as nextOperationBatchTime when batches are unordered", function()
        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
          makeOperationBatch({ time = "2026-02-14 14:00:00" }),
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal("2026-02-14 14:00:00", snapshot.nextOperationBatchTime)
        assert.are.equal("2026-02-14 06:00:00", snapshot.mostRecentTime)
      end)

      -- Negative: empty operationBatches
      it("should return empty snapshot for an empty batch list", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime({})

        assert.are.equal(0, #snapshot.air)
        assert.are.equal(0, #snapshot.ground)
        assert.is_nil(snapshot.nextOperationBatchTime)
        assert.is_nil(snapshot.mostRecentTime)
      end)

      -- Negative: GameApi returns nil
      it("should return empty snapshot when GameApi returns nil", function()
        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(nil))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime({
          makeOperationBatch()
        })

        assert.are.equal(0, #snapshot.air)
        assert.are.equal(0, #snapshot.ground)
        assert.is_nil(snapshot.mostRecentTime)
      end)

      -- Boundary: all entries in future
      it("should return no operations but has nextOperationBatchTime when all entries are in future", function()
        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 12:00:00" }),
          makeOperationBatch({ time = "2026-02-14 18:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 06:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal(0, #snapshot.air)
        assert.are.equal(0, #snapshot.ground)
        assert.are.equal("2026-02-14 12:00:00", snapshot.nextOperationBatchTime)
        assert.is_nil(snapshot.mostRecentTime)
      end)

      -- Boundary: all entries in past
      it("should return no nextOperationBatchTime when all entries are in past", function()
        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 06:00:00" }),
          makeOperationBatch({ time = "2026-02-14 08:00:00" }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 20:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.is_nil(snapshot.nextOperationBatchTime)
        assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
      end)

      -- Boundary: operationBatch with nil operations
      it("should handle operationBatch with nil operations", function()
        local operationBatch = makeOperationBatch({ time = "2026-02-14 08:00:00" })
        operationBatch.operations = nil
        local operationBatches = { operationBatch }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal(0, #snapshot.air)
        assert.are.equal(0, #snapshot.ground)
        assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
      end)

      -- Boundary: operationBatch at exactly current time
      it("should handle operationBatch at exactly current time as past", function()
        local operation = makeOperation({ type = "ground" })
        local exactTime = "2026-02-14 08:00:00"
        local operationBatches = {
          makeOperationBatch({ time = exactTime, operations = { operation } }),
        }

        trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
          Utils.parseDatetimeToTimestamp(exactTime)))

        local snapshot = OperationScheduler.getMostRecentOperationsAndNextTime(operationBatches)

        assert.are.equal(1, #snapshot.ground)
      end)
    end)

    -- ============================================================================
    -- isOperationScheduled
    -- ============================================================================

    describe("isOperationScheduled", function()
      -- Positive: exact match
      it("should find exact match by template name and type", function()
        local operation = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local operationBatch = makeOperationBatch({ operations = { operation } })

        local exists = OperationScheduler.isOperationScheduled(
          { operationBatch }, "AIR/STRIKE/AB/W/1", "air")

        assert.is_true(exists)
      end)

      -- Positive: searches across multiple entries
      it("should search across multiple entries and operations", function()
        local targetOperation = makeOperation({ type = "ground", template = { name = "INFRA/2" } })
        local operationBatches = {
          makeOperationBatch({
            operations = { makeOperation({ type = "air", template = { name = "STRIKE/1" } }) }
          }),
          makeOperationBatch({
            time = "2026-02-14 10:00:00",
            operations = {
              makeOperation({ type = "air", template = { name = "SEAD/1" } }),
              targetOperation
            }
          }),
        }

        local exists = OperationScheduler.isOperationScheduled(operationBatches, "INFRA/2", "ground")

        assert.is_true(exists)
      end)

      -- Negative: type mismatch
      it("should not match when type differs", function()
        local operation = makeOperation({ type = "ground", template = { name = "AIR/STRIKE/AB/W/1" } })
        local operationBatches = { makeOperationBatch({ operations = { operation } }) }

        local exists = OperationScheduler.isOperationScheduled(operationBatches, "AIR/STRIKE/AB/W/1", "air")

        assert.is_false(exists)
      end)

      -- Negative: name mismatch
      it("should not match when name differs", function()
        local operation = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local operationBatches = { makeOperationBatch({ operations = { operation } }) }

        local exists = OperationScheduler.isOperationScheduled(operationBatches, "AIR/STRIKE/AB/W/2", "air")

        assert.is_false(exists)
      end)

      -- Negative: nil template
      it("should skip operations with nil template", function()
        local operation = makeOperation({ template = nil })
        local operationBatches = { makeOperationBatch({ operations = { operation } }) }

        local exists = OperationScheduler.isOperationScheduled(operationBatches, "STRIKE/1", "air")

        assert.is_false(exists)
      end)

      -- Negative: nil operations
      it("should skip entries with nil operations", function()
        local operationBatches = { makeOperationBatch({ operations = nil }) }

        local exists = OperationScheduler.isOperationScheduled(operationBatches, "STRIKE/1", "air")

        assert.is_false(exists)
      end)

      -- Boundary: an unexecuted operation still counts as scheduled
      it("should count an unexecuted operation as scheduled", function()
        local pendingOperation = makeOperation({
          executed = false, type = "ground", template = { name = "GND/STRIKE/INFRA/ALL/1" },
        })
        local operationBatches = { makeOperationBatch({ operations = { pendingOperation } }) }

        local exists = OperationScheduler.isOperationScheduled(
          operationBatches, "GND/STRIKE/INFRA/ALL/1", "ground")

        assert.is_true(exists)
      end)
    end)

    -- ============================================================================
    -- findLatestExecutedOperation
    -- ============================================================================

    describe("findLatestExecutedOperation", function()
      -- Positive: picks the highest wave number
      it("should find highest number with prefix search", function()
        local op1 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
        local op3 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/3" } })
        local op2 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })

        local operationBatches = {
          makeOperationBatch({ operations = { op1, op3, op2 } })
        }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_not_nil(foundOperation)
        assert.are.equal(op3, foundOperation)
      end)

      -- Positive: ties on wave number fall back to the later batch
      it("should pick latest time when prefix search finds same max number", function()
        local olderOperation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })
        local newerOperation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })

        local operationBatches = {
          makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { olderOperation } }),
          makeOperationBatch({ time = "2026-02-14 12:00:00", operations = { newerOperation } }),
        }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_not_nil(foundOperation)
        assert.are.equal(newerOperation, foundOperation)
      end)

      -- Negative: prefix search skips operations that are not yet executed
      it("should skip unexecuted operations in prefix search", function()
        local pendingOperation = makeOperation({
          executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" },
        })
        local operationBatches = { makeOperationBatch({ operations = { pendingOperation } }) }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_nil(foundOperation)
        assert.is_nil(foundOperation)
      end)

      -- Positive: prefix search picks the highest executed number, ignoring unexecuted ones
      it("should ignore unexecuted higher-numbered ops and pick highest executed", function()
        local executedOp1 = makeOperation({
          executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" },
        })
        local pendingOp3 = makeOperation({
          executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" },
        })
        local operationBatches = { makeOperationBatch({ operations = { executedOp1, pendingOp3 } }) }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_not_nil(foundOperation)
        assert.are.equal(executedOp1, foundOperation)
      end)

      -- Positive: exact match is not affected by executed gate
      -- Negative: prefix search no matches
      it("should return nil for prefix search with no matches", function()
        local operation = makeOperation({ type = "air", template = { name = "SEAD/1" } })
        local operationBatches = { makeOperationBatch({ operations = { operation } }) }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_nil(foundOperation)
      end)

      -- Negative: prefix search ignores non-numeric suffix
      it("should ignore non-numeric suffix in prefix search", function()
        local operation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/abc" } })
        local operationBatches = { makeOperationBatch({ operations = { operation } }) }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_nil(foundOperation)
      end)

      -- Negative: prefix search filters by type
      it("should filter by type in prefix search", function()
        local groundOperation = makeOperation({ executed = true, type = "ground", template = { name = "AIR/STRIKE/AB/W/5" } })
        local operationBatches = { makeOperationBatch({ operations = { groundOperation } }) }

        local foundOperation = OperationScheduler.findLatestExecutedOperation(operationBatches, "AIR/STRIKE/AB/W/", "air")

        assert.is_nil(foundOperation)
      end)
    end)

    -- ============================================================================
    -- isOperationPending
    -- ============================================================================

    describe("isOperationPending", function()
      -- Positive: a matching unexecuted operation exists
      it("should return true when a matching unexecuted operation exists", function()
        local operationBatches = {
          makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/2" } }) } }),
        }

        assert.is_true(OperationScheduler.isOperationPending(operationBatches, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: the matching operation is already executed
      it("should return false when the matching operation is already executed", function()
        local operationBatches = {
          makeOperationBatch({
            operations = { makeOperation({ executed = true, template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_false(OperationScheduler.isOperationPending(operationBatches, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: the operation type differs
      it("should return false when the operation type differs", function()
        local operationBatches = {
          makeOperationBatch({
            operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_false(OperationScheduler.isOperationPending(operationBatches, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Negative: no operation name matches
      it("should return false when no operation name matches", function()
        local operationBatches = {
          makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/1" } }) } }),
        }

        assert.is_false(OperationScheduler.isOperationPending(operationBatches, "GND/STRIKE/C2/N/2", "air"))
      end)

      -- Positive: executed prior wave plus pending next wave across separate entries
      it("should find a pending operation across multiple batches", function()
        local operationBatches = {
          makeOperationBatch({
            executed = true,
            operations = { makeOperation({ type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }) }
          }),
          makeOperationBatch({
            operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) }
          }),
        }

        assert.is_true(OperationScheduler.isOperationPending(operationBatches, "GND/STRIKE/C2/N/2", "ground"))
      end)

      -- Boundary: empty operationBatches
      it("should return false for an empty batch list", function()
        assert.is_false(OperationScheduler.isOperationPending({}, "GND/STRIKE/C2/N/2", "air"))
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("AIR/STRIKE/AB/W/2", nextOperation.template.name)
        assert.are.equal("air", nextOperation.type)
        assert.is_false(nextOperation.executed)
        assert.is_false(nextOperation.template.isFirstWave)
        assert.are.equal(120, nextOperation.template.strikeInterval)
        -- The /2 template must replace the source's packages, not carry them forward
        assert.are.equal("NEW-BASE", nextOperation.template.packages[1].striker.baseGUID)
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("INFRASTRUCTURE/2", nextOperation.template.name)
        assert.are.equal("ground", nextOperation.type)
        assert.is_false(nextOperation.executed)
        assert.is_false(nextOperation.template.isFirstWave)
        assert.are.equal(60, nextOperation.template.strikeInterval)
        assert.are.equal("FST-2-NEW", nextOperation.template.fireSupportTasks[1].name)
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("STRIKE/AB/100", nextOperation.template.name)
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("AIR/STRIKE/AB/W/5", nextOperation.template.name)
        assert.are.equal(originalPackages, nextOperation.template.packages)
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("ANTISHIP/3", nextOperation.template.name)
        assert.are.equal(originalTasks, nextOperation.template.fireSupportTasks)
        assert.are.equal("REUSED_CURRENT", status)
      end)

      -- Negative: unparseable template name
      it("should return deep copy when template name is unparseable", function()
        local operation = makeOperation({
          type = "air",
          template = { name = "NO-NUMBER-SUFFIX" }
        })
        local config = { c = { packageTemplates = {} } }

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal("air", nextOperation.type)
        assert.is_not.equal(operation, nextOperation)
        assert.are.equal("PARSE_ERROR", status)
      end)

      -- Negative: unknown operation type
      it("should return deep copy for unknown operation type", function()
        local operation = makeOperation({
          type = "naval",
          template = { name = "BLOCKADE/1" }
        })
        local config = { c = { packageTemplates = {}, fireSupportTaskTemplates = {} } }

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.is_not.equal(operation, nextOperation)
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

        local nextOperation, status = OperationScheduler.generateNextOperation(operation, config)

        assert.are.equal(0, nextOperation.template.strikeInterval)
        assert.are.equal("FOUND_NEXT", status)
      end)
    end)
  end
end)
