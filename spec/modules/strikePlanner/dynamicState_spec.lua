-- DynamicState Unit Tests
local DynamicState = require("src.modules.strikePlanner.dynamicState")

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
    -- Positive: marks with success
    it("should mark operation as executed with success", function()
      local op = makeOperation()
      local entry = makeOperationBatch({ operations = { op } })

      DynamicState.markOperationExecuted(entry, op, true)

      assert.is_true(op.executed)
      assert.is_true(op.executionResult)
    end)

    -- Positive: marks with failure
    it("should mark operation as executed with failure", function()
      local op = makeOperation()
      local entry = makeOperationBatch({ operations = { op } })

      DynamicState.markOperationExecuted(entry, op, false)

      assert.is_true(op.executed)
      assert.is_false(op.executionResult)
    end)

    -- Positive: completes entry when all done
    it("should mark reconEntry as completed when all operations are now executed", function()
      local op1 = makeOperation({ executed = true })
      local op2 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      DynamicState.markOperationExecuted(entry, op2, true)

      assert.is_true(entry.executed)
    end)

    -- Negative: does not complete entry when others remain
    it("should not mark reconEntry as completed when other operations remain", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local entry = makeOperationBatch({ operations = { op1, op2 } })

      DynamicState.markOperationExecuted(entry, op1, true)

      assert.is_false(entry.executed)
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
