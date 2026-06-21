-- MissileSystem Context Unit Tests
local stub = require("luassert.stub")
local Context = require("src.modules.missileSystem.context")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

describe("MissileSystem Context", function()
  ---@type luassert.spy[]
  local activeStubs

  local function makeSystemCtx(overrides)
    local ctx = {
      name = "srbm",
      reloadTime = 60,
      firingUnits = {
        ["Firing Unit Alpha"] = {
          name = "Firing Unit Alpha",
          state = constants.MISSILE_SYSTEM_STATE.RELOAD,
          resupplyUnit = "Ammo Sec, Alpha",
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          },
          weaponDBID = 1234,
          ammoThreshold = 60,
        }
      },
      resupplyUnits = {
        ["Ammo Sec, Alpha"] = {
          name = "Ammo Sec, Alpha",
          state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
          wpnCurrent = 10,
          wpnDefault = 20,
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          }
        }
      },
      ammunitions = {}
    }

    if overrides then
      for k, v in pairs(overrides) do
        ctx[k] = v
      end
    end

    return ctx
  end

  before_each(function()
    activeStubs = {}
    table.insert(activeStubs, stub(Logger, "log"))
    table.insert(activeStubs, stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- handleSupplyAssetDestruction
  -- ============================================================================

  describe("handleSupplyAssetDestruction", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = makeSystemCtx({
        firingUnits = {},
        resupplyUnits = {
          ["Resupply Group Alpha"] = {
            name = "Resupply Group Alpha",
            wpnCurrent = 20,
            wpnDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Beta"] = {
            name = "Resupply Group Beta",
            wpnCurrent = 3,
            wpnDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Empty"] = {
            name = "Resupply Group Empty",
            wpnCurrent = 0,
            wpnDefault = 20,
            unitCount = 4
          }
        },
        ammunitions = {
          ["Ammo Depot Alpha"] = {
            name = "Ammo Depot Alpha",
            wpnCurrent = 100
          },
          ["Ammo Depot Empty"] = {
            name = "Ammo Depot Empty",
            wpnCurrent = 0
          }
        }
      })
    end)

    -- Positive: clears ammo depot ammo on destruction
    it("should set wpnCurrent to 0 when ammo depot with ammo is destroyed", function()
      local unit = { name = "Ammo Depot Alpha" }

      local result, detail = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].wpnCurrent)
      assert.are.equal("ammo_depot", detail.role)
      assert.are.equal(100, detail.ammoBefore)
      assert.are.equal(0, detail.ammoAfter)
      assert.are.equal(-100, detail.delta)
    end)

    -- Positive: reduces resupply ammo proportionally on destruction
    it("should reduce wpnCurrent proportionally when resupply unit is destroyed", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }

      local result, detail = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(15, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].wpnCurrent)
      assert.are.equal("resupply_unit", detail.role)
      assert.are.equal("Resupply Group Alpha", detail.contextName)
      assert.are.equal(20, detail.ammoBefore)
      assert.are.equal(15, detail.ammoAfter)
      assert.are.equal(-5, detail.delta)
    end)

    -- Boundary: clamps resupply ammo at zero
    it("should set wpnCurrent to 0 when reduction would go negative", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Beta" }
      }

      local result = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Beta"].wpnCurrent)
    end)

    -- Negative: returns false when resupply unit has no ammo
    it("should return false when resupply unit has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result, detail = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
      assert.is_nil(detail)
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Empty"].wpnCurrent)
    end)

    -- Negative: returns false for unknown units
    it("should return false when unit is not in ammunitions or resupplyUnits", function()
      local unit = {
        name = "Unknown Unit",
        group = { name = "Unknown Group" }
      }

      local result = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
    end)

    -- Positive: handles multiple destructions correctly
    it("should handle multiple destructions correctly", function()
      local unit1 = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }
      local unit2 = {
        name = "Resupply Vehicle 2",
        group = { name = "Resupply Group Alpha" }
      }

      Context.handleSupplyAssetDestruction(unit1, mockSystemCtx)
      Context.handleSupplyAssetDestruction(unit2, mockSystemCtx)

      assert.are.equal(10, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].wpnCurrent)
    end)

    -- Positive: prioritizes ammo depot match over resupply group match
    it("should prioritize ammo depot match over resupply unit match", function()
      mockSystemCtx.resupplyUnits["Ammo Depot Alpha"] = {
        name = "Ammo Depot Alpha",
        wpnCurrent = 50,
        wpnDefault = 50,
        unitCount = 5
      }

      local unit = { name = "Ammo Depot Alpha" }

      local result = Context.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].wpnCurrent)
      assert.are.equal(50, mockSystemCtx.resupplyUnits["Ammo Depot Alpha"].wpnCurrent)
    end)
  end)

  -- ============================================================================
  -- initMissileSystemContexts
  -- ============================================================================

  describe("initMissileSystemContexts", function()
    -- Positive: initializes firing unit contexts from config
    it("should deep copy firing unit descriptors and set reloadStartTime to nil", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0, reloadStartTime = 999 }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.firingUnits["FU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("FU-1", ctx.name)
      assert.is_nil(ctx.reloadStartTime)
    end)

    -- Positive: initializes resupply unit contexts from config
    it("should deep copy resupply unit descriptors and set reloadStartTime to nil", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {
            ru1 = { name = "RU-1", state = 0, reloadStartTime = 888 }
          },
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.resupplyUnits["RU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("RU-1", ctx.name)
      assert.is_nil(ctx.reloadStartTime)
    end)

    -- Positive: initializes ammunition contexts from config
    it("should deep copy ammunition descriptors into context", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {},
          ammunitions = {
            ammo1 = { name = "Ammo-1", wpnCurrent = 50 }
          }
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.ammunitions["Ammo-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("Ammo-1", ctx.name)
      assert.are.equal(50, ctx.wpnCurrent)
    end)

    -- Positive: isolates context from config references
    it("should not share references between config and context", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0, operationalArea = { name = "OA-1" } }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      groundForceCtx.system1.firingUnits["FU-1"].operationalArea.name = "CHANGED"
      assert.are.equal("OA-1", groundForceCfg.system1.firingUnits.fu1.operationalArea.name)
    end)

    -- Positive: initializes contexts for multiple systems
    it("should initialize contexts for multiple missile systems", function()
      local groundForceCfg = {
        sysA = {
          firingUnits = { a = { name = "A", state = 0 } },
          resupplyUnits = {},
          ammunitions = {}
        },
        sysB = {
          firingUnits = {},
          resupplyUnits = { b = { name = "B", state = 0 } },
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        sysA = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
        sysB = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      assert.is_not_nil(groundForceCtx.sysA.firingUnits["A"])
      assert.is_not_nil(groundForceCtx.sysB.resupplyUnits["B"])
    end)
  end)
end)
