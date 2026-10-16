-- OperationType Unit Tests
local OperationType = require("src.modules.strikePlanner.operationType")
---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field

describe("OperationType", function()
  ---Create the minimal plannerState shape both plan tables live in
  ---@return table
  local function makePlannerState()
    return {
      air = { airTaskingOrder = { AIR_WAVE = {} } },
      ground = { fireSupportPlan = { GND_MATRIX = {} } }
    }
  end

  -- Positive: the air descriptor points at package templates and the ATO
  it("should describe air operations", function()
    local descriptor = OperationType.resolve("air")
    local plannerState = makePlannerState()
    local config = { red = { air = { strikeInterval = 900 } } }

    assert.is_table(descriptor)
    assert.are.equal("packageTemplates", descriptor.templateSource)
    assert.are.equal("packages", descriptor.templateField)
    assert.are.equal("air", descriptor.registryKey)
    assert.are.equal(plannerState.air.airTaskingOrder, descriptor.resolvePlan(plannerState))
    assert.are.equal(900, descriptor.resolveDefaultInterval(config))
  end)

  -- Positive: the ground descriptor points at fire support task templates and the FSP
  it("should describe ground operations", function()
    local descriptor = OperationType.resolve("ground")
    local plannerState = makePlannerState()
    local config = { red = { air = { strikeInterval = 900 } } }

    assert.is_table(descriptor)
    assert.are.equal("fireSupportTaskTemplates", descriptor.templateSource)
    assert.are.equal("fireSupportTasks", descriptor.templateField)
    assert.are.equal("ground", descriptor.registryKey)
    assert.are.equal(plannerState.ground.fireSupportPlan, descriptor.resolvePlan(plannerState))
    -- Ground dynamic FSP is TOT-oriented, so the interval is always zero
    assert.are.equal(0, descriptor.resolveDefaultInterval(config))
  end)

  -- Negative: an unknown type has no descriptor
  it("should return nil for an unknown operation type", function()
    assert.is_nil(OperationType.resolve("naval"))
  end)

  -- Boundary: nil type does not error
  it("should return nil for a nil operation type", function()
    assert.is_nil(OperationType.resolve(nil))
  end)
end)
