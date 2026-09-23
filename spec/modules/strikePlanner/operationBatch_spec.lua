-- OperationBatch Unit Tests
local OperationBatch = require("src.modules.strikePlanner.operationBatch")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

describe("OperationBatch", function()
  local activeStubs

  ---Track and register test stub for automatic cleanup.
  ---@param stubObject any
  ---@return luassert.spy
  local function trackStub(stubObject)
    table.insert(activeStubs, stubObject)
    return stubObject
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

  local BATCH_TIME = "2026-02-14 08:00:00"
  local TRIGGER_TIME = Utils.parseDatetimeToTimestamp(BATCH_TIME)
  local WINDOW_SEC = 1800

  ---Create a single operation
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

  ---Create a reconnaissance-triggered operation batch
  ---@param overrides? table
  ---@return table
  local function makeOperationBatch(overrides)
    local batch = {
      time = BATCH_TIME,
      type = "satellite",
      delay = 0,
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

  ---Build run params whose tryInsert always answers with the given outcome
  ---@param outcome table Outcome handed back for every operation
  ---@param overrides? table Params fields to override
  ---@return table params
  ---@return table tryInsertCalls Batched operations tryInsert was called with, in order
  local function makeRunParams(outcome, overrides)
    local tryInsertCalls = {}
    local params = {
      currentTime = TRIGGER_TIME,
      windowSec = WINDOW_SEC,
      retryableReasonSet = { retry_me = true },
      tryInsert = function(batchedOp)
        table.insert(tryInsertCalls, batchedOp)
        return outcome
      end
    }
    if overrides then
      for k, v in pairs(overrides) do params[k] = v end
    end
    return params, tryInsertCalls
  end

  local SUCCESS_OUTCOME = { success = true, tag = "OK", fields = { packages = "1/1" } }
  local RETRYABLE_OUTCOME = { success = false, tag = "SKIP", reason = "retry_me", fields = { targets = 0 } }
  local TERMINAL_OUTCOME = { success = false, tag = "FAIL", reason = "give_up" }

  -- ============================================================================
  -- add
  -- ============================================================================

  describe("add", function()
    -- Positive: the batch carries the recon entry's identity for the builders
    it("should append a batch stamped with the entry's end time and type", function()
      local batches = {}
      local operations = { makeOperation() }

      OperationBatch.add(batches, { type = "SIGINT", endTime = "2026-02-14 09:30:00" }, operations)

      assert.are.equal(1, #batches)
      assert.are.equal("2026-02-14 09:30:00", batches[1].time)
      assert.are.equal("SIGINT", batches[1].type)
      assert.are.equal(0, batches[1].delay)
      assert.is_false(batches[1].executed)
      assert.are.equal(operations, batches[1].operations)
    end)

    -- Positive: batches accumulate in insertion order
    it("should keep earlier batches in place", function()
      local first = makeOperationBatch()
      local batches = { first }

      OperationBatch.add(batches, { type = "UAV", endTime = "2026-02-14 10:00:00" }, {})

      assert.are.equal(2, #batches)
      assert.are.equal(first, batches[1])
    end)
  end)

  -- ============================================================================
  -- run: selection
  -- ============================================================================

  describe("run selection", function()
    -- Positive: only unexecuted operations of the requested type are attempted
    it("should hand only unexecuted operations of the requested type to tryInsert", function()
      local airOp = makeOperation({ type = "air" })
      local groundOp = makeOperation({ type = "ground" })
      local doneOp = makeOperation({ type = "air", executed = true })
      local batch = makeOperationBatch({ operations = { airOp, groundOp, doneOp } })
      local params, calls = makeRunParams(RETRYABLE_OUTCOME)

      OperationBatch.run({ batch }, "air", params)

      assert.are.equal(1, #calls)
      assert.are.equal(airOp, calls[1].operation)
      assert.are.equal(batch, calls[1].operationBatch)
    end)

    -- Negative: a closed batch is never scanned again
    it("should skip batches already marked executed", function()
      local batch = makeOperationBatch({ executed = true })
      local params, calls = makeRunParams(SUCCESS_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(0, #calls)
      assert.are.equal(0, #result.entries)
      assert.is_false(result.hasExecutedAny)
    end)

    -- Negative: batches without an operations array are tolerated
    it("should skip batches with nil operations", function()
      local batch = makeOperationBatch()
      batch.operations = nil
      local params, calls = makeRunParams(SUCCESS_OUTCOME)

      OperationBatch.run({ batch }, "air", params)

      assert.are.equal(0, #calls)
    end)

    -- Positive: operations are collected across batches
    it("should attempt operations across multiple batches", function()
      local batches = {
        makeOperationBatch({ operations = { makeOperation() } }),
        makeOperationBatch({ operations = { makeOperation(), makeOperation() } }),
      }
      local params, calls = makeRunParams(RETRYABLE_OUTCOME)

      local result = OperationBatch.run(batches, "air", params)

      assert.are.equal(3, #calls)
      assert.are.equal(3, #result.entries)
    end)

    -- Boundary: empty batch list
    it("should return an empty result for an empty batch list", function()
      local params, calls = makeRunParams(SUCCESS_OUTCOME)

      local result = OperationBatch.run({}, "air", params)

      assert.are.equal(0, #calls)
      assert.are.equal(0, #result.entries)
      assert.is_false(result.hasExecutedAny)
    end)
  end)

  -- ============================================================================
  -- run: observation window
  -- ============================================================================

  describe("run observation window", function()
    -- Negative: not due yet, no attempt and no entry
    it("should skip silently before the trigger time", function()
      local batch = makeOperationBatch()
      local params, calls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME - 1 })

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(0, #calls)
      assert.are.equal(0, #result.entries)
      assert.is_false(batch.operations[1].executed)
    end)

    -- Boundary: the window opens exactly at the trigger time
    it("should attempt exactly at the trigger time", function()
      local params, calls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME })

      OperationBatch.run({ makeOperationBatch() }, "air", params)

      assert.are.equal(1, #calls)
    end)

    -- Boundary: the last second of the window still counts as open
    it("should attempt exactly at the window deadline", function()
      local params, calls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME + WINDOW_SEC })

      OperationBatch.run({ makeOperationBatch() }, "air", params)

      assert.are.equal(1, #calls)
    end)

    -- Boundary: one second past the deadline expires the operation
    it("should expire and abandon one second past the window deadline", function()
      local operation = makeOperation()
      local batch = makeOperationBatch({ operations = { operation } })
      local params, calls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME + WINDOW_SEC + 1 })

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(0, #calls)
      assert.are.equal(1, #result.entries)
      assert.are.equal("WARN", result.entries[1].tag)
      assert.are.equal("observation_window_expired", result.entries[1].fields.reason)
      assert.are.equal("abandoned", result.entries[1].fields.state)
      assert.are.equal(0, #batch.operations)
      assert.is_true(batch.executed)
      assert.is_false(result.hasExecutedAny)
    end)

    -- Positive: the batch delay pushes the whole window back
    it("should shift the window by the batch delay", function()
      local batch = makeOperationBatch({ delay = 600 })

      local early, earlyCalls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME + 599 })
      OperationBatch.run({ batch }, "air", early)
      assert.are.equal(0, #earlyCalls)

      local due, dueCalls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME + 600 })
      OperationBatch.run({ batch }, "air", due)
      assert.are.equal(1, #dueCalls)
    end)

    -- Boundary: a batch authored without a delay is treated as zero delay
    it("should treat a missing delay as zero", function()
      local batch = makeOperationBatch()
      batch.delay = nil
      local params, calls = makeRunParams(SUCCESS_OUTCOME, { currentTime = TRIGGER_TIME })

      OperationBatch.run({ batch }, "air", params)

      assert.are.equal(1, #calls)
    end)
  end)

  -- ============================================================================
  -- run: outcome policy
  -- ============================================================================

  describe("run outcome policy", function()
    -- Positive: success marks the operation executed and reports it
    it("should mark the operation executed on success", function()
      local operation = makeOperation()
      local batch = makeOperationBatch({ operations = { operation } })
      local params = makeRunParams(SUCCESS_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.is_true(operation.executed)
      assert.is_true(result.hasExecutedAny)
      assert.are.equal("OK", result.entries[1].tag)
      assert.is_nil(result.entries[1].fields.state)
      assert.are.equal(SUCCESS_OUTCOME, result.entries[1].outcome)
    end)

    -- Positive: the batch closes once its last operation executes
    it("should close the batch when all operations have executed", function()
      local batch = makeOperationBatch({
        operations = { makeOperation({ executed = true }), makeOperation() }
      })
      local params = makeRunParams(SUCCESS_OUTCOME)

      OperationBatch.run({ batch }, "air", params)

      assert.is_true(batch.executed)
    end)

    -- Negative: the batch stays open while other operations remain
    it("should keep the batch open while another operation is still pending", function()
      local batch = makeOperationBatch({
        operations = { makeOperation(), makeOperation({ type = "ground" }) }
      })
      local params = makeRunParams(SUCCESS_OUTCOME)

      OperationBatch.run({ batch }, "air", params)

      assert.is_true(batch.operations[1].executed)
      assert.is_false(batch.executed)
    end)

    -- Positive: a retryable reason keeps the operation in place for the next tick
    it("should keep a retryable operation pending and report it as observing", function()
      local operation = makeOperation()
      local batch = makeOperationBatch({ operations = { operation } })
      local params = makeRunParams(RETRYABLE_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.is_false(operation.executed)
      assert.are.equal(1, #batch.operations)
      assert.is_false(batch.executed)
      assert.is_false(result.hasExecutedAny)
      assert.are.equal("SKIP", result.entries[1].tag)
      assert.are.equal("observing", result.entries[1].fields.state)
      assert.are.equal("retry_me", result.entries[1].fields.reason)
    end)

    -- Negative: a terminal reason drops the operation from its batch
    it("should abandon an operation with a non-retryable reason", function()
      local operation = makeOperation()
      local sibling = makeOperation({ type = "ground" })
      local batch = makeOperationBatch({ operations = { operation, sibling } })
      local params = makeRunParams(TERMINAL_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(1, #batch.operations)
      assert.are.equal(sibling, batch.operations[1])
      assert.is_false(batch.executed)
      assert.are.equal("abandoned", result.entries[1].fields.state)
      assert.are.equal("give_up", result.entries[1].fields.reason)
    end)

    -- Negative: an outcome without a reason is treated as terminal
    it("should abandon an operation whose failure carries no reason", function()
      local batch = makeOperationBatch()
      local params = makeRunParams({ success = false, tag = "FAIL" })

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(0, #batch.operations)
      assert.are.equal("abandoned", result.entries[1].fields.state)
      assert.is_nil(result.entries[1].fields.reason)
    end)

    -- Positive: several operations of one batch can be abandoned in the same pass
    it("should remove every abandoned operation when a whole batch fails in one pass", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local op3 = makeOperation()
      local batch = makeOperationBatch({ operations = { op1, op2, op3 } })
      local params = makeRunParams(TERMINAL_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal(3, #result.entries)
      assert.are.equal(0, #batch.operations)
      assert.is_true(batch.executed)
    end)

    -- Positive: identical-looking siblings are told apart by identity
    it("should remove only the failed operation when siblings look identical", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local batch = makeOperationBatch({ operations = { op1, op2 } })
      local outcomes = { TERMINAL_OUTCOME, RETRYABLE_OUTCOME }
      local callIndex = 0
      local params = makeRunParams(nil, {
        tryInsert = function()
          callIndex = callIndex + 1
          return outcomes[callIndex]
        end
      })

      OperationBatch.run({ batch }, "air", params)

      assert.are.equal(1, #batch.operations)
      assert.are.equal(op2, batch.operations[1])
    end)

    -- Positive: mixed outcomes are reported per operation in order
    it("should report each operation's outcome in batch order", function()
      local batch = makeOperationBatch({ operations = { makeOperation(), makeOperation(), makeOperation() } })
      local outcomes = { SUCCESS_OUTCOME, RETRYABLE_OUTCOME, TERMINAL_OUTCOME }
      local callIndex = 0
      local params = makeRunParams(nil, {
        tryInsert = function()
          callIndex = callIndex + 1
          return outcomes[callIndex]
        end
      })

      local result = OperationBatch.run({ batch }, "air", params)

      assert.is_true(result.hasExecutedAny)
      assert.are.equal("OK", result.entries[1].tag)
      assert.are.equal("observing", result.entries[2].fields.state)
      assert.are.equal("abandoned", result.entries[3].fields.state)
    end)
  end)

  -- ============================================================================
  -- run: entry fields
  -- ============================================================================

  describe("run entry fields", function()
    -- Positive: identity columns and outcome counters land in one row
    it("should merge operation identity with the outcome fields", function()
      local batch = makeOperationBatch({ type = "UAV", time = BATCH_TIME })
      local params = makeRunParams(SUCCESS_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      local fields = result.entries[1].fields
      assert.are.equal("AIR/STRIKE/AB/W/1", fields.operation)
      assert.are.equal("UAV@" .. BATCH_TIME, fields.batch)
      assert.are.equal("1/1", fields.packages)
    end)

    -- Boundary: an operation without a template still gets a row
    it("should label a template-less operation as unknown", function()
      local operation = makeOperation()
      operation.template = nil
      local batch = makeOperationBatch({ operations = { operation } })
      local params = makeRunParams(TERMINAL_OUTCOME)

      local result = OperationBatch.run({ batch }, "air", params)

      assert.are.equal("unknown", result.entries[1].fields.operation)
    end)

    -- Negative: the outcome's own fields table is not mutated
    it("should not write state or identity into the outcome's fields table", function()
      local outcome = { success = false, tag = "SKIP", reason = "retry_me", fields = { targets = 0 } }
      local params = makeRunParams(outcome)

      OperationBatch.run({ makeOperationBatch() }, "air", params)

      assert.is_nil(outcome.fields.state)
      assert.is_nil(outcome.fields.operation)
    end)
  end)

  -- ============================================================================
  -- findMostRecentSnapshot
  -- ============================================================================

  describe("findMostRecentSnapshot", function()
    -- Positive: finds most recent past batch and classifies operations
    it("should find most recent past batch and classify operations", function()
      local airOperation = makeOperation({ type = "air" })
      local groundOperation = makeOperation({ type = "ground" })
      local batches = {
        makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { makeOperation({ type = "air" }) } }),
        makeOperationBatch({ time = "2026-02-14 08:00:00", operations = { airOperation, groundOperation } }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.are.equal(1, #snapshot.air)
      assert.are.equal(1, #snapshot.ground)
      assert.are.equal(airOperation, snapshot.air[1])
      assert.are.equal(groundOperation, snapshot.ground[1])
      assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
    end)

    -- Positive: finds next batch time from future batches
    it("should find next batch time from future batches", function()
      local batches = {
        makeOperationBatch({ time = "2026-02-14 06:00:00" }),
        makeOperationBatch({ time = "2026-02-14 12:00:00" }),
        makeOperationBatch({ time = "2026-02-14 18:00:00" }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.are.equal("2026-02-14 12:00:00", snapshot.nextOperationBatchTime)
      assert.are.equal("2026-02-14 06:00:00", snapshot.mostRecentTime)
    end)

    -- Positive: picks latest past batch from unordered batches
    it("should pick latest past batch when batches are not in time order", function()
      local laterOperation = makeOperation({ type = "air" })
      local batches = {
        makeOperationBatch({ time = "2026-02-14 10:00:00", operations = { laterOperation } }),
        makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { makeOperation() } }),
        makeOperationBatch({ time = "2026-02-14 08:00:00", operations = { makeOperation() } }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 12:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.are.equal(1, #snapshot.air)
      assert.are.equal(laterOperation, snapshot.air[1])
      assert.are.equal("2026-02-14 10:00:00", snapshot.mostRecentTime)
    end)

    -- Positive: picks earliest future batch as nextOperationBatchTime
    it("should pick earliest future batch as nextOperationBatchTime when batches are unordered", function()
      local batches = {
        makeOperationBatch({ time = "2026-02-14 18:00:00" }),
        makeOperationBatch({ time = "2026-02-14 14:00:00" }),
        makeOperationBatch({ time = "2026-02-14 06:00:00" }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.are.equal("2026-02-14 14:00:00", snapshot.nextOperationBatchTime)
      assert.are.equal("2026-02-14 06:00:00", snapshot.mostRecentTime)
    end)

    -- Negative: empty batches
    it("should return empty snapshot for an empty batch list", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

      local snapshot = OperationBatch.findMostRecentSnapshot({})

      assert.are.equal(0, #snapshot.air)
      assert.are.equal(0, #snapshot.ground)
      assert.is_nil(snapshot.nextOperationBatchTime)
      assert.is_nil(snapshot.mostRecentTime)
    end)

    -- Negative: GameApi returns nil
    it("should return empty snapshot when GameApi returns nil", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(nil))

      local snapshot = OperationBatch.findMostRecentSnapshot({ makeOperationBatch() })

      assert.are.equal(0, #snapshot.air)
      assert.are.equal(0, #snapshot.ground)
      assert.is_nil(snapshot.mostRecentTime)
    end)

    -- Boundary: all batches in future
    it("should return no operations but a nextOperationBatchTime when all batches are in the future", function()
      local batches = {
        makeOperationBatch({ time = "2026-02-14 12:00:00" }),
        makeOperationBatch({ time = "2026-02-14 18:00:00" }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 06:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.are.equal(0, #snapshot.air)
      assert.are.equal(0, #snapshot.ground)
      assert.are.equal("2026-02-14 12:00:00", snapshot.nextOperationBatchTime)
      assert.is_nil(snapshot.mostRecentTime)
    end)

    -- Boundary: all batches in past
    it("should return no nextOperationBatchTime when all batches are in the past", function()
      local batches = {
        makeOperationBatch({ time = "2026-02-14 06:00:00" }),
        makeOperationBatch({ time = "2026-02-14 08:00:00" }),
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 20:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot(batches)

      assert.is_nil(snapshot.nextOperationBatchTime)
      assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
    end)

    -- Boundary: batch with nil operations
    it("should handle a batch with nil operations", function()
      local batch = makeOperationBatch({ time = "2026-02-14 08:00:00" })
      batch.operations = nil
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local snapshot = OperationBatch.findMostRecentSnapshot({ batch })

      assert.are.equal(0, #snapshot.air)
      assert.are.equal(0, #snapshot.ground)
      assert.are.equal("2026-02-14 08:00:00", snapshot.mostRecentTime)
    end)

    -- Boundary: batch at exactly current time counts as past
    it("should treat a batch at exactly current time as past", function()
      local operation = makeOperation({ type = "ground" })
      local exactTime = "2026-02-14 08:00:00"
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(Utils.parseDatetimeToTimestamp(exactTime)))

      local snapshot = OperationBatch.findMostRecentSnapshot({
        makeOperationBatch({ time = exactTime, operations = { operation } }),
      })

      assert.are.equal(1, #snapshot.ground)
    end)
  end)

  -- ============================================================================
  -- isScheduled
  -- ============================================================================

  describe("isScheduled", function()
    -- Positive: exact match
    it("should find exact match by template name and type", function()
      local operation = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
      local batch = makeOperationBatch({ operations = { operation } })

      assert.is_true(OperationBatch.isScheduled({ batch }, "AIR/STRIKE/AB/W/1", "air"))
    end)

    -- Positive: searches across multiple batches
    it("should search across multiple batches and operations", function()
      local targetOperation = makeOperation({ type = "ground", template = { name = "INFRA/2" } })
      local batches = {
        makeOperationBatch({ operations = { makeOperation({ type = "air", template = { name = "STRIKE/1" } }) } }),
        makeOperationBatch({
          time = "2026-02-14 10:00:00",
          operations = { makeOperation({ type = "air", template = { name = "SEAD/1" } }), targetOperation }
        }),
      }

      assert.is_true(OperationBatch.isScheduled(batches, "INFRA/2", "ground"))
    end)

    -- Negative: type mismatch
    it("should not match when type differs", function()
      local operation = makeOperation({ type = "ground", template = { name = "AIR/STRIKE/AB/W/1" } })

      assert.is_false(OperationBatch.isScheduled({ makeOperationBatch({ operations = { operation } }) }, "AIR/STRIKE/AB/W/1", "air"))
    end)

    -- Negative: name mismatch
    it("should not match when name differs", function()
      local operation = makeOperation({ type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })

      assert.is_false(OperationBatch.isScheduled({ makeOperationBatch({ operations = { operation } }) }, "AIR/STRIKE/AB/W/2", "air"))
    end)

    -- Negative: nil template
    it("should skip operations with nil template", function()
      local operation = makeOperation()
      operation.template = nil

      assert.is_false(OperationBatch.isScheduled({ makeOperationBatch({ operations = { operation } }) }, "STRIKE/1", "air"))
    end)

    -- Negative: nil operations
    it("should skip batches with nil operations", function()
      local batch = makeOperationBatch()
      batch.operations = nil

      assert.is_false(OperationBatch.isScheduled({ batch }, "STRIKE/1", "air"))
    end)

    -- Boundary: an unexecuted operation still counts as scheduled
    it("should count an unexecuted operation as scheduled", function()
      local pendingOperation = makeOperation({
        executed = false, type = "ground", template = { name = "GND/STRIKE/INFRA/ALL/1" },
      })

      assert.is_true(OperationBatch.isScheduled(
        { makeOperationBatch({ operations = { pendingOperation } }) }, "GND/STRIKE/INFRA/ALL/1", "ground"))
    end)
  end)

  -- ============================================================================
  -- isPending
  -- ============================================================================

  describe("isPending", function()
    -- Positive: a matching unexecuted operation exists
    it("should return true when a matching unexecuted operation exists", function()
      local batches = {
        makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/2" } }) } }),
      }

      assert.is_true(OperationBatch.isPending(batches, "GND/STRIKE/C2/N/2", "air"))
    end)

    -- Negative: the matching operation is already executed
    it("should return false when the matching operation is already executed", function()
      local batches = {
        makeOperationBatch({ operations = { makeOperation({ executed = true, template = { name = "GND/STRIKE/C2/N/2" } }) } }),
      }

      assert.is_false(OperationBatch.isPending(batches, "GND/STRIKE/C2/N/2", "air"))
    end)

    -- Negative: the operation type differs
    it("should return false when the operation type differs", function()
      local batches = {
        makeOperationBatch({ operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) } }),
      }

      assert.is_false(OperationBatch.isPending(batches, "GND/STRIKE/C2/N/2", "air"))
    end)

    -- Negative: no operation name matches
    it("should return false when no operation name matches", function()
      local batches = {
        makeOperationBatch({ operations = { makeOperation({ template = { name = "GND/STRIKE/C2/N/1" } }) } }),
      }

      assert.is_false(OperationBatch.isPending(batches, "GND/STRIKE/C2/N/2", "air"))
    end)

    -- Positive: executed prior wave plus pending next wave across separate batches
    it("should find a pending operation across multiple batches", function()
      local batches = {
        makeOperationBatch({
          executed = true,
          operations = { makeOperation({ type = "ground", executed = true, template = { name = "GND/STRIKE/C2/N/1" } }) }
        }),
        makeOperationBatch({
          operations = { makeOperation({ type = "ground", template = { name = "GND/STRIKE/C2/N/2" } }) }
        }),
      }

      assert.is_true(OperationBatch.isPending(batches, "GND/STRIKE/C2/N/2", "ground"))
    end)

    -- Boundary: empty batches
    it("should return false for an empty batch list", function()
      assert.is_false(OperationBatch.isPending({}, "GND/STRIKE/C2/N/2", "air"))
    end)
  end)

  -- ============================================================================
  -- findLatestExecuted
  -- ============================================================================

  describe("findLatestExecuted", function()
    -- Positive: picks the highest wave number
    it("should find highest number with prefix search", function()
      local op1 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
      local op3 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/3" } })
      local op2 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })
      local batches = { makeOperationBatch({ operations = { op1, op3, op2 } }) }

      local found = OperationBatch.findLatestExecuted(batches, "AIR/STRIKE/AB/W/", "air")

      assert.are.equal(op3, found)
    end)

    -- Positive: ties on wave number fall back to the later batch
    it("should pick latest time when prefix search finds same max number", function()
      local olderOperation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })
      local newerOperation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/2" } })
      local batches = {
        makeOperationBatch({ time = "2026-02-14 06:00:00", operations = { olderOperation } }),
        makeOperationBatch({ time = "2026-02-14 12:00:00", operations = { newerOperation } }),
      }

      local found = OperationBatch.findLatestExecuted(batches, "AIR/STRIKE/AB/W/", "air")

      assert.are.equal(newerOperation, found)
    end)

    -- Negative: prefix search skips operations that are not yet executed
    it("should skip unexecuted operations in prefix search", function()
      local pendingOperation = makeOperation({ executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" } })

      local found = OperationBatch.findLatestExecuted({ makeOperationBatch({ operations = { pendingOperation } }) }, "AIR/STRIKE/AB/W/", "air")

      assert.is_nil(found)
    end)

    -- Positive: prefix search picks the highest executed number, ignoring unexecuted ones
    it("should ignore unexecuted higher-numbered ops and pick highest executed", function()
      local executedOp1 = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/1" } })
      local pendingOp3 = makeOperation({ executed = false, type = "air", template = { name = "AIR/STRIKE/AB/W/3" } })

      local found = OperationBatch.findLatestExecuted({ makeOperationBatch({ operations = { executedOp1, pendingOp3 } }) }, "AIR/STRIKE/AB/W/", "air")

      assert.are.equal(executedOp1, found)
    end)

    -- Negative: prefix search no matches
    it("should return nil for prefix search with no matches", function()
      local operation = makeOperation({ type = "air", template = { name = "SEAD/1" } })

      local found = OperationBatch.findLatestExecuted({ makeOperationBatch({ operations = { operation } }) }, "AIR/STRIKE/AB/W/", "air")

      assert.is_nil(found)
    end)

    -- Negative: prefix search ignores non-numeric suffix
    it("should ignore non-numeric suffix in prefix search", function()
      local operation = makeOperation({ executed = true, type = "air", template = { name = "AIR/STRIKE/AB/W/abc" } })

      local found = OperationBatch.findLatestExecuted({ makeOperationBatch({ operations = { operation } }) }, "AIR/STRIKE/AB/W/", "air")

      assert.is_nil(found)
    end)

    -- Negative: prefix search filters by type
    it("should filter by type in prefix search", function()
      local groundOperation = makeOperation({ executed = true, type = "ground", template = { name = "AIR/STRIKE/AB/W/5" } })

      local found = OperationBatch.findLatestExecuted({ makeOperationBatch({ operations = { groundOperation } }) }, "AIR/STRIKE/AB/W/", "air")

      assert.is_nil(found)
    end)
  end)
end)
