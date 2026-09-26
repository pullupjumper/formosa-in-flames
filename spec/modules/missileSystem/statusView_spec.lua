-- MissileSystem StatusView Unit Tests
local StatusView = require("src.modules.missileSystem.statusView")
local constants = require("src.core.constants")

describe("MissileSystem StatusView", function()
  local STATE = constants.MISSILE_SYSTEM_STATE

  describe("formatState", function()
    it("should label known states", function()
      assert.are.equal("STATIC", StatusView.formatState(STATE.STATIC))
      assert.are.equal("REPOSITIONING", StatusView.formatState(STATE.REPOSITIONING))
      assert.are.equal("HIDE", StatusView.formatState(STATE.HIDE))
      assert.are.equal("RELOAD", StatusView.formatState(STATE.RELOAD))
    end)

    it("should label unknown states as UNKNOWN", function()
      assert.are.equal("UNKNOWN", StatusView.formatState(nil))
      assert.are.equal("UNKNOWN", StatusView.formatState(-99))
    end)
  end)

  describe("calculateReloadMinutes", function()
    it("should return 0 when not reloading", function()
      assert.are.equal(0, StatusView.calculateReloadMinutes(nil, 1000))
    end)

    it("should round elapsed minutes to 2 decimals", function()
      assert.are.equal(1.5, StatusView.calculateReloadMinutes(1000, 1090))
      assert.are.equal(0.33, StatusView.calculateReloadMinutes(1000, 1020))
    end)

    it("should clamp a future start time to 0", function()
      assert.are.equal(0, StatusView.calculateReloadMinutes(2000, 1000))
    end)
  end)

  describe("buildBatteryStatusRows", function()
    local function makeGroundCtx()
      return {
        srbm = {
          firingUnits = {
            ["FU-1"] = {
              name = "FU-1",
              state = STATE.RELOAD,
              resupplyUnit = "RS-1",
              reloadStartTime = 1000
            }
          },
          resupplyUnits = {
            ["RS-1"] = { name = "RS-1", state = STATE.HIDE, wpnCurrent = 4, ammunition = "AHA-1" },
            ["RS-2"] = { name = "RS-2", state = STATE.STATIC, wpnCurrent = 0, ammunition = "AHA-1" }
          },
          ammunitions = { ["AHA-1"] = { wpnCurrent = 12 } }
        }
      }
    end

    local groundCfg = { srbm = { reloadTime = 1800 }, mlrs = { reloadTime = 600 } }

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
  end)
end)
