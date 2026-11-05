---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps FireSupportGate Unit Tests
local FireSupportGate = require("src.modules.landingOps.fireSupportGate")
local constants = require("src.core.constants")

describe("FireSupportGate", function()
  local PHASES = constants.AMPHIBIOUS_PHASES

  ---@param totalPercentage number
  ---@return SBJ__AmmoInventoryResult
  local function buildReport(totalPercentage)
    return {
      firing   = { current = 0, max = 0, percentage = 11 },
      resupply = { current = 0, max = 0, percentage = 22 },
      canisterStock = { current = 0, max = 0, percentage = 33 },
      total    = { current = 0, max = 0, percentage = totalPercentage },
    }
  end

  ---@param phases table<string, string> Zone name to phase
  ---@param onHold? boolean
  ---@return table config
  ---@return table landingState
  local function buildScene(phases, onHold)
    local zones, zoneStates = {}, {}
    for name, phase in pairs(phases) do
      table.insert(zones, { name = name })
      zoneStates[name] = { phase = phase }
    end
    local config = { red = { amphibOps = { zones = zones, fireSupport = { srbmHoldAmmoPct = 50 } } } }
    local landingState = {
      ground = {},
      amphibOps = { zoneStates = zoneStates, fireSupportOnHold = onHold },
    }
    return config, landingState
  end

  ---@param report? table
  ---@return fun(): table|nil reader
  ---@return table calls
  local function buildReader(report)
    local calls = { count = 0 }
    return function()
      calls.count = calls.count + 1
      return report
    end, calls
  end

  it("should hold and report the ammo levels when ammo is below the threshold and a zone has not arrived", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.MOVING })

    local result = FireSupportGate.evaluate(config, landingState, buildReader(buildReport(40)))

    assert.is_true(landingState.amphibOps.fireSupportOnHold)
    assert.are.same({
      tag = "HOLD",
      fields = {
        scope = "fireSupportGate", reason = "srbm_low",
        total = 40, threshold = 50, firing = 11, resupply = 22, canisterStock = 33,
      },
    }, result)
  end)

  it("should not hold when ammo is exactly at the threshold", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.MOVING })

    local result = FireSupportGate.evaluate(config, landingState, buildReader(buildReport(50)))

    assert.is_nil(result)
    assert.is_not_true(landingState.amphibOps.fireSupportOnHold)
  end)

  it("should resume once every zone reaches WAITING_ASSAULT or later", function()
    local config, landingState = buildScene({
      Taoyuan = PHASES.WAITING_ASSAULT,
      Tainan = PHASES.WAITING_ADMIN_OFFLOADING,
    }, true)

    local result = FireSupportGate.evaluate(config, landingState, buildReader(buildReport(40)))

    assert.is_false(landingState.amphibOps.fireSupportOnHold)
    assert.are.same({
      tag = "RESUME",
      fields = { scope = "fireSupportGate", reason = "all_zones_at_staging_waters" },
    }, result)
  end)

  it("should keep the hold while one zone is still waiting for arrival", function()
    local config, landingState = buildScene({
      Taoyuan = PHASES.WAITING_ASSAULT,
      Tainan = PHASES.WAITING_ARRIVAL,
    }, true)

    local result = FireSupportGate.evaluate(config, landingState, buildReader(buildReport(40)))

    assert.is_nil(result)
    assert.is_true(landingState.amphibOps.fireSupportOnHold)
  end)

  it("should treat a zone without a state as not arrived", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.WAITING_ASSAULT })
    table.insert(config.red.amphibOps.zones, { name = "Missing" })

    FireSupportGate.evaluate(config, landingState, buildReader(buildReport(40)))

    assert.is_true(landingState.amphibOps.fireSupportOnHold)
  end)

  it("should not read ammo while already on hold", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.MOVING }, true)
    local reader, calls = buildReader(buildReport(40))

    FireSupportGate.evaluate(config, landingState, reader)

    assert.are.equal(0, calls.count)
  end)

  it("should not read ammo once every zone has arrived", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.COMPLETED })
    local reader, calls = buildReader(buildReport(40))

    FireSupportGate.evaluate(config, landingState, reader)

    assert.are.equal(0, calls.count)
    assert.is_not_true(landingState.amphibOps.fireSupportOnHold)
  end)

  it("should do nothing when there are no ground forces or no ammo report", function()
    local config, landingState = buildScene({ Taoyuan = PHASES.MOVING })
    landingState.ground = nil
    assert.is_nil(FireSupportGate.evaluate(config, landingState, buildReader(buildReport(0))))

    landingState.ground = {}
    assert.is_nil(FireSupportGate.evaluate(config, landingState, buildReader(nil)))
    assert.is_not_true(landingState.amphibOps.fireSupportOnHold)
  end)
end)
