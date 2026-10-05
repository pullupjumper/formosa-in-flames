-- MissileSystem StatusView Unit Tests
local StatusView = require("src.modules.missileSystem.statusView")
local constants = require("src.core.constants")

describe("MissileSystem StatusView", function()
  local STATE = constants.MISSILE_SYSTEM_STATE

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a firing unit context that is mid-reload
  ---@param overrides? table
  ---@return table
  local function makeFiringUnitCtx(overrides)
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

  ---Create a resupply unit context that is not reloading
  ---@param overrides? table
  ---@return table
  local function makeResupplyUnitCtx(overrides)
    local ctx = { name = "RS-1", state = STATE.HIDE, weaponCountCurrent = 4, ammunition = "AHA-1" }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create an SRBM ground context with one paired battery and one idle resupply unit
  ---@param firingUnitCtx? table
  ---@param resupplyUnitCtx? table
  ---@return table
  local function makeGroundCtx(firingUnitCtx, resupplyUnitCtx)
    return {
      missileSystemTypes = {
        srbm = {
          firingUnits = { ["FU-1"] = firingUnitCtx or makeFiringUnitCtx() },
          resupplyUnits = {
            ["RS-1"] = resupplyUnitCtx or makeResupplyUnitCtx(),
            ["RS-2"] = makeResupplyUnitCtx({ name = "RS-2" })
          },
          ammunitions = { ["AHA-1"] = { weaponCountCurrent = 12 } }
        }
      }
    }
  end

  local missileSystemConfigMap = { srbm = { reloadTime = 1800 }, mlrs = { reloadTime = 600 } }

  ---Build statuses for SRBM and return the FU-1 status
  ---@param groundCtx table
  ---@param now number
  ---@return table
  local function buildRow(groundCtx, now)
    return StatusView.buildBatteryStatuses(groundCtx, missileSystemConfigMap, now)[1]
  end

  -- ============================================================================
  -- buildBatteryStatuses
  -- ============================================================================

  describe("buildBatteryStatuses", function()
    -- Positive: one status per firing unit
    it("should build one status per firing unit", function()
      local rows = StatusView.buildBatteryStatuses(makeGroundCtx(), missileSystemConfigMap, 1120)

      assert.are.same({
        {
          name = "FU-1",
          missileSystemType = "srbm",
          firingUnitState = "RELOAD",
          resupplyUnitState = "HIDE",
          missilesInAmmoVehicles = 4,
          missilesInAHA = 12,
          firingUnitReloadTime = 2,
          resupplyUnitReloadTime = 0,
          defaultReloadTime = 30
        }
      }, rows)
    end)

    -- Positive: idle resupply units have no firing unit, so they produce no status
    it("should skip resupply units without a firing unit", function()
      local rows = StatusView.buildBatteryStatuses(makeGroundCtx(), missileSystemConfigMap, 1120)

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
        local groundCtx = makeGroundCtx(makeFiringUnitCtx({ state = state }), makeResupplyUnitCtx({ state = state }))
        local row = buildRow(groundCtx, 1120)
        assert.are.equal(label, row.firingUnitState)
        assert.are.equal(label, row.resupplyUnitState)
      end
    end)

    -- Negative: a ground context without any missile system state produces no rows
    it("should return no statuses when there are no system contexts", function()
      local groundCtx = makeGroundCtx()
      groundCtx.missileSystemTypes = {}

      local rows = StatusView.buildBatteryStatuses(groundCtx, missileSystemConfigMap, 1120)

      assert.are.same({}, rows)
    end)

    -- Negative: an unexpected state still renders
    it("should label an unknown state as UNKNOWN", function()
      local row = buildRow(makeGroundCtx(makeFiringUnitCtx({ state = -99 })), 1120)

      assert.are.equal("UNKNOWN", row.firingUnitState)
    end)

    -- Boundary: 40 s is 0.666... minutes, which must round up rather than truncate
    it("should round elapsed reload minutes to 2 decimals", function()
      local row = buildRow(makeGroundCtx(), 1040)

      assert.are.equal(0.67, row.firingUnitReloadTime)
    end)

    -- Boundary: a start time after now must not show a negative countdown
    it("should clamp a reload that starts in the future to 0", function()
      local groundCtx = makeGroundCtx(
        makeFiringUnitCtx({ reloadStartTime = 2000 }),
        makeResupplyUnitCtx({ reloadStartTime = 3000 })
      )

      local row = buildRow(groundCtx, 1000)

      assert.are.equal(0, row.firingUnitReloadTime)
      assert.are.equal(0, row.resupplyUnitReloadTime)
    end)
  end)
end)
