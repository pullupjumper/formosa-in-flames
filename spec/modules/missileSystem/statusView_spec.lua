-- MissileSystem StatusView Unit Tests
local StatusView = require("src.modules.missileSystem.statusView")
local constants = require("src.core.constants")

describe("MissileSystem StatusView", function()
  local STATE = constants.MISSILE_SYSTEM_STATE

  describe("buildBatteryStatusRows", function()
    ---Build a one-battery ground context; overrides apply to the firing and resupply unit contexts
    ---@param firingOverrides? table
    ---@param resupplyOverrides? table
    local function makeGroundCtx(firingOverrides, resupplyOverrides)
      local firingUnitCtx = {
        name = "FU-1",
        state = STATE.RELOAD,
        resupplyUnit = "RS-1",
        reloadStartTime = 1000
      }
      local resupplyUnitCtx = { name = "RS-1", state = STATE.HIDE, wpnCurrent = 4, ammunition = "AHA-1" }

      for k, v in pairs(firingOverrides or {}) do firingUnitCtx[k] = v end
      for k, v in pairs(resupplyOverrides or {}) do resupplyUnitCtx[k] = v end

      return {
        srbm = {
          firingUnits = { ["FU-1"] = firingUnitCtx },
          resupplyUnits = {
            ["RS-1"] = resupplyUnitCtx,
            ["RS-2"] = { name = "RS-2", state = STATE.STATIC, wpnCurrent = 0, ammunition = "AHA-1" }
          },
          ammunitions = { ["AHA-1"] = { wpnCurrent = 12 } }
        }
      }
    end

    local groundCfg = { srbm = { reloadTime = 1800 }, mlrs = { reloadTime = 600 } }

    ---Build rows and return the single FU-1 row
    local function buildRow(groundCtx, now)
      return StatusView.buildBatteryStatusRows(groundCtx, groundCfg, { "srbm" }, now)["RS-1"][1]
    end

    it("should group firing unit rows under their resupply unit", function()
      local rows = StatusView.buildBatteryStatusRows(makeGroundCtx(), groundCfg, { "srbm" }, 1120)

      assert.are.same({
        {
          name = "FU-1",
          missileSystem = "srbm",
          firingUnitState = "RELOAD",
          resupplyUnitState = "HIDE",
          missilesInAmmoVehicles = 4,
          missilesInAHA = 12,
          firingUnitReloadTime = 2,
          resupplyUnitReloadTime = 0,
          defaultReloadTime = 30
        }
      }, rows["RS-1"])
    end)

    it("should keep an empty row list for resupply units without a firing unit", function()
      local rows = StatusView.buildBatteryStatusRows(makeGroundCtx(), groundCfg, { "srbm" }, 1120)

      assert.are.same({}, rows["RS-2"])
    end)

    it("should skip system types that are not requested or have no context", function()
      local rows = StatusView.buildBatteryStatusRows(makeGroundCtx(), groundCfg, { "mlrs" }, 1120)

      assert.are.same({}, rows)
    end)

    it("should label every known state", function()
      local labels = {
        [STATE.STATIC] = "STATIC",
        [STATE.REPOSITIONING] = "REPOSITIONING",
        [STATE.HIDE] = "HIDE",
        [STATE.RELOAD] = "RELOAD",
      }

      for state, label in pairs(labels) do
        local row = buildRow(makeGroundCtx({ state = state }, { state = state }), 1120)
        assert.are.equal(label, row.firingUnitState)
        assert.are.equal(label, row.resupplyUnitState)
      end
    end)

    it("should label an unknown state as UNKNOWN", function()
      local row = buildRow(makeGroundCtx({ state = -99 }), 1120)

      assert.are.equal("UNKNOWN", row.firingUnitState)
    end)

    it("should round elapsed reload minutes to 2 decimals", function()
      assert.are.equal(1.5, buildRow(makeGroundCtx(), 1090).firingUnitReloadTime)
      assert.are.equal(0.33, buildRow(makeGroundCtx(), 1020).firingUnitReloadTime)
    end)

    it("should clamp a reload that starts in the future to 0", function()
      local row = buildRow(makeGroundCtx({ reloadStartTime = 2000 }, { reloadStartTime = 3000 }), 1000)

      assert.are.equal(0, row.firingUnitReloadTime)
      assert.are.equal(0, row.resupplyUnitReloadTime)
    end)

    it("should time the resupply unit's reload on its own start time", function()
      local row = buildRow(makeGroundCtx({ reloadStartTime = nil }, { reloadStartTime = 880 }), 1000)

      assert.are.equal(0, row.firingUnitReloadTime)
      assert.are.equal(2, row.resupplyUnitReloadTime)
    end)
  end)
end)
