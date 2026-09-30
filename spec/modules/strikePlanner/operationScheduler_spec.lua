-- OperationScheduler Unit Tests
local OperationScheduler = require("src.modules.strikePlanner.operationScheduler")
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
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
    -- The pre-insertion snapshot reads scenario time whenever a batch already exists
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
      Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00")))
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
        missileSystemType = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
      GND_STRIKE_C2_N_2 = { {
        name = "FST-C2-2",
        firingUnits = {},
        missileSystemType = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
    }
    return config
  end

  ---Create a minimal recon context.
  ---@param overrides? table
  ---@return SBJ__ReconContext
  local function makeReconContext(overrides)
    local reconCtx = { queue = {}, frontlineRedirected = false }
    if overrides then
      for k, v in pairs(overrides) do reconCtx[k] = v end
    end
    return reconCtx
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
  local function makeLacmContext(enabled)
    return { enabled = enabled or false, startTime = "2026-02-14 06:00:00" }
  end

  ---Create a reconnaissance queue processing context.
  ---@param config SBJ__Config Configuration data
  ---@param reconCtx SBJ__ReconContext Reconnaissance runtime context
  ---@param reconTriggeredOperationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
  ---@param lacmCtx SBJ__LACMContext LACM context data
  ---@param fireSupportOnHold? boolean Whether SRBM-driven mappings should be skipped
  ---@return SBJ__ReconQueueProcessingContext
  local function makeProcessingContext(config, reconCtx, reconTriggeredOperationBatches, lacmCtx,
                                       fireSupportOnHold)
    return {
      config = config,
      reconCtx = reconCtx,
      reconTriggeredOperationBatches = reconTriggeredOperationBatches,
      lacmCtx = lacmCtx,
      fireSupportOnHold = fireSupportOnHold == true
    }
  end

  ---Seed the batches with one already-executed wave so its series advances instead of opening.
  ---Any other mapping stays unscheduled and takes the first-wave path.
  ---@param operationBatches table[] Batches to seed; mutated
  ---@param templateName string Exact template name of the series, e.g. "GND/STRIKE/C2/N/1"
  ---@param operationType string Operation type of that series
  ---@param templateOverrides? table Extra template fields the next wave may inherit or reuse
  ---@return table # The operation the series will read as its latest executed wave
  local function addExecutedSeries(operationBatches, templateName, operationType, templateOverrides)
    local template = { name = templateName }
    for k, v in pairs(templateOverrides or {}) do template[k] = v end

    local executedOperation = {
      type = operationType,
      executed = true,
      template = template,
    }

    table.insert(operationBatches, {
      time = "2026-02-14 05:00:00",
      type = "satellite",
      delay = 0,
      executed = true,
      operations = { executedOperation },
    })

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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({
          type = "SIGINT",
          reconObjectiveId = "C2_EMITTER_TARGETING",
          endTime = "2026-02-14 09:30:00",
        })
      )

      -- Builders label rows with type@time; OperationBatch skips batches already executed
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
        { name = "AIR/STRIKE/AB/E/1", type = "air",   requiresLACM = true },
      }
      local operationBatches = {}
      -- C/1 has already executed, so its mapping advances instead of opening a wave
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/C/1", "ground")
      config.c.fireSupportTaskTemplates.GND_STRIKE_C2_C_2 = { {
        name = "FST-C2-C-2",
        firingUnits = {},
        missileSystemType = "",
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } }

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      -- Batch 1 is the seeded executed wave; the new batch lands behind it
      assert.are.equal(2, #operationBatches)
      assert.are.equal(2, #operationBatches[2].operations)

      local operationNames = {
        operationBatches[2].operations[1].template.name,
        operationBatches[2].operations[2].template.name,
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
        { name = "AIR/STRIKE/AB/W/1",      type = "air" },
      }
      config.c.packageTemplates.AIR_STRIKE_AB_W_1 = {
        { timeToReady = 5 * 60, name = "PKG-AB-W-1", target = { list = {}, contactAge = 0, minTargetCount = 1 } }
      }
      local operationBatches = {}

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), true),
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
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
      -- The seeded executed wave is load-bearing: without it the mapping falls through to the
      -- first-wave path and stops on a missing template, passing for the wrong reason.
      addExecutedSeries(operationBatches, "AIR/STRIKE/AB/E/1", "air")

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      -- Only the seeded batch remains; nothing was scheduled
      assert.are.equal(1, #operationBatches)
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasErrorCall("%[ERROR%].*operation=AIR/STRIKE/NOPE/1.*reason=template_not_found"))
    end)

    -- Negative: an operation type OperationType cannot resolve has no template field to fill.
    it("should reject a mapping with an unknown operation type", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "SEA/STRIKE/PORT/1", type = "naval" },
      }
      local operationBatches = {}

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(0, #operationBatches)
      assert.is_true(hasErrorCall("%[ERROR%].*reason=unknown_operation_type"))
    end)

    -- Positive: strikeInterval defaults come from the OperationType descriptor, per operation type.
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      local templatesByName = {}
      for _, operation in ipairs(operationBatches[1].operations) do
        templatesByName[operation.template.name] = operation.template
      end

      assert.are.equal(config.c.air.strikeInterval, templatesByName["AIR/STRIKE/AB/W/1"].strikeInterval)
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
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
        missileSystemType = "",
        target = { contactAge = 0, minTargetCount = 1, list = {} },
      } }
      local operationBatches = {}

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
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

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), true),
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
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground")

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      -- Pending /2 plus the seeded executed /1; no third batch was added
      assert.are.equal(2, #operationBatches)
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
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground")
      -- Without a /2 template the scheduler falls back to the already-executed /1
      config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_2 = nil

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      -- Pending copy plus the seeded executed wave; nothing new was queued
      assert.are.equal(2, #operationBatches)
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
      -- The executed /1 batch above is what the series advances from; without a /2
      -- template it can only reuse /1
      config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_2 = nil

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.are.equal(2, #operationBatches)
      assert.are.equal("GND/STRIKE/C2/N/1", operationBatches[2].operations[1].template.name)
    end)

    -- Regression: repeated recon completions must not stack identical pending waves.
    -- Runs the real query/buildNextOperation path; before the fix this reached 3.
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
          makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
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

      OperationScheduler.schedule(
        makeProcessingContext(
          config,
          makeReconContext({ frontlineRedirected = true }),
          operationBatches,
          makeLacmContext(true),
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
    it("should warn instead of scheduling when the latest wave name cannot be parsed", function()
      local config = makeConfig()
      local operationBatches = {}
      -- The series lookup accepts any tonumber-able suffix, but the wave parser only
      -- takes plain digits, so "1.5" wins as latest wave and then fails to parse.
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground")
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1.5", "ground")

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      -- Only the seeded batches remain; nothing was scheduled
      assert.are.equal(2, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "%[WARN%]"))
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=parse_error"))
      assert.is_false(hasErrorCall("."))
    end)

    -- Negative: a series whose type OperationType cannot resolve has no next template to look up
    it("should warn instead of scheduling when the executed series has an unknown type", function()
      local config = makeConfig()
      config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = {
        { name = "SEA/STRIKE/PORT/1", type = "naval" },
      }
      local operationBatches = {}
      -- Already scheduled, so the mapping advances instead of failing on the first-wave path
      addExecutedSeries(operationBatches, "SEA/STRIKE/PORT/1", "naval")

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
      )

      assert.are.equal(1, #operationBatches)
      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "%[WARN%].*reason=unknown_type"))
      assert.is_false(hasErrorCall("."))
    end)

    -- Positive: the domain status is lowercased into the status field
    it("should emit the next operation status as a snake_case token", function()
      local config = makeConfig()
      local operationBatches = {}
      addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground")

      OperationScheduler.schedule(
        makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
        makeReconEntry({ type = "UAV", reconObjectiveId = "C2_NORTH_TARGETING" })
      )

      assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "status=found_next"))
    end)

    -- ============================================================================
    -- Abandoned operations (builders drop what they gave up on)
    -- ============================================================================
    --
    -- These run against real batches instead of stubbed queries: the whole point is
    -- that removing an operation is what lets the scheduler re-open its wave, and a
    -- stubbed OperationBatch.isScheduled would hide exactly that.

    describe("abandoned operations", function()
      ---Create a batch holding one already-executed wave of the C2 series.
      ---@param waveNumber integer
      ---@param time string
      ---@return table
      local function makeExecutedWaveBatch(waveNumber, time)
        return {
          time = time,
          type = "satellite",
          delay = 0,
          executed = true,
          operations = {
            {
              type = "ground",
              executed = true,
              template = { name = "GND/STRIKE/C2/N/" .. waveNumber, fireSupportTasks = {} }
            }
          }
        }
      end

      ---Run one scheduling pass for the C2 north mapping.
      ---@param config SBJ__Config
      ---@param operationBatches table[]
      local function schedule(config, operationBatches)
        OperationScheduler.schedule(
          makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(false), false),
          makeReconEntry({ reconObjectiveId = "C2_NORTH_TARGETING" })
        )
      end

      ---Drop every due ground operation the way a builder does when it gives up on it.
      ---Runs the real OperationBatch tick with a terminal outcome so the removal path is the
      ---production one, not a hand-rolled table.remove.
      ---@param operationBatches table[]
      local function abandonPendingGroundOperations(operationBatches)
        OperationBatch.process(operationBatches, "ground", {
          currentTime = Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00"),
          windowSec = 3600,
          retryableReasonSet = {},
          tryInsert = function()
            return { success = false, tag = "FAIL", reason = "no_valid_tasks" }
          end
        })
      end

      -- Positive: a first wave that was given up on is opened again from config
      it("should re-open the first wave after it is abandoned", function()
        local config = makeConfig()
        local operationBatches = {}

        schedule(config, operationBatches)
        assert.are.equal(1, #operationBatches)
        local firstWave = operationBatches[1].operations[1]
        assert.are.equal("GND/STRIKE/C2/N/1", firstWave.template.name)

        abandonPendingGroundOperations(operationBatches)

        schedule(config, operationBatches)

        assert.are.equal(2, #operationBatches)
        assert.are.equal("GND/STRIKE/C2/N/1", operationBatches[2].operations[1].template.name)
      end)

      -- Negative: an operation still observing must not be queued a second time
      it("should not re-open the first wave while it is still pending", function()
        local config = makeConfig()
        local operationBatches = {}

        schedule(config, operationBatches)
        schedule(config, operationBatches)

        -- The pending wave has no executed predecessor to advance from, and it is
        -- already scheduled, so this pass produces nothing at all.
        assert.are.equal(1, #operationBatches)
        assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "reason=no_executed_predecessor"))
      end)

      -- Positive: abandoning wave 3 regenerates wave 3, it does not advance to wave 4
      it("should regenerate the same wave after a follow-on wave is abandoned", function()
        local config = makeConfig()
        config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_3 = { {
          name = "FST-C2-3",
          firingUnits = {},
          missileSystemType = "",
          target = { list = {}, contactAge = 0, minTargetCount = 1 },
        } }

        local operationBatches = {
          makeExecutedWaveBatch(1, "2026-02-14 06:00:00"),
          makeExecutedWaveBatch(2, "2026-02-14 07:00:00")
        }

        schedule(config, operationBatches)
        assert.are.equal(3, #operationBatches)
        local thirdWave = operationBatches[3].operations[1]
        assert.are.equal("GND/STRIKE/C2/N/3", thirdWave.template.name)

        abandonPendingGroundOperations(operationBatches)

        schedule(config, operationBatches)

        assert.are.equal(4, #operationBatches)
        -- Wave 2 is still the latest executed wave, so the series retries wave 3
        assert.are.equal("GND/STRIKE/C2/N/3", operationBatches[4].operations[1].template.name)
      end)
    end)

    -- ============================================================================
    -- Next wave generation
    -- ============================================================================

    describe("next wave generation", function()
      ---Schedule one mapping against batches already holding its executed series.
      ---@param config SBJ__Config
      ---@param operationBatches table[]
      ---@param strikeMapping table
      ---@return table|nil # The operation queued by this pass, or nil when none was
      local function scheduleNextWave(config, operationBatches, strikeMapping)
        config.c.recon.strikeMappingsByReconObjective.FIXED_SITE_TARGETING = { strikeMapping }
        local batchCountBefore = #operationBatches

        OperationScheduler.schedule(
          makeProcessingContext(config, makeReconContext(), operationBatches, makeLacmContext(true), false),
          makeReconEntry({ reconObjectiveId = "FIXED_SITE_TARGETING" })
        )

        if #operationBatches == batchCountBefore then
          return nil
        end
        return operationBatches[#operationBatches].operations[1]
      end

      -- Positive: finds next air template
      it("should queue the next air wave from its own template", function()
        local config = makeConfig()
        local template = { { striker = { baseGUID = "NEW-BASE" } } }
        config.c.packageTemplates.AIR_STRIKE_AB_W_2 = template
        local operationBatches = {}
        addExecutedSeries(operationBatches, "AIR/STRIKE/AB/W/1", "air", {
          isFirstWave = true,
          strikeInterval = 120,
          packages = { { striker = {} } }
        })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "AIR/STRIKE/AB/W/1", type = "air" })

        assert(nextOperation ~= nil)
        assert.are.equal("AIR/STRIKE/AB/W/2", nextOperation.template.name)
        assert.are.equal("air", nextOperation.type)
        assert.is_false(nextOperation.executed)
        assert.is_false(nextOperation.template.isFirstWave)
        assert.are.equal(120, nextOperation.template.strikeInterval)
        -- The /2 template must replace the source's packages, not carry them forward
        assert.are.equal("NEW-BASE", nextOperation.template.packages[1].striker.baseGUID)
      end)

      -- Positive: finds next ground template
      it("should queue the next ground wave from its own template", function()
        local config = makeConfig()
        local template = { { name = "FST-2-NEW" } }
        config.c.fireSupportTaskTemplates.GND_STRIKE_C2_N_2 = template
        local operationBatches = {}
        addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground", {
          strikeInterval = 60,
          fireSupportTasks = { { name = "FST-1" } }
        })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "GND/STRIKE/C2/N/1", type = "ground" })

        assert(nextOperation ~= nil)
        assert.are.equal("GND/STRIKE/C2/N/2", nextOperation.template.name)
        assert.are.equal("ground", nextOperation.type)
        assert.is_false(nextOperation.executed)
        assert.is_false(nextOperation.template.isFirstWave)
        assert.are.equal(60, nextOperation.template.strikeInterval)
        assert.are.equal("FST-2-NEW", nextOperation.template.fireSupportTasks[1].name)
      end)

      -- Positive: handles multi-digit numbers
      it("should increment a multi-digit wave number", function()
        local config = makeConfig()
        local template = { { striker = {} } }
        config.c.packageTemplates.AIR_STRIKE_AB_W_100 = template
        local operationBatches = {}
        addExecutedSeries(operationBatches, "AIR/STRIKE/AB/W/99", "air", { packages = {} })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "AIR/STRIKE/AB/W/99", type = "air" })

        assert(nextOperation ~= nil)
        assert.are.equal("AIR/STRIKE/AB/W/100", nextOperation.template.name)
      end)

      -- Negative: reuses current air template when next not found
      it("should reuse the executed air wave's packages when no next template exists", function()
        local config = makeConfig()
        local originalPackages = { { striker = { baseGUID = "BASE-1" } } }
        local operationBatches = {}
        addExecutedSeries(operationBatches, "AIR/STRIKE/AB/W/5", "air", {
          isFirstWave = true,
          strikeInterval = 90,
          packages = originalPackages
        })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "AIR/STRIKE/AB/W/5", type = "air" })

        assert(nextOperation ~= nil)
        assert.are.equal("AIR/STRIKE/AB/W/5", nextOperation.template.name)
        assert.are.equal(originalPackages, nextOperation.template.packages)
        assert.is_true(hasLogCall(constants.TAGS.DYNAMIC_OPERATIONS, "status=reused_current"))
      end)

      -- Negative: reuses current ground template when next not found
      it("should reuse the executed ground wave's tasks when no next template exists", function()
        local config = makeConfig()
        local originalTasks = { { name = "FST-ORIGINAL" } }
        local operationBatches = {}
        addExecutedSeries(operationBatches, "GND/STRIKE/ANTISHIP/3", "ground", {
          strikeInterval = 0,
          fireSupportTasks = originalTasks
        })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "GND/STRIKE/ANTISHIP/3", type = "ground" })

        assert(nextOperation ~= nil)
        assert.are.equal("GND/STRIKE/ANTISHIP/3", nextOperation.template.name)
        assert.are.equal(originalTasks, nextOperation.template.fireSupportTasks)
      end)

      -- Boundary: nil strikeInterval defaults to 0 for ground
      it("should default a ground wave's strikeInterval to 0 when the executed wave has none", function()
        local config = makeConfig()
        local operationBatches = {}
        addExecutedSeries(operationBatches, "GND/STRIKE/C2/N/1", "ground", { fireSupportTasks = {} })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "GND/STRIKE/C2/N/1", type = "ground" })

        assert(nextOperation ~= nil)
        assert.are.equal("GND/STRIKE/C2/N/2", nextOperation.template.name)
        assert.are.equal(0, nextOperation.template.strikeInterval)
      end)

      -- Boundary: nil strikeInterval falls back to the configured interval for air
      it("should default an air wave's strikeInterval to the configured interval", function()
        local config = makeConfig()
        local template = { { striker = {} } }
        config.c.air.strikeInterval = 45
        config.c.packageTemplates.AIR_STRIKE_AB_W_2 = template
        local operationBatches = {}
        addExecutedSeries(operationBatches, "AIR/STRIKE/AB/W/1", "air", { packages = {} })

        local nextOperation = scheduleNextWave(config, operationBatches,
          { name = "AIR/STRIKE/AB/W/1", type = "air" })

        assert(nextOperation ~= nil)
        assert.are.equal(45, nextOperation.template.strikeInterval)
      end)
    end)
  end)
end)
