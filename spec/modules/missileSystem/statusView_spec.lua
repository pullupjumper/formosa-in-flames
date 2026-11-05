---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem StatusView Unit Tests
local StatusView = require("src.modules.missileSystem.statusView")
local constants = require("src.core.constants")

describe("MissileSystem StatusView", function()
  local STATE = constants.MISSILE_SYSTEM_STATE

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a firing unit state that is mid-reload
  ---@param overrides? table
  ---@return table
  local function makeFiringUnitState(overrides)
    local ctx = {
      name = "FU-1",
      state = STATE.RELOAD,
      resupplyUnit = "RS-1",
      reloadStartTime = 1000
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a resupply unit state that is not reloading
  ---@param overrides? table
  ---@return table
  local function makeResupplyUnitState(overrides)
    local ctx = { name = "RS-1", state = STATE.HIDE, weaponCountCurrent = 4, canisterStock = "ATP-1" }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create an SRBM ground state with one paired battery and one idle resupply unit
  ---@param firingUnitState? table
  ---@param resupplyUnitState? table
  ---@return table
  local function makeGroundState(firingUnitState, resupplyUnitState)
    return {
      missileSystemTypes = {
        srbm = {
          firingUnits = { ["FU-1"] = firingUnitState or makeFiringUnitState() },
          resupplyUnits = {
            ["RS-1"] = resupplyUnitState or makeResupplyUnitState(),
            ["RS-2"] = makeResupplyUnitState({ name = "RS-2" })
          },
          canisterStocks = { ["ATP-1"] = { weaponCountCurrent = 12 } }
        }
      }
    }
  end

  local missileSystemConfigMap = { srbm = { reloadTime = 1800 }, mlrs = { reloadTime = 600 } }

  ---Build statuses for SRBM and return the FU-1 status
  ---@param groundState table
  ---@param now number
  ---@return table
  local function buildRow(groundState, now)
    return StatusView.buildBatteryStatuses(groundState, missileSystemConfigMap, now)[1]
  end

  -- ============================================================================
  -- buildBatteryStatuses
  -- ============================================================================

  describe("buildBatteryStatuses", function()
    -- Positive: one status per firing unit
    it("should build one status per firing unit", function()
      local rows = StatusView.buildBatteryStatuses(makeGroundState(), missileSystemConfigMap, 1120)

      assert.are.same({
        {
          name = "FU-1",
          missileSystemType = "srbm",
          firingUnitState = "RELOAD",
          resupplyUnitState = "HIDE",
          missilesInAmmoVehicles = 4,
          missilesInATP = 12,
          firingUnitReloadTime = 2,
          resupplyUnitReloadTime = 0,
          defaultReloadTime = 30
        }
      }, rows)
    end)

    it("should report the default ammo counts of the resupply unit and its canister stock", function()
      local groundState = makeGroundState(nil, makeResupplyUnitState({ weaponCountDefault = 8 }))
      groundState.missileSystemTypes.srbm.canisterStocks["ATP-1"].weaponCountDefault = 24

      local row = buildRow(groundState, 1120)

      assert.are.equal(8, row.missilesInTransloaderDefault)
      assert.are.equal(24, row.missilesInATPDefault)
    end)

    -- Positive: idle resupply units have no firing unit, so they produce no status
    it("should skip resupply units without a firing unit", function()
      local rows = StatusView.buildBatteryStatuses(makeGroundState(), missileSystemConfigMap, 1120)

      assert.are.equal(1, #rows)
    end)

    -- Positive: every known state has its own label
    it("should label every known state", function()
      local labels = {
        [STATE.STATIC] = "STATIC",
        [STATE.REPOSITIONING] = "REPOSITIONING",
        [STATE.HIDE] = "HIDE",
        [STATE.RELOAD] = "RELOAD",
      }

      for state, label in pairs(labels) do
        local groundState = makeGroundState(makeFiringUnitState({ state = state }), makeResupplyUnitState({ state = state }))
        local row = buildRow(groundState, 1120)
        assert.are.equal(label, row.firingUnitState)
        assert.are.equal(label, row.resupplyUnitState)
      end
    end)

    -- Negative: a ground state without any missile system state produces no rows
    it("should return no statuses when there are no system contexts", function()
      local groundState = makeGroundState()
      groundState.missileSystemTypes = {}

      local rows = StatusView.buildBatteryStatuses(groundState, missileSystemConfigMap, 1120)

      assert.are.same({}, rows)
    end)

    -- Negative: an unexpected state still renders
    it("should label an unknown state as UNKNOWN", function()
      local row = buildRow(makeGroundState(makeFiringUnitState({ state = -99 })), 1120)

      assert.are.equal("UNKNOWN", row.firingUnitState)
    end)

    -- Boundary: 40 s is 0.666... minutes, which must round up rather than truncate
    it("should round elapsed reload minutes to 2 decimals", function()
      local row = buildRow(makeGroundState(), 1040)

      assert.are.equal(0.67, row.firingUnitReloadTime)
    end)

    -- Boundary: a start time after now must not show a negative countdown
    it("should clamp a reload that starts in the future to 0", function()
      local groundState = makeGroundState(
        makeFiringUnitState({ reloadStartTime = 2000 }),
        makeResupplyUnitState({ reloadStartTime = 3000 })
      )

      local row = buildRow(groundState, 1000)

      assert.are.equal(0, row.firingUnitReloadTime)
      assert.are.equal(0, row.resupplyUnitReloadTime)
    end)
  end)
end)
