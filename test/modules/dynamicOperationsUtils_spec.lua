-- DynamicOperationsUtils Unit Tests
---@diagnostic disable: undefined-field
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")

describe("DynamicOperationsUtils", function()
  local activeStubs

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

  ---Create a single operation
  ---@param overrides? table
  ---@return table
  local function makeOperation(overrides)
    local op = {
      type = "air",
      executed = false,
      template = { name = "STRIKE/AB/W/1" }
    }
    if overrides then
      for k, v in pairs(overrides) do op[k] = v end
    end
    return op
  end

  ---Create a reconnaissance schedule entry
  ---@param overrides? table
  ---@return table
  local function makeReconEntry(overrides)
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
          reconSchedule = overrides.reconSchedule or {},
          generatedOperations = overrides.generatedOperations or { air = {}, ground = {} }
        }
      }
    }
  end

  -- ============================================================================
  -- checkReconEntryCompleted
  -- ============================================================================

  describe("checkReconEntryCompleted", function()
    -- Positive: all operations executed
    it("should return true and set executed when all operations are executed", function()
      local entry = makeReconEntry({
        operations = {
          makeOperation({ executed = true }),
          makeOperation({ executed = true, type = "ground" }),
        }
      })

      local result = DynamicOperationsUtils.checkReconEntryCompleted(entry)

      assert.is_true(result)
      assert.is_true(entry.executed)
    end)

    -- Negative: some operations not executed
    it("should return false when some operations are not executed", function()
      local entry = makeReconEntry({
        operations = {
          makeOperation({ executed = true }),
          makeOperation({ executed = false }),
        }
      })

      local result = DynamicOperationsUtils.checkReconEntryCompleted(entry)

      assert.is_false(result)
      assert.is_false(entry.executed)
    end)

    -- Negative: single operation not executed
    it("should return false when single operation is not executed", function()
      local entry = makeReconEntry({
        operations = { makeOperation({ executed = false }) }
      })

      assert.is_false(DynamicOperationsUtils.checkReconEntryCompleted(entry))
    end)

    -- Boundary: nil operations
    it("should return true when operations is nil", function()
      local entry = makeReconEntry()
      entry.operations = nil

      local result = DynamicOperationsUtils.checkReconEntryCompleted(entry)

      assert.is_true(result)
    end)

    -- Boundary: empty operations
    it("should return true when operations is empty table", function()
      local entry = makeReconEntry({ operations = {} })

      local result = DynamicOperationsUtils.checkReconEntryCompleted(entry)

      assert.is_true(result)
      assert.is_true(entry.executed)
    end)
  end)

  -- ============================================================================
  -- updateReconScheduleStatus
  -- ============================================================================

  describe("updateReconScheduleStatus", function()
    -- Positive: marks completed entries
    it("should mark completed entries via checkReconEntryCompleted", function()
      local entry = makeReconEntry({
        operations = { makeOperation({ executed = true }) }
      })
      local saveData = makeSaveData({ reconSchedule = { entry } })

      DynamicOperationsUtils.updateReconScheduleStatus(saveData)

      assert.is_true(entry.executed)
    end)

    -- Positive: skips already executed
    it("should skip already executed entries", function()
      local entry = makeReconEntry({
        executed = true,
        operations = { makeOperation({ executed = false }) }
      })
      local saveData = makeSaveData({ reconSchedule = { entry } })

      DynamicOperationsUtils.updateReconScheduleStatus(saveData)

      -- Should remain true because already executed entries are skipped
      assert.is_true(entry.executed)
    end)

    -- Positive: processes multiple entries independently
    it("should process multiple entries independently", function()
      local entry1 = makeReconEntry({
        operations = { makeOperation({ executed = true }) }
      })
      local entry2 = makeReconEntry({
        operations = { makeOperation({ executed = false }) }
      })
      local saveData = makeSaveData({ reconSchedule = { entry1, entry2 } })

      DynamicOperationsUtils.updateReconScheduleStatus(saveData)

      assert.is_true(entry1.executed)
      assert.is_false(entry2.executed)
    end)

    -- Boundary: nil dynamicOperations
    it("should not error when dynamicOperations is nil", function()
      local saveData = { c = {} }

      assert.has_no.errors(function()
        DynamicOperationsUtils.updateReconScheduleStatus(saveData)
      end)
    end)

    -- Boundary: nil reconSchedule
    it("should not error when reconSchedule is nil", function()
      local saveData = { c = { dynamicOperations = {} } }

      assert.has_no.errors(function()
        DynamicOperationsUtils.updateReconScheduleStatus(saveData)
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
        makeReconEntry({ operations = { airOp, groundOp } })
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(1, #result)
      assert.are.equal(airOp, result[1].operation)
    end)

    -- Positive: returns ground operations
    it("should return ground operations from non-executed entries", function()
      local airOp = makeOperation({ type = "air" })
      local groundOp = makeOperation({ type = "ground" })
      local schedule = {
        makeReconEntry({ operations = { airOp, groundOp } })
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "ground")

      assert.are.equal(1, #result)
      assert.are.equal(groundOp, result[1].operation)
    end)

    -- Positive: includes parent reconEntry
    it("should include parent reconEntry in results", function()
      local entry = makeReconEntry()
      local schedule = { entry }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(1, #result)
      assert.are.equal(entry, result[1].reconEntry)
    end)

    -- Positive: collects across multiple entries
    it("should collect operations across multiple entries", function()
      local schedule = {
        makeReconEntry({ operations = { makeOperation({ type = "air" }) } }),
        makeReconEntry({
          time = "2026-02-14 10:00:00",
          operations = { makeOperation({ type = "air" }), makeOperation({ type = "air" }) }
        }),
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(3, #result)
    end)

    -- Negative: skips executed reconEntries
    it("should skip executed reconEntries", function()
      local schedule = {
        makeReconEntry({ executed = true })
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: skips executed operations
    it("should skip executed operations", function()
      local schedule = {
        makeReconEntry({
          operations = { makeOperation({ executed = true }) }
        })
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: skips entries with nil operations
    it("should skip entries with nil operations", function()
      local entry = makeReconEntry()
      entry.operations = nil
      local schedule = { entry }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Negative: no type match
    it("should return empty when no operations match the type", function()
      local schedule = {
        makeReconEntry({
          operations = { makeOperation({ type = "ground" }) }
        })
      }

      local result = DynamicOperationsUtils.filterOperationsByType(schedule, "air")

      assert.are.equal(0, #result)
    end)

    -- Boundary: empty schedule
    it("should return empty for empty schedule", function()
      local result = DynamicOperationsUtils.filterOperationsByType({}, "air")

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
      local entry = makeReconEntry({ operations = { op } })

      DynamicOperationsUtils.markOperationExecuted(entry, op, true)

      assert.is_true(op.executed)
      assert.is_true(op.executionResult)
    end)

    -- Positive: marks with failure
    it("should mark operation as executed with failure", function()
      local op = makeOperation()
      local entry = makeReconEntry({ operations = { op } })

      DynamicOperationsUtils.markOperationExecuted(entry, op, false)

      assert.is_true(op.executed)
      assert.is_false(op.executionResult)
    end)

    -- Positive: completes entry when all done
    it("should mark reconEntry as completed when all operations are now executed", function()
      local op1 = makeOperation({ executed = true })
      local op2 = makeOperation()
      local entry = makeReconEntry({ operations = { op1, op2 } })

      DynamicOperationsUtils.markOperationExecuted(entry, op2, true)

      assert.is_true(entry.executed)
    end)

    -- Negative: does not complete entry when others remain
    it("should not mark reconEntry as completed when other operations remain", function()
      local op1 = makeOperation()
      local op2 = makeOperation()
      local entry = makeReconEntry({ operations = { op1, op2 } })

      DynamicOperationsUtils.markOperationExecuted(entry, op1, true)

      assert.is_false(entry.executed)
    end)
  end)

  -- ============================================================================
  -- generateUniqueAirOperationName
  -- ============================================================================

  describe("generateUniqueAirOperationName", function()
    -- Positive: first sequence
    it("should generate first sequence name when nothing exists", function()
      local saveData = makeSaveData()

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("STRIKE/AB/W", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/STRIKE/AB/W/1", name)
    end)

    -- Positive: uppercases reconType
    it("should uppercase reconType in name", function()
      local saveData = makeSaveData()

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("ANTISHIP", "aircraft", saveData)

      assert.are.equal("DYNAMIC/AIRCRAFT/ANTISHIP/1", name)
    end)

    -- Negative: skips names in generatedOperations.air
    it("should skip names already in generatedOperations.air", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = { ["DYNAMIC/SATELLITE/STRIKE/AB/W/1"] = true },
          ground = {}
        }
      })

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("STRIKE/AB/W", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/STRIKE/AB/W/2", name)
    end)

    -- Negative: skips names in airTaskingOrder
    it("should skip names already in airTaskingOrder", function()
      local saveData = makeSaveData({
        airTaskingOrder = { ["DYNAMIC/AIRCRAFT/SEAD/1"] = { name = "existing" } }
      })

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("SEAD", "aircraft", saveData)

      assert.are.equal("DYNAMIC/AIRCRAFT/SEAD/2", name)
    end)

    -- Negative: skips names in both registries
    it("should skip names in both generatedOperations and airTaskingOrder", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = { ["DYNAMIC/SATELLITE/STRIKE/1"] = true },
          ground = {}
        },
        airTaskingOrder = { ["DYNAMIC/SATELLITE/STRIKE/2"] = { name = "existing" } }
      })

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("STRIKE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/STRIKE/3", name)
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("STRIKE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/STRIKE/1", name)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations.air)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations.ground)
    end)

    -- Boundary: nil airTaskingOrder
    it("should handle nil airTaskingOrder gracefully", function()
      local saveData = makeSaveData()
      saveData.c.air.airTaskingOrder = nil

      local name = DynamicOperationsUtils.generateUniqueAirOperationName("STRIKE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/STRIKE/1", name)
    end)
  end)

  -- ============================================================================
  -- generateUniqueGroundOperationName
  -- ============================================================================

  describe("generateUniqueGroundOperationName", function()
    -- Positive: first sequence
    it("should generate first sequence name when nothing exists", function()
      local saveData = makeSaveData()

      local name = DynamicOperationsUtils.generateUniqueGroundOperationName("INFRASTRUCTURE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/INFRASTRUCTURE/1", name)
    end)

    -- Negative: skips names in generatedOperations.ground
    it("should skip names already in generatedOperations.ground", function()
      local saveData = makeSaveData({
        generatedOperations = {
          air = {},
          ground = { ["DYNAMIC/SATELLITE/INFRASTRUCTURE/1"] = true }
        }
      })

      local name = DynamicOperationsUtils.generateUniqueGroundOperationName("INFRASTRUCTURE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/INFRASTRUCTURE/2", name)
    end)

    -- Negative: skips names in fireSupportPlan
    it("should skip names already in fireSupportPlan", function()
      local saveData = makeSaveData({
        fireSupportPlan = { ["DYNAMIC/AIRCRAFT/ANTISHIP/1"] = { name = "existing" } }
      })

      local name = DynamicOperationsUtils.generateUniqueGroundOperationName("ANTISHIP", "aircraft", saveData)

      assert.are.equal("DYNAMIC/AIRCRAFT/ANTISHIP/2", name)
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      local name = DynamicOperationsUtils.generateUniqueGroundOperationName("INFRASTRUCTURE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/INFRASTRUCTURE/1", name)
      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
    end)

    -- Boundary: nil fireSupportPlan
    it("should handle nil fireSupportPlan gracefully", function()
      local saveData = makeSaveData()
      saveData.c.ground.fireSupportPlan = nil

      local name = DynamicOperationsUtils.generateUniqueGroundOperationName("INFRASTRUCTURE", "satellite", saveData)

      assert.are.equal("DYNAMIC/SATELLITE/INFRASTRUCTURE/1", name)
    end)
  end)

  -- ============================================================================
  -- registerGeneratedOperation
  -- ============================================================================

  describe("registerGeneratedOperation", function()
    -- Positive: registers air operation
    it("should register air operation name", function()
      local saveData = makeSaveData()

      DynamicOperationsUtils.registerGeneratedOperation("air", "DYNAMIC/SAT/STRIKE/1", saveData)

      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["DYNAMIC/SAT/STRIKE/1"])
    end)

    -- Positive: registers ground operation
    it("should register ground operation name", function()
      local saveData = makeSaveData()

      DynamicOperationsUtils.registerGeneratedOperation("ground", "DYNAMIC/SAT/INFRA/1", saveData)

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

      DynamicOperationsUtils.registerGeneratedOperation("air", "NEW/1", saveData)

      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["EXISTING/1"])
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["NEW/1"])
    end)

    -- Boundary: nil generatedOperations
    it("should initialize generatedOperations when nil", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      DynamicOperationsUtils.registerGeneratedOperation("air", "DYNAMIC/SAT/STRIKE/1", saveData)

      assert.is_table(saveData.c.dynamicOperations.generatedOperations)
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air["DYNAMIC/SAT/STRIKE/1"])
    end)
  end)

  -- ============================================================================
  -- getLastExecutedOperationsAndNextTime
  -- ============================================================================

  describe("getLastExecutedOperationsAndNextTime", function()
    -- Positive: finds most recent past entry and classifies operations
    it("should find most recent past entry and classify operations", function()
      local airOp = makeOperation({ type = "air" })
      local groundOp = makeOperation({ type = "ground" })
      local schedule = {
        makeReconEntry({
          time = "2026-02-14 06:00:00",
          operations = { makeOperation({ type = "air" }) }
        }),
        makeReconEntry({
          time = "2026-02-14 08:00:00",
          operations = { airOp, groundOp }
        }),
      }

      -- Current time after both entries
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal(1, #result.air)
      assert.are.equal(1, #result.ground)
      assert.are.equal(airOp, result.air[1])
      assert.are.equal(groundOp, result.ground[1])
      assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
    end)

    -- Positive: finds next recon time
    it("should find next recon time from future entries", function()
      local schedule = {
        makeReconEntry({ time = "2026-02-14 06:00:00" }),
        makeReconEntry({ time = "2026-02-14 12:00:00" }),
        makeReconEntry({ time = "2026-02-14 18:00:00" }),
      }

      -- Current time between first and second entry
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 08:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal("2026-02-14 12:00:00", result.nextReconTime)
      assert.are.equal("2026-02-14 06:00:00", result.mostRecentTime)
    end)

    -- Positive: picks latest past entry from unordered schedule
    it("should pick latest past entry when schedule is not in time order", function()
      local laterOp = makeOperation({ type = "air" })
      local schedule = {
        makeReconEntry({ time = "2026-02-14 10:00:00", operations = { laterOp } }),
        makeReconEntry({ time = "2026-02-14 06:00:00", operations = { makeOperation() } }),
        makeReconEntry({ time = "2026-02-14 08:00:00", operations = { makeOperation() } }),
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 12:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal(1, #result.air)
      assert.are.equal(laterOp, result.air[1])
      assert.are.equal("2026-02-14 10:00:00", result.mostRecentTime)
    end)

    -- Positive: picks earliest future entry as nextReconTime
    it("should pick earliest future entry as nextReconTime when schedule is unordered", function()
      local schedule = {
        makeReconEntry({ time = "2026-02-14 18:00:00" }),
        makeReconEntry({ time = "2026-02-14 14:00:00" }),
        makeReconEntry({ time = "2026-02-14 06:00:00" }),
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal("2026-02-14 14:00:00", result.nextReconTime)
      assert.are.equal("2026-02-14 06:00:00", result.mostRecentTime)
    end)

    -- Negative: nil schedule
    it("should return empty result for nil schedule", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(nil)

      assert.are.equal(0, #result.air)
      assert.are.equal(0, #result.ground)
      assert.is_nil(result.nextReconTime)
      assert.is_nil(result.mostRecentTime)
    end)

    -- Negative: empty schedule
    it("should return empty result for empty schedule", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime({})

      assert.are.equal(0, #result.air)
      assert.are.equal(0, #result.ground)
      assert.is_nil(result.nextReconTime)
      assert.is_nil(result.mostRecentTime)
    end)

    -- Negative: GameApi returns nil
    it("should return empty result when GameApi returns nil", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(nil))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime({
        makeReconEntry()
      })

      assert.are.equal(0, #result.air)
      assert.are.equal(0, #result.ground)
      assert.is_nil(result.mostRecentTime)
    end)

    -- Boundary: all entries in future
    it("should return no operations but has nextReconTime when all entries are in future", function()
      local schedule = {
        makeReconEntry({ time = "2026-02-14 12:00:00" }),
        makeReconEntry({ time = "2026-02-14 18:00:00" }),
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 06:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal(0, #result.air)
      assert.are.equal(0, #result.ground)
      assert.are.equal("2026-02-14 12:00:00", result.nextReconTime)
      assert.is_nil(result.mostRecentTime)
    end)

    -- Boundary: all entries in past
    it("should return no nextReconTime when all entries are in past", function()
      local schedule = {
        makeReconEntry({ time = "2026-02-14 06:00:00" }),
        makeReconEntry({ time = "2026-02-14 08:00:00" }),
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 20:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.is_nil(result.nextReconTime)
      assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
    end)

    -- Boundary: entry with nil operations
    it("should handle entry with nil operations", function()
      local entry = makeReconEntry({ time = "2026-02-14 08:00:00" })
      entry.operations = nil
      local schedule = { entry }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp("2026-02-14 10:00:00")))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      assert.are.equal(0, #result.air)
      assert.are.equal(0, #result.ground)
      assert.are.equal("2026-02-14 08:00:00", result.mostRecentTime)
    end)

    -- Boundary: entry at exactly current time
    it("should handle entry at exactly current time as past", function()
      local op = makeOperation({ type = "ground" })
      local exactTime = "2026-02-14 08:00:00"
      local schedule = {
        makeReconEntry({ time = exactTime, operations = { op } }),
      }

      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(
        Utils.parseDatetimeToTimestamp(exactTime)))

      local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(schedule)

      -- entryTimestamp <= currentTimestamp, so it's included
      assert.are.equal(1, #result.ground)
    end)
  end)

  -- ============================================================================
  -- hasOperation
  -- ============================================================================

  describe("hasOperation", function()
    -- Positive: exact match
    it("should find exact match by template name and type", function()
      local op = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/1" } })
      local entry = makeReconEntry({ operations = { op } })

      local exists, foundOp, foundEntry = DynamicOperationsUtils.hasOperation(
        { entry }, "STRIKE/AB/W/1", "air")

      assert.is_true(exists)
      assert.are.equal(op, foundOp)
      assert.are.equal(entry, foundEntry)
    end)

    -- Positive: searches across multiple entries
    it("should search across multiple entries and operations", function()
      local targetOp = makeOperation({ type = "ground", template = { name = "INFRA/2" } })
      local schedule = {
        makeReconEntry({
          operations = { makeOperation({ type = "air", template = { name = "STRIKE/1" } }) }
        }),
        makeReconEntry({
          time = "2026-02-14 10:00:00",
          operations = {
            makeOperation({ type = "air", template = { name = "SEAD/1" } }),
            targetOp
          }
        }),
      }

      local exists, foundOp = DynamicOperationsUtils.hasOperation(schedule, "INFRA/2", "ground")

      assert.is_true(exists)
      assert.are.equal(targetOp, foundOp)
    end)

    -- Negative: type mismatch
    it("should not match when type differs", function()
      local op = makeOperation({ type = "ground", template = { name = "STRIKE/AB/W/1" } })
      local schedule = { makeReconEntry({ operations = { op } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/1", "air")

      assert.is_false(exists)
    end)

    -- Negative: name mismatch
    it("should not match when name differs", function()
      local op = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/1" } })
      local schedule = { makeReconEntry({ operations = { op } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/2", "air")

      assert.is_false(exists)
    end)

    -- Negative: nil inputs
    it("should return false for nil inputs", function()
      assert.is_false(DynamicOperationsUtils.hasOperation(nil, "STRIKE/1", "air"))
      assert.is_false(DynamicOperationsUtils.hasOperation({}, nil, "air"))
      assert.is_false(DynamicOperationsUtils.hasOperation({}, "STRIKE/1", nil))
    end)

    -- Negative: nil template
    it("should skip operations with nil template", function()
      local op = makeOperation({ template = nil })
      local schedule = { makeReconEntry({ operations = { op } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/1", "air")

      assert.is_false(exists)
    end)

    -- Negative: nil operations
    it("should skip entries with nil operations", function()
      local schedule = { makeReconEntry({ operations = nil }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/1", "air")

      assert.is_false(exists)
    end)

    -- Positive: prefix search finds highest number
    it("should find highest number with prefix search", function()
      local op1 = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/1" } })
      local op3 = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/3" } })
      local op2 = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/2" } })

      local schedule = {
        makeReconEntry({ operations = { op1, op3, op2 } })
      }

      local exists, foundOp = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/", "air")

      assert.is_true(exists)
      assert.are.equal(op3, foundOp)
    end)

    -- Positive: prefix search picks latest time on same number
    it("should pick latest time when prefix search finds same max number", function()
      local olderOp = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/2" } })
      local newerOp = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/2" } })

      local schedule = {
        makeReconEntry({ time = "2026-02-14 06:00:00", operations = { olderOp } }),
        makeReconEntry({ time = "2026-02-14 12:00:00", operations = { newerOp } }),
      }

      local exists, foundOp, foundEntry = DynamicOperationsUtils.hasOperation(
        schedule, "STRIKE/AB/W/", "air")

      assert.is_true(exists)
      assert.are.equal(newerOp, foundOp)
      assert.are.equal("2026-02-14 12:00:00", foundEntry.time)
    end)

    -- Negative: prefix search no matches
    it("should return false for prefix search with no matches", function()
      local op = makeOperation({ type = "air", template = { name = "SEAD/1" } })
      local schedule = { makeReconEntry({ operations = { op } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/", "air")

      assert.is_false(exists)
    end)

    -- Negative: prefix search ignores non-numeric suffix
    it("should ignore non-numeric suffix in prefix search", function()
      local op = makeOperation({ type = "air", template = { name = "STRIKE/AB/W/abc" } })
      local schedule = { makeReconEntry({ operations = { op } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/", "air")

      assert.is_false(exists)
    end)

    -- Negative: prefix search filters by type
    it("should filter by type in prefix search", function()
      local groundOp = makeOperation({ type = "ground", template = { name = "STRIKE/AB/W/5" } })
      local schedule = { makeReconEntry({ operations = { groundOp } }) }

      local exists = DynamicOperationsUtils.hasOperation(schedule, "STRIKE/AB/W/", "air")

      assert.is_false(exists)
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
          name = "STRIKE/AB/W/1",
          isFirstWave = true,
          strikeInterval = 120,
          packages = { { striker = {} } }
        }
      })
      local config = {
        c = {
          packageTemplates = {
            STRIKE_AB_W_2 = { { striker = { baseGUID = "NEW-BASE" } } }
          }
        }
      }

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

      assert.are.equal("STRIKE/AB/W/2", result.template.name)
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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

      assert.are.equal("STRIKE/AB/100", result.template.name)
      assert.are.equal("FOUND_NEXT", status)
    end)

    -- Negative: reuses current air template when next not found
    it("should reuse current template when next is not found for air", function()
      local originalPackages = { { striker = { baseGUID = "BASE-1" } } }
      local operation = makeOperation({
        type = "air",
        template = {
          name = "STRIKE/AB/W/5",
          isFirstWave = true,
          strikeInterval = 90,
          packages = originalPackages
        }
      })
      local config = { c = { packageTemplates = {} } }

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

      -- Name stays the same when reusing
      assert.are.equal("STRIKE/AB/W/5", result.template.name)
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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

      assert.are.equal("air", result.type)
      -- Returns a copy of the original, not a new operation
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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

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

      local result, status = DynamicOperationsUtils.generateNextOperation(operation, config)

      assert.are.equal(0, result.template.strikeInterval)
      assert.are.equal("FOUND_NEXT", status)
    end)
  end)
end)
