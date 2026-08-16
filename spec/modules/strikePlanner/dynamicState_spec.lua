-- DynamicState Unit Tests
local DynamicState = require("src.modules.strikePlanner.dynamicState")
local Utils = require("src.utils.utils")

describe("DynamicState", function()
  ---Create a single operation
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

  ---Create a reconnaissance-triggered operation batch
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

  ---Create minimal saveData with dynamicOperations structure
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        air = { airTaskingOrder = overrides.airTaskingOrder or {} },
        ground = { fireSupportPlan = overrides.fireSupportPlan or {} },
        dynamicOperations = {
          reconTriggeredOperationBatches = overrides.reconTriggeredOperationBatches or {},
          generatedOperations = overrides.generatedOperations or { air = {}, ground = {} }
        }
      }
    }
  end

  -- ============================================================================
  -- checkOperationBatchCompleted
  -- ============================================================================

  describe("checkOperationBatchCompleted", function()
    -- Positive: all operations executed
    it("should return true and set executed when all operations are executed", function()
      local entry = makeOperationBatch({
        operations = {
          makeOperation({ executed = true }),
          makeOperation({ executed = true, type = "ground" }),
        }
      })

      local result = DynamicState.checkOperationBatchCompleted(entry)

      assert.is_true(result)
      assert.is_true(entry.executed)
    end)

    -- Negative: some operations not executed
    it("should return false when some operations are not executed", function()
      local entry = makeOperationBatch({
        operations = {
          makeOperation({ executed = true }),
          makeOperation({ executed = false }),
        }
      })

      local result = DynamicState.checkOperationBatchCompleted(entry)

      assert.is_false(result)
      assert.is_false(entry.executed)
    end)

    -- Negative: single operation not executed
    it("should return false when single operation is not executed", function()
      local entry = makeOperationBatch({
        operations = { makeOperation({ executed = false }) }
      })

      assert.is_false(DynamicState.checkOperationBatchCompleted(entry))
    end)

    -- Boundary: nil operations
    it("should return true when operations is nil", function()
      local entry = makeOperationBatch()
      entry.operations = nil

      local result = DynamicState.checkOperationBatchCompleted(entry)

      assert.is_true(result)
    end)

    -- Boundary: empty operations
    it("should return true when operations is empty table", function()
      local entry = makeOperationBatch({ operations = {} })

      local result = DynamicState.checkOperationBatchCompleted(entry)

      assert.is_true(result)
      assert.is_true(entry.executed)
    end)
  end)

  -- ============================================================================
  -- updateReconTriggeredOperationStatus
  -- ============================================================================

  describe("updateReconTriggeredOperationStatus", function()
    -- Positive: marks completed entries
    it("should mark completed entries via checkOperationBatchCompleted", function()
      local entry = makeOperationBatch({
        operations = { makeOperation({ executed = true }) }
      })
      local saveData = makeSaveData({ reconTriggeredOperationBatches = { entry } })

      DynamicState.updateReconTriggeredOperationStatus(saveData)

      assert.is_true(entry.executed)
    end)

    -- Positive: skips already executed
    it("should skip already executed entries", function()
      local entry = makeOperationBatch({
        executed = true,
        operations = { makeOperation({ executed = false }) }
      })
      local saveData = makeSaveData({ reconTriggeredOperationBatches = { entry } })

      DynamicState.updateReconTriggeredOperationStatus(saveData)

      assert.is_true(entry.executed)
    end)

    -- Positive: processes multiple entries independently
    it("should process multiple entries independently", function()
      local entry1 = makeOperationBatch({
        operations = { makeOperation({ executed = true }) }
      })
      local entry2 = makeOperationBatch({
        operations = { makeOperation({ executed = false }) }
      })
      local saveData = makeSaveData({ reconTriggeredOperationBatches = { entry1, entry2 } })

      DynamicState.updateReconTriggeredOperationStatus(saveData)

      assert.is_true(entry1.executed)
      assert.is_false(entry2.executed)
    end)

    -- Boundary: nil dynamicOperations
    it("should not error when dynamicOperations is nil", function()
      local saveData = { c = {} }

      assert.has_no.error(function()
        DynamicState.updateReconTriggeredOperationStatus(saveData)
      end)
    end)

    -- Boundary: nil reconTriggeredOperationBatches
    it("should not error when reconTriggeredOperationBatches is nil", function()
      local saveData = { c = { dynamicOperations = {} } }

      assert.has_no.error(function()
        DynamicState.updateReconTriggeredOperationStatus(saveData)
      end)
    end)
  end)

  -- ============================================================================
  -- filterOperationsByType
  -- ============================================================================

  describe("filterOperationsByType", function()
    -- Positive: returns air operations
    it("should return air operations from non-executed entries", function()
      local airOp = makeOperation({ type = "air" })
      local groundOp = makeOperation({ type = "ground" })
      local schedule = {
        makeOperationBatch({ operations = { airOp, groundOp } })
      }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(1, #result)
      assert.are.equal(airOp, result[1].operation)
    end)

    -- Positive: returns ground operations
    it("should return ground operations from non-executed entries", function()
      local airOp = makeOperation({ type = "air" })
      local groundOp = makeOperation({ type = "ground" })
      local schedule = {
        makeOperationBatch({ operations = { airOp, groundOp } })
      }

      local result = DynamicState.filterOperationsByType(schedule, "ground")

      assert.are.equal(1, #result)
      assert.are.equal(groundOp, result[1].operation)
    end)

    -- Positive: includes parent reconEntry
    it("should include parent reconEntry in results", function()
      local entry = makeOperationBatch()
      local schedule = { entry }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(1, #result)
      assert.are.equal(entry, result[1].operationBatch)
    end)

    -- Positive: collects across multiple entries
    it("should collect operations across multiple entries", function()
      local schedule = {
        makeOperationBatch({ operations = { makeOperation({ type = "air" }) } }),
        makeOperationBatch({
          time = "2026-02-14 10:00:00",
          operations = { makeOperation({ type = "air" }), makeOperation({ type = "air" }) }
        }),
      }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(3, #result)
    end)

    -- Negative: skips executed reconEntries
    it("should skip executed reconEntries", function()
      local schedule = {
        makeOperationBatch({ executed = true })
      }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: skips executed operations
    it("should skip executed operations", function()
      local schedule = {
        makeOperationBatch({
          operations = { makeOperation({ executed = true }) }
        })
      }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: skips entries with nil operations
    it("should skip entries with nil operations", function()
      local entry = makeOperationBatch()
      entry.operations = nil
      local schedule = { entry }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: no type match
    it("should return empty when no operations match the type", function()
      local schedule = {
        makeOperationBatch({
          operations = { makeOperation({ type = "ground" }) }
        })
      }

      local result = DynamicState.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty schedule
    it("should return empty for empty schedule", function()
      local result = DynamicState.filterOperationsByType({}, "air")

      assert.are.equal(0, #result)
    end)
  end)

  -- ============================================================================
  -- markOperationExecuted
  -- ============================================================================

  describe("markOperationExecuted", function()
    -- Positive: marks the operation as executed
    it("should mark operation as executed", function()
      local op = makeOperation()
      local entry = makeOperationBatch({ operations = { op } })

      DynamicState.markOperationExecuted(entry, op)

      assert.is_true(op.executed)
    end)

    -- Positive: completes entry when all done
    it("should mark reconEntry as completed when all operations are now executed", function()
      local op1 = makeOperation({ executed = true })
      local op2 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      DynamicState.markOperationExecuted(entry, op2)

      assert.is_true(entry.executed)
    end)

    -- Negative: does not complete entry when others remain
    it("should not mark reconEntry as completed when other operations remain", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      DynamicState.markOperationExecuted(entry, op1)

      assert.is_false(entry.executed)
    end)
  end)

  -- ============================================================================
  -- abandonOperation
  -- ============================================================================

  describe("abandonOperation", function()
    -- Positive: the abandoned operation leaves the batch, the others stay put
    it("should remove the operation from its batch by identity", function()
      local op1 = makeOperation({ template = { name = "AIR/STRIKE/AB/W/1" } })
      local op2 = makeOperation({ template = { name = "AIR/STRIKE/AB/W/2" } })
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      assert.is_true(DynamicState.abandonOperation(entry, op1))

      assert.are.equal(1, #entry.operations)
      assert.are.equal(op2, entry.operations[1])
    end)

    -- Positive: an identical-looking sibling is not removed in its place
    it("should remove only the given operation when siblings look identical", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      DynamicState.abandonOperation(entry, op2)

      assert.are.equal(1, #entry.operations)
      assert.are.equal(op1, entry.operations[1])
    end)

    -- Positive: several operations of one batch can be abandoned in the same pass
    it("should keep removing correctly when the whole batch is abandoned in one pass", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local op3 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2, op3 } })

      DynamicState.abandonOperation(entry, op1)
      DynamicState.abandonOperation(entry, op3)

      assert.are.equal(1, #entry.operations)
      assert.are.equal(op2, entry.operations[1])
    end)

    -- Positive: emptying the batch closes it, so it stops being scanned
    it("should complete the batch when the last operation is abandoned", function()
      local op = makeOperation()
      local entry = makeOperationBatch({ operations = { op } })

      DynamicState.abandonOperation(entry, op)

      assert.are.equal(0, #entry.operations)
      assert.is_true(entry.executed)
    end)

    -- Negative: batch stays open while executed and pending operations remain
    it("should not complete the batch when a pending operation remains", function()
      local abandoned = makeOperation()
      local pending = makeOperation()
      local entry = makeOperationBatch({ operations = { abandoned, pending } })

      DynamicState.abandonOperation(entry, abandoned)

      assert.is_false(entry.executed)
    end)

    -- Negative: unknown operation
    it("should return false when the operation is not in the batch", function()
      local op = makeOperation()
      local entry = makeOperationBatch({ operations = { makeOperation() } })

      assert.is_false(DynamicState.abandonOperation(entry, op))
      assert.are.equal(1, #entry.operations)
    end)

    -- Negative: batch without an operations array
    it("should return false when the batch has no operations", function()
      local entry = makeOperationBatch({ operations = nil })

      assert.is_false(DynamicState.abandonOperation(entry, makeOperation()))
    end)
  end)

  -- ============================================================================
  -- evaluateObservationWindow
  -- ============================================================================

  describe("evaluateObservationWindow", function()
    local WINDOW_SEC = 1800
    local batchTime = "2026-02-14 08:00:00"
    local triggerTime = Utils.parseDatetimeToTimestamp(batchTime)

    ---Create a batch whose window opens at batchTime plus the given delay
    ---@param delay? number
    ---@return table
    local function makeWindowBatch(delay)
      return makeOperationBatch({ time = batchTime, delay = delay })
    end

    -- Negative: not due yet
    it("should report pre_trigger before the trigger time", function()
      local state = DynamicState.evaluateObservationWindow(triggerTime - 1, makeWindowBatch(0), WINDOW_SEC)

      assert.are.equal(DynamicState.OBSERVATION_STATE.PRE_TRIGGER, state)
    end)

    -- Boundary: the window opens exactly at the trigger time
    it("should report in_window exactly at the trigger time", function()
      local state = DynamicState.evaluateObservationWindow(triggerTime, makeWindowBatch(0), WINDOW_SEC)

      assert.are.equal(DynamicState.OBSERVATION_STATE.IN_WINDOW, state)
    end)

    -- Boundary: the last second of the window still counts as open
    it("should report in_window exactly at the window deadline", function()
      local state = DynamicState.evaluateObservationWindow(
        triggerTime + WINDOW_SEC,
        makeWindowBatch(0),
        WINDOW_SEC
      )

      assert.are.equal(DynamicState.OBSERVATION_STATE.IN_WINDOW, state)
    end)

    -- Boundary: one second past the deadline expires
    it("should report expired one second past the window deadline", function()
      local state = DynamicState.evaluateObservationWindow(
        triggerTime + WINDOW_SEC + 1,
        makeWindowBatch(0),
        WINDOW_SEC
      )

      assert.are.equal(DynamicState.OBSERVATION_STATE.EXPIRED, state)
    end)

    -- Positive: the batch delay pushes the whole window back
    it("should shift the window by the batch delay", function()
      local batch = makeWindowBatch(600)

      assert.are.equal(
        DynamicState.OBSERVATION_STATE.PRE_TRIGGER,
        DynamicState.evaluateObservationWindow(triggerTime + 599, batch, WINDOW_SEC)
      )
      assert.are.equal(
        DynamicState.OBSERVATION_STATE.IN_WINDOW,
        DynamicState.evaluateObservationWindow(triggerTime + 600, batch, WINDOW_SEC)
      )
    end)

    -- Boundary: a batch authored without a delay is treated as zero delay
    it("should treat a missing delay as zero", function()
      local state = DynamicState.evaluateObservationWindow(triggerTime, makeWindowBatch(nil), WINDOW_SEC)

      assert.are.equal(DynamicState.OBSERVATION_STATE.IN_WINDOW, state)
    end)
  end)

  -- ============================================================================
  -- generateUniqueAirOperationName
  -- ============================================================================

  describe("generateUniqueAirOperationName", function()
    -- Positive: first sequence, and the template wave-stage number is preserved (not swallowed)
    it("should generate first sequence name and preserve the template wave-stage number", function()
      local saveData = makeSaveData()

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", name)
      -- Wave-stage number stays recoverable as the trailing /<digits> of the template segment
      assert.are.equal("2", name:match("^AIR/STRIKE/AB/W/(%d+)/DYN"))
    end)

    -- Positive: UAV source passes through as uppercase (not in the abbreviation table)
    it("should pass through UAV source as uppercase in name", function()
      local saveData = makeSaveData()

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "UAV", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-UAV-01", name)
    end)

    -- Negative: skips names in generatedOperations.air
    it("should skip names already in generatedOperations.air", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = { ["AIR/STRIKE/AB/W/2/DYN-SAT-01"] = true },
          ground = {}
        }
      })

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-02", name)
    end)

    -- Negative: skips names in airTaskingOrder
    it("should skip names already in airTaskingOrder", function()
      local saveData = makeSaveData({
        airTaskingOrder = { ["AIR/STRIKE/AB/W/2/DYN-SAT-01"] = { name = "existing" } }
      })

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-02", name)
    end)

    -- Negative: skips names in both registries
    it("should skip names in both generatedOperations and airTaskingOrder", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = { ["AIR/STRIKE/AB/W/2/DYN-SAT-01"] = true },
          ground = {}
        },
        airTaskingOrder = { ["AIR/STRIKE/AB/W/2/DYN-SAT-02"] = { name = "existing" } }
      })

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-03", name)
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", name)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations.air)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations.ground)
    end)

    -- Boundary: nil airTaskingOrder
    it("should handle nil airTaskingOrder gracefully", function()
      local saveData = makeSaveData()
      saveData.c.air.airTaskingOrder = nil

      local name = DynamicState.generateUniqueAirOperationName("AIR/STRIKE/AB/W/2", "satellite", saveData)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", name)
    end)
  end)

  -- ============================================================================
  -- generateUniqueGroundOperationName
  -- ============================================================================

  describe("generateUniqueGroundOperationName", function()
    -- Positive: first sequence
    it("should generate first sequence name when nothing exists", function()
      local saveData = makeSaveData()

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "satellite", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-01", name)
    end)

    -- Positive: SIGINT source passes through as uppercase (not in the abbreviation table)
    it("should pass through SIGINT source as uppercase in name", function()
      local saveData = makeSaveData()

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "SIGINT", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SIGINT-01", name)
    end)

    -- Negative: skips names in generatedOperations.ground
    it("should skip names already in generatedOperations.ground", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = {},
          ground = { ["GND/STRIKE/INFRA/ALL/1/DYN-SAT-01"] = true }
        }
      })

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "satellite", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-02", name)
    end)

    -- Negative: skips names in fireSupportPlan
    it("should skip names already in fireSupportPlan", function()
      local saveData = makeSaveData({
        fireSupportPlan = { ["GND/STRIKE/INFRA/ALL/1/DYN-SAT-01"] = { name = "existing" } }
      })

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "satellite", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-02", name)
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "satellite", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-01", name)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
    end)

    -- Boundary: nil fireSupportPlan
    it("should handle nil fireSupportPlan gracefully", function()
      local saveData = makeSaveData()
      saveData.c.ground.fireSupportPlan = nil

      local name = DynamicState.generateUniqueGroundOperationName("GND/STRIKE/INFRA/ALL/1", "satellite", saveData)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-01", name)
    end)
  end)

  -- ============================================================================
  -- registerGeneratedOperation
  -- ============================================================================

  describe("registerGeneratedOperation", function()
    -- Positive: registers air operation
    it("should register air operation name", function()
      local saveData = makeSaveData()

      DynamicState.registerGeneratedOperation("air", "DYNAMIC/SAT/STRIKE/1", saveData)

      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["DYNAMIC/SAT/STRIKE/1"])
    end)

    -- Positive: registers ground operation
    it("should register ground operation name", function()
      local saveData = makeSaveData()

      DynamicState.registerGeneratedOperation("ground", "DYNAMIC/SAT/INFRA/1", saveData)

      assert.is_true(saveData.c.dynamicOperations.generatedOperations.ground["DYNAMIC/SAT/INFRA/1"])
    end)

    -- Positive: preserves existing registrations
    it("should not overwrite existing registrations", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = { ["EXISTING/1"] = true },
          ground = {}
        }
      })

      DynamicState.registerGeneratedOperation("air", "NEW/1", saveData)

      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["EXISTING/1"])
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["NEW/1"])
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      DynamicState.registerGeneratedOperation("air", "DYNAMIC/SAT/STRIKE/1", saveData)

      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["DYNAMIC/SAT/STRIKE/1"])
    end)
  end)
end)
