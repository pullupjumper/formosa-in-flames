-- OperationType Unit Tests
local OperationType = require("src.modules.strikePlanner.operationType")

describe("OperationType", function()
  ---Create the minimal saveData shape both plan tables live in
  ---@return table
  local function makeSaveData()
    return {
      c = {
        air = { airTaskingOrder = { AIR_WAVE = {} } },
        ground = { fireSupportPlan = { GND_MATRIX = {} } }
      }
    }
  end

  -- Positive: the air descriptor points at package templates and the ATO
  it("should describe air operations", function()
    local descriptor = OperationType.resolve("air")
    local saveData = makeSaveData()

    assert.is_table(descriptor)
    assert.are.equal("packageTemplates", descriptor.templateSource)
    assert.are.equal("packages", descriptor.templateField)
    assert.are.equal("air", descriptor.registryKey)
    assert.are.equal(saveData.c.air.airTaskingOrder, descriptor.resolvePlan(saveData))
    assert.are.equal(900, descriptor.resolveDefaultInterval({ strikeInterval = 900 }))
  end)

  -- Positive: the ground descriptor points at fire support task templates and the FSP
  it("should describe ground operations", function()
    local descriptor = OperationType.resolve("ground")
    local saveData = makeSaveData()

    assert.is_table(descriptor)
    assert.are.equal("fireSupportTaskTemplates", descriptor.templateSource)
    assert.are.equal("fireSupportTasks", descriptor.templateField)
    assert.are.equal("ground", descriptor.registryKey)
    assert.are.equal(saveData.c.ground.fireSupportPlan, descriptor.resolvePlan(saveData))
    -- Ground dynamic FSP is TOT-oriented, so the interval is always zero
    assert.are.equal(0, descriptor.resolveDefaultInterval({ strikeInterval = 900 }))
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
